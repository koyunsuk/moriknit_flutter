import 'package:flutter/material.dart';
import 'knit_symbols.dart';

enum ChartMode { color, symbol, narrative }

enum ChartTool { draw, erase, fill, select, move }

enum PatternType { chart, image, pdf }

enum PatternSourceType { editor, image, external, aiConverted }

class CellData {
  final Color? color;
  final String? symbolId;

  const CellData({this.color, this.symbolId});

  CellData copyWith({Color? color, String? symbolId}) {
    return CellData(
      color: color ?? this.color,
      symbolId: symbolId ?? this.symbolId,
    );
  }

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color!.toARGB32(),
        if (symbolId != null) 'symbolId': symbolId,
      };

  factory CellData.fromJson(Map<String, dynamic> json) => CellData(
        color: json['color'] != null ? Color(json['color'] as int) : null,
        symbolId: json['symbolId'] as String?,
      );

  KnitSymbol? get symbol =>
      symbolId != null ? KnitSymbolLibrary.byId(symbolId!) : null;

  @override
  bool operator ==(Object other) =>
      other is CellData &&
      other.color?.toARGB32() == color?.toARGB32() &&
      other.symbolId == symbolId;

  @override
  int get hashCode => Object.hash(color?.toARGB32(), symbolId);
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
