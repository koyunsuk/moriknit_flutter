// lib/features/blueprint/data/step_blueprint_repository.dart
//
// 이슈 #687 (Phase G) — StepBlueprint Repository.
//
// 컬렉션 경로:
//   - step_blueprints/{bid}                    (전역, ownerUid 필드)
//   - step_blueprints/{bid}/units/{unitId}     (subcollection)
//
// 책임:
//   1. CRUD (create / get / update / delete / watch)
//   2. units subcollection 관리 (batch 저장)
//   3. 버전 발행 (publishVersion)
//   4. Fork (다른 청사진을 내 청사진으로 복제)
//   5. visibility별 query
//
// 본격 권한 검사는 Firestore Rules에 위임. 본 Repository는 데이터 정합성만 책임.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/errors/network_errors.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart' as pat;
import '../../project/domain/builtin_template.dart' as bt;
import '../domain/step_blueprint.dart';
import '../domain/step_blueprint_unit.dart';
import '../domain/step_unit_groupmeta.dart';

class StepBlueprintRepository {
  StepBlueprintRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _root =>
      _db.collection('step_blueprints');

  DocumentReference<Map<String, dynamic>> _doc(String id) => _root.doc(id);

  CollectionReference<Map<String, dynamic>> _unitsCol(String bid) =>
      _doc(bid).collection('units');

  // ── helpers ────────────────────────────────────────────────────────────────

  StepBlueprint _readBlueprint(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepBlueprint.fromMap({...data, 'id': snap.id});
  }

  StepBlueprintUnit _readUnit(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepBlueprintUnit.fromMap({...data, 'id': snap.id});
  }

  // ── #704 Phase 2 : Hive 폴백 캐시 헬퍼 ────────────────────────────────────
  //
  // "종이 도안 대체성" — 오프라인에서도 도안 단계가 보여야 카운터/타이머가 유효.
  // - blueprintBox: key = blueprintId, value = StepBlueprint.toMap()
  // - unitsBox:     key = blueprintId, value = { 'units': [unit.toMap(), ...] }
  // 박스가 닫혀 있거나 웹 환경이면 null 반환 (조용히 폴백 skip).

  Box<Map>? get _blueprintBox {
    if (!Hive.isBoxOpen(SubscriptionConstants.boxStepBlueprintsHiveCache)) {
      return null;
    }
    return Hive.box<Map>(SubscriptionConstants.boxStepBlueprintsHiveCache);
  }

  Box<Map>? get _unitsBox {
    if (!Hive.isBoxOpen(SubscriptionConstants.boxStepBlueprintUnitsHiveCache)) {
      return null;
    }
    return Hive.box<Map>(SubscriptionConstants.boxStepBlueprintUnitsHiveCache);
  }

  Future<void> _cacheBlueprint(StepBlueprint b) async {
    final box = _blueprintBox;
    if (box == null || b.id.isEmpty) return;
    try {
      await box.put(b.id, b.toMap());
    } catch (e) {
      debugPrint('StepBlueprintRepository: blueprint Hive write failed - $e');
    }
  }

  Future<void> _cacheBlueprints(Iterable<StepBlueprint> list) async {
    final box = _blueprintBox;
    if (box == null) return;
    try {
      for (final b in list) {
        if (b.id.isEmpty) continue;
        await box.put(b.id, b.toMap());
      }
    } catch (e) {
      debugPrint('StepBlueprintRepository: blueprint Hive bulk write failed - $e');
    }
  }

