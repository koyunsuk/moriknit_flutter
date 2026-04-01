import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/user_template.dart';

class TemplateRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('templates');

  Stream<List<UserTemplate>> watchTemplates() {
    if (_uid.isEmpty) return Stream.value([]);
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserTemplate.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> create({
    required String title,
    required String description,
    required List<String> stepTitles,
    required List<String> stepDescs,
  }) async {
    if (_uid.isEmpty) return;
    await _col.add({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': null,
    });
  }

  Future<void> update({
    required String id,
    required String title,
    required String description,
    required List<String> stepTitles,
    required List<String> stepDescs,
  }) async {
    if (_uid.isEmpty) return;
    await _col.doc(id).update({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> delete(String id) async {
    if (_uid.isEmpty) return;
    await _col.doc(id).delete();
  }
}
