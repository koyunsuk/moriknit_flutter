import 'package:cloud_firestore/cloud_firestore.dart';

class EditorialPost {
  final String id;
  final String type; // 'letter' | 'tips' | 'trending' | 'youtube'
  final String title;
  final String content;
  final String youtubeVideoId; // empty if not youtube
  final String imageUrl; // optional
  final bool isPublished;
  final DateTime? createdAt;
  final String authorName;

  const EditorialPost({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.youtubeVideoId = '',
    this.imageUrl = '',
    required this.isPublished,
    this.createdAt,
    this.authorName = '',
  });

  factory EditorialPost.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EditorialPost(
      id: doc.id,
      type: data['type'] as String? ?? 'letter',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      youtubeVideoId: data['youtubeVideoId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      isPublished: data['isPublished'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      authorName: data['authorName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'content': content,
        'youtubeVideoId': youtubeVideoId,
        'imageUrl': imageUrl,
        'isPublished': isPublished,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': authorName,
      };
}