  StepBlueprint? _readBlueprintFromHive(String id) {
    final box = _blueprintBox;
    if (box == null || id.isEmpty) return null;
    try {
      final raw = box.get(id);
      if (raw == null) return null;
      return StepBlueprint.fromMap(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('StepBlueprintRepository: blueprint Hive read failed - $e');
      return null;
    }
  }

  /// ownerUid 로 Hive 폴백 리스트 — updatedAt desc 정렬.
  List<StepBlueprint> _readBlueprintsByOwnerFromHive(String ownerUid) {
    final box = _blueprintBox;
    if (box == null || ownerUid.isEmpty) return const [];
    try {
      final result = <StepBlueprint>[];
      for (final raw in box.values) {
        try {
          final map = Map<String, dynamic>.from(raw);
          if ((map['ownerUid'] as String?) != ownerUid) continue;
          result.add(StepBlueprint.fromMap(map));
        } catch (_) {
          /* skip invalid entry */
        }
      }
      result.sort((a, b) {
        final au = a.updatedAt ?? a.createdAt;
        final bu = b.updatedAt ?? b.createdAt;
        return bu.compareTo(au);
      });
      return result;
    } catch (e) {
      debugPrint('StepBlueprintRepository: blueprint Hive owner read failed - $e');
      return const [];
    }
  }

  Future<void> _removeBlueprintFromHive(String id) async {
    final box = _blueprintBox;
    if (box == null || id.isEmpty) return;
    try {
      await box.delete(id);
    } catch (e) {
      debugPrint('StepBlueprintRepository: blueprint Hive delete failed - $e');
    }
  }

  Future<void> _cacheUnits(
    String blueprintId,
    List<StepBlueprintUnit> units,
  ) async {
    final box = _unitsBox;
    if (box == null || blueprintId.isEmpty) return;
    try {
      await box.put(blueprintId, {
        'units': units.map((u) => u.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('StepBlueprintRepository: units Hive write failed - $e');
    }
  }

  List<StepBlueprintUnit>? _readUnitsFromHive(String blueprintId) {
    final box = _unitsBox;
    if (box == null || blueprintId.isEmpty) return null;
    try {
      final raw = box.get(blueprintId);
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw);
      final list = (map['units'] as List?) ?? const [];
      final units = list
          .map((e) =>
              StepBlueprintUnit.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      units.sort((a, b) => a.order.compareTo(b.order));
      return units;
    } catch (e) {
      debugPrint('StepBlueprintRepository: units Hive read failed - $e');
      return null;
    }
  }

  Future<void> _removeUnitsFromHive(String blueprintId) async {
    final box = _unitsBox;
    if (box == null || blueprintId.isEmpty) return;
    try {
      await box.delete(blueprintId);
    } catch (e) {
      debugPrint('StepBlueprintRepository: units Hive delete failed - $e');
    }
  }

  // ── CRUD: blueprint 본체 ───────────────────────────────────────────────────

  /// 신규 청사진 저장. id 비어 있으면 새 문서 발급.
  Future<StepBlueprint> create(StepBlueprint blueprint) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final ref = blueprint.id.isEmpty ? _root.doc() : _doc(blueprint.id);
    final now = DateTime.now();
    final prepared = blueprint.copyWith(
      id: ref.id,
      ownerUid: blueprint.ownerUid.isEmpty ? _uid : blueprint.ownerUid,
      createdAt: blueprint.createdAt,
      updatedAt: now,
    );
    // 이슈 #803 — create timeout 5s → 15s (단일 set 인데 5s 는 너무 짧음).
    await ref.set({
      ...prepared.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false)).withServerTimeout(
          op: 'create_step_blueprint',
          d: const Duration(seconds: 15),
        );
    // #704 Phase 2 — write-through (Firestore 성공 시에만).
    await _cacheBlueprint(prepared);
    return prepared;
  }

  /// 부분 업데이트(merge). updatedAt 자동.
  Future<void> update(String id, Map<String, dynamic> patch) async {
    // 이슈 #803 — update timeout 5s → 15s.
    await _doc(id).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(
          op: 'update_step_blueprint',
          d: const Duration(seconds: 15),
        );
    // #704 Phase 2 — write-through. 캐시에 기존 blueprint 가 있으면 patch 반영.
    final cached = _readBlueprintFromHive(id);
    if (cached != null) {
      final mergedMap = <String, dynamic>{
        ...cached.toMap(),
        ...patch,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      try {
        await _cacheBlueprint(StepBlueprint.fromMap(mergedMap));
      } catch (e) {
        debugPrint('StepBlueprintRepository.update: cache merge failed - $e');
      }
    }
  }

  /// 전체 덮어쓰기 저장.
  Future<StepBlueprint> save(StepBlueprint blueprint) async {
    if (blueprint.id.isEmpty) return create(blueprint);
    final now = DateTime.now();
    final next = blueprint.copyWith(updatedAt: now);
    // 이슈 #803 — save timeout 5s → 15s.
    await _doc(blueprint.id).set({
      ...next.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(
          op: 'save_step_blueprint',
          d: const Duration(seconds: 15),
        );
    // #704 Phase 2 — write-through (Firestore 성공 시에만).
    await _cacheBlueprint(next);
    return next;
  }

  /// #704 Phase 2 — Firestore 우선, ServerUnavailableException 시 Hive 폴백.
  /// 빈 캐시면 그대로 null 반환 (오프라인이라도 진짜 없는 도안은 없는 채로).
  Future<StepBlueprint?> get(String id) async {
    try {
      final snap = await _doc(id).get().withServerTimeout(op: 'get_step_blueprint');
      if (!snap.exists) return null;
      final blueprint = _readBlueprint(snap);
      // write-through.
      await _cacheBlueprint(blueprint);
      return blueprint;
    } on ServerUnavailableException {
      // 오프라인/타임아웃 — Hive 폴백.
      return _readBlueprintFromHive(id);
    }
  }

  /// #704 Phase 2 — Firestore stream 실패/timeout 시 Hive 캐시 emit.
  /// 캐시도 비어 있으면 emit 안 함 (loading 유지).
  Stream<StepBlueprint?> watch(String id) async* {
    bool emittedAny = false;
    final controller = _doc(id).snapshots().map<StepBlueprint?>((s) {
      if (!s.exists) return null;
      final blueprint = _readBlueprint(s);
      // 서버 응답일 때만 write-through.
      if (!s.metadata.isFromCache) {
        unawaited(_cacheBlueprint(blueprint));
      }
      return blueprint;
    });

    yield* controller
        .timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!emittedAny) {
          final fallback = _readBlueprintFromHive(id);
          if (fallback != null) {
            sink.add(fallback);
            emittedAny = true;
          }
        }
      },
    )
        .handleError((Object e) {
      debugPrint('StepBlueprintRepository.watch error: $e');
      // 에러 발생 시도 Hive 폴백 (이미 emit 했으면 노이즈 가능하나 안전 우선).
      final fallback = _readBlueprintFromHive(id);
      if (fallback != null && !emittedAny) {
        emittedAny = true;
        return fallback;
      }
      return null;
    }).map((b) {
      emittedAny = true;
      return b;
    });
  }

  /// 청사진 + units subcollection 일괄 삭제 (#687 본문 교체).
  /// units가 많을 경우에도 batch로 안전하게 처리.
  Future<void> delete(String id) async {
    // units subcollection 먼저 삭제 (batch).
    final unitsSnap = await _unitsCol(id).get().withServerTimeout(op: 'get_step_blueprint_units_for_delete');
    final batch = _db.batch();
    for (final doc in unitsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_doc(id));
    await batch.commit().withServerTimeout(op: 'delete_step_blueprint_batch');
    // #704 Phase 2 — Firestore 성공 시 Hive 캐시도 제거.
    await _removeBlueprintFromHive(id);
    await _removeUnitsFromHive(id);
  }

  // ── units subcollection ────────────────────────────────────────────────────

  Future<StepBlueprintUnit> saveUnit(StepBlueprintUnit unit) async {
    final ref = unit.id.isEmpty
        ? _unitsCol(unit.blueprintId).doc()
        : _unitsCol(unit.blueprintId).doc(unit.id);
    final now = DateTime.now();
    final next = unit.copyWith(id: ref.id, updatedAt: now);
    await ref.set({
      ...next.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (unit.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'save_step_blueprint_unit');
    // #704 Phase 2 — write-through. 캐시에 기존 units 리스트가 있으면 합쳐서 저장.
    final existing = _readUnitsFromHive(next.blueprintId) ?? const [];
    final mergedMap = {for (final u in existing) u.id: u};
    mergedMap[next.id] = next;
    final mergedList = mergedMap.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    await _cacheUnits(next.blueprintId, mergedList);
    return next;
  }

  /// units 일괄 저장 (그룹 unitIds 와 일치하도록 일괄 갱신).
  Future<List<StepBlueprintUnit>> saveUnits(
    String blueprintId,
    List<StepBlueprintUnit> units,
  ) async {
    final batch = _db.batch();
    final result = <StepBlueprintUnit>[];
    for (final u in units) {
      final ref = u.id.isEmpty
          ? _unitsCol(blueprintId).doc()
          : _unitsCol(blueprintId).doc(u.id);
      final next = u.copyWith(id: ref.id, blueprintId: blueprintId);
      batch.set(ref, {
        ...next.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      result.add(next);
    }
    await batch.commit().withServerTimeout(op: 'save_step_blueprint_units_batch');
    // #704 Phase 2 — write-through. 일괄 저장은 그 batch 가 곧 캐시 전체 (호출부가 그룹의 unitIds 기준 일괄 갱신을 보장).
    await _cacheUnits(blueprintId, result);
    return result;
  }

  Future<void> deleteUnit(String blueprintId, String unitId) async {
    await _unitsCol(blueprintId)
        .doc(unitId)
        .delete()
        .withServerTimeout(op: 'delete_step_blueprint_unit');
    // #704 Phase 2 — Firestore 성공 시 Hive 캐시에서도 제거.
    final existing = _readUnitsFromHive(blueprintId);
    if (existing != null) {
      final filtered =
          existing.where((u) => u.id != unitId).toList(growable: false);
      await _cacheUnits(blueprintId, filtered);
    }
  }

  /// #704 Phase 2 — Firestore 우선 + ServerUnavailableException 시 Hive 폴백.
  Future<List<StepBlueprintUnit>> listUnits(String blueprintId) async {
    try {
      final snap = await _unitsCol(blueprintId)
          .orderBy('order')
          .get()
          .withServerTimeout(op: 'list_step_blueprint_units');
      final units = snap.docs.map(_readUnit).toList();
      // write-through.
      await _cacheUnits(blueprintId, units);
      return units;
    } on ServerUnavailableException {
      final cached = _readUnitsFromHive(blueprintId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// #704 Phase 2 — units stream 폴백.
  /// 첫 5초 안에 Firestore emit 없으면 Hive 캐시 emit (있을 때만).
  Stream<List<StepBlueprintUnit>> watchUnits(String blueprintId) async* {
    bool emittedAny = false;
    final stream = _unitsCol(blueprintId)
        .orderBy('order')
        .snapshots()
        .map<List<StepBlueprintUnit>>((s) {
      final units = s.docs.map(_readUnit).toList();
      // 서버 응답일 때만 write-through.
      if (!s.metadata.isFromCache) {
        unawaited(_cacheUnits(blueprintId, units));
      }
      return units;
    });

    yield* stream
        .timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!emittedAny) {
          final fallback = _readUnitsFromHive(blueprintId);
          if (fallback != null) {
            sink.add(fallback);
            emittedAny = true;
          }
        }
      },
    )
        .handleError((Object e) {
      debugPrint('StepBlueprintRepository.watchUnits error: $e');
      final fallback = _readUnitsFromHive(blueprintId);
      if (fallback != null && !emittedAny) {
        emittedAny = true;
        return fallback;
      }
      return const <StepBlueprintUnit>[];
    }).map((list) {
      emittedAny = true;
      return list;
    });
  }

  // ── group meta 갱신 (그룹 reorder/추가/삭제) ──────────────────────────────

  Future<void> updateGroups(
    String blueprintId,
    List<StepGroupMeta> groups,
  ) async =>
      update(blueprintId, {
        'groups': groups.map((g) => g.toMap()).toList(),
      });

  // ── 버전 발행 ─────────────────────────────────────────────────────────────

  /// 버전 발행 — version 필드 갱신 + publishedVersions 누적.
  /// visibility가 draft면 자동으로 private로 승격(작가가 직접 마켓/공개 전환은 별도 액션).
  Future<StepBlueprint> publishVersion({
    required String blueprintId,
    required String version,
    String? changelog,
  }) async {
    return _db.runTransaction<StepBlueprint>((tx) async {
      final ref = _doc(blueprintId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('청사진이 존재하지 않아요.');
      final current = _readBlueprint(snap);

      final entry = BlueprintPublishedVersion(
        version: version,
        publishedAt: DateTime.now(),
        changelog: changelog,
      );

      final nextVisibility = current.visibility == BlueprintVisibility.draft
          ? BlueprintVisibility.private
          : current.visibility;

      final next = current.copyWith(
        version: version,
        publishedVersions: [...current.publishedVersions, entry],
        visibility: nextVisibility,
        updatedAt: DateTime.now(),
      );
      tx.set(ref, {
        'version': version,
        'visibility': nextVisibility.name,
        'publishedVersions': next.publishedVersions
            .map((v) => v.toMap())
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    }).withServerTimeout(op: 'publish_step_blueprint_version');
  }

  // ── Fork ──────────────────────────────────────────────────────────────────

  /// 다른 청사진을 내 청사진으로 복제. units까지 함께 복제.
  /// 라이선스가 modify/redistribute 둘 다 막혀 있으면 호출부에서 사전 차단 권장.
  Future<StepBlueprint> fork({
    required StepBlueprint source,
    required String fromOwnerName,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final newRef = _root.doc();
    final now = DateTime.now();
    final forked = source.copyWith(
      id: newRef.id,
      ownerUid: _uid,
      visibility: BlueprintVisibility.draft,
      provider: BlueprintProvider.user,
      fromBlueprintId: source.id,
      fromAttribution: 'forked from @$fromOwnerName',
      publishedVersions: const [],
      version: '1.0.0',
      isFeatured: false,
      isCurated: false,
      moriknitVerified: false,
      members: const {},
      autoSyncOwnerRuns: false,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(newRef, {
      ...forked.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // units 복제
    final srcUnits = await _unitsCol(source.id).get().withServerTimeout(op: 'fork_get_source_units');
    for (final doc in srcUnits.docs) {
      final unit = _readUnit(doc);
      final newUnitRef = _unitsCol(newRef.id).doc();
      batch.set(newUnitRef, {
        ...unit.toMap(),
        'id': newUnitRef.id,
        'blueprintId': newRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit().withServerTimeout(op: 'fork_step_blueprint_batch');
    return forked;
  }

  // ── Query — visibility / kind / owner ─────────────────────────────────────

  // 이슈 #701 재발 fix — 기존 `.timeout(5s)` 는 Stream inactivity 기반이라
  //   첫 emit 후 5초간 변경 없으면 빈 리스트로 강제 reset → 도안이 사라지는 회귀 원인.
  //   Firestore snapshots 는 정상 상태에서 첫 도착 후 침묵하므로 timeout 부적합.
  //   인덱스 빌드/네트워크 지연은 error 콜백(AsyncDelayedFriendly)로 별도 처리.
  // #704 Phase 2 — Firestore 성공 시 Hive write-through. stream error 시 Hive emit.
  //   빈 Hive 캐시면 emit 안 함 (loading 유지) — 호출부 onError 가 빈 리스트로 폴백.
  Stream<List<StepBlueprint>> watchByOwner(String ownerUid) {
    final controller = StreamController<List<StepBlueprint>>();
    final sub = _root
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
      (s) {
        final list = s.docs.map(_readBlueprint).toList();
        // 서버 응답일 때만 write-through.
        if (!s.metadata.isFromCache) {
          unawaited(_cacheBlueprints(list));
        }
        if (!controller.isClosed) controller.add(list);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('StepBlueprintRepository.watchByOwner error: $e');
        // stream error → Hive 폴백 (있을 때만 emit, 빈 캐시면 에러 그대로 forward).
        final fallback = _readBlueprintsByOwnerFromHive(ownerUid);
        if (fallback.isNotEmpty) {
          if (!controller.isClosed) controller.add(fallback);
        } else {
          if (!controller.isClosed) controller.addError(e, st);
        }
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// 협업자(members 맵의 key)로 참여 중인 청사진 스트림.
  ///
  /// Firestore는 map 의 key 존재 여부 단독 query 가 어렵기 때문에
  /// `members.{uid}` 필드 존재 여부로 매칭한다. Firestore rules 의 hasBlueprintMemberRole
  /// 와 동일한 정책: members 맵에 uid 가 키로 들어가 있으면 협업자.
  ///
  /// 자기 자신이 ownerUid 인 청사진은 제외 (watchByOwner 와 중복 방지).
  Stream<List<StepBlueprint>> watchByMember(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _root
        .where('members.$uid', whereIn: const [
          'admin',
          'editor',
          'tester',
          'commenter',
          'viewer',
        ])
        .snapshots()
        .map((s) => s.docs
            .map(_readBlueprint)
            .where((bp) => bp.ownerUid != uid)
            .toList());
  }

  // ── 협업자(members) 관리 ──────────────────────────────────────────────────

  /// 협업자 추가/역할 변경. owner 만 호출해야 한다(Rules 에서 차단됨).
  Future<void> upsertMember({
    required String blueprintId,
    required String memberUid,
    required BlueprintMemberRole role,
  }) async {
    await _doc(blueprintId).set({
      'members': {memberUid: role.name},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'upsert_blueprint_member');
  }

  /// 협업자 제거.
  Future<void> removeMember({
    required String blueprintId,
    required String memberUid,
  }) async {
    await _doc(blueprintId).update({
      'members.$memberUid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'remove_blueprint_member');
  }

  /// 사용자 검색 (displayName prefix). 협업자 초대 시트에서 사용.
  Future<List<Map<String, String>>> searchUsersByDisplayName(
    String query, {
    String? excludeUid,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$qꯦ')
        .limit(20)
        .get()
        .withServerTimeout(op: 'search_users_by_display_name');
    return snap.docs
        .map((doc) => {
              'uid': doc.id,
              'displayName': (doc.data()['displayName'] as String?) ?? '',
              'email': (doc.data()['email'] as String?) ?? '',
              'photoURL': (doc.data()['photoURL'] as String?) ?? '',
            })
        .where((u) =>
            u['uid'] != excludeUid && (u['displayName']!.isNotEmpty))
        .toList();
  }

  /// 단일 사용자 조회 (uid 로). 협업자 표시에 닉네임 가져올 때 사용.
  Future<Map<String, String>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final snap = await _db.collection('users').doc(uid).get().withServerTimeout(op: 'get_user_profile');
    final data = snap.data();
    if (data == null) return null;
    return {
      'uid': uid,
      'displayName': (data['displayName'] as String?) ?? '',
      'email': (data['email'] as String?) ?? '',
      'photoURL': (data['photoURL'] as String?) ?? '',
    };
  }

  Stream<List<StepBlueprint>> watchByVisibility(BlueprintVisibility v) => _root
      .where('visibility', isEqualTo: v.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  /// #791 — 함께 뜨기(Knit-Along) 대상 청사진 — forkCount > 0 + 공개 범위.
  /// 누구나 한 번이라도 함께 뜨기를 시작한 도안만 노출. orderBy(forkCount desc).
  /// 색인 부재/오류 시 빈 리스트 폴백 (broadcast controller 로 안전 처리).
  Stream<List<StepBlueprint>> watchKnitAlongGroups({int limit = 20}) {
    final controller = StreamController<List<StepBlueprint>>();
    final sub = _root
        .where('forkCount', isGreaterThan: 0)
        .orderBy('forkCount', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
      (s) {
        if (!controller.isClosed) {
          controller.add(s.docs.map(_readBlueprint).toList());
        }
      },
      onError: (Object e) {
        debugPrint('StepBlueprintRepository.watchKnitAlongGroups error: $e');
        if (!controller.isClosed) controller.add(const <StepBlueprint>[]);
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// #791 — 내가 함께 뜨고 있는(=fork 한) 청사진. fromBlueprintId 가 비어있지 않은 내 청사진.
  Stream<List<StepBlueprint>> watchMyKnitAlongs(String ownerUid,
      {int limit = 10}) {
    if (ownerUid.isEmpty) return Stream.value(const <StepBlueprint>[]);
    final controller = StreamController<List<StepBlueprint>>();
    final sub = _root
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (s) {
        final list = s.docs
            .map(_readBlueprint)
            .where((b) =>
                b.fromBlueprintId != null && b.fromBlueprintId!.isNotEmpty)
            .take(limit)
            .toList();
        if (!controller.isClosed) controller.add(list);
      },
      onError: (Object e) {
        debugPrint('StepBlueprintRepository.watchMyKnitAlongs error: $e');
        if (!controller.isClosed) controller.add(const <StepBlueprint>[]);
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// #791 — 특정 도안(origin blueprint)에 대해 함께 뜨고 있는 사용자들의 청사진.
  /// fromBlueprintId == originBlueprintId.
  Stream<List<StepBlueprint>> watchKnitAlongParticipants(
    String originBlueprintId, {
    int limit = 50,
  }) {
    if (originBlueprintId.isEmpty) {
      return Stream.value(const <StepBlueprint>[]);
    }
    final controller = StreamController<List<StepBlueprint>>();
    final sub = _root
        .where('fromBlueprintId', isEqualTo: originBlueprintId)
        .limit(limit)
        .snapshots()
        .listen(
      (s) {
        if (!controller.isClosed) {
          controller.add(s.docs.map(_readBlueprint).toList());
        }
      },
      onError: (Object e) {
        debugPrint(
            'StepBlueprintRepository.watchKnitAlongParticipants error: $e');
        if (!controller.isClosed) controller.add(const <StepBlueprint>[]);
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// #792 — 작성자(나)의 도안들의 테스터/협업자 진척 집계용. 내 ownerUid 청사진만.
  Stream<List<StepBlueprint>> watchMyAuthoredBlueprints(String ownerUid) {
    if (ownerUid.isEmpty) return Stream.value(const <StepBlueprint>[]);
    final controller = StreamController<List<StepBlueprint>>();
    final sub = _root
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
      (s) {
        if (!controller.isClosed) {
          controller.add(s.docs.map(_readBlueprint).toList());
        }
      },
      onError: (Object e) {
        debugPrint(
            'StepBlueprintRepository.watchMyAuthoredBlueprints error: $e');
        if (!controller.isClosed) controller.add(const <StepBlueprint>[]);
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Stream<List<StepBlueprint>> watchByKind(BlueprintKind kind) => _root
      .where('kind', isEqualTo: kind.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  /// 마켓플레이스 노출 청사진.
  Stream<List<StepBlueprint>> watchMarketplace() => _root
      .where('visibility', whereIn: [
        BlueprintVisibility.marketplace.name,
        BlueprintVisibility.public.name,
      ])
      .where('discoverability',
          isEqualTo: BlueprintDiscoverability.searchable.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  // ── Phase I-A : 신규 컬렉션 우선 + 기존 pattern_charts 어댑터 fallback ────
  //
  // 마이그레이션 실행 여부와 무관하게 화면이 정상 동작하도록 보강.
  // 본 메서드는 **읽기 전용 어댑터** — pattern_charts 데이터는 변형하지 않음.
  // 어댑터로 생성된 StepBlueprint는 신규 컬렉션에 저장되지 않고 메모리에서만 사용.
  //
  // Phase J(옛 코드 삭제) 진입 시 본 fallback 메서드들도 함께 제거 예정.

  /// 단일 청사진 조회 — 신규 컬렉션 우선, 없으면 기존 pattern_charts에서 어댑터 변환.
  ///
  /// 사용 예: 청사진 상세화면이 [id]를 받아 표시할 때, 마이그레이션 안 한 사용자는
  /// pattern_charts 데이터를 어댑터로 즉시 보여줌(저장 안 함).
  Future<StepBlueprint?> getOrAdaptLegacy(
    String id, {
    required PatternRepository patternRepo,
  }) async {
    final blueprint = await get(id);
    if (blueprint != null) return blueprint;
    final chart = await patternRepo.get(id);
    if (chart == null) return null;
    return adaptFromPatternChart(chart, ownerUid: _uid);
  }

  // ── #788 — 빌트인 템플릿 네트워크 폴백 ─────────────────────────────────────
  //
  // step_blueprints 의 빌트인 청사진(`tmpl_builtin_*`)이 Hive 캐시에 없고
  // Firestore 가 지연/오프라인 상태일 때, `builtin_templates/{originalId}` 컬렉션을
  // 직접 조회해 메모리상 청사진으로 즉시 구성한다. 본 메서드는 ServerUnavailableException
  // 을 자체 catch 하여 호출자에게 친화적인 흐름을 제공한다.

  /// 빌트인 청사진 id 패턴 검사 + 원본 builtin_templates 문서 id 추출.
  /// 예: `tmpl_builtin_abc123` → `abc123`.
  String? _builtinSourceId(String blueprintId) {
    const prefix = 'tmpl_builtin_';
    if (!blueprintId.startsWith(prefix)) return null;
    return blueprintId.substring(prefix.length);
  }

  /// BuiltinTemplate → StepBlueprint 메모리 변환 (네트워크 폴백 전용).
  ///
  /// 마이그레이션의 `migrateBuiltinTemplates` 로직을 1건만 적용해 청사진을 만든다.
  /// `tmpl_builtin_{srcId}` 형식의 id 를 유지하므로 후속 호출자가 동일 id 로 다시
  /// 조회해도 일관된 결과가 나온다.
  ({StepBlueprint blueprint, List<StepBlueprintUnit> units}) _adaptFromBuiltin(
    bt.BuiltinTemplate tmpl, {
    required String blueprintId,
  }) {
    final useKo = tmpl.stepsKo.isNotEmpty;
    final titles = useKo ? tmpl.stepsKo : tmpl.stepsEn;
    final notesKo = tmpl.stepNotesKo;
    final notesEn = tmpl.stepNotesEn;
    final targets = tmpl.stepTargetRows;

    final units = <StepBlueprintUnit>[];
    final unitIds = <String>[];
    for (var i = 0; i < titles.length; i++) {
      final unitId = '${blueprintId}_u$i';
      unitIds.add(unitId);
      final ko = i < notesKo.length ? notesKo[i] : '';
      final en = i < notesEn.length ? notesEn[i] : '';
      final target = i < targets.length ? targets[i] : 0;
      units.add(StepBlueprintUnit(
        id: unitId,
        blueprintId: blueprintId,
        order: i,
        title: titles[i],
        titleKo: i < tmpl.stepsKo.length ? tmpl.stepsKo[i] : null,
        titleEn: i < tmpl.stepsEn.length ? tmpl.stepsEn[i] : null,
        instruction: ko.isNotEmpty ? ko : en,
        instructionKo: ko.isEmpty ? null : ko,
        instructionEn: en.isEmpty ? null : en,
        targetRows: target,
        referenceImages: const [],
        chartRegion: null,
        isPreview: false,
        tags: const [],
        createdAt: DateTime.now(),
      ));
    }

    final groups = <StepGroupMeta>[
      StepGroupMeta(
        id: 'main',
        title: tmpl.titleKo.isNotEmpty ? tmpl.titleKo : tmpl.titleEn,
        titleKo: tmpl.titleKo,
        titleEn: tmpl.titleEn,
        order: 0,
        unitIds: unitIds,
      ),
    ];

    final blueprint = StepBlueprint(
      id: blueprintId,
      ownerUid: _uid, // 호출자(사용자) uid 로 표시 — 권한 비교용. 진짜 owner 는 official.
      title: tmpl.titleKo.isNotEmpty ? tmpl.titleKo : tmpl.titleEn,
      titleKo: tmpl.titleKo,
      titleEn: tmpl.titleEn,
      kind: BlueprintKind.template,
      visibility: BlueprintVisibility.public,
      license: const BlueprintLicense(type: LicenseType.moriknit_official),
      provider: BlueprintProvider.official,
      version: '1.0.0',
      publishedVersions: const [],
      autoSyncOwnerRuns: false,
      members: const {},
      discoverability: BlueprintDiscoverability.curated_only,
      isFeatured: false,
      isCurated: true,
      moriknitVerified: true,
      tags: const ['fallback:builtin'],
      groups: groups,
      iconName: tmpl.iconName.isEmpty ? null : tmpl.iconName,
      colorHex: tmpl.colorHex.isEmpty ? null : tmpl.colorHex,
      order: tmpl.order,
      measurementData: tmpl.measurementData,
      description: tmpl.descKo.isNotEmpty
          ? tmpl.descKo
          : (tmpl.descEn.isNotEmpty ? tmpl.descEn : null),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return (blueprint: blueprint, units: units);
  }

  /// 빌트인 청사진 보장 조회 — get() 실패 시 builtin_templates 폴백 + Hive write-through.
  ///
  /// 흐름:
  ///   1) `get(blueprintId)` 시도 (Firestore 우선, Hive 폴백 포함)
  ///   2) null/실패 시 id 가 `tmpl_builtin_*` 이면 builtin_templates 컬렉션에서 원본 조회
  ///   3) 원본 → 메모리 청사진 합성 + Hive write-through (다음 호출부터는 즉시 표시)
  ///   4) units 도 함께 캐시.
  ///
  /// 본 메서드는 ServerUnavailableException 을 호출자에게 노출하지 않고, 폴백 실패 시에만
  /// null 반환한다. 호출부는 null → 친화 안내 표시.
  Future<StepBlueprint?> ensureBuiltinBlueprint(String blueprintId) async {
    // 1) Firestore + Hive 우선.
    try {
      final existing = await get(blueprintId);
      if (existing != null) return existing;
    } on ServerUnavailableException {
      // 폴백 흐름으로 진행.
    }

    // 2) 빌트인 id 가 아니면 폴백 없음.
    final srcId = _builtinSourceId(blueprintId);
    if (srcId == null) return null;

    // 3) builtin_templates/{srcId} 조회 — 짧은 timeout.
    try {
      final snap = await _db
          .collection('builtin_templates')
          .doc(srcId)
          .get()
          .withServerTimeout(op: 'get_builtin_template_fallback');
      if (!snap.exists) return null;
      final tmpl = bt.BuiltinTemplate.fromFirestore(snap);
      final result = _adaptFromBuiltin(tmpl, blueprintId: blueprintId);

      // 4) Hive write-through (오프라인에서도 다음 호출 즉시 표시).
      await _cacheBlueprint(result.blueprint);
      await _cacheUnits(blueprintId, result.units);
      return result.blueprint;
    } on ServerUnavailableException {
      // 빌트인 원본도 못 가져옴 — 진짜 오프라인.
      return null;
    }
  }

  /// 빌트인/공식 청사진을 사용자 본인 사본으로 복제 (#788).
  ///
  /// 흐름:
  ///   1) 원본 청사진 + units 보장 조회 (ensureBuiltinBlueprint).
  ///   2) 새 doc id 발급 (`user_${uid}_${...}`) — 사용자 sub 영역 아님, step_blueprints 루트.
  ///   3) blueprint deep copy (ownerUid=self, kind=template, provider=user, visibility=draft,
  ///      sourceBuiltinId=srcId 추적용 tag).
  ///   4) units deep copy + 새 unit id 발급, groups.unitIds 매핑 갱신.
  ///   5) batch 저장 + Hive write-through.
  ///
  /// 라이선스: 빌트인은 moriknit_official 라이선스로 modify 허용 — 사본은 user 라이선스(reserved) 시작.
  Future<StepBlueprint> duplicateAsUserCopy(String sourceBlueprintId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    // 1) 원본 확보 (빌트인 폴백 포함).
    final source = await ensureBuiltinBlueprint(sourceBlueprintId);
    if (source == null) {
      throw Exception('원본 템플릿을 불러올 수 없어요. 잠시 후 다시 시도해 주세요.');
    }
    // units 도 함께 확보 (Firestore → Hive 폴백 → builtin 폴백 순으로 캐시됨).
    List<StepBlueprintUnit> srcUnits;
    try {
      srcUnits = await listUnits(sourceBlueprintId);
    } on ServerUnavailableException {
      // Hive 캐시는 listUnits 내부에서 폴백 시도됨 → 그래도 실패면 폴백 hive 직접 읽기.
      srcUnits = _readUnitsFromHive(sourceBlueprintId) ?? const [];
    }
    if (srcUnits.isEmpty) {
      // builtin 폴백으로 ensureBuiltinBlueprint 가 Hive 에 units 를 미리 캐싱했다면 한 번 더 시도.
      srcUnits = _readUnitsFromHive(sourceBlueprintId) ?? const [];
    }

    // 2) 새 ID 발급.
    final newRef = _root.doc();
    final newId = newRef.id;
    final now = DateTime.now();
    final srcBuiltinId = _builtinSourceId(sourceBlueprintId);

    // 3) blueprint deep copy.
    // unit id 매핑 (옛 unit id → 새 unit id) — groups.unitIds 갱신용.
    final unitIdMap = <String, String>{};
    final newUnits = <StepBlueprintUnit>[];
    for (final u in srcUnits) {
      final newUnitRef = _unitsCol(newId).doc();
      unitIdMap[u.id] = newUnitRef.id;
      newUnits.add(u.copyWith(
        id: newUnitRef.id,
        blueprintId: newId,
        createdAt: now,
        updatedAt: now,
      ));
    }
    final newGroups = source.groups
        .map((g) => g.copyWith(
              unitIds: g.unitIds
                  .map((id) => unitIdMap[id] ?? id)
                  .where((id) => unitIdMap.containsValue(id))
                  .toList(),
            ))
        .toList();

    final copy = source.copyWith(
      id: newId,
      ownerUid: _uid,
      kind: BlueprintKind.template,
      visibility: BlueprintVisibility.draft,
      provider: BlueprintProvider.user,
      license: const BlueprintLicense(),
      fromBlueprintId: source.id,
      fromAttribution: srcBuiltinId == null
          ? 'duplicated from blueprint'
          : 'duplicated from builtin:$srcBuiltinId',
      publishedVersions: const [],
      version: '1.0.0',
      isFeatured: false,
      isCurated: false,
      moriknitVerified: false,
      members: const {},
      autoSyncOwnerRuns: false,
      discoverability: BlueprintDiscoverability.hidden,
      tags: <String>[
        'user_template',
        if (srcBuiltinId != null) 'sourceBuiltinId:$srcBuiltinId',
      ],
      groups: newGroups,
      createdAt: now,
      updatedAt: now,
    );

    // 4) batch 저장.
    final batch = _db.batch();
    batch.set(newRef, {
      ...copy.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final u in newUnits) {
      batch.set(_unitsCol(newId).doc(u.id), {
        ...u.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit().withServerTimeout(op: 'duplicate_blueprint_batch');

    // 5) Hive write-through.
    await _cacheBlueprint(copy);
    await _cacheUnits(newId, newUnits);
    return copy;
  }

  /// 내 청사진 목록 — step_blueprints 우선 + pattern_charts 어댑터 보충 (중복 제거).
  ///
  /// 두 stream을 동시 구독하고 매 emission마다 최신 결합 리스트를 emit.
  /// - 같은 id가 양쪽에 있으면 step_blueprints 우선 (마이그레이션 완료 데이터).
  /// - pattern_charts 단독은 어댑터로 변환(임시) 후 합산.
  ///
  /// 이슈 #701 — UI freeze 방지:
  /// - 세 stream 동시 listen 시 매 tick 마다 emit 폭주 → 직전 결과와 동일 id 시그니처면 emit 차단.
  /// - 각 stream 의 첫 도착 전 dummy emit 도 distinct 로 중복 차단.
  Stream<List<StepBlueprint>> watchMyBlueprintsWithLegacy({
    required String ownerUid,
    required PatternRepository patternRepo,
  }) {
    final controller = StreamController<List<StepBlueprint>>.broadcast();
    var latestBlueprints = <StepBlueprint>[];
    var latestMemberBlueprints = <StepBlueprint>[];
    var latestCharts = <pat.PatternChart>[];
    // 이슈 #700 — emit 게이트 제거. 어느 stream 이 먼저 와도 즉시 노출.
    // 이전: hasCharts/hasBlueprints 양쪽 게이트로 한쪽 hang 시 무한로딩.
    // 현재: 첫 emit 보장 + 매 stream tick 마다 결합 결과 즉시 노출.
    // 이슈 #701 — distinct 시그니처로 동일 결과 반복 emit 차단 (UI freeze 방지).
    // 이슈 #720 — synthetic 빈 리스트 emit 제거. 진짜 데이터 첫 도착 시점부터 emit.
    //   기존: 마이크로태스크로 [] emit → 빈상태 잠시 노출 → 이후 데이터 도착 시 '다시 나타남' 회귀.
    //   현재: 첫 실제 도착 후에만 emit, 그 전에는 AsyncLoading 상태 유지.
    String? lastSignature;
    bool sawAnySource = false;

    void emit({bool fromSource = true}) {
      if (fromSource) sawAnySource = true;
      // 첫 실제 데이터 도착 전에는 emit 안 함 (loading 상태 유지).
      if (!sawAnySource) return;
      // step_blueprints는 우선권 (이미 마이그레이션된 데이터).
      // ownerUid 가 자신인 청사진 + 협업자로 참여중인 청사진 결합.
      final ownerIds = latestBlueprints.map((b) => b.id).toSet();
      final memberOnly = latestMemberBlueprints
          .where((b) => !ownerIds.contains(b.id))
          .toList();
      final combinedBlueprints = <StepBlueprint>[
        ...latestBlueprints,
        ...memberOnly,
      ];
      final blueprintIds = combinedBlueprints.map((b) => b.id).toSet();
      // sourcePatternChartId / chartAssetId 매칭으로도 중복 차단 (id 형식이 다를 수 있음).
      final referencedChartIds = <String>{
        for (final b in combinedBlueprints) ...[
          if (b.sourcePatternChartId != null) b.sourcePatternChartId!,
          if (b.chartAssetId != null) b.chartAssetId!,
        ],
      };

      final adapted = <StepBlueprint>[];
      for (final chart in latestCharts) {
        if (blueprintIds.contains(chart.id)) continue;
        if (referencedChartIds.contains(chart.id)) continue;
        adapted.add(adaptFromPatternChart(chart, ownerUid: ownerUid));
      }

      final merged = <StepBlueprint>[...combinedBlueprints, ...adapted];
      merged.sort((a, b) {
        final au = a.updatedAt ?? a.createdAt;
        final bu = b.updatedAt ?? b.createdAt;
        return bu.compareTo(au);
      });
      // 이슈 #701 — 시그니처(id+updatedAt) 기반 distinct. 동일 결과면 emit 생략.
      final signature = merged
          .map((b) => '${b.id}|${(b.updatedAt ?? b.createdAt).millisecondsSinceEpoch}')
          .join(',');
      if (signature == lastSignature) return;
      lastSignature = signature;
      if (!controller.isClosed) controller.add(merged);
    }

    // 이슈 #720 — synthetic 빈 리스트 emit 제거.
    //   기존: scheduleMicrotask로 [] emit → 빈상태 → 이후 데이터 도착 시 갑자기 '다시 나타남' 회귀.
    //   현재: 첫 실제 도착 시점부터 emit (sawAnySource 게이트).
    //   무한로딩 차단은 onError 콜백에서 빈 리스트로 폴백(에러 시에도 sawAnySource=true)으로 보장.

    final subBlueprints = watchByOwner(ownerUid).listen(
      (list) {
        latestBlueprints = list;
        emit();
      },
      // 인덱스 빌드/네트워크 지연 시 raw 예외 노출 금지. 빈 리스트로 폴백.
      onError: (_) {
        latestBlueprints = const [];
        emit();
      },
    );
    // 협업자로 참여 중인 청사진도 함께 라이브러리에 노출 (#687).
    final subMemberBlueprints = watchByMember(ownerUid).listen(
      (list) {
        latestMemberBlueprints = list;
        emit();
      },
      // members map 쿼리 미지원 환경/색인 부재 시 조용히 빈 리스트 유지.
      onError: (_) {
        latestMemberBlueprints = const [];
        emit();
      },
    );
    final subCharts = patternRepo.watchAll().listen(
      (list) {
        latestCharts = list;
        emit();
      },
      // pattern_charts 옛 컬렉션 오류 시도 폴백.
      onError: (_) {
        latestCharts = const [];
        emit();
      },
    );

    controller.onCancel = () async {
      await subBlueprints.cancel();
      await subMemberBlueprints.cancel();
      await subCharts.cancel();
    };
    return controller.stream;
  }

  /// PatternChart → StepBlueprint 어댑터 (메모리 변환, 저장 X).
  ///
  /// 신규 컬렉션이 비어 있을 때 화면에 표시하기 위한 임시 표현. 사용자가 청사진을
  /// 명시적으로 발행/저장할 때 비로소 step_blueprints 컬렉션에 기록된다.
  static StepBlueprint adaptFromPatternChart(
    pat.PatternChart chart, {
    required String ownerUid,
  }) {
    final aiSections = chart.aiSections ?? const [];
    final groups = <StepGroupMeta>[];
    for (var gi = 0; gi < aiSections.length; gi++) {
      final section = aiSections[gi];
      groups.add(StepGroupMeta(
        id: section.id,
        title: section.title,
        titleKo: section.titleKo,
        order: gi,
        unitIds: section.steps.map((s) => s.id).toList(),
      ));
    }

    final attachedImageUrls =
        chart.imageUrl.isNotEmpty ? <String>[chart.imageUrl] : null;
    final attachedPdfUrls =
        chart.pdfUrl.isNotEmpty ? <String>[chart.pdfUrl] : null;

    return StepBlueprint(
      id: chart.id,
      ownerUid: ownerUid,
      title: chart.title,
      kind: BlueprintKind.pattern,
      visibility: BlueprintVisibility.private,
      license: const BlueprintLicense(),
      provider: BlueprintProvider.user,
      sourcePatternChartId: chart.id,
      chartAssetId: chart.id,
      attachedImageUrls: attachedImageUrls,
      attachedPdfUrls: attachedPdfUrls,
      version: '1.0.0',
      publishedVersions: const [],
      autoSyncOwnerRuns: true,
      members: const {},
      discoverability: BlueprintDiscoverability.hidden,
      isFeatured: false,
      isCurated: false,
      moriknitVerified: false,
      tags: const ['adapter:legacy_pattern_chart'],
      groups: groups,
      // ── #687 Phase A — 1:1 이식 보강 필드 ──
      ravelryPatternId: chart.ravelryPatternId,
      forkCount: chart.forkCount,
      assetType: chart.type.name,
      gaugeJson: chart.gauge?.toJson(),
      repeatRegionsJson:
          chart.repeatRegions.map((r) => r.toJson()).toList(),
      createdAt: chart.createdAt ?? DateTime.now(),
      updatedAt: chart.createdAt,
    );
  }
}
