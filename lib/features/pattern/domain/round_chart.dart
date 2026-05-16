// lib/features/pattern/domain/round_chart.dart
//
// 이슈 #665 — 원형 작품용 도안 데이터 모델 (코바늘 라운드).
// 사각 그리드(PatternChart)와 분리. 도안에디터에서 모드 토글로 진입.
//
// 좌표계: 이산 극좌표 (R, S)
//   - R: 라운드 인덱스 (1-base)
//   - S: 세그먼트 인덱스 (0-base, 0..stitchCounts[R-1]-1)
//
// 라운드별 코수 자동 증가:
//   - autoIncreasePerRound = true → stitchCounts[R-1] = baseStitchCount × R (코바늘 평면 원 표준)
//   - false → stitchCounts 사용자 정의

import 'dart:ui' show Color;

/// 원형 도안 형태.
enum ChartShape {
  /// 사각 그리드 (기존 PatternChart — 호환용 enum 값).
  rect,

  /// 360도 전체 원형.
  roundFull,

  /// 180도 반원형.
  roundHalf,

  /// 사용자 정의 부채꼴 (sectorAngleStart ~ sectorAngleEnd).
  roundSector,

  /// 이슈 #668 — 자유 Path 도안 (왕관/꽃잎/Granny 같은 비정형 모티프).
  /// 데이터는 PatternChart.guidePathData (GuidePathChart)에 저장됨.
  guidePath,
}

/// 원형 도안 셀의 고유 키 (Map 키로 사용).
class RoundCellKey {
  /// 라운드 (1-base).
  final int round;

  /// 세그먼트 (0-base).
  final int segment;

  const RoundCellKey({required this.round, required this.segment});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundCellKey && round == other.round && segment == other.segment;

  @override
  int get hashCode => Object.hash(round, segment);

  Map<String, dynamic> toJson() => {'r': round, 's': segment};

  factory RoundCellKey.fromJson(Map<String, dynamic> json) => RoundCellKey(
        round: (json['r'] as num).toInt(),
        segment: (json['s'] as num).toInt(),
      );
}

/// 원형 도안 셀 한 칸.
/// 셀 정렬 모드 (#680 — 패션 드로잉 수준).
/// - [cellArea]: 셀 사각 영역 안에 contain (기본, 사각 그리드처럼)
/// - [onLine]: 라인(라운드 호) 위에 baseline 정렬 (체인 같은 표현)
enum CellAlign { cellArea, onLine }

class RoundCell {
  /// 심볼 ID (SvgSymbolCache의 키, encyclopedia 등록 ID).
  final String? symbolId;

  /// 셀 배경색.
  final Color? color;

  /// 심볼 색상 오버라이드 (ColorFilter.srcIn).
  final Color? symbolColor;

  /// 자동 회전 (true 시 심볼이 중심을 향함).
  /// #682 — 기본 OFF. SVG 원본 방향(위가 위) 유지가 일관성 있고 가독성 좋음.
  /// 사용자가 외곽 향하게 하려면 셀 인스펙터에서 ON.
  final bool autoRotate;

  /// 사용자 미세 회전 (라디안, autoRotate 위에 추가됨).
  final double rotationDelta;

  /// 세그먼트 묶음 (cluster/shell 표현). 1이면 단일 셀.
  final int spanS;

  /// #680 — 셀 정렬 모드 (셀 영역 contain 또는 라인 baseline).
  final CellAlign align;

  const RoundCell({
    this.symbolId,
    this.color,
    this.symbolColor,
    this.autoRotate = false,
    this.rotationDelta = 0,
    this.spanS = 1,
    this.align = CellAlign.cellArea,
  });

  RoundCell copyWith({
    String? symbolId,
    Color? color,
    Color? symbolColor,
    bool? autoRotate,
    double? rotationDelta,
    int? spanS,
    CellAlign? align,
  }) =>
      RoundCell(
        symbolId: symbolId ?? this.symbolId,
        color: color ?? this.color,
        symbolColor: symbolColor ?? this.symbolColor,
        autoRotate: autoRotate ?? this.autoRotate,
        rotationDelta: rotationDelta ?? this.rotationDelta,
        spanS: spanS ?? this.spanS,
        align: align ?? this.align,
      );

