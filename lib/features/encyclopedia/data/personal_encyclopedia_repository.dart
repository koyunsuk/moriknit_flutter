import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/personal_encyclopedia_entry.dart';

class PersonalEncyclopediaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('personal_encyclopedia');

  Stream<List<PersonalEncyclopediaEntry>> watchAll(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PersonalEncyclopediaEntry.fromFirestore).toList());
  }

  Future<void> addEntry(String uid, PersonalEncyclopediaEntry entry) async {
    await _col(uid).add(entry.toJson());
  }

  Future<void> addBookmark(String uid, Map<String, dynamic> data) async {
    await _col(uid).add(data);
  }

  Future<void> removeBySourceId(String uid, String sourceId) async {
    final snap = await _col(uid).where('sourceId', isEqualTo: sourceId).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteEntry(String uid, String docId) async {
    await _col(uid).doc(docId).delete();
  }
}
