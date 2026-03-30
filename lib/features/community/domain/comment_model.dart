import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String uid;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CommentModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '익명',
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'authorName': authorName,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}/${createdAt.day}';
  }
}
