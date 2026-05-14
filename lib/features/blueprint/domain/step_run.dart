// lib/features/blueprint/domain/step_run.dart
//
// 이슈 #687 (Phase G) — 사용자의 청사진 실행 인스턴스.
//
// StepBlueprint → 사용자가 시작하면 StepRun 1건 생성.
// projectId 와 연결되거나 단독으로 실행 가능 (튜토리얼 등).
//
// 컬렉션 경로: users/{uid}/step_runs/{rid}
// 단계별 진행은 subcollection: users/{uid}/step_runs/{rid}/progress/{unitId}

import 'step_blueprint.dart' show BlueprintMemberRole;

// ── enums ────────────────────────────────────────────────────────────────────

/// 실행 역할.
enum StepRunRole {
  user, // 일반 사용자
  tester, // 청사진 테스터 (작가 초청)
  beta, // 베타 빌드
  preview; // 미리보기

  String get name => toString().split('.').last;

  static StepRunRole fromName(String? n) {
    if (n == null) return StepRunRole.user;
    return StepRunRole.values.firstWhere(
      (e) => e.name == n,
      orElse: () => StepRunRole.user,
    );
  }
}

/// 테스트 노트의 중요도.
enum TestNoteSeverity {
  info,
  warning,
  bug,
  blocker;

  String get name => toString().split('.').last;

  static TestNoteSeverity fromName(String? n) {
    if (n == null) return TestNoteSeverity.info;
    return TestNoteSeverity.values.firstWhere(
      (e) => e.name == n,
      orElse: () => TestNoteSeverity.info,
    );
  }
}

// ── value objects ────────────────────────────────────────────────────────────

/// 진행 요약 캐시 — progress 변경 시 transaction으로 갱신.
class RunSummary {
  final int totalUnits;
  final int completedCount;
  final String? currentUnitId;
  final double percentComplete; // 0.0 ~ 1.0
  final DateTime? lastActivityAt;

  const RunSummary({
    this.totalUnits = 0,
    this.completedCount = 0,
    this.currentUnitId,
    this.percentComplete = 0,
    this.lastActivityAt,
  });

  Map<String, dynamic> toMap() => {
        'totalUnits': totalUnits,
        'completedCount': completedCount,
        if (currentUnitId != null) 'currentUnitId': currentUnitId,
        'percentComplete': percentComplete,
        if (lastActivityAt != null)
          'lastActivityAt': lastActivityAt!.toIso8601String(),
      };

  factory RunSummary.fromMap(Map<String, dynamic> m) => RunSummary(
        totalUnits: m['totalUnits'] as int? ?? 0,
        completedCount: m['completedCount'] as int? ?? 0,
        currentUnitId: m['currentUnitId'] as String?,
        percentComplete: (m['percentComplete'] as num?)?.toDouble() ?? 0,
        lastActivityAt: m['lastActivityAt'] == null
            ? null
            : DateTime.tryParse(m['lastActivityAt'] as String),
      );

  RunSummary copyWith({
    int? totalUnits,
    int? completedCount,
    String? currentUnitId,
    double? percentComplete,
    DateTime? lastActivityAt,
  }) =>
      RunSummary(
        totalUnits: totalUnits ?? this.totalUnits,
        completedCount: completedCount ?? this.completedCount,
        currentUnitId: currentUnitId ?? this.currentUnitId,
        percentComplete: percentComplete ?? this.percentComplete,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );
}

/// 테스터 노트 (tester role만 작성).
class RunTestNote {
  final String unitId;
  final String note;
  final TestNoteSeverity severity;
  final String? resolvedInBlueprintVersion;
  final DateTime createdAt;

