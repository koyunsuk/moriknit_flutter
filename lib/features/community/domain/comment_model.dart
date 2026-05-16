import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String uid;
  final String authorName;
  final String content;
  final DateTime createdAt;
  // 이슈 #749 — 질문게시판 답글 채택 시스템
  final bool isAccepted;
  final DateTime? acceptedAt;

  const CommentModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.isAccepted = false,
    this.acceptedAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CommentModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '익명',
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAccepted: data['isAccepted'] as bool? ?? false,
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
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
