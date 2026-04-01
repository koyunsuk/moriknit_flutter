import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/editorial_post.dart';

class EditorialRepository {
  final _col =
      FirebaseFirestore.instance.collection('editorial_posts');

  /// Latest published post per type (for home screen preview)
  Stream<List<EditorialPost>> watchLatestByType(String type) {
    return _col
        .where('type', isEqualTo: type)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => EditorialPost.fromFirestore(d)).toList());
  }

  /// All published posts for a type (list screen)
  Stream<List<EditorialPost>> watchByType(String type) {
    return _col
        .where('type', isEqualTo: type)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => EditorialPost.fromFirestore(d)).toList());
  }

  /// Admin: all posts
  Stream<List<EditorialPost>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => EditorialPost.fromFirestore(d)).toList());
  }

  Future<void> createPost(EditorialPost post) async {
    await _col.add(post.toJson());
  }

  Future<void> updatePost(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  Future<void> deletePost(String id) async {
    await _col.doc(id).delete();
  }
}
