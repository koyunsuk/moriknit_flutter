import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/firestore_timeout_extension.dart';
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
    await _col(uid).add(entry.toJson()).withServerTimeout(op: 'add_personal_encyclopedia_entry');
  }

  Future<void> addBookmark(String uid, Map<String, dynamic> data) async {
    await _col(uid).add(data).withServerTimeout(op: 'add_personal_encyclopedia_bookmark');
  }

  Future<void> removeBySourceId(String uid, String sourceId) async {
    final snap = await _col(uid).where('sourceId', isEqualTo: sourceId).get().withServerTimeout(op: 'query_personal_encyclopedia_by_source');
    for (final doc in snap.docs) {
      await doc.reference.delete().withServerTimeout(op: 'delete_personal_encyclopedia_by_source');
    }
  }

  Future<void> deleteEntry(String uid, String docId) async {
    await _col(uid).doc(docId).delete().withServerTimeout(op: 'delete_personal_encyclopedia_entry');
  }
}
