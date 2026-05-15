import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'ai_pattern_section.dart';
import 'crochet_symbols.dart';
import 'guide_path_chart.dart';
import 'knit_symbols.dart';
import 'narrative_block.dart';
import 'round_chart.dart';

enum ChartMode { color, symbol, colorChart, narrative }

enum ChartTool { draw, brush, erase, fill, select, move }

enum PatternType { chart, image, pdf }

enum PatternSourceType { editor, image, external, aiConverted }

/// 이슈 #626 — 도안 완성 상태. Fork/판매/공유/프로젝트 단계 미러링은 complete만 허용.
enum PatternStatus { draft, complete }

/// RS(겉면)/WS(안면) 독해 방향 — 평면뜨기 vs 원통뜨기
enum KnittingDirection { flatRows, inTheRound }

/// 게이지(스와치) 정보 — 10cm 기준 코수·단수
class GaugeInfo {
  final double stitchesPer10cm;
  final double rowsPer10cm;

  const GaugeInfo({required this.stitchesPer10cm, required this.rowsPer10cm});

  /// 그리드 크기로 완성 치수 계산 (cm)
  double widthCm(int cols) => cols / (stitchesPer10cm / 10);
  double heightCm(int rows) => rows / (rowsPer10cm / 10);

  Map<String, dynamic> toJson() => {
        'stitchesPer10cm': stitchesPer10cm,
        'rowsPer10cm': rowsPer10cm,
      };

  factory GaugeInfo.fromJson(Map<String, dynamic> json) => GaugeInfo(
        stitchesPer10cm: (json['stitchesPer10cm'] as num).toDouble(),
        rowsPer10cm: (json['rowsPer10cm'] as num).toDouble(),
      );
}

/// 반복 구간 마커 — 도안에서 * ~ * 반복 표시
/// 격자 좌표 기반. 서술형 블록과의 연결은 NarrativeBlock.repeatRegionId 로 이루어짐.
class RepeatRegion {
  /// 반복구간 식별자 — 서술형 블록 연결용. 비어 있으면 호환 모드(연결 없음).
  final String id;
  final int startRow;
  final int startCol;
  final int endRow;   // inclusive
  final int endCol;   // inclusive
  final int repeatCount; // 반복 횟수 (표시용)

  /// 반복구간 레이블 — "소매 반복", "케이블 무늬 반복" 등 의미 정보
  final String? label;
  final String? labelKo;

  const RepeatRegion({
    this.id = '',
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
    this.repeatCount = 1,
    this.label,
    this.labelKo,
  });

  /// 신규 생성 시 id 자동 부여
  factory RepeatRegion.create({
    required int startRow,
    required int startCol,
    required int endRow,
    required int endCol,
    int repeatCount = 1,
    String? label,
    String? labelKo,
  }) =>
      RepeatRegion(
        id: const Uuid().v4(),
        startRow: startRow,
        startCol: startCol,
        endRow: endRow,
        endCol: endCol,
        repeatCount: repeatCount,
        label: label,
        labelKo: labelKo,
      );

  int get rowSpan => endRow - startRow + 1;
  int get colSpan => endCol - startCol + 1;

  RepeatRegion copyWith({
    String? id,
    int? startRow,
    int? startCol,
    int? endRow,
    int? endCol,
    int? repeatCount,
    Object? label = _sentinel,
    Object? labelKo = _sentinel,
  }) {
    return RepeatRegion(
      id: id ?? this.id,
      startRow: startRow ?? this.startRow,
      startCol: startCol ?? this.startCol,
      endRow: endRow ?? this.endRow,
      endCol: endCol ?? this.endCol,
      repeatCount: repeatCount ?? this.repeatCount,
      label: identical(label, _sentinel) ? this.label : label as String?,
      labelKo: identical(labelKo, _sentinel) ? this.labelKo : labelKo as String?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'startRow': startRow,
        'startCol': startCol,
        'endRow': endRow,
        'endCol': endCol,
        'repeatCount': repeatCount,
        if (label != null) 'label': label,
        if (labelKo != null) 'labelKo': labelKo,
      };

  factory RepeatRegion.fromJson(Map<String, dynamic> json) => RepeatRegion(
        id: (json['id'] as String?) ?? const Uuid().v4(),
        startRow: json['startRow'] as int,
        startCol: json['startCol'] as int,
        endRow: json['endRow'] as int,
        endCol: json['endCol'] as int,
        repeatCount: json['repeatCount'] as int? ?? 1,
        label: json['label'] as String?,
        labelKo: json['labelKo'] as String?,
      );
}

class CellData {
  final Color? color;       // 배경색
  final Color? symbolColor; // 심볼(SVG) 색상
  final String? symbolId;