  /// 색상 명시적 제거 (null 설정용 — copyWith는 null이면 기존값 유지).
  RoundCell withoutColor() => RoundCell(
        symbolId: symbolId,
        color: null,
        symbolColor: symbolColor,
        autoRotate: autoRotate,
        rotationDelta: rotationDelta,
        spanS: spanS,
        align: align,
      );

  /// 심볼 명시적 제거.
  RoundCell withoutSymbol() => RoundCell(
        symbolId: null,
        color: color,
        symbolColor: null,
        autoRotate: autoRotate,
        rotationDelta: rotationDelta,
        spanS: spanS,
        align: align,
      );

  Map<String, dynamic> toJson() => {
        if (symbolId != null) 'symbolId': symbolId,
        if (color != null) 'color': color!.toARGB32(),
        if (symbolColor != null) 'symbolColor': symbolColor!.toARGB32(),
        if (autoRotate) 'autoRotate': true,
        if (rotationDelta != 0) 'rotationDelta': rotationDelta,
        if (spanS != 1) 'spanS': spanS,
        if (align != CellAlign.cellArea) 'align': align.name,
      };

  factory RoundCell.fromJson(Map<String, dynamic> json) => RoundCell(
        symbolId: json['symbolId'] as String?,
        color: json['color'] != null
            ? Color((json['color'] as num).toInt())
            : null,
        symbolColor: json['symbolColor'] != null
            ? Color((json['symbolColor'] as num).toInt())
            : null,
        autoRotate: json['autoRotate'] as bool? ?? false,
        rotationDelta:
            (json['rotationDelta'] as num?)?.toDouble() ?? 0,
        spanS: (json['spanS'] as num?)?.toInt() ?? 1,
        align: CellAlign.values.firstWhere(
          (e) => e.name == (json['align'] as String?),
          orElse: () => CellAlign.cellArea,
        ),
      );
}

/// 원형 도안 (코바늘 라운드 도안용).
///
/// PatternChart 안에 chartType이 round* 인 경우 roundData로 보관됨.
class RoundChart {
  /// 총 라운드 수.
  final int rounds;

  /// 1단 코수 (기본 6 — 코바늘 평면 원 황금률).
  final int baseStitchCount;

  /// R별 코수 [stitchCounts[R-1]]. 비어 있으면 autoIncreasePerRound로 자동 계산.
  final List<int> stitchCounts;

  /// R별 시작 각도 오프셋 (라디안). 비어 있으면 모두 -π/2 (12시 방향).
  final List<double> startAngleOffsets;

  /// 셀 sparse map.
  final Map<RoundCellKey, RoundCell> cells;

  /// 도안 형태.
  final ChartShape shape;

  /// roundSector일 때 시작 각도 (라디안).
  final double sectorAngleStart;

  /// roundSector일 때 끝 각도 (라디안).
  final double sectorAngleEnd;

  /// 자동 +6/단 증가 여부.
  final bool autoIncreasePerRound;

  const RoundChart({
    this.rounds = 6,
    this.baseStitchCount = 6,
    this.stitchCounts = const [],
    this.startAngleOffsets = const [],
    this.cells = const {},
    this.shape = ChartShape.roundFull,
    this.sectorAngleStart = 0,
    this.sectorAngleEnd = 0,
    this.autoIncreasePerRound = true,
  });

  /// R번째 라운드의 실제 코수 (자동 또는 수동).
  int stitchCountForRound(int round) {
    if (round < 1 || round > rounds) return 0;
    if (!autoIncreasePerRound && stitchCounts.length >= round) {
      return stitchCounts[round - 1];
    }
    return baseStitchCount * round;
  }

  /// R번째 라운드의 시작 각도 (라디안).
  double startAngleForRound(int round) {
    if (round < 1 || round > rounds) return 0;
    if (startAngleOffsets.length >= round) {
      return startAngleOffsets[round - 1];
    }
    return -1.5707963267948966; // -π/2 (12시 방향)
  }

