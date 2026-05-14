import 'step_unit_origin.dart';
import 'step_unit_progress.dart';
import 'step_unit_source.dart';
import 'step_unit_tag.dart';

/// 이슈 #687 — 공통 StepUnit 모델.
///
/// 모리니트 4개 단계 개념(단계로그/섹션/AI단계/템플릿)을 통합하는 단일 도메인 객체.
/// - `progress == null` → 청사진(blueprint): 도안/템플릿에 저장되는 정적 단계
/// - `progress != null` → 인스턴스: 프로젝트에 적용되어 진행 상태를 보유한 단계
class StepUnit {
  final String id;
  final int order;

  final String title;
  final String? titleKo;
  final String? titleEn;

  final String instruction;
  final String? instructionKo;
  final String? instructionEn;

  final int targetRows;

  final StepUnitSource source;
  final StepUnitOrigin? origin;
  final List<StepUnitTag> tags;

  /// 사용자 인스턴스 진행상태. null이면 청사진.
  final StepUnitProgress? progress;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const StepUnit({
    required this.id,
    required this.order,
    required this.title,
    this.titleKo,
    this.titleEn,
    required this.instruction,
    this.instructionKo,
    this.instructionEn,
    this.targetRows = 0,
    required this.source,
    this.origin,
    this.tags = const [],
    this.progress,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isBlueprint => progress == null;
  bool get isInstance => progress != null;

  String localizedTitle(bool ko) =>
      ko ? (titleKo ?? title) : (titleEn ?? title);

  String localizedInstruction(bool ko) =>
      ko ? (instructionKo ?? instruction) : (instructionEn ?? instruction);

  Map<String, dynamic> toMap() => {
        'id': id,
        'order': order,
        'title': title,
        if (titleKo != null) 'titleKo': titleKo,
        if (titleEn != null) 'titleEn': titleEn,
        'instruction': instruction,
        if (instructionKo != null) 'instructionKo': instructionKo,
        if (instructionEn != null) 'instructionEn': instructionEn,
        'targetRows': targetRows,
        'source': source.name,
        if (origin != null) 'origin': origin!.toMap(),
        'tags': tags.map((t) => t.toMap()).toList(),
        if (progress != null) 'progress': progress!.toMap(),
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory StepUnit.fromMap(Map<String, dynamic> m) => StepUnit(
        id: m['id'] as String,
        order: m['order'] as int? ?? 0,
        title: m['title'] as String? ?? '',
        titleKo: m['titleKo'] as String?,
        titleEn: m['titleEn'] as String?,
        instruction: m['instruction'] as String? ?? '',
        instructionKo: m['instructionKo'] as String?,
        instructionEn: m['instructionEn'] as String?,
        targetRows: m['targetRows'] as int? ?? 0,
        source: StepUnitSource.fromName(m['source'] as String?),
        origin: m['origin'] == null
            ? null
            : StepUnitOrigin.fromMap(
                Map<String, dynamic>.from(m['origin'] as Map),
              ),
        tags: ((m['tags'] as List?) ?? [])
            .map(
              (t) => StepUnitTag.fromMap(Map<String, dynamic>.from(t as Map)),
            )
            .toList(),
        progress: m['progress'] == null
            ? null
            : StepUnitProgress.fromMap(
                Map<String, dynamic>.from(m['progress'] as Map),
              ),
        createdAt:
            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  StepUnit copyWith({
    String? id,
    int? order,
    String? title,
    String? titleKo,
    String? titleEn,
    String? instruction,
    String? instructionKo,
    String? instructionEn,
    int? targetRows,
    StepUnitSource? source,
    StepUnitOrigin? origin,
    List<StepUnitTag>? tags,
    StepUnitProgress? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StepUnit(
        id: id ?? this.id,
        order: order ?? this.order,
        title: title ?? this.title,
        titleKo: titleKo ?? this.titleKo,
        titleEn: titleEn ?? this.titleEn,
        instruction: instruction ?? this.instruction,
        instructionKo: instructionKo ?? this.instructionKo,
        instructionEn: instructionEn ?? this.instructionEn,
        targetRows: targetRows ?? this.targetRows,
        source: source ?? this.source,
        origin: origin ?? this.origin,
        tags: tags ?? this.tags,
        progress: progress ?? this.progress,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