  /// 앵커 셀 전용: span 가로 코 수 (1 = 기본, null = 비span)
  final int? spanW;
  /// 앵커 셀 전용: span 세로 단 수 (1 = 기본, null = 비span)
  final int? spanH;
  /// 점유 셀 전용: 앵커 셀 row 좌표
  final int? anchorRow;
  /// 점유 셀 전용: 앵커 셀 col 좌표
  final int? anchorCol;

  const CellData({
    this.color,
    this.symbolColor,
    this.symbolId,
    this.spanW,
    this.spanH,
    this.anchorRow,
    this.anchorCol,
  });

  /// 앵커 셀 여부 (span 심볼의 기준 셀)
  bool get isAnchor => symbolId != null && anchorRow == null;
  /// 점유 셀 여부 (앵커 셀에 의해 덮인 셀)
  bool get isOccupied => anchorRow != null;

  CellData copyWith({Color? color, Color? symbolColor, String? symbolId}) {
    return CellData(
      color: color ?? this.color,
      symbolColor: symbolColor ?? this.symbolColor,
      symbolId: symbolId ?? this.symbolId,
      spanW: spanW,
      spanH: spanH,
      anchorRow: anchorRow,
      anchorCol: anchorCol,
    );
  }

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color!.toARGB32(),
        if (symbolColor != null) 'symbolColor': symbolColor!.toARGB32(),
        if (symbolId != null) 'symbolId': symbolId,
        if (spanW != null && spanW! > 1) 'spanW': spanW,
        if (spanH != null && spanH! > 1) 'spanH': spanH,
        if (anchorRow != null) 'anchorRow': anchorRow,
        if (anchorCol != null) 'anchorCol': anchorCol,
      };

  factory CellData.fromJson(Map<String, dynamic> json) => CellData(
        color: json['color'] != null ? Color(json['color'] as int) : null,
        symbolColor: json['symbolColor'] != null ? Color(json['symbolColor'] as int) : null,
        symbolId: json['symbolId'] as String?,
        spanW: json['spanW'] as int?,
        spanH: json['spanH'] as int?,
        anchorRow: json['anchorRow'] as int?,
        anchorCol: json['anchorCol'] as int?,
      );

  KnitSymbol? get symbol =>
      symbolId != null ? KnitSymbolLibrary.byId(symbolId!) : null;

  @override
  bool operator ==(Object other) =>
      other is CellData &&
      other.color?.toARGB32() == color?.toARGB32() &&
      other.symbolColor?.toARGB32() == symbolColor?.toARGB32() &&
      other.symbolId == symbolId &&
      other.spanW == spanW &&
      other.spanH == spanH &&
      other.anchorRow == anchorRow &&
      other.anchorCol == anchorCol;

  @override
  int get hashCode => Object.hash(color?.toARGB32(), symbolColor?.toARGB32(), symbolId, spanW, spanH, anchorRow, anchorCol);
}

class PatternChart {
  final String id;
  final String title;
  final int rows;
  final int cols;
  final ChartMode mode;
  final List<List<CellData>> grid;
  final String narrativeText;
  final PatternType type;
  final String imageUrl;
  final String pdfUrl;

  /// Fork 관련 필드
  final int forkCount;
  final String? sourcePatternId;
  final String? sourceOwnerName;
  final PatternSourceType sourceType;

