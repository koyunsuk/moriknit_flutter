// lib/features/counter/data/counter_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../domain/counter_model.dart';
import '../../../core/constants/subscription_constants.dart';

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
      });

      final saved = prepared.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved);
      return saved;
    } catch (e) {
      final dirty = prepared.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── READ (목록) ──────────────────────────────────────────
  Stream<List<CounterModel>> watchCounters() {
    if (_uid.isEmpty) return Stream.value([]);
    return _countersRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CounterModel.fromFirestore(doc))
            .toList());
  }

  // ── READ (프로젝트별) ─────────────────────────────────────
  Stream<List<CounterModel>> watchCountersByProject(String projectId) {
    if (_uid.isEmpty) return Stream.value([]);
    return _countersRef
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CounterModel.fromFirestore(doc))
            .toList());
  }

  // ── READ (단건) ──────────────────────────────────────────
  Stream<CounterModel?> watchCounter(String id) {
    if (_uid.isEmpty) return Stream.value(null);
    return _countersRef.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CounterModel.fromFirestore(doc);
    });
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<CounterModel> updateCounter(CounterModel counter) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = counter.copyWith(updatedAt: DateTime.now());
    await _saveToHive(updated);

    try {
      await _countersRef.doc(counter.id).update({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
      });
      return updated.copyWith(isDirty: false);
    } catch (e) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── INCREMENT (카운터 값만 빠르게 업데이트) ───────────────
  Future<void> incrementStitch(String id, int delta) async {
    await _countersRef.doc(id).update({
      'stitchCount': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementRow(String id, int delta) async {
    await _countersRef.doc(id).update({
      'rowCount': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── ADD MARK ─────────────────────────────────────────────
  Future<void> addMark(String id, CounterMark mark) async {
    await _countersRef.doc(id).update({
      'marks': FieldValue.arrayUnion([mark.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMark(String id, CounterMark mark) async {
    await _countersRef.doc(id).update({
      'marks': FieldValue.arrayRemove([mark.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    });
  }

  // ── Hive ─────────────────────────────────────────────────
  Future<void> _saveToHive(CounterModel counter) async {
    final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
    final key = counter.id.isEmpty
        ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
        : counter.id;
    await box.put(key, counter.toJson());
  }

  Future<void> _removeFromHive(String id) async {
    final box = Hive.box<Map>(SubscriptionConstants.boxCounters);
    await box.delete(id);
  }

  Future<void> syncDirtyCounters() async {
    if (_uid.isEmpty) return;
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
