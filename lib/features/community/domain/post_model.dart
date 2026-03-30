import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String uid;
  final String authorName;
  final String category;
  final String title;
  final String content;
  final List<String> imageUrls;
  final List<String> attachmentUrls;
  final List<String> attachmentNames;
  final int likeCount;
  final int commentCount;
  final List<String> likedBy;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.category,
    required this.title,
    required this.content,
    this.imageUrls = const [],
    this.attachmentUrls = const [],
    this.attachmentNames = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedBy = const [],
    required this.createdAt,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PostModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Anonymous',
      category: data['category'] as String? ?? 'all',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const <String>[]),
      attachmentUrls: List<String>.from(data['attachmentUrls'] as List? ?? const <String>[]),
      attachmentNames: List<String>.from(data['attachmentNames'] as List? ?? const <String>[]),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] as List? ?? const <String>[]),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'authorName': authorName,
        'category': category,
        'title': title,
        'content': content,
        'imageUrls': imageUrls,
        'attachmentUrls': attachmentUrls,
        'attachmentNames': attachmentNames,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'likedBy': likedBy,
      };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${createdAt.month}/${createdAt.day}';
  }
}