  const RunTestNote({
    required this.unitId,
    required this.note,
    this.severity = TestNoteSeverity.info,
    this.resolvedInBlueprintVersion,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'unitId': unitId,
        'note': note,
        'severity': severity.name,
        if (resolvedInBlueprintVersion != null)
          'resolvedInBlueprintVersion': resolvedInBlueprintVersion,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RunTestNote.fromMap(Map<String, dynamic> m) => RunTestNote(
        unitId: m['unitId'] as String? ?? '',
        note: m['note'] as String? ?? '',
        severity: TestNoteSeverity.fromName(m['severity'] as String?),
        resolvedInBlueprintVersion:
            m['resolvedInBlueprintVersion'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ── main entity ──────────────────────────────────────────────────────────────

class StepRun {
  final String id;
  final String userUid;

  final String blueprintId;
  final String sourceBlueprintVersion;

  /// 프로젝트 연결 (선택). 도안→프로젝트 미러링 시 채움.
  final String? projectId;

  final StepRunRole role;

  /// 협업 멤버 — uid → role (예: 작가가 자기 도안의 tester 추가).
  final Map<String, BlueprintMemberRole> members;

  final RunSummary summary;

  /// 사용한 자산 — 추후 시간/재고 집계용.
  final List<String> yarnIds;
  final List<String> needleIds;
  final String? swatchId;

  /// 테스터 역할일 때 작성된 노트.
  final List<RunTestNote>? testNotes;

  /// 완성 후 발행된 Article 참조 (community_showcase 등).
  final String? publishedArticleId;

  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const StepRun({
    required this.id,
    required this.userUid,
    required this.blueprintId,
    this.sourceBlueprintVersion = '1.0.0',
    this.projectId,
    this.role = StepRunRole.user,
    this.members = const {},
    this.summary = const RunSummary(),
    this.yarnIds = const [],
    this.needleIds = const [],
    this.swatchId,
    this.testNotes,
    this.publishedArticleId,
    required this.startedAt,
    this.completedAt,
    this.updatedAt,
  });

  bool get isCompleted => completedAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userUid': userUid,
        'blueprintId': blueprintId,
        'sourceBlueprintVersion': sourceBlueprintVersion,
        if (projectId != null) 'projectId': projectId,
        'role': role.name,
        'members': members.map((k, v) => MapEntry(k, v.name)),
        'summary': summary.toMap(),
        'yarnIds': yarnIds,
        'needleIds': needleIds,
        if (swatchId != null) 'swatchId': swatchId,
        if (testNotes != null)
          'testNotes': testNotes!.map((n) => n.toMap()).toList(),
        if (publishedArticleId != null)
          'publishedArticleId': publishedArticleId,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory StepRun.fromMap(Map<String, dynamic> m) => StepRun(
        id: m['id'] as String? ?? '',
        userUid: m['userUid'] as String? ?? '',
        blueprintId: m['blueprintId'] as String? ?? '',
        sourceBlueprintVersion:
            m['sourceBlueprintVersion'] as String? ?? '1.0.0',
        projectId: m['projectId'] as String?,
        role: StepRunRole.fromName(m['role'] as String?),
        members: ((m['members'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(
            k as String,
            BlueprintMemberRole.fromName(v as String?),
          ),
        ),
        summary: m['summary'] == null
            ? const RunSummary()
            : RunSummary.fromMap(
                Map<String, dynamic>.from(m['summary'] as Map),
              ),
        yarnIds:
            ((m['yarnIds'] as List?) ?? []).map((e) => e as String).toList(),
        needleIds: ((m['needleIds'] as List?) ?? [])
            .map((e) => e as String)
            .toList(),
        swatchId: m['swatchId'] as String?,
        testNotes: m['testNotes'] == null
            ? null
            : ((m['testNotes'] as List)
                .map(
                  (n) => RunTestNote.fromMap(
                    Map<String, dynamic>.from(n as Map),
                  ),
                )
                .toList()),
        publishedArticleId: m['publishedArticleId'] as String?,
        startedAt: DateTime.tryParse(m['startedAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: m['completedAt'] == null
            ? null
            : DateTime.tryParse(m['completedAt'] as String),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  StepRun copyWith({
    String? id,
    String? userUid,
    String? blueprintId,
    String? sourceBlueprintVersion,
    String? projectId,
    StepRunRole? role,
    Map<String, BlueprintMemberRole>? members,
    RunSummary? summary,
    List<String>? yarnIds,
    List<String>? needleIds,
    String? swatchId,
    List<RunTestNote>? testNotes,
    String? publishedArticleId,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      StepRun(
        id: id ?? this.id,
        userUid: userUid ?? this.userUid,
        blueprintId: blueprintId ?? this.blueprintId,
        sourceBlueprintVersion:
            sourceBlueprintVersion ?? this.sourceBlueprintVersion,
        projectId: projectId ?? this.projectId,
        role: role ?? this.role,
        members: members ?? this.members,
        summary: summary ?? this.summary,
        yarnIds: yarnIds ?? this.yarnIds,
        needleIds: needleIds ?? this.needleIds,
        swatchId: swatchId ?? this.swatchId,
        testNotes: testNotes ?? this.testNotes,
        publishedArticleId: publishedArticleId ?? this.publishedArticleId,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
