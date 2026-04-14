import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/accessory_model.dart';

class AccessoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('myAccessories');

  Stream<List<AccessoryModel>> watchAccessories() {
    if (_uid.isEmpty) return Stream.value([]);
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AccessoryModel.fromFirestore(d)).toList());
  }

  Future<AccessoryModel> createAccessory(AccessoryModel item,
      {String? photoUrl}) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final docRef = item.id.isEmpty ? _col.doc() : _col.doc(item.id);
    await docRef.set({
      ...item.toJson(),
      'id': docRef.id,
      'uid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return item.copyWith(id: docRef.id);
  }

  Future<AccessoryModel> updateAccessory(AccessoryModel item,
      {String? photoUrl}) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _col.doc(item.id).update({
      ...item.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return item;
  }

  Future<void> deleteAccessory(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _col.doc(id).delete();
  }
}
