// lib/features/tester_feedback/domain/tester_feedback.dart
//
// 이슈 #794 — 테스터가 도안 작성자에게 보내는 전용 피드백.
// 작성자가 한 곳에서 받은 피드백을 보고, 응답하고, 해결 상태 토글 가능.

import 'package:cloud_firestore/cloud_firestore.dart';

enum TesterFeedbackCategory {
  bug,         // 버그 — 동작이 안 되거나 오류
  unclear,     // 표현 모호 — 단계/지시가 헷갈림
  missing,     // 누락 — 필요한 정보가 빠짐
  suggestion,  // 개선 제안 — 더 좋은 방향
  other,       // 기타
  ;

  String label(bool isKorean) {
    switch (this) {
      case TesterFeedbackCategory.bug:
        return isKorean ? '버그' : 'Bug';
      case TesterFeedbackCategory.unclear:
        return isKorean ? '표현 모호' : 'Unclear';
      case TesterFeedbackCategory.missing:
        return isKorean ? '누락' : 'Missing';
      case TesterFeedbackCategory.suggestion:
        return isKorean ? '개선 제안' : 'Suggestion';
      case TesterFeedbackCategory.other:
        return isKorean ? '기타' : 'Other';
    }
  }

  static TesterFeedbackCategory fromName(String? n) {
    if (n == null) return TesterFeedbackCategory.other;
    return TesterFeedbackCategory.values.firstWhere(
      (e) => e.name == n,
      orElse: () => TesterFeedbackCategory.other,
    );
  }
}

class TesterFeedbackReply {
  final String authorUid;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const TesterFeedbackReply({
    required this.authorUid,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static TesterFeedbackReply fromMap(Map<String, dynamic> m) {
    final ts = m['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else if (ts is DateTime) {
      created = ts;
    } else {
      created = DateTime.now();
    }
    return TesterFeedbackReply(
      authorUid: (m['authorUid'] ?? '').toString(),
      authorName: (m['authorName'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      createdAt: created,
    );
  }
}

class TesterFeedback {
  final String id;
  final String blueprintId;
  final String authorUid;
  final String authorName;
  final TesterFeedbackCategory category;
  final String content;
  // 단계 참조 — 어느 단계에 대한 피드백인지 (선택).
  final String? unitId;
  final int? unitOrder;
  final bool resolved;
  final List<TesterFeedbackReply> replies;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TesterFeedback({
    required this.id,
    required this.blueprintId,
    required this.authorUid,
    required this.authorName,
    required this.category,
    required this.content,
    this.unitId,
    this.unitOrder,
    this.resolved = false,
    this.replies = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  TesterFeedback copyWith({
    bool? resolved,
    List<TesterFeedbackReply>? replies,
    DateTime? updatedAt,
  }) {
    return TesterFeedback(
      id: id,
      blueprintId: blueprintId,
      authorUid: authorUid,
      authorName: authorName,
      category: category,
      content: content,
      unitId: unitId,
      unitOrder: unitOrder,
      resolved: resolved ?? this.resolved,
      replies: replies ?? this.replies,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'blueprintId': blueprintId,
        'authorUid': authorUid,
        'authorName': authorName,
        'category': category.name,
        'content': content,
        'unitId': unitId,
        'unitOrder': unitOrder,
        'resolved': resolved,
        'replies': replies.map((r) => r.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static TesterFeedback fromMap(Map<String, dynamic> m) {
    DateTime asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return TesterFeedback(
      id: (m['id'] ?? '').toString(),
      blueprintId: (m['blueprintId'] ?? '').toString(),
      authorUid: (m['authorUid'] ?? '').toString(),
      authorName: (m['authorName'] ?? '').toString(),
      category: TesterFeedbackCategory.fromName(m['category'] as String?),
      content: (m['content'] ?? '').toString(),
      unitId: m['unitId'] as String?,
      unitOrder: (m['unitOrder'] as num?)?.toInt(),
      resolved: m['resolved'] == true,
      replies: ((m['replies'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => TesterFeedbackReply.fromMap(
                e.cast<String, dynamic>(),
              ))
          .toList(),
      createdAt: asDate(m['createdAt']),
      updatedAt: asDate(m['updatedAt']),
    );
  }
}