  /// AI 변환 도안 섹션 데이터 (aiConverted 타입에서 사용)
  ///
  /// #687 Phase E1 — 단계 데이터는 step_blueprints/units로 단방향 이전됨.
  /// 이 필드는 다음 용도로만 유지됨:
  ///   - 기존 Firestore 데이터의 fromJson 호환 (마이그레이션 전 도안 표시)
  ///   - 메모리상 도안 객체에서 섹션 정보를 읽는 기존 호출자 호환
  /// 신규 저장 시 toJson은 이 필드를 출력하지 않음 (pattern_charts에 aiSections=[]).
  /// 단계 정보는 step_blueprints + units에서 직접 조회할 것.
  @Deprecated('Use step_blueprints + units via StepBlueprintRepository. '
      'This field is kept for legacy in-memory compatibility only and is no longer persisted to pattern_charts.')
  final List<AiSection>? aiSections;

  /// 최초 생성 시각 (NEW 뱃지용, 24시간 내 생성 도안 표시)
  final DateTime? createdAt;

  /// 연결된 프로젝트 ID
  final String? linkedProjectId;

  /// 좌우 대칭 모드 (왼쪽 절반만 그리면 오른쪽 자동 미러)
  final bool mirrorMode;

  /// 도안 카테고리 ('의상', '소품', '기타', null)
  final String? category;

  /// 뜨기 방향 — 평면뜨기(flatRows) vs 원통뜨기(inTheRound)
  final KnittingDirection knittingDirection;

  /// 게이지 정보 — 10cm 기준 코수·단수 (치수 계산용)
  final GaugeInfo? gauge;

  /// 반복 구간 마커 목록
  final List<RepeatRegion> repeatRegions;

  /// 서술형 블록 리스트 — 서술형 텍스트의 원자 단위 (줄 단위).
  /// narrativeText 필드는 하위 호환용으로 유지되며, 저장/로드 시 자동 동기화됨.
  final List<NarrativeBlock> narrativeBlocks;

  /// 이슈 #644 — Ravelry 도안 ID. Ravelry에서 임포트된 도안일 때만 set.
  /// 모리니트 자체 도안은 null. 프로젝트 동기화 시 Ravelry createProject의 pattern_id로 전달.
  final int? ravelryPatternId;

  /// 이슈 #665 — 도안 형태 (사각 그리드 / 원형 라운드).
  /// 기본 ChartShape.rect (기존 도안과 호환).
  final ChartShape chartType;

  /// 이슈 #665 — chartType이 round*일 때 원형 도안 데이터.
  /// 사각 그리드 도안은 null.
  final RoundChart? roundData;

  /// 이슈 #668 — chartType이 guidePath일 때 자유 Path 도안 데이터.
  /// 사각·원형 도안은 null.
  final GuidePathChart? guidePathData;

  PatternChart({
    required this.id,
    required this.title,
    required this.rows,
    required this.cols,
    required this.mode,
    required this.grid,
    this.narrativeText = '',
    this.type = PatternType.chart,
    this.imageUrl = '',
    this.pdfUrl = '',
    this.forkCount = 0,
    this.sourcePatternId,
    this.sourceOwnerName,
    this.sourceType = PatternSourceType.editor,
    this.aiSections,
    this.createdAt,
    this.linkedProjectId,
    this.mirrorMode = false,
    this.category,
    this.knittingDirection = KnittingDirection.flatRows,
    this.gauge,
    this.repeatRegions = const [],
    this.narrativeBlocks = const [],
    this.ravelryPatternId,
    this.chartType = ChartShape.rect,
    this.roundData,
    this.guidePathData,
  });

  PatternChart setCell(int row, int col, CellData cell) {
    final newGrid = [
      for (int r = 0; r < rows; r++)
        [
          for (int c = 0; c < cols; c++)
            (r == row && c == col) ? cell : grid[r][c],
        ],
    ];
    return _copyWith(grid: newGrid);
  }

