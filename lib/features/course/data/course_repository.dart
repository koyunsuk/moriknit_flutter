import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/course_item.dart';

class CourseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('courses');

  Stream<List<CourseItem>> watchPublished() {
    return _col.where('isPublished', isEqualTo: true).snapshots().map((s) {
      final list = s.docs.map(CourseItem.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CourseItem>> watchAll() {
    return _col.orderBy('createdAt', descending: true).snapshots()
        .map((s) => s.docs.map(CourseItem.fromFirestore).toList());
  }

  Future<void> createCourse(CourseItem item) async {
    await _col.add({...item.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateCourse(CourseItem item) async {
    await _col.doc(item.id).update(item.toJson());
  }

  Future<void> deleteCourse(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> togglePublished(String id, bool value) async {
    await _col.doc(id).update({'isPublished': value});
  }
}
