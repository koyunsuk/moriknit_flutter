// lib/features/blueprint/domain/step_blueprint_unit.dart
//
// 이슈 #687 (Phase G) — 청사진의 개별 단위(단계).
//
// StepUnit(통합 view)과 별개로 청사진 storage 모델. subcollection 경로:
//   step_blueprints/{bid}/units/{unitId}
//
// chartRegion: 단계가 차트의 어느 영역에 해당하는지 명시 (행/열 또는 round 또는 path).
// referenceImages: 단계마다 참고 사진/도식 첨부 가능.

import '../../../core/domain/step_unit/step_unit_tag.dart';

class StepBlueprintUnit {
  final String id;
  final String blueprintId;
  final int order;

  final String title;
  final String? titleKo;
  final String? titleEn;

  final String instruction;
  final String? instructionKo;
  final String? instructionEn;

  /// 목표 행/단 수.
  final int targetRows;

  /// 참고 이미지(여러 장).
  final List<UnitReferenceImage> referenceImages;

  /// (선택) 단계가 차트의 어느 영역에 해당하는지.
  final ChartRegion? chartRegion;

  /// 마켓플레이스 무료 미리보기 단계 여부.
  final bool isPreview;

  final List<StepUnitTag> tags;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const StepBlueprintUnit({
    required this.id,
    required this.blueprintId,
    this.order = 0,
    required this.title,
    this.titleKo,
    this.titleEn,
    required this.instruction,
    this.instructionKo,
    this.instructionEn,
    this.targetRows = 0,
    this.referenceImages = const [],
    this.chartRegion,
    this.isPreview = false,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  String localizedTitle(bool ko) =>
      ko ? (titleKo ?? title) : (titleEn ?? title);

  String localizedInstruction(bool ko) =>
      ko ? (instructionKo ?? instruction) : (instructionEn ?? instruction);

  Map<String, dynamic> toMap() => {
        'id': id,
        'blueprintId': blueprintId,
        'order': order,
        'title': title,
        if (titleKo != null) 'titleKo': titleKo,
        if (titleEn != null) 'titleEn': titleEn,
        'instruction': instruction,
        if (instructionKo != null) 'instructionKo': instructionKo,
        if (instructionEn != null) 'instructionEn': instructionEn,
        'targetRows': targetRows,
        'referenceImages':
            referenceImages.map((i) => i.toMap()).toList(),
        if (chartRegion != null) 'chartRegion': chartRegion!.toMap(),
        'isPreview': isPreview,
        'tags': tags.map((t) => t.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory StepBlueprintUnit.fromMap(Map<String, dynamic> m) =>
      StepBlueprintUnit(
        id: m['id'] as String? ?? '',
        blueprintId: m['blueprintId'] as String? ?? '',
        order: m['order'] as int? ?? 0,
        title: m['title'] as String? ?? '',
        titleKo: m['titleKo'] as String?,
        titleEn: m['titleEn'] as String?,
        instruction: m['instruction'] as String? ?? '',
        instructionKo: m['instructionKo'] as String?,
        instructionEn: m['instructionEn'] as String?,
        targetRows: m['targetRows'] as int? ?? 0,
        referenceImages: ((m['referenceImages'] as List?) ?? const [])
            .map(
              (e) => UnitReferenceImage.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        chartRegion: m['chartRegion'] == null
            ? null
            : ChartRegion.fromMap(
                Map<String, dynamic>.from(m['chartRegion'] as Map),
              ),
        isPreview: m['isPreview'] as bool? ?? false,
        tags: ((m['tags'] as List?) ?? const [])
            .map(
              (t) => StepUnitTag.fromMap(Map<String, dynamic>.from(t as Map)),
            )
            .toList(),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  StepBlueprintUnit copyWith({
    String? id,
    String? blueprintId,
    int? order,
    String? title,
    String? titleKo,
    String? titleEn,
    String? instruction,
    String? instructionKo,
    String? instructionEn,
    int? targetRows,
    List<UnitReferenceImage>? referenceImages,
    ChartRegion? chartRegion,
    bool? isPreview,
    List<StepUnitTag>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StepBlueprintUnit(
        id: id ?? this.id,
        blueprintId: blueprintId ?? this.blueprintId,
        order: order ?? this.order,
        title: title ?? this.title,
        titleKo: titleKo ?? this.titleKo,
        titleEn: titleEn ?? this.titleEn,
        instruction: instruction ?? this.instruction,
        instructionKo: instructionKo ?? this.instructionKo,
        instructionEn: instructionEn ?? this.instructionEn,
        targetRows: targetRows ?? this.targetRows,
        referenceImages: referenceImages ?? this.referenceImages,
        chartRegion: chartRegion ?? this.chartRegion,
        isPreview: isPreview ?? this.isPreview,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 참고 이미지.
class UnitReferenceImage {
  final String url;
  final String? caption;
  final int order;

  const UnitReferenceImage({
    required this.url,
    this.caption,
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'url': url,
        if (caption != null) 'caption': caption,
        'order': order,
      };

  factory UnitReferenceImage.fromMap(Map<String, dynamic> m) =>
      UnitReferenceImage(
        url: m['url'] as String? ?? '',
        caption: m['caption'] as String?,
        order: m['order'] as int? ?? 0,
      );

  UnitReferenceImage copyWith({String? url, String? caption, int? order}) =>
      UnitReferenceImage(
        url: url ?? this.url,
        caption: caption ?? this.caption,
        order: order ?? this.order,
      );
}

/// 단계가 차트의 어느 영역에 해당하는지.
/// rect 차트: rowStart..rowEnd / colStart..colEnd
/// round 차트: roundStart..roundEnd (예: 'R1', 'R12')
/// free path: guidePathId 참조
class ChartRegion {
  final int? rowStart;
  final int? rowEnd;
  final int? colStart;
  final int? colEnd;
  final String? roundStart;
  final String? roundEnd;
  final String? guidePathId;

  const ChartRegion({
    this.rowStart,
    this.rowEnd,
    this.colStart,
    this.colEnd,
    this.roundStart,
    this.roundEnd,
    this.guidePathId,
  });

  bool get isEmpty =>
      rowStart == null &&
      rowEnd == null &&
      colStart == null &&
      colEnd == null &&
      roundStart == null &&
      roundEnd == null &&
      guidePathId == null;

  Map<String, dynamic> toMap() => {
        if (rowStart != null) 'rowStart': rowStart,
        if (rowEnd != null) 'rowEnd': rowEnd,
        if (colStart != null) 'colStart': colStart,
        if (colEnd != null) 'colEnd': colEnd,
        if (roundStart != null) 'roundStart': roundStart,
        if (roundEnd != null) 'roundEnd': roundEnd,
        if (guidePathId != null) 'guidePathId': guidePathId,
      };

  factory ChartRegion.fromMap(Map<String, dynamic> m) => ChartRegion(
        rowStart: m['rowStart'] as int?,
        rowEnd: m['rowEnd'] as int?,
        colStart: m['colStart'] as int?,
        colEnd: m['colEnd'] as int?,
        roundStart: m['roundStart'] as String?,
        roundEnd: m['roundEnd'] as String?,
        guidePathId: m['guidePathId'] as String?,
      );

  ChartRegion copyWith({
    int? rowStart,
    int? rowEnd,
    int? colStart,
    int? colEnd,
    String? roundStart,
    String? roundEnd,
    String? guidePathId,
  }) =>
      ChartRegion(
        rowStart: rowStart ?? this.rowStart,
        rowEnd: rowEnd ?? this.rowEnd,
        colStart: colStart ?? this.colStart,
        colEnd: colEnd ?? this.colEnd,
        roundStart: roundStart ?? this.roundStart,
        roundEnd: roundEnd ?? this.roundEnd,
        guidePathId: guidePathId ?? this.guidePathId,
      );
}