  /// 색상 레이어만 업데이트 — 기호/span 정보 보존
  PatternChart setCellColor(int row, int col, Color color) {
    final newGrid = [for (final r in grid) List<CellData>.from(r)];
    final existing = newGrid[row][col];
    newGrid[row][col] = CellData(
      color: color,
      symbolId: existing.symbolId,
      spanW: existing.spanW,
      spanH: existing.spanH,
      anchorRow: existing.anchorRow,
      anchorCol: existing.anchorCol,
    );
    return _copyWith(grid: newGrid);
  }

  /// 기호 레이어만 업데이트 — 색상 보존, 점유 셀에는 적용 안 함
  PatternChart setCellSymbol(int row, int col, String? symbolId) {
    final newGrid = [for (final r in grid) List<CellData>.from(r)];
    final existing = newGrid[row][col];
    if (existing.isOccupied) return this;
    newGrid[row][col] = CellData(
      color: existing.color,
      symbolId: symbolId,
      spanW: existing.spanW,
      spanH: existing.spanH,
    );
    return _copyWith(grid: newGrid);
  }

  /// span 심볼 배치: 앵커 셀 + 점유 셀 자동 설정
  /// span 범위가 그리드 경계 초과 시 무시하고 반환
  PatternChart setSpanCell(int row, int col, CellData anchorCell, int spanW, int spanH) {
    // 경계 초과 체크
    if (col + spanW > cols || row + spanH > rows) return this;

    final newGrid = [for (final r in grid) List<CellData>.from(r)];

    // 새 span 영역과 겹치는 기존 span 심볼을 먼저 제거
    for (int dr = 0; dr < spanH; dr++) {
      for (int dc = 0; dc < spanW; dc++) {
        final existing = newGrid[row + dr][col + dc];
        if (existing.isOccupied) {
          // 점유 셀이면 해당 앵커 전체를 제거
          _clearSpanAt(newGrid, existing.anchorRow!, existing.anchorCol!);
        } else if (existing.isAnchor) {
          _clearSpanAt(newGrid, row + dr, col + dc);
        }
      }
    }

    // 앵커 셀 배치 — 기존 배경색 보존, 심볼색은 anchorCell에서 가져옴
    final anchor = CellData(
      color: anchorCell.color ?? newGrid[row][col].color,
      symbolColor: anchorCell.symbolColor,
      symbolId: anchorCell.symbolId,
      spanW: spanW > 1 ? spanW : null,
      spanH: spanH > 1 ? spanH : null,
    );
    newGrid[row][col] = anchor;

    // 점유 셀 배치
    for (int dr = 0; dr < spanH; dr++) {
      for (int dc = 0; dc < spanW; dc++) {
        if (dr == 0 && dc == 0) continue;
        newGrid[row + dr][col + dc] = CellData(anchorRow: row, anchorCol: col);
      }
    }

    return _copyWith(grid: newGrid);
  }

  /// span 심볼 제거: 점유 셀 터치 시 앵커 포함 전체 제거
  PatternChart eraseSpanCell(int row, int col) {
    final cell = grid[row][col];
    final newGrid = [for (final r in grid) List<CellData>.from(r)];

    if (cell.isOccupied) {
      _clearSpanAt(newGrid, cell.anchorRow!, cell.anchorCol!);
    } else if (cell.isAnchor) {
      _clearSpanAt(newGrid, row, col);
    } else {
      newGrid[row][col] = const CellData();
    }

    return _copyWith(grid: newGrid);
  }

  /// 내부 헬퍼: 앵커 위치 기준으로 span 전체 초기화
  void _clearSpanAt(List<List<CellData>> grid, int anchorR, int anchorC) {
    final anchor = grid[anchorR][anchorC];
    final sw = anchor.spanW ?? 1;
    final sh = anchor.spanH ?? 1;
    for (int dr = 0; dr < sh; dr++) {
      for (int dc = 0; dc < sw; dc++) {
        if (anchorR + dr < rows && anchorC + dc < cols) {
          grid[anchorR + dr][anchorC + dc] = const CellData();
        }
      }
    }
  }

