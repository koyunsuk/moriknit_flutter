import 'package:cloud_firestore/cloud_firestore.dart';

class MemoModel {
  final String id;
  final String uid;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoModel({
    required this.id,
    required this.uid,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoModel.empty({required String uid}) => MemoModel(
        id: '',
        uid: uid,
        content: '',
        imageUrls: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  factory MemoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MemoModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrls: (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'content': content,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateJson() => {
        'content': content,
        'imageUrls': imageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  MemoModel copyWith({
    String? id,
    String? uid,
    String? content,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MemoModel(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        content: content ?? this.content,
        imageUrls: imageUrls ?? this.imageUrls,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
