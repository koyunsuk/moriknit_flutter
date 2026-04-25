import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_json.dart';

class MarketReview {
  final String id;
  final String itemId;
  final String reviewerUid;
  final String reviewerName;
  final double rating; // 1.0 ~ 5.0
  final String comment;
  final DateTime? createdAt;

  const MarketReview({
    required this.id,
    required this.itemId,
    required this.reviewerUid,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory MarketReview.fromFirestore(DocumentSnapshot doc) {
    final data = normalizeFirestoreMap((doc.data() as Map<String, dynamic>?) ?? {});
    return MarketReview(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      reviewerUid: data['reviewerUid'] as String? ?? '',
      reviewerName: data['reviewerName'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'reviewerUid': reviewerUid,
        'reviewerName': reviewerName,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt?.toIso8601String(),
      };
}
