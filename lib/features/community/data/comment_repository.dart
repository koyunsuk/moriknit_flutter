import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) =>
      _db.collection('posts').doc(postId).collection('comments');

  Stream<List<CommentModel>> watchComments(String postId) {
    return _commentsRef(postId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
  }

  Future<void> addComment(String postId, CommentModel comment) async {
    await _db.runTransaction((tx) async {
      final commentRef = _commentsRef(postId).doc();
      tx.set(commentRef, comment.toJson());
      tx.update(_db.collection('posts').doc(postId), {
        'commentCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db.runTransaction((tx) async {
      tx.delete(_commentsRef(postId).doc(commentId));
      tx.update(_db.collection('posts').doc(postId), {
        'commentCount': FieldValue.increment(-1),
      });
    });
  }
}
