// lib/features/blueprint/domain/article.dart
//
// 이슈 #687 (Phase G) — 청사진/실행 후 발행 가능한 글(Article) 메타.
//
// StepRun 완료 후 사용자 후기·튜토리얼 작성 / 작가의 청사진 소개 글 등에 활용.
// 본격 구현(블록 에디터 등)은 후속 Phase. 본 파일은 메타만 정의.
//
// 컬렉션 경로: articles/{aid}

enum ArticleKind {
  blueprintIntro, // 청사진 소개 (작가 글)
  runReview, // 실행 후기
  techniqueGuide, // 기법 가이드
  storyShowcase; // 커뮤니티 쇼케이스 스토리

  String get name => toString().split('.').last;

  static ArticleKind fromName(String? n) {
    if (n == null) return ArticleKind.storyShowcase;
    return ArticleKind.values.firstWhere(
      (e) => e.name == n,
      orElse: () => ArticleKind.storyShowcase,
    );
  }
}

enum ArticlePublishStatus {
  draft,
  scheduled,
  published,
  archived;

  String get name => toString().split('.').last;

  static ArticlePublishStatus fromName(String? n) {
    if (n == null) return ArticlePublishStatus.draft;
    return ArticlePublishStatus.values.firstWhere(
      (e) => e.name == n,
      orElse: () => ArticlePublishStatus.draft,
    );
  }
}

class Article {
  final String id;
  final String authorUid;
  final ArticleKind kind;
  final ArticlePublishStatus publishStatus;

  final String title;
  final String? subtitle;
  final String? coverImageUrl;

  /// (선택) 관련 청사진/실행 참조.
  final String? blueprintId;
  final String? stepRunId;

  /// 본문(메타). 본격 블록 에디터 도입 전 placeholder.
  final String body;

  final List<String> tags;

  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  const Article({
    required this.id,
    required this.authorUid,
    this.kind = ArticleKind.storyShowcase,
    this.publishStatus = ArticlePublishStatus.draft,
    required this.title,
    this.subtitle,
    this.coverImageUrl,
    this.blueprintId,
    this.stepRunId,
    this.body = '',
    this.tags = const [],
    required this.createdAt,
    this.publishedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorUid': authorUid,
        'kind': kind.name,
        'publishStatus': publishStatus.name,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (blueprintId != null) 'blueprintId': blueprintId,
        if (stepRunId != null) 'stepRunId': stepRunId,
        'body': body,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Article.fromMap(Map<String, dynamic> m) => Article(
        id: m['id'] as String? ?? '',
        authorUid: m['authorUid'] as String? ?? '',
        kind: ArticleKind.fromName(m['kind'] as String?),
        publishStatus:
            ArticlePublishStatus.fromName(m['publishStatus'] as String?),
        title: m['title'] as String? ?? '',
        subtitle: m['subtitle'] as String?,
        coverImageUrl: m['coverImageUrl'] as String?,
        blueprintId: m['blueprintId'] as String?,
        stepRunId: m['stepRunId'] as String?,
        body: m['body'] as String? ?? '',
        tags: ((m['tags'] as List?) ?? []).map((e) => e as String).toList(),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        publishedAt: m['publishedAt'] == null
            ? null
            : DateTime.tryParse(m['publishedAt'] as String),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  Article copyWith({
    String? id,
    String? authorUid,
    ArticleKind? kind,
    ArticlePublishStatus? publishStatus,
    String? title,
    String? subtitle,
    String? coverImageUrl,
    String? blueprintId,
    String? stepRunId,
    String? body,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) =>
      Article(
        id: id ?? this.id,
        authorUid: authorUid ?? this.authorUid,
        kind: kind ?? this.kind,
        publishStatus: publishStatus ?? this.publishStatus,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        blueprintId: blueprintId ?? this.blueprintId,
        stepRunId: stepRunId ?? this.stepRunId,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        publishedAt: publishedAt ?? this.publishedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
