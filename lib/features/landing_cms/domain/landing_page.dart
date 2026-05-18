// 이슈 — 랜딩 CMS: 페이지/섹션 도메인 모델
//
// CMS Layer (Firestore landing_pages/{pageId})
//   { id, title, status, updatedAt, sections: [LandingSection.toMap(), ...] }
//
// 안전망: 데이터 없거나 fetch 실패 시 기존 랜딩 위젯(fallback)이 그대로 렌더.

import 'package:cloud_firestore/cloud_firestore.dart';

/// 페이지 발행 상태.
enum PublishStatus {
  draft,
  published;

  String get raw => switch (this) {
        PublishStatus.draft => 'draft',
        PublishStatus.published => 'published',
      };

  static PublishStatus parse(String? value) {
    switch (value) {
      case 'published':
        return PublishStatus.published;
      case 'draft':
      default:
        return PublishStatus.draft;
    }
  }
}

/// 섹션 타입.
///
/// `custom` 은 알 수 없는/미래 타입을 위한 안전망 — 렌더러가 무시하면 fallback이 자동으로 동작.
enum SectionType {
  hero,
  featureGrid,
  faq,
  pricing,
  cta,
  markdown,
  imageGallery,
  testimonial,
  custom;

  String get raw => switch (this) {
        SectionType.hero => 'hero',
        SectionType.featureGrid => 'featureGrid',
        SectionType.faq => 'faq',
        SectionType.pricing => 'pricing',
        SectionType.cta => 'cta',
        SectionType.markdown => 'markdown',
        SectionType.imageGallery => 'imageGallery',
        SectionType.testimonial => 'testimonial',
        SectionType.custom => 'custom',
      };

  String get label => switch (this) {
        SectionType.hero => '히어로',
        SectionType.featureGrid => '기능 그리드',
        SectionType.faq => 'FAQ',
        SectionType.pricing => '가격표',
        SectionType.cta => 'CTA 배너',
        SectionType.markdown => '본문(마크다운)',
        SectionType.imageGallery => '이미지 갤러리',
        SectionType.testimonial => '후기',
        SectionType.custom => '커스텀',
      };

  static SectionType parse(String? value) {
    switch (value) {
      case 'hero':
        return SectionType.hero;
      case 'featureGrid':
        return SectionType.featureGrid;
      case 'faq':
        return SectionType.faq;
      case 'pricing':
        return SectionType.pricing;
      case 'cta':
        return SectionType.cta;
      case 'markdown':
        return SectionType.markdown;
      case 'imageGallery':
        return SectionType.imageGallery;
      case 'testimonial':
        return SectionType.testimonial;
      default:
        return SectionType.custom;
    }
  }
}

/// CMS 섹션. content는 타입별 자유 JSON.
class LandingSection {
  final String id;
  final SectionType type;
  final int order;
  final Map<String, dynamic> content;

  const LandingSection({
    required this.id,
    required this.type,
    required this.order,
    required this.content,
  });

  LandingSection copyWith({
    String? id,
    SectionType? type,
    int? order,
    Map<String, dynamic>? content,
  }) {
    return LandingSection(
      id: id ?? this.id,
      type: type ?? this.type,
      order: order ?? this.order,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.raw,
        'order': order,
        'content': content,
      };

  factory LandingSection.fromMap(Map<dynamic, dynamic> raw) {
    final rawContent = raw['content'];
    final content = <String, dynamic>{};
    if (rawContent is Map) {
      rawContent.forEach((key, value) {
        content[key.toString()] = value;
      });
    }
    return LandingSection(
      id: (raw['id'] as String?)?.trim().isNotEmpty == true
          ? raw['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      type: SectionType.parse(raw['type'] as String?),
      order: (raw['order'] as num?)?.toInt() ?? 0,
      content: content,
    );
  }
}

/// CMS 페이지.
class LandingPage {
  final String id; // 'home' | 'pricing' | 'about' | ...
  final String title;
  final List<LandingSection> sections;
  final PublishStatus status;
  final DateTime? updatedAt;

  const LandingPage({
    required this.id,
    required this.title,
    required this.sections,
    required this.status,
    this.updatedAt,
  });

  /// 빈 페이지(처음 만들 때).
  factory LandingPage.empty(String id, {String? title}) => LandingPage(
        id: id,
        title: title ?? id,
        sections: const [],
        status: PublishStatus.draft,
        updatedAt: null,
      );

  LandingPage copyWith({
    String? id,
    String? title,
    List<LandingSection>? sections,
    PublishStatus? status,
    DateTime? updatedAt,
  }) {
    return LandingPage(
      id: id ?? this.id,
      title: title ?? this.title,
      sections: sections ?? this.sections,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'status': status.raw,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'sections': sections.map((s) => s.toMap()).toList(),
      };

  /// Firestore 직렬화용 — serverTimestamp 사용.
  Map<String, dynamic> toFirestore() => {
        'id': id,
        'title': title,
        'status': status.raw,
        'updatedAt': FieldValue.serverTimestamp(),
        'sections': sections.map((s) => s.toMap()).toList(),
      };

  factory LandingPage.fromMap(String id, Map<dynamic, dynamic> raw) {
    final rawSections = raw['sections'];
    final sections = <LandingSection>[];
    if (rawSections is List) {
      for (final s in rawSections) {
        if (s is Map) {
          sections.add(LandingSection.fromMap(s));
        }
      }
      sections.sort((a, b) => a.order.compareTo(b.order));
    }
    DateTime? updatedAt;
    final ts = raw['updatedAt'];
    if (ts is Timestamp) {
      updatedAt = ts.toDate();
    } else if (ts is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    return LandingPage(
      id: id,
      title: (raw['title'] as String?) ?? id,
      status: PublishStatus.parse(raw['status'] as String?),
      updatedAt: updatedAt,
      sections: sections,
    );
  }
}

/// 어드민 페이지 목록에 노출할 표준 페이지 ID와 라벨.
class LandingPageCatalog {
  static const List<({String id, String label})> defaults = [
    (id: 'home', label: '홈'),
    (id: 'pricing', label: '가격'),
    (id: 'about', label: '소개'),
    (id: 'features', label: '기능'),
    (id: 'classes', label: '클래스'),
    (id: 'contact', label: '문의'),
  ];

  static String labelOf(String id) {
    for (final p in defaults) {
      if (p.id == id) return p.label;
    }
    return id;
  }
}
