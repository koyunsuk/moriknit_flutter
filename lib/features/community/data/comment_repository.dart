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

/// 갤러리(public_projects) 전용 댓글 저장소
class GalleryCommentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String entryId) =>
      _db.collection('public_projects').doc(entryId).collection('comments');

  Stream<List<CommentModel>> watchComments(String entryId) {
    return _ref(entryId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
  }

  Future<void> addComment(String entryId, CommentModel comment) async {
    await _ref(entryId).add(comment.toJson());
  }

  Future<void> deleteComment(String entryId, String commentId) async {
    await _ref(entryId).doc(commentId).delete();
  }
}