  PatternChart resize(int newRows, int newCols) {
    final newGrid = List.generate(
      newRows,
      (r) => List.generate(
        newCols,
        (c) => (r < rows && c < cols) ? grid[r][c] : const CellData(),
      ),
    );
    return _copyWith(rows: newRows, cols: newCols, grid: newGrid);
  }

  /// 심볼 모드 그리드 → RLE 서술형 도안 변환
  /// 예: "1단: 겉뜨기 10, 안뜨기 2, 바늘비우기, 2코모아겉뜨기 3"
  ///
  /// - 빈 칸 / 'empty' / 'no_st' = 겉뜨기(knit)로 처리
  /// - 컬러차트 모드(ChartMode.colorChart)에서는 (symbolId, color) 조합으로 RLE,
  ///   색상 라벨(MC/CC1...)을 함께 출력: "겉뜨기 3[MC], 겉뜨기 2[CC1]"
  String toNarrative({bool korean = true}) {
    final isColorChart = mode == ChartMode.colorChart;
    final colorLabels = isColorChart ? buildColorLabels(grid) : const <int, String>{};

    final buffer = StringBuffer();
    for (int r = 0; r < rows; r++) {
      final rowCells = grid[r];
      // RLE — 연속 동일 (symId, argb) 압축
      final runs = <_NarrativeRun>[];
      int c = 0;
      while (c < cols) {
        final cell = rowCells[c];
        // 점유 셀(span 내부)은 앵커에서 이미 처리됨 → 건너뜀
        if (cell.isOccupied) {
          c++;
          continue;
        }
        final normId = _normalizeSymId(cell.symbolId);
        final argb = cell.color?.toARGB32() ?? 0xFFFFFFFF;
        int count = 1;
        while (c + count < cols) {
          final next = rowCells[c + count];
          if (next.isOccupied) break;
          final nextNorm = _normalizeSymId(next.symbolId);
          final nextArgb = next.color?.toARGB32() ?? 0xFFFFFFFF;
          if (nextNorm != normId) break;
          if (isColorChart && nextArgb != argb) break;
          count++;
        }
        runs.add(_NarrativeRun(symId: normId, argb: argb, count: count));
        c += count;
      }
      if (runs.isEmpty) continue;

      final rowLabel = korean ? '${r + 1}단' : 'Row ${r + 1}';
      final parts = runs.map((run) {
        // 이슈 #665 옵션 1.5 — 대바늘 라이브러리에 없으면 코바늘 fallback (혼용 도안 지원)
        final sym = KnitSymbolLibrary.byId(run.symId);
        final crochet = sym == null ? CrochetSymbolLibrary.byId(run.symId) : null;
        final name = korean
            ? (sym?.verbKo ?? sym?.name ?? crochet?.labelKo ?? run.symId)
            : (sym?.verbEn ?? sym?.abbr ?? crochet?.labelEn ?? run.symId);
        final base = run.count > 1 ? '$name ${run.count}' : name;
        if (!isColorChart) return base;
        final label = colorLabels[run.argb] ?? 'MC';
        return '$base[$label]';
      }).join(', ');

      buffer.writeln('$rowLabel: $parts');
    }
    return buffer.toString().trim();
  }

  /// 빈 칸/'empty'/'no_st' → 'knit' 로 정규화
  static String _normalizeSymId(String? symId) {
    if (symId == null || symId == 'empty' || symId == 'no_st') return 'k';
    return symId;
  }

  /// 그리드에 사용된 색상(ARGB int) → 라벨 매핑
  /// 첫 번째 등장 색상 = MC, 이후 등장 순서대로 CC1, CC2, ...
  static Map<int, String> buildColorLabels(List<List<CellData>> grid) {
    final colorOrder = <int>[];
    for (final row in grid) {
      for (final cell in row) {
        if (cell.isOccupied) continue;
        final argb = cell.color?.toARGB32() ?? 0xFFFFFFFF;
        if (!colorOrder.contains(argb)) colorOrder.add(argb);
      }
    }
    return {
      for (int i = 0; i < colorOrder.length; i++)
        colorOrder[i]: i == 0 ? 'MC' : 'CC$i',
    };
  }

