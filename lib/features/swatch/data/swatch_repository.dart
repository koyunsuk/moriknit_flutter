// lib/features/swatch/data/swatch_repository.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../domain/swatch_model.dart';
import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/sync/conflict_resolver.dart';
import '../../../core/sync/sync_queue.dart';
import '../../sync/presentation/conflict_inbox_screen.dart' show ConflictItem;

class SwatchRepository {
  SwatchRepository({SyncQueue? syncQueue}) : _syncQueue = syncQueue;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SyncQueue? _syncQueue;
  static const _uuid = Uuid();

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _swatchesRef =>
      _db.collection('users').doc(_uid).collection('swatches');

  DocumentReference get _userRef =>
      _db.collection('users').doc(_uid);

  // ── CREATE ───────────────────────────────────────────────
  Future<SwatchModel> createSwatch(SwatchModel swatch) async {
    // 세션 체크
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    // 수축률 자동 계산
    final calculated = swatch.copyWith(
      shrinkageRate: swatch.calculateShrinkageRate(),
      updatedAt: DateTime.now(),
    );

    // Hive에 즉시 저장 (오프라인 안전)
    await _saveToHive(calculated);

    // Firestore에 저장 + usage.swatchCount +1 (트랜잭션)
    try {
      final docRef = swatch.id.isEmpty
          ? _swatchesRef.doc()
          : _swatchesRef.doc(swatch.id);

      await _db.runTransaction((transaction) async {
        transaction.set(docRef, {
          ...calculated.toJson(),
          'id': docRef.id,
          'uid': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isDirty': false,
        });
        // usage.swatchCount 증가
        transaction.update(_userRef, {
          'usage.swatchCount': FieldValue.increment(1),
        });
      }).withServerTimeout(op: 'create_swatch_tx');

      final saved = calculated.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved); // Hive 업데이트 (id 반영)
      return saved;
    } catch (e) {
      // Firestore 실패 시 Hive에 dirty 상태로 유지 → 나중에 sync
      // 임시 ID 생성 (id가 비어있는 신규 작성 케이스)
      final tempId = calculated.id.isEmpty
          ? 'local_${DateTime.now().millisecondsSinceEpoch}'
          : calculated.id;
      final dirty = calculated.copyWith(id: tempId, isDirty: true);
      await _saveToHive(dirty);
      await _enqueueSync(entity: 'swatch', docId: tempId, op: 'create', data: dirty.toJson());
      return dirty;
    }
  }

  // ── DUPLICATE ────────────────────────────────────────────
  Future<SwatchModel> duplicateSwatch(SwatchModel original) async {
    final now = DateTime.now();
    final copy = original.copyWith(
      id: '',
      swatchName: original.swatchName.isEmpty
          ? ''
          : '${original.swatchName} (복사)',
      createdAt: now,
      updatedAt: now,
      isDirty: false,
    );
    return createSwatch(copy);
  }

  // ── READ (목록) ──────────────────────────────────────────
  Stream<List<SwatchModel>> watchSwatches() {
    if (_uid.isEmpty) return Stream.value([]);
    return _swatchesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SwatchModel.fromFirestore(doc))
            .toList())
        .handleError((Object error, StackTrace _) {
          debugPrint('[watchSwatches] firestore error, falling back to Hive: $error');
        })
        .transform(StreamTransformer<List<SwatchModel>, List<SwatchModel>>.fromHandlers(
          handleError: (error, _, sink) {
            sink.add(_loadAllFromHive());
          },
        ));
  }

  // ── READ (단건, 스트림) ──────────────────────────────────
  Stream<SwatchModel?> watchSwatch(String swatchId) {
    if (_uid.isEmpty) return Stream.value(null);
    return _swatchesRef.doc(swatchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SwatchModel.fromFirestore(doc);
    }).transform(StreamTransformer<SwatchModel?, SwatchModel?>.fromHandlers(
      handleError: (error, _, sink) {
        debugPrint('[watchSwatch] firestore error, falling back to Hive: $error');
        sink.add(_loadFromHive(swatchId));
      },
    ));
  }

  // ── READ (단건) ──────────────────────────────────────────
  Future<SwatchModel?> getSwatch(String swatchId) async {
    try {
      final doc = await _swatchesRef.doc(swatchId).get().withServerTimeout(op: 'get_swatch');
      if (!doc.exists) return _loadFromHive(swatchId);
      return SwatchModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[getSwatch] firestore error, falling back to Hive: $e');
      return _loadFromHive(swatchId);
    }
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<SwatchModel> updateSwatch(SwatchModel swatch) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = swatch.copyWith(
      shrinkageRate: swatch.calculateShrinkageRate(),
      updatedAt: DateTime.now(),
    );

    await _saveToHive(updated);

    try {
      await _swatchesRef.doc(swatch.id).update({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
      }).withServerTimeout(op: 'update_swatch');
      return updated.copyWith(isDirty: false);
    } catch (e) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      await _enqueueSync(entity: 'swatch', docId: swatch.id, op: 'update', data: dirty.toJson());
      return dirty;
    }
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteSwatch(String swatchId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    // Hive에서 제거
    await _removeFromHive(swatchId);

    // Firestore 삭제 + usage.swatchCount -1
    try {
      await _db.runTransaction((transaction) async {
        transaction.delete(_swatchesRef.doc(swatchId));
        transaction.update(_userRef, {
          'usage.swatchCount': FieldValue.increment(-1),
        });
      }).withServerTimeout(op: 'delete_swatch_tx');
    } catch (e) {
      debugPrint('[deleteSwatch] firestore error, enqueueing for later: $e');
      await _enqueueSync(entity: 'swatch', docId: swatchId, op: 'delete', data: {'id': swatchId});
    }
  }

  // ── Hive 로컬 저장 ───────────────────────────────────────
  Future<void> _saveToHive(SwatchModel swatch) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    await box.put(swatch.id.isEmpty ? 'temp_${DateTime.now().millisecondsSinceEpoch}' : swatch.id,
        swatch.toJson());
  }

  Future<void> _removeFromHive(String swatchId) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    await box.delete(swatchId);
  }

  // ── Hive 로컬 읽기 (Firestore 폴백) ──────────────────────
  SwatchModel? _loadFromHive(String swatchId) {
    if (kIsWeb) return null;
    if (!Hive.isBoxOpen(SubscriptionConstants.boxSwatches)) return null;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
      final data = box.get(swatchId);
      if (data == null) return null;
      return SwatchModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[_loadFromHive] parse error: $e');
      return null;
    }
  }

  List<SwatchModel> _loadAllFromHive() {
    if (kIsWeb) return const [];
    if (!Hive.isBoxOpen(SubscriptionConstants.boxSwatches)) return const [];
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
      final list = <SwatchModel>[];
      for (final raw in box.values) {
        try {
          list.add(SwatchModel.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    } catch (e) {
      debugPrint('[_loadAllFromHive] error: $e');
      return const [];
    }
  }

  // ── SyncQueue 적재 (Phase 1 인프라) ─────────────────────
  Future<void> _enqueueSync({
    required String entity,
    required String docId,
    required String op,
    required Map<String, dynamic> data,
  }) async {
    final queue = _syncQueue;
    if (queue == null) return;
    try {
      await queue.enqueue(SyncOp(
        id: _uuid.v4(),
        entity: entity,
        docId: docId,
        op: op,
        data: data,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('[_enqueueSync] enqueue error: $e');
    }
  }

  // ── #704 Phase 2 — SyncQueue 에서 위임된 push ─────────────────
  /// SyncOrchestrator 가 큐에서 꺼낸 SyncOp 를 Firestore 로 push.
  ///
  /// 흐름:
  /// 1. 서버 최신 doc fetch → updatedAt 비교
  /// 2. 서버가 더 최신이면 manual 정책 → ConflictItem 적재 후 push 보류
  /// 3. 그 외에는 op.data 를 그대로 set/merge
  /// 4. 성공 시 Hive 의 isDirty=false 갱신
  ///
  /// [onConflict] manual 충돌을 ConflictInbox 로 보내는 콜백.
  /// 회귀 방지: 일반 create/update 경로(`createSwatch`/`updateSwatch`)는 영향 없음.
  Future<void> pushFromSync(
    SyncOp op, {
    void Function(ConflictItem item)? onConflict,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final data = op.data;
    final docId = op.docId;
    final docRef = _swatchesRef.doc(docId);

    // 1) 서버 최신본 확인.
    DocumentSnapshot? serverDoc;
    try {
      serverDoc = await docRef.get().withServerTimeout(op: 'push_from_sync_get');
    } catch (e) {
      debugPrint('[pushFromSync] server fetch failed: $e');
      rethrow; // 큐는 다음 사이클에 재시도.
    }

    // 2) 충돌 감지 — local.updatedAt < server.updatedAt.
    if (serverDoc.exists) {
      final serverData = serverDoc.data() as Map<String, dynamic>?;
      final serverUpdatedAt = _parseUpdatedAt(serverData?['updatedAt']);
      final localUpdatedAt = _parseUpdatedAt(data['updatedAt']);
      if (serverUpdatedAt != null &&
          localUpdatedAt != null &&
          localUpdatedAt.isBefore(serverUpdatedAt)) {
        // ConflictResolver — swatch 는 manual 정책 (사용자 선택).
        const resolver = ConflictResolver<Map<String, dynamic>>(
          policy: ConflictPolicy.manual,
        );
        try {
          resolver.resolve(data, serverData ?? const {});
        } on ManualResolutionRequired {
          // 인박스에 적재 후 종료 — markDone 되지 않도록 throw.
          if (onConflict != null && serverData != null) {
            onConflict(_buildSwatchConflictItem(
              opId: op.id,
              docId: docId,
              local: data,
              server: serverData,
              localUpdatedAt: localUpdatedAt,
              serverUpdatedAt: serverUpdatedAt,
            ));
          }
          // 사용자가 해결할 때까지 보류. 큐에서 빼지 않기 위해 throw.
          throw _ConflictPending('swatch $docId conflict — sent to inbox');
        }
      }
    }

    // 3) push (set + merge 로 create/update 통합).
    final payload = Map<String, dynamic>.from(data)
      ..['id'] = docId
      ..['uid'] = _uid
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['isDirty'] = false;
    await docRef.set(payload, SetOptions(merge: true))
        .withServerTimeout(op: 'push_from_sync_set');

    // 4) Hive dirty 해제.
    try {
      final hiveModel = SwatchModel.fromJson(Map<String, dynamic>.from(data))
          .copyWith(id: docId, isDirty: false);
      await _saveToHive(hiveModel);
    } catch (e) {
      debugPrint('[pushFromSync] hive dirty clear failed: $e');
    }
  }

  DateTime? _parseUpdatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  ConflictItem _buildSwatchConflictItem({
    required String opId,
    required String docId,
    required Map<String, dynamic> local,
    required Map<String, dynamic> server,
    DateTime? localUpdatedAt,
    DateTime? serverUpdatedAt,
  }) {
    String s(dynamic v) => v?.toString() ?? '';
    const fields = ['swatchName', 'beforeStitchCount', 'beforeRowCount', 'memo'];
    final localFields = {for (final k in fields) k: s(local[k])};
    final serverFields = {for (final k in fields) k: s(server[k])};
    return ConflictItem(
      id: opId,
      entity: 'swatch',
      docId: docId,
      title: s(local['swatchName']).isEmpty ? '(이름 없음)' : s(local['swatchName']),
      localFields: localFields,
      serverFields: serverFields,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
    );
  }

  // ── Dirty 항목 sync (30분마다 호출) ─────────────────────
  Future<void> syncDirtySwatches() async {
    if (kIsWeb || _uid.isEmpty) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data['isDirty'] == true) {
        try {
          final swatch = SwatchModel.fromJson(Map<String, dynamic>.from(data));
          await updateSwatch(swatch);
        } catch (e) {
          // sync 실패 시 다음 타이머에 재시도
        }
      }
    }
  }
}

/// #704 Phase 2 — pushFromSync 가 충돌을 인박스로 보낸 뒤 큐에서 빼지 않도록
/// 던지는 내부 마커 예외. SyncOrchestrator 는 일반 예외와 동일하게 다음 사이클에
/// 재시도하지만, 사용자가 인박스에서 해결할 때까지 op 는 큐에 남는다.
class _ConflictPending implements Exception {
  final String message;
  const _ConflictPending(this.message);
  @override
  String toString() => 'ConflictPending: $message';
}
