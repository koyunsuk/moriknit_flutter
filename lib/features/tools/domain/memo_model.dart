import 'package:cloud_firestore/cloud_firestore.dart';

class MemoModel {
  final String id;
  final String uid;
  final String content;
  final List<String> imageUrls;
  final String? voiceUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoModel({
    required this.id,
    required this.uid,
    required this.content,
    required this.imageUrls,
    this.voiceUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoModel.empty({required String uid}) => MemoModel(
        id: '',
        uid: uid,
        content: '',
        imageUrls: const [],
        voiceUrl: null,
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
      voiceUrl: data['voiceUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'content': content,
        'imageUrls': imageUrls,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateJson() => {
        'content': content,
        'imageUrls': imageUrls,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  MemoModel copyWith({
    String? id,
    String? uid,
    String? content,
    List<String>? imageUrls,
    String? voiceUrl,
    bool clearVoiceUrl = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MemoModel(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        content: content ?? this.content,
        imageUrls: imageUrls ?? this.imageUrls,
        voiceUrl: clearVoiceUrl ? null : (voiceUrl ?? this.voiceUrl),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
