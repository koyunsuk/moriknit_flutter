import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/encyclopedia_entry.dart';

class EncyclopediaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('encyclopedia');

  Stream<List<EncyclopediaEntry>> watchAll() {
    return _col.orderBy('order').snapshots()
        .map((s) => s.docs.map(EncyclopediaEntry.fromFirestore).toList());
  }

  Stream<List<EncyclopediaEntry>> watchByCategory(String category) {
    return _col.where('category', isEqualTo: category).orderBy('order').snapshots()
        .map((s) => s.docs.map(EncyclopediaEntry.fromFirestore).toList());
  }

  Future<void> createEntry(EncyclopediaEntry entry) async {
    await _col.add({...entry.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateEntry(EncyclopediaEntry entry) async {
    await _col.doc(entry.id).update(entry.toJson());
  }

  Future<void> deleteEntry(String id) async {
    await _col.doc(id).delete();
  }
}