  RoundChart copyWith({
    int? rounds,
    int? baseStitchCount,
    List<int>? stitchCounts,
    List<double>? startAngleOffsets,
    Map<RoundCellKey, RoundCell>? cells,
    ChartShape? shape,
    double? sectorAngleStart,
    double? sectorAngleEnd,
    bool? autoIncreasePerRound,
  }) =>
      RoundChart(
        rounds: rounds ?? this.rounds,
        baseStitchCount: baseStitchCount ?? this.baseStitchCount,
        stitchCounts: stitchCounts ?? this.stitchCounts,
        startAngleOffsets: startAngleOffsets ?? this.startAngleOffsets,
        cells: cells ?? this.cells,
        shape: shape ?? this.shape,
        sectorAngleStart: sectorAngleStart ?? this.sectorAngleStart,
        sectorAngleEnd: sectorAngleEnd ?? this.sectorAngleEnd,
        autoIncreasePerRound: autoIncreasePerRound ?? this.autoIncreasePerRound,
      );

  /// 셀 추가/덮어쓰기.
  RoundChart withCell(RoundCellKey key, RoundCell cell) {
    final newCells = Map<RoundCellKey, RoundCell>.from(cells);
    newCells[key] = cell;
    return copyWith(cells: newCells);
  }

  /// 셀 제거.
  RoundChart withoutCell(RoundCellKey key) {
    if (!cells.containsKey(key)) return this;
    final newCells = Map<RoundCellKey, RoundCell>.from(cells);
    newCells.remove(key);
    return copyWith(cells: newCells);
  }

  Map<String, dynamic> toJson() => {
        'rounds': rounds,
        'baseStitchCount': baseStitchCount,
        if (!autoIncreasePerRound && stitchCounts.isNotEmpty)
          'stitchCounts': stitchCounts,
        if (startAngleOffsets.isNotEmpty)
          'startAngleOffsets': startAngleOffsets,
        'shape': shape.name,
        if (shape == ChartShape.roundSector) ...{
          'sectorAngleStart': sectorAngleStart,
          'sectorAngleEnd': sectorAngleEnd,
        },
        'autoIncreasePerRound': autoIncreasePerRound,
        'cells': cells.entries
            .map((e) => {...e.key.toJson(), ...e.value.toJson()})
            .toList(),
      };

  factory RoundChart.fromJson(Map<String, dynamic> json) {
    final cellsList = (json['cells'] as List<dynamic>?) ?? const [];
    final cellsMap = <RoundCellKey, RoundCell>{};
    for (final entry in cellsList) {
      final m = Map<String, dynamic>.from(entry as Map);
      final key = RoundCellKey.fromJson(m);
      final cell = RoundCell.fromJson(m);
      cellsMap[key] = cell;
    }
    return RoundChart(
      rounds: (json['rounds'] as num?)?.toInt() ?? 6,
      baseStitchCount: (json['baseStitchCount'] as num?)?.toInt() ?? 6,
      stitchCounts: (json['stitchCounts'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      startAngleOffsets: (json['startAngleOffsets'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      cells: cellsMap,
      shape: _shapeFromName(json['shape'] as String?),
      sectorAngleStart:
          (json['sectorAngleStart'] as num?)?.toDouble() ?? 0,
      sectorAngleEnd: (json['sectorAngleEnd'] as num?)?.toDouble() ?? 0,
      autoIncreasePerRound: json['autoIncreasePerRound'] as bool? ?? true,
    );
  }

  static ChartShape _shapeFromName(String? name) {
    switch (name) {
      case 'roundFull':
        return ChartShape.roundFull;
      case 'roundHalf':
        return ChartShape.roundHalf;
      case 'roundSector':
        return ChartShape.roundSector;
      case 'guidePath':
        return ChartShape.guidePath;
      case 'rect':
      default:
        return ChartShape.rect;
    }
  }
}
