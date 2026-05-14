// lib/features/blueprint/domain/project_book.dart
//
// 이슈 #687 (Phase G) — 프로젝트 결과물을 묶는 작품집(ProjectBook) 메타.
//
// 1개 ProjectBook = N개 StepRun · Article · Photo. 사용자의 포트폴리오·연감.
// 본격 구현은 후속 Phase. 본 파일은 메타만 정의.
//
// 컬렉션 경로: users/{uid}/project_books/{bid}

enum ProjectBookKind {
  portfolio, // 포트폴리오
  yearbook, // 연감(연도별 모음)
  giftbook, // 선물 묶음
  custom;

  String get name => toString().split('.').last;

  static ProjectBookKind fromName(String? n) {
    if (n == null) return ProjectBookKind.custom;
    return ProjectBookKind.values.firstWhere(
      (e) => e.name == n,
      orElse: () => ProjectBookKind.custom,
    );
  }
}

class ProjectBook {
  final String id;
  final String ownerUid;
  final ProjectBookKind kind;

  final String title;
  final String? subtitle;
  final String? coverImageUrl;

  final List<String> stepRunIds;
  final List<String> articleIds;
  final List<String> projectIds;

  final bool isPublic;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProjectBook({
    required this.id,
    required this.ownerUid,
    this.kind = ProjectBookKind.custom,
    required this.title,
    this.subtitle,
    this.coverImageUrl,
    this.stepRunIds = const [],
    this.articleIds = const [],
    this.projectIds = const [],
    this.isPublic = false,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerUid': ownerUid,
        'kind': kind.name,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        'stepRunIds': stepRunIds,
        'articleIds': articleIds,
        'projectIds': projectIds,
        'isPublic': isPublic,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory ProjectBook.fromMap(Map<String, dynamic> m) => ProjectBook(
        id: m['id'] as String? ?? '',
        ownerUid: m['ownerUid'] as String? ?? '',
        kind: ProjectBookKind.fromName(m['kind'] as String?),
        title: m['title'] as String? ?? '',
        subtitle: m['subtitle'] as String?,
        coverImageUrl: m['coverImageUrl'] as String?,
        stepRunIds: ((m['stepRunIds'] as List?) ?? [])
            .map((e) => e as String)
            .toList(),
        articleIds: ((m['articleIds'] as List?) ?? [])
            .map((e) => e as String)
            .toList(),
        projectIds: ((m['projectIds'] as List?) ?? [])
            .map((e) => e as String)
            .toList(),
        isPublic: m['isPublic'] as bool? ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  ProjectBook copyWith({
    String? id,
    String? ownerUid,
    ProjectBookKind? kind,
    String? title,
    String? subtitle,
    String? coverImageUrl,
    List<String>? stepRunIds,
    List<String>? articleIds,
    List<String>? projectIds,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProjectBook(
        id: id ?? this.id,
        ownerUid: ownerUid ?? this.ownerUid,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        stepRunIds: stepRunIds ?? this.stepRunIds,
        articleIds: articleIds ?? this.articleIds,
        projectIds: projectIds ?? this.projectIds,
        isPublic: isPublic ?? this.isPublic,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