  PatternChart copyWith({
    String? id,
    String? title,
    int? rows,
    int? cols,
    ChartMode? mode,
    List<List<CellData>>? grid,
    String? narrativeText,
    PatternType? type,
    String? imageUrl,
    String? pdfUrl,
    int? forkCount,
    String? sourcePatternId,
    String? sourceOwnerName,
    PatternSourceType? sourceType,
    List<AiSection>? aiSections,
    DateTime? createdAt,
    Object? linkedProjectId = _sentinel,
    bool? mirrorMode,
    Object? category = _sentinel,
    KnittingDirection? knittingDirection,
    Object? gauge = _sentinel,
    List<RepeatRegion>? repeatRegions,
    List<NarrativeBlock>? narrativeBlocks,
    Object? ravelryPatternId = _sentinel,
    ChartShape? chartType,
    Object? roundData = _sentinel,
    Object? guidePathData = _sentinel,
  }) => _copyWith(
    id: id, title: title, rows: rows, cols: cols, mode: mode, grid: grid,
    narrativeText: narrativeText, type: type, imageUrl: imageUrl, pdfUrl: pdfUrl,
    forkCount: forkCount, sourcePatternId: sourcePatternId,
    sourceOwnerName: sourceOwnerName, sourceType: sourceType, aiSections: aiSections,
    createdAt: createdAt, linkedProjectId: linkedProjectId,
    mirrorMode: mirrorMode, category: category,
    knittingDirection: knittingDirection, gauge: gauge, repeatRegions: repeatRegions,
    narrativeBlocks: narrativeBlocks,
    ravelryPatternId: ravelryPatternId,
    chartType: chartType,
    roundData: roundData,
    guidePathData: guidePathData,
  );

  static const Object _sentinel = Object();

