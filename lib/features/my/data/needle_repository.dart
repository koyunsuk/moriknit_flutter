import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/subscription_constants.dart';
import '../domain/needle_model.dart';

class NeedleRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _needlesRef => _db.collection('users').doc(_uid).collection('myNeedles');

  Future<NeedleModel> createNeedle(NeedleModel needle, {String? photoUrl}) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final prepared = needle.copyWith(updatedAt: DateTime.now());
    await _saveToHive(prepared);

    try {
      final docRef = needle.id.isEmpty ? _needlesRef.doc() : _needlesRef.doc(needle.id);

      await docRef.set({
        ...prepared.toJson(),
        'id': docRef.id,
        'uid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
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

  Stream<List<NeedleModel>> watchNeedles() {
    if (_uid.isEmpty) return Stream.value([]);
    return _needlesRef.orderBy('size').snapshots().map((snapshot) => snapshot.docs.map((doc) => NeedleModel.fromFirestore(doc)).toList());
  }

  Future<List<NeedleModel>> getNeedles() async {
    if (_uid.isEmpty) return [];
    final snapshot = await _needlesRef.orderBy('size').get();
    return snapshot.docs.map((doc) => NeedleModel.fromFirestore(doc)).toList();
  }

  Future<NeedleModel> updateNeedle(NeedleModel needle, {String? photoUrl}) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = needle.copyWith(updatedAt: DateTime.now());
    await _saveToHive(updated);

    try {
      await _needlesRef.doc(needle.id).update({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      });
      return updated.copyWith(isDirty: false);
    } catch (_) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  Future<void> deleteNeedle(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _removeFromHive(id);
    await _needlesRef.doc(id).delete();
  }

  Future<void> _saveToHive(NeedleModel needle) async {
    final box = Hive.box<Map>(SubscriptionConstants.boxNeedles);
    final key = needle.id.isEmpty ? 'temp_${DateTime.now().millisecondsSinceEpoch}' : needle.id;
    await box.put(key, needle.toJson());
  }

  Future<void> _removeFromHive(String id) async {
    final box = Hive.box<Map>(SubscriptionConstants.boxNeedles);
    await box.delete(id);
  }

  Future<void> syncDirtyNeedles() async {
    if (_uid.isEmpty) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxNeedles);
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data['isDirty'] == true) {
        try {
          final needle = NeedleModel.fromJson(Map<String, dynamic>.from(data));
          await updateNeedle(needle);
        } catch (_) {}
      }
    }
  }
}
