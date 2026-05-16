// lib/features/counter/data/counter_repository.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../domain/counter_model.dart';
import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/utils/firestore_json.dart';

class CounterRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _countersRef =>
      _db.collection('users').doc(_uid).collection('counters');

  DocumentReference get _userRef =>
      _db.collection('users').doc(_uid);

  // ── CREATE ───────────────────────────────────────────────
  Future<CounterModel> createCounter(CounterModel counter) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final now = DateTime.now();
    final prepared = counter.copyWith(updatedAt: now);
    await _saveToHive(prepared);

    try {
      final docRef = counter.id.isEmpty
          ? _countersRef.doc()
          : _countersRef.doc(counter.id);

      await _db.runTransaction((tx) async {
        tx.set(docRef, {
          ...prepared.toJson(),
          'id': docRef.id,
          'uid': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isDirty': false,
        });
        tx.update(_userRef, {
          'usage.counterCount': FieldValue.increment(1),
        });
      }).withServerTimeout(op: 'create_counter_tx');

      final saved = prepared.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved);
      return saved;
    } catch (e) {
      final dirty = prepared.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── DUPLICATE ────────────────────────────────────────────
  Future<CounterModel> duplicateCounter(CounterModel original) async {
    final now = DateTime.now();
    final copy = original.copyWith(
      id: '',
      name: '${original.name} (복사)',
      createdAt: now,
      updatedAt: now,
      isDirty: false,
      marks: [],
    );
    return createCounter(copy);
  }

  // ── READ (목록) ──────────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  Stream<List<CounterModel>> watchCounters() {
    if (_uid.isEmpty) return Stream.value([]);

    final controller = StreamController<List<CounterModel>>();

    final cached = _readListFromHive();
    if (cached.isNotEmpty) {
      controller.add(cached);
    }

    final sub = _countersRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        final list = snap.docs.map((doc) => CounterModel.fromFirestore(doc)).toList();
        controller.add(list);
        unawaited(_writeListToHive(list));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchCounters] firestore error → hive fallback: $e');
        controller.add(_readListFromHive());
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ── READ (프로젝트별) ─────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  Stream<List<CounterModel>> watchCountersByProject(String projectId) {
    if (_uid.isEmpty) return Stream.value([]);

    final controller = StreamController<List<CounterModel>>();

    final cached = _readListFromHive(projectId: projectId);
    if (cached.isNotEmpty) {
      controller.add(cached);
    }

    final sub = _countersRef
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .listen(
      (snap) {
        final list = snap.docs.map((doc) => CounterModel.fromFirestore(doc)).toList();
        controller.add(list);
        unawaited(_writeListToHive(list));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchCountersByProject] firestore error → hive fallback: $e');
        controller.add(_readListFromHive(projectId: projectId));
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ── READ (도안 차트별) ────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  Stream<CounterModel?> watchCounterByChartId(String chartId) {
    if (_uid.isEmpty || chartId.isEmpty) return Stream.value(null);

    final controller = StreamController<CounterModel?>();

    final cached = _readListFromHive(chartId: chartId);
    if (cached.isNotEmpty) {
      controller.add(cached.first);
    }

    final sub = _countersRef
        .where('patternChartId', isEqualTo: chartId)
        .limit(1)
        .snapshots()
        .listen(
      (snap) {
        final model = snap.docs.isEmpty
            ? null
            : CounterModel.fromFirestore(snap.docs.first);
        controller.add(model);
        if (model != null) unawaited(_saveToHive(model));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchCounterByChartId] firestore error → hive fallback: $e');
        final fallback = _readListFromHive(chartId: chartId);
        controller.add(fallback.isEmpty ? null : fallback.first);
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ── READ (단건) ──────────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  Stream<CounterModel?> watchCounter(String id) {
    if (_uid.isEmpty) return Stream.value(null);

    final controller = StreamController<CounterModel?>();

    final cached = _readFromHive(id);
    if (cached != null) {
      controller.add(cached);
    }

    final sub = _countersRef.doc(id).snapshots().listen(
      (doc) {
        if (!doc.exists) {
          controller.add(null);
          return;
        }
        final model = CounterModel.fromFirestore(doc);
        controller.add(model);
        unawaited(_saveToHive(model));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchCounter] firestore error → hive fallback: $e');
        controller.add(_readFromHive(id));
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<CounterModel> updateCounter(CounterModel counter) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = counter.copyWith(updatedAt: DateTime.now());
    await _saveToHive(updated);

    try {
      final json = Map<String, dynamic>.from(updated.toJson())
        ..remove('id')
        ..remove('uid')
        ..remove('createdAt');
      json['updatedAt'] = FieldValue.serverTimestamp();
      json['isDirty'] = false;
      await _countersRef.doc(counter.id).update(json).withServerTimeout(op: 'update_counter');
      return updated.copyWith(isDirty: false);
    } catch (e) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── INCREMENT (카운터 값만 빠르게 업데이트) ───────────────
  // 이슈 #704 Phase B — Hive 즉시 반영 → Firestore best-effort.
  // ConflictPolicy.lastWriteWins: updatedAt 비교는 Firestore serverTimestamp 우선.
  Future<void> incrementStitch(String id, int delta) async {
    // 1) Hive 즉시 반영 (사용자 +/- 버튼 응답성 보장)
    _bumpHive(id, stitchDelta: delta);
    // 2) Firestore best-effort
    try {
      await _countersRef.doc(id).update({
        'stitchCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }).withServerTimeout(op: 'increment_stitch');
    } catch (e) {
      debugPrint('[incrementStitch] firestore best-effort failed: $e');
      _markDirtyHive(id);
    }
  }

  Future<void> incrementRow(String id, int delta) async {
    _bumpHive(id, rowDelta: delta);
    try {
      await _countersRef.doc(id).update({
        'rowCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }).withServerTimeout(op: 'increment_row');
    } catch (e) {
      debugPrint('[incrementRow] firestore best-effort failed: $e');
      _markDirtyHive(id);
    }
  }

  // ── ADD MARK ─────────────────────────────────────────────
  Future<void> addMark(String id, CounterMark mark) async {
    await _countersRef.doc(id).update({
      'marks': FieldValue.arrayUnion([mark.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'add_mark');
  }

  Future<void> removeMark(String id, CounterMark mark) async {
    await _countersRef.doc(id).update({
      'marks': FieldValue.arrayRemove([mark.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'remove_mark');
  }

  Future<void> updateTargets(String id, {required int targetStitchCount, required int targetRowCount}) async {
    await _countersRef.doc(id).update({
      'targetStitchCount': targetStitchCount,
      'targetRowCount': targetRowCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'update_targets');
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteCounter(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    await _removeFromHive(id);
    await _db.runTransaction((tx) async {
      tx.delete(_countersRef.doc(id));
      tx.update(_userRef, {
        'usage.counterCount': FieldValue.increment(-1),
      });
    }).withServerTimeout(op: 'delete_counter_tx');
  }

  // ── Hive ─────────────────────────────────────────────────
  Future<void> _saveToHive(CounterModel counter) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      final key = counter.id.isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : counter.id;
      await box.put(key, counter.toJson());
    } catch (_) {
      // Hive 캐시 실패는 무시 — Firestore가 primary
    }
  }

  Future<void> _removeFromHive(String id) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      await box.delete(id);
    } catch (_) {}
  }

  // 이슈 #704 Phase A — Hive 읽기 헬퍼.
  // projectId/chartId 필터 옵션 제공 (Firestore where 절 대응).
  List<CounterModel> _readListFromHive({String? projectId, String? chartId}) {
    if (kIsWeb) return const [];
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      final uid = _uid;
      final items = <CounterModel>[];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data == null) continue;
        try {
          final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
          final model = CounterModel.fromJson(json);
          if (uid.isNotEmpty && model.uid.isNotEmpty && model.uid != uid) continue;
          if (projectId != null && model.projectId != projectId) continue;
          if (chartId != null && model.patternChartId != chartId) continue;
          items.add(model);
        } catch (_) {}
      }
      items.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return items;
    } catch (_) {
      return const [];
    }
  }

  CounterModel? _readFromHive(String id) {
    if (kIsWeb || id.isEmpty) return null;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      final data = box.get(id);
      if (data == null) return null;
      final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
      return CounterModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeListToHive(List<CounterModel> counters) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      for (final c in counters) {
        if (c.id.isEmpty) continue;
        await box.put(c.id, c.toJson());
      }
    } catch (_) {}
  }

  // 이슈 #704 Phase B — Hive 즉시 increment.
  // stitchDelta/rowDelta 만 받아 in-place 가산. Firestore가 따라잡으면 write-through로 덮어씀.
  void _bumpHive(String id, {int stitchDelta = 0, int rowDelta = 0}) {
    if (kIsWeb || id.isEmpty) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      final data = box.get(id);
      if (data == null) return;
      final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
      final current = CounterModel.fromJson(json);
      final updated = current.copyWith(
        stitchCount: current.stitchCount + stitchDelta,
        rowCount: current.rowCount + rowDelta,
        updatedAt: DateTime.now(),
      );
      box.put(id, updated.toJson());
    } catch (_) {}
  }

  void _markDirtyHive(String id) {
    if (kIsWeb || id.isEmpty) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
      final data = box.get(id);
      if (data == null) return;
      final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
      final current = CounterModel.fromJson(json);
      box.put(id, current.copyWith(isDirty: true).toJson());
    } catch (_) {}
  }

  Future<void> syncDirtyCounters() async {
    if (kIsWeb || _uid.isEmpty) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data['isDirty'] == true) {
        try {
          final counter = CounterModel.fromJson(Map<String, dynamic>.from(data));
          await updateCounter(counter);
        } catch (_) {}
      }
    }
  }
}
