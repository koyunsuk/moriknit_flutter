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

  /// 코바늘 전용 — craftType 필드가 명시된 문서만 조회 (신규 등록 항목)
  Stream<List<EncyclopediaEntry>> watchCrochet() {
    return _col.where('craftType', isEqualTo: 'crochet').orderBy('order').snapshots()
        .map((s) => s.docs.map(EncyclopediaEntry.fromFirestore).toList());
  }

  /// 대바늘 전용 — craftType 필드가 없는 구버전 항목 포함 (전체 로드 후 클라이언트 필터)
  Stream<List<EncyclopediaEntry>> watchKnitting() {
    return watchAll().map(
      (entries) => entries.where((e) => e.craftType == 'knitting').toList(),
    );
  }

  Stream<List<EncyclopediaEntry>> watchByCraftType(String craftType) {
    if (craftType == 'knitting') return watchKnitting();
    return watchCrochet();
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
