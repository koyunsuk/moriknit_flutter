import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalEncyclopediaEntry {
  final String id;
  final String term;
  final String definition;
  final String example;
  final String sourceId; // empty if user-created, official entry id if bookmarked
  final bool isBookmark;
  final DateTime createdAt;

  const PersonalEncyclopediaEntry({
    required this.id,
    required this.term,
    required this.definition,
    this.example = '',
    this.sourceId = '',
    this.isBookmark = false,
    required this.createdAt,
  });

  factory PersonalEncyclopediaEntry.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PersonalEncyclopediaEntry(
      id: doc.id,
      term: data['term'] as String? ?? '',
      definition: data['definition'] as String? ?? '',
      example: data['example'] as String? ?? '',
      sourceId: data['sourceId'] as String? ?? '',
      isBookmark: data['isBookmark'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'definition': definition,
        'example': example,
        'sourceId': sourceId,
        'isBookmark': isBookmark,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