  PatternChart _copyWith({
    String? id,
    String? title,
    int? rows,
    int? cols,
    ChartMode? mode,
    List<List<CellData>>? grid,
    String? narrativeText,
    PatternType? type,
    String? imageUrl,
    String? pdfUrl,
    int? forkCount,
    String? sourcePatternId,
    String? sourceOwnerName,
    PatternSourceType? sourceType,
    List<AiSection>? aiSections,
    DateTime? createdAt,
    Object? linkedProjectId = _sentinel,
    bool? mirrorMode,
    Object? category = _sentinel,
    KnittingDirection? knittingDirection,
    Object? gauge = _sentinel,
    List<RepeatRegion>? repeatRegions,
    List<NarrativeBlock>? narrativeBlocks,
    Object? ravelryPatternId = _sentinel,
    ChartShape? chartType,
    Object? roundData = _sentinel,
    Object? guidePathData = _sentinel,
  }) {
    return PatternChart(
      id: id ?? this.id,
      title: title ?? this.title,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      mode: mode ?? this.mode,
      grid: grid ?? this.grid,
      narrativeText: narrativeText ?? this.narrativeText,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      forkCount: forkCount ?? this.forkCount,
      sourcePatternId: sourcePatternId ?? this.sourcePatternId,
      sourceOwnerName: sourceOwnerName ?? this.sourceOwnerName,
      sourceType: sourceType ?? this.sourceType,
      aiSections: aiSections ?? this.aiSections,
      createdAt: createdAt ?? this.createdAt,
      linkedProjectId: identical(linkedProjectId, _sentinel) ? this.linkedProjectId : linkedProjectId as String?,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      category: identical(category, _sentinel) ? this.category : category as String?,
      knittingDirection: knittingDirection ?? this.knittingDirection,
      gauge: identical(gauge, _sentinel) ? this.gauge : gauge as GaugeInfo?,
      repeatRegions: repeatRegions ?? this.repeatRegions,
      narrativeBlocks: narrativeBlocks ?? this.narrativeBlocks,
      ravelryPatternId: identical(ravelryPatternId, _sentinel)
          ? this.ravelryPatternId
          : ravelryPatternId as int?,
      chartType: chartType ?? this.chartType,
      roundData: identical(roundData, _sentinel)
          ? this.roundData
          : roundData as RoundChart?,
      guidePathData: identical(guidePathData, _sentinel)
          ? this.guidePathData
          : guidePathData as GuidePathChart?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'rows': rows,
        'cols': cols,
        'mode': mode.name,
        'grid': grid
            .map((row) => <String, dynamic>{'cells': row.map((cell) => cell.toJson()).toList()})
            .toList(),
        'narrativeText': narrativeText,
        'type': type.name,
        'imageUrl': imageUrl,
        'pdfUrl': pdfUrl,
        'forkCount': forkCount,
        if (sourcePatternId != null) 'sourcePatternId': sourcePatternId,
        if (sourceOwnerName != null) 'sourceOwnerName': sourceOwnerName,
        'sourceType': sourceType.name,
        // #687 Phase E1 — aiSections는 더 이상 pattern_charts에 저장하지 않는다.
        // 단계 데이터는 step_blueprints + units 단방향 흐름.
        // 기존 데이터 호환을 위해 fromJson은 그대로 읽음.
        if (linkedProjectId != null) 'linkedProjectId': linkedProjectId,
        'mirrorMode': mirrorMode,
        if (category != null) 'category': category,
        'knittingDirection': knittingDirection.name,
        if (gauge != null) 'gauge': gauge!.toJson(),
        if (repeatRegions.isNotEmpty) 'repeatRegions': repeatRegions.map((r) => r.toJson()).toList(),
        if (narrativeBlocks.isNotEmpty) 'narrativeBlocks': narrativeBlocks.map((b) => b.toMap()).toList(),
        if (ravelryPatternId != null) 'ravelryPatternId': ravelryPatternId,
        // 이슈 #665 — 원형 도안. 기본 rect는 저장 생략 (호환성).
        if (chartType != ChartShape.rect) 'chartType': chartType.name,
        if (roundData != null) 'roundData': roundData!.toJson(),
        // 이슈 #668 — 자유 Path 도안.
        if (guidePathData != null) 'guidePathData': guidePathData!.toJson(),
      };

  factory PatternChart.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final rawGrid = json['grid'] as List<dynamic>;
    final grid = List.generate(
      rows,
      (r) {
        final rowData = rawGrid[r];
        final cells = rowData is List
            ? rowData
            : ((rowData as Map<String, dynamic>)['cells'] as List<dynamic>);
        return List.generate(
          cols,
          (c) => CellData.fromJson(cells[c] as Map<String, dynamic>),
        );
      },
    );
    return PatternChart(
      id: json['id'] as String? ?? '',
      title: json['title'] as String,
      rows: rows,
      cols: cols,
      mode: ChartMode.values.byName(json['mode'] as String),
      grid: grid,
      narrativeText: json['narrativeText'] as String? ?? '',
      type: PatternType.values.byName(json['type'] as String? ?? 'chart'),
      imageUrl: json['imageUrl'] as String? ?? '',
      pdfUrl: json['pdfUrl'] as String? ?? '',
      forkCount: json['forkCount'] as int? ?? 0,
      sourcePatternId: json['sourcePatternId'] as String?,
      sourceOwnerName: json['sourceOwnerName'] as String?,
      sourceType: PatternSourceType.values.byName(
          json['sourceType'] as String? ?? 'editor'),
      aiSections: (json['aiSections'] as List?)
          ?.map((s) => AiSection.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      createdAt: (json['createdAt'] as dynamic)?.toDate() as DateTime?,
      linkedProjectId: json['linkedProjectId'] as String?,
      mirrorMode: json['mirrorMode'] as bool? ?? false,
      category: json['category'] as String?,
      knittingDirection: KnittingDirection.values.byName(
          json['knittingDirection'] as String? ?? 'flatRows'),
      gauge: json['gauge'] != null
          ? GaugeInfo.fromJson(json['gauge'] as Map<String, dynamic>)
          : null,
      repeatRegions: (json['repeatRegions'] as List?)
          ?.map((r) => RepeatRegion.fromJson(r as Map<String, dynamic>))
          .toList() ?? const [],
      narrativeBlocks: _parseNarrativeBlocks(json),
      ravelryPatternId: json['ravelryPatternId'] is int
          ? json['ravelryPatternId'] as int
          : (json['ravelryPatternId'] is num
              ? (json['ravelryPatternId'] as num).toInt()
              : null),
      // 이슈 #665 — 원형 도안 마이그레이션 (없으면 rect).
      chartType: _parseChartShape(json['chartType'] as String?),
      roundData: json['roundData'] != null
          ? RoundChart.fromJson(Map<String, dynamic>.from(json['roundData'] as Map))
          : null,
      // 이슈 #668 — 자유 Path 도안 마이그레이션.
      guidePathData: json['guidePathData'] != null
          ? GuidePathChart.fromJson(
              Map<String, dynamic>.from(json['guidePathData'] as Map))
          : null,
    );
  }

  static ChartShape _parseChartShape(String? name) {
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

  /// narrativeBlocks 파싱 + 호환 레이어:
  /// 신규 필드 없으면 기존 narrativeText에서 줄 단위로 자동 변환.
  static List<NarrativeBlock> _parseNarrativeBlocks(Map<String, dynamic> json) {
    final raw = json['narrativeBlocks'] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw
          .map((b) => NarrativeBlock.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
    }
    final text = (json['narrativeText'] as String?) ?? '';
    return NarrativeBlock.fromText(text);
  }

  /// 이슈 #626 — 도안 내용 기반 완성 판정 (자동 판정, B안).
  /// 조건: 섹션 1개 이상 존재 + 섹션 중 하나라도 내용(steps 또는 연결 블록) 보유.
  /// 빈 섹션만 있는 도안은 draft로 간주.
  ///
  /// #687 Phase E1 — 단계 데이터가 step_blueprints/units로 분리되었으므로
  /// 메모리상 aiSections 기반 판정은 곧 무력화될 예정. StepBlueprintRepository의
  /// units 개수로 판정하는 경로로 마이그레이션 필요.
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('Compute from step_blueprints/units instead. '
      'aiSections is no longer persisted to pattern_charts (#687 Phase E1).')
  bool get isComplete {
    // ignore: deprecated_member_use_from_same_package
    final sections = aiSections ?? const [];
    if (sections.isEmpty) return false;
    return sections.any((s) {
      if (s.steps.isNotEmpty) return true;
      return narrativeBlocks.any((b) => b.sectionId == s.id);
    });
  }

  /// UI 배지·필터·게이트용 상태 (isComplete 기반 자동 판정).
  PatternStatus get status =>
      isComplete ? PatternStatus.complete : PatternStatus.draft;

  factory PatternChart.empty({
    String id = '',
    String title = 'Untitled',
    int rows = 30,
    int cols = 20,
    ChartMode mode = ChartMode.color,
    String narrativeText = '',
    bool mirrorMode = false,
    String? category,
    DateTime? createdAt,
  }) {
    final grid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => const CellData()),
    );
    return PatternChart(
      id: id,
      title: title,
      rows: rows,
      cols: cols,
      mode: mode,
      grid: grid,
      narrativeText: narrativeText,
      mirrorMode: mirrorMode,
      category: category,
      createdAt: createdAt,
    );
  }
}

/// toNarrative 내부 RLE 런 — (심볼ID, 배경색 argb, 반복 수)
class _NarrativeRun {
  final String symId;
  final int argb;
  final int count;
  const _NarrativeRun({
    required this.symId,
    required this.argb,
    required this.count,
  });
}
