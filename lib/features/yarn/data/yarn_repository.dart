import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';

import '../domain/yarn_model.dart';

class YarnRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _boxName = 'myYarns';

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _yarnsRef =>
      _db.collection('users').doc(_uid).collection('myYarns');

  // ── CREATE ───────────────────────────────────────────────
  Future<YarnModel> createYarn(YarnModel yarn) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final prepared = yarn.copyWith(updatedAt: DateTime.now());
    await _saveToHive(prepared);

    try {
      final docRef =
          yarn.id.isEmpty ? _yarnsRef.doc() : _yarnsRef.doc(yarn.id);

      await docRef.set({
        ...prepared.toJson(),
        'id': docRef.id,
        'uid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
      });

      final saved = prepared.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved);
      return saved;
    } catch (_) {
      final dirty = prepared.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── READ (목록, 스트림) ─────────────────────────────────
  Stream<List<YarnModel>> watchYarns() {
    if (_uid.isEmpty) return Stream.value([]);
    return _yarnsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => YarnModel.fromFirestore(doc)).toList());
  }

  // ── READ (목록) ──────────────────────────────────────────
  Future<List<YarnModel>> getYarns() async {
    if (_uid.isEmpty) return [];
    final snapshot =
        await _yarnsRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => YarnModel.fromFirestore(doc))
        .toList();
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<YarnModel> updateYarn(YarnModel yarn) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = yarn.copyWith(updatedAt: DateTime.now());
    await _saveToHive(updated);

    try {
      final json = Map<String, dynamic>.from(updated.toJson())
        ..remove('id')
        ..remove('uid')
        ..remove('createdAt');
      json['updatedAt'] = FieldValue.serverTimestamp();
      json['isDirty'] = false;
      await _yarnsRef.doc(yarn.id).update(json);
      return updated.copyWith(isDirty: false);
    } catch (_) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteYarn(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _removeFromHive(id);
    await _yarnsRef.doc(id).delete();
  }

  // ── DUPLICATE ─────────────────────────────────────────────
  Future<YarnModel> duplicateYarn(YarnModel original) async {
    final copy = original.copyWith(
      id: '',
      name: '${original.name} (복사)',
      isDirty: false,
    );
    return createYarn(copy);
  }

  // ── Hive 로컬 저장 ───────────────────────────────────────
  Future<void> _saveToHive(YarnModel yarn) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(_boxName);
      final key = yarn.id.isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : yarn.id;
      await box.put(key, yarn.toJson());
    } catch (_) {
      // Hive box not open yet — skip local cache
    }
  }

  Future<void> _removeFromHive(String id) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(_boxName);
      await box.delete(id);
    } catch (_) {}
  }

  // ── Dirty 항목 sync ──────────────────────────────────────
  Future<void> syncDirtyYarns() async {
    if (kIsWeb || _uid.isEmpty) return;
    try {
      final box = Hive.box<Map>(_boxName);
      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null && data['isDirty'] == true) {
          try {
            final yarn =
                YarnModel.fromJson(Map<String, dynamic>.from(data));
            await updateYarn(yarn);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
