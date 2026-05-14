// lib/features/blueprint/domain/step_run_progress.dart
//
// 이슈 #687 (Phase G) — 청사진 실행 시 단계별 진행 상태.
//
// 컬렉션 경로: users/{uid}/step_runs/{rid}/progress/{unitId}
// 1 unitId = 1 progress 문서 (unitId == blueprint unit.id).
//
// 카운터·타이머·진행사진을 단일 문서에서 다룬다.

class StepRunProgress {
  /// blueprint unit.id 와 동일 (문서 ID로 사용 권장).
  final String unitId;
  final String runId;

  final bool isDone;
  final DateTime? doneAt;

  final int currentRow;
  final int targetRow;

  /// 작업 누적 시간 (초).
  final int totalSeconds;

  /// 현재 타이머가 켜져 있다면 시작 시각.
  final DateTime? sessionStartedAt;

  /// 단계 진행 중 찍은 사진들.
  final List<ProgressImage> progressImages;

  final String? note;

  /// 단계에 연결된 카운터 문서 id (기존 carrier 호환).
  final String? counterId;

  /// 단계에서 실제 사용한 실 양(g) — 텍스트 그대로 저장.
  final String? yarnUsedG;

  final DateTime? updatedAt;

  const StepRunProgress({
    required this.unitId,
    required this.runId,
    this.isDone = false,
    this.doneAt,
    this.currentRow = 0,
    this.targetRow = 0,
    this.totalSeconds = 0,
    this.sessionStartedAt,
    this.progressImages = const [],
    this.note,
    this.counterId,
    this.yarnUsedG,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'unitId': unitId,
        'runId': runId,
        'isDone': isDone,
        if (doneAt != null) 'doneAt': doneAt!.toIso8601String(),
        'currentRow': currentRow,
        'targetRow': targetRow,
        'totalSeconds': totalSeconds,
        if (sessionStartedAt != null)
          'sessionStartedAt': sessionStartedAt!.toIso8601String(),
        'progressImages':
            progressImages.map((i) => i.toMap()).toList(),
        if (note != null) 'note': note,
        if (counterId != null) 'counterId': counterId,
        if (yarnUsedG != null) 'yarnUsedG': yarnUsedG,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory StepRunProgress.fromMap(Map<String, dynamic> m) => StepRunProgress(
        unitId: m['unitId'] as String? ?? '',
        runId: m['runId'] as String? ?? '',
        isDone: m['isDone'] as bool? ?? false,
        doneAt: m['doneAt'] == null
            ? null
            : DateTime.tryParse(m['doneAt'] as String),
        currentRow: m['currentRow'] as int? ?? 0,
        targetRow: m['targetRow'] as int? ?? 0,
        totalSeconds: m['totalSeconds'] as int? ?? 0,
        sessionStartedAt: m['sessionStartedAt'] == null
            ? null
            : DateTime.tryParse(m['sessionStartedAt'] as String),
        progressImages: ((m['progressImages'] as List?) ?? const [])
            .map(
              (e) => ProgressImage.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        note: m['note'] as String?,
        counterId: m['counterId'] as String?,
        yarnUsedG: m['yarnUsedG'] as String?,
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  StepRunProgress copyWith({
    String? unitId,
    String? runId,
    bool? isDone,
    DateTime? doneAt,
    int? currentRow,
    int? targetRow,
    int? totalSeconds,
    DateTime? sessionStartedAt,
    List<ProgressImage>? progressImages,
    String? note,
    String? counterId,
    String? yarnUsedG,
    DateTime? updatedAt,
  }) =>
      StepRunProgress(
        unitId: unitId ?? this.unitId,
        runId: runId ?? this.runId,
        isDone: isDone ?? this.isDone,
        doneAt: doneAt ?? this.doneAt,
        currentRow: currentRow ?? this.currentRow,
        targetRow: targetRow ?? this.targetRow,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
        progressImages: progressImages ?? this.progressImages,
        note: note ?? this.note,
        counterId: counterId ?? this.counterId,
        yarnUsedG: yarnUsedG ?? this.yarnUsedG,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class ProgressImage {
  final String url;
  final String? caption;
  final DateTime takenAt;
  final int order;

  const ProgressImage({
    required this.url,
    this.caption,
    required this.takenAt,
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'url': url,
        if (caption != null) 'caption': caption,
        'takenAt': takenAt.toIso8601String(),
        'order': order,
      };

  factory ProgressImage.fromMap(Map<String, dynamic> m) => ProgressImage(
        url: m['url'] as String? ?? '',
        caption: m['caption'] as String?,
        takenAt: DateTime.tryParse(m['takenAt'] as String? ?? '') ??
            DateTime.now(),
        order: m['order'] as int? ?? 0,
      );

  ProgressImage copyWith({
    String? url,
    String? caption,
    DateTime? takenAt,
    int? order,
  }) =>
      ProgressImage(
        url: url ?? this.url,
        caption: caption ?? this.caption,
        takenAt: takenAt ?? this.takenAt,
        order: order ?? this.order,
      );
}
