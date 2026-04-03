import 'package:cloud_firestore/cloud_firestore.dart';

class CourseItem {
  final String id;
  final String title;
  final String titleEn;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String category; // '입문', '중급', '고급'
  final String mediaType; // 'youtube', 'video', 'audio', 'pdf', 'file'
  final int order;
  final bool isPublished;
  final DateTime createdAt;

  const CourseItem({
    required this.id,
    required this.title,
    this.titleEn = '',
    this.description = '',
    this.videoUrl = '',
    this.thumbnailUrl = '',
    required this.category,
    this.mediaType = 'youtube',
    this.order = 0,
    this.isPublished = false,
    required this.createdAt,
  });

  factory CourseItem.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return CourseItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      titleEn: d['titleEn'] as String? ?? '',
      description: d['description'] as String? ?? '',
      videoUrl: d['videoUrl'] as String? ?? '',
      thumbnailUrl: d['thumbnailUrl'] as String? ?? '',
      category: d['category'] as String? ?? '입문',
      mediaType: d['mediaType'] as String? ?? 'youtube',
      order: (d['order'] as num?)?.toInt() ?? 0,
      isPublished: d['isPublished'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'titleEn': titleEn,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'mediaType': mediaType,
        'order': order,
        'isPublished': isPublished,
      };
}
