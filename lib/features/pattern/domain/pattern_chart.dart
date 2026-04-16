import 'package:flutter/material.dart';
import 'knit_symbols.dart';

enum ChartMode { color, symbol, narrative }

enum ChartTool { draw, erase, fill, select, move }

enum PatternType { chart, image, pdf }

enum PatternSourceType { editor, image, external, aiConverted }

class CellData {
  final Color? color;
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

  CellData copyWith({Color? color, String? symbolId}) {
    return CellData(
      color: color ?? this.color,
      symbolId: symbolId ?? this.symbolId,
      spanW: spanW,
      spanH: spanH,
      anchorRow: anchorRow,
      anchorCol: anchorCol,
    );
  }

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color!.toARGB32(),
        if (symbolId != null) 'symbolId': symbolId,
        if (spanW != null && spanW! > 1) 'spanW': spanW,
        if (spanH != null && spanH! > 1) 'spanH': spanH,
        if (anchorRow != null) 'anchorRow': anchorRow,
        if (anchorCol != null) 'anchorCol': anchorCol,
      };

  factory CellData.fromJson(Map<String, dynamic> json) => CellData(
        color: json['color'] != null ? Color(json['color'] as int) : null,
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
      other.symbolId == symbolId &&
      other.spanW == spanW &&
      other.spanH == spanH &&
      other.anchorRow == anchorRow &&
      other.anchorCol == anchorCol;

  @override
  int get hashCode => Object.hash(color?.toARGB32(), symbolId, spanW, spanH, anchorRow, anchorCol);
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
  final List<Map<String, dynamic>>? aiSections;

  /// 최초 생성 시각 (NEW 뱃지용, 24시간 내 생성 도안 표시)
  final DateTime? createdAt;

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

    // 앵커 셀 배치
    final anchor = CellData(
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
  String toNarrative({bool korean = true}) {
    final buffer = StringBuffer();
    for (int r = 0; r < rows; r++) {
      final rowCells = grid[r];
      // RLE — 연속 동일 심볼 압축
      final runs = <(String, int)>[];
      int c = 0;
      while (c < cols) {
        final symId = rowCells[c].symbolId;
        if (symId == null || symId == 'empty' || symId == 'no_st') {
          c++;
          continue;
        }
        int count = 1;
        while (c + count < cols && rowCells[c + count].symbolId == symId) {
          count++;
        }
        runs.add((symId, count));
        c += count;
      }
      if (runs.isEmpty) continue;

      final rowLabel = korean ? '${r + 1}단' : 'Row ${r + 1}';
      final parts = runs.map(((String id, int count) run) {
        final sym = KnitSymbolLibrary.byId(run.$1);
        final name = korean
            ? (sym?.verbKo ?? sym?.name ?? run.$1)
            : (sym?.verbEn ?? sym?.abbr ?? run.$1);
        return run.$2 > 1 ? '$name ${run.$2}' : name;
      }).join(', ');

      buffer.writeln('$rowLabel: $parts');
    }
    return buffer.toString().trim();
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
    List<Map<String, dynamic>>? aiSections,
    DateTime? createdAt,
  }) => _copyWith(
    id: id, title: title, rows: rows, cols: cols, mode: mode, grid: grid,
    narrativeText: narrativeText, type: type, imageUrl: imageUrl, pdfUrl: pdfUrl,
    forkCount: forkCount, sourcePatternId: sourcePatternId,
    sourceOwnerName: sourceOwnerName, sourceType: sourceType, aiSections: aiSections,
    createdAt: createdAt,
  );

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
    List<Map<String, dynamic>>? aiSections,
    DateTime? createdAt,
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
        if (aiSections != null) 'aiSections': aiSections,
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
          ?.map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      createdAt: (json['createdAt'] as dynamic)?.toDate() as DateTime?,
    );
  }

  factory PatternChart.empty({
    String id = '',
    String title = 'Untitled',
    int rows = 30,
    int cols = 20,
    ChartMode mode = ChartMode.color,
    String narrativeText = '',
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
    );
  }
}
