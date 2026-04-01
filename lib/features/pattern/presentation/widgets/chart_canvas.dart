import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';

const double _cellW = 36.0;
const double _cellH = 24.0;
const double _headerW = 20.0;
const double _headerH = 20.0;

class ChartCanvas extends StatefulWidget {
  final PatternChart chart;
  final ChartTool tool;
  final Color activeColor;
  final String? activeSymbolId;
  final ValueChanged<PatternChart> onChartChanged;
  final TransformationController? transformationController;
  /// 전체 조망: non-null Size가 들어오면 해당 크기에 맞게 셀 크기 자동 조정
  final ValueNotifier<Size?>? fitToScreenNotifier;

  const ChartCanvas({
    super.key,
    required this.chart,
    required this.tool,
    required this.activeColor,
    this.activeSymbolId,
    required this.onChartChanged,
    this.transformationController,
    this.fitToScreenNotifier,
  });

  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas> {
  TransformationController? _ownedCtrl;
  TransformationController get _transformCtrl =>
      widget.transformationController ?? (_ownedCtrl ??= TransformationController());
  bool _isPainting = false;

  @override
  void initState() {
    super.initState();
    widget.fitToScreenNotifier?.addListener(_onFitScreen);
  }

  @override
  void didUpdateWidget(ChartCanvas old) {
    super.didUpdateWidget(old);
    if (old.fitToScreenNotifier != widget.fitToScreenNotifier) {
      old.fitToScreenNotifier?.removeListener(_onFitScreen);
      widget.fitToScreenNotifier?.addListener(_onFitScreen);
    }
  }

  void _onFitScreen() {
    final size = widget.fitToScreenNotifier?.value;
    if (size == null) return;
    final chart = widget.chart;
    final availableW = size.width - _headerW;
    final availableH = size.height - _headerH;
    final cellW = availableW / chart.cols;
    final cellH = availableH / chart.rows;
    final scale = (cellW < cellH ? cellW : cellH) / _cellW;
    _transformCtrl.value = Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  @override
  void dispose() {
    widget.fitToScreenNotifier?.removeListener(_onFitScreen);
    _ownedCtrl?.dispose();
    super.dispose();
  }

  (int row, int col)? _hitCell(Offset localPos) {
    final inverted = _transformCtrl.value.clone()..invert();
    final canvasPos = MatrixUtils.transformPoint(inverted, localPos);
    final x = canvasPos.dx - _headerW;
    final y = canvasPos.dy - _headerH;
    if (x < 0 || y < 0) return null;
    final col = (x / _cellW).floor();
    final row = (y / _cellH).floor();
    if (row < 0 || row >= widget.chart.rows) return null;
    if (col < 0 || col >= widget.chart.cols) return null;
    return (row, col);
  }

  CellData get _activeCell {
    if (widget.chart.mode == ChartMode.symbol) {
      return CellData(symbolId: widget.activeSymbolId);
    }
    return CellData(color: widget.activeColor);
  }

  void _handleTap(Offset localPos) {
    final hit = _hitCell(localPos);
    if (hit == null) return;
    final (row, col) = hit;
    switch (widget.tool) {
      case ChartTool.draw:
        widget.onChartChanged(widget.chart.setCell(row, col, _activeCell));
      case ChartTool.erase:
        widget.onChartChanged(widget.chart.setCell(row, col, const CellData()));
      case ChartTool.fill:
        final filled = _floodFill(widget.chart, row, col, _activeCell);
        widget.onChartChanged(filled);
      case ChartTool.select:
        break;
      case ChartTool.move:
        break;
    }
  }

  void _handleDragUpdate(Offset localPos) {
    if (widget.tool == ChartTool.fill || widget.tool == ChartTool.move) return;
    final hit = _hitCell(localPos);
    if (hit == null) return;
    final (row, col) = hit;
    if (widget.tool == ChartTool.draw) {
      widget.onChartChanged(widget.chart.setCell(row, col, _activeCell));
    } else if (widget.tool == ChartTool.erase) {
      widget.onChartChanged(widget.chart.setCell(row, col, const CellData()));
    }
  }

  PatternChart _floodFill(PatternChart chart, int startRow, int startCol, CellData newCell) {
    final target = chart.grid[startRow][startCol];
    if (target == newCell) return chart;

    final newGrid = [for (final row in chart.grid) List<CellData>.from(row)];
    final queue = Queue<(int, int)>();
    queue.add((startRow, startCol));

    while (queue.isNotEmpty) {
      final (r, c) = queue.removeFirst();
      if (r < 0 || r >= chart.rows || c < 0 || c >= chart.cols) continue;
      if (newGrid[r][c] != target) continue;
      newGrid[r][c] = newCell;
      queue.add((r - 1, c));
      queue.add((r + 1, c));
      queue.add((r, c - 1));
      queue.add((r, c + 1));
    }

    return PatternChart(
      id: chart.id,
      title: chart.title,
      rows: chart.rows,
      cols: chart.cols,
      mode: chart.mode,
      grid: newGrid,
    );
  }

  bool get _interactiveEnabled => widget.tool == ChartTool.move;

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _headerW + widget.chart.cols * _cellW;
    final canvasHeight = _headerH + widget.chart.rows * _cellH;

    final painter = _ChartPainter(
      chart: widget.chart,
    );

    Widget canvas = CustomPaint(
      size: Size(canvasWidth, canvasHeight),
      painter: painter,
    );

    if (!_interactiveEnabled) {
      canvas = GestureDetector(
        onTapDown: (d) => _handleTap(d.localPosition),
        onPanStart: (d) {
          _isPainting = true;
          _handleDragUpdate(d.localPosition);
        },
        onPanUpdate: (d) {
          if (_isPainting) _handleDragUpdate(d.localPosition);
        },
        onPanEnd: (_) => _isPainting = false,
        child: canvas,
      );
    }

    return InteractiveViewer(
      transformationController: _transformCtrl,
      panEnabled: _interactiveEnabled,
      scaleEnabled: _interactiveEnabled,
      minScale: 0.3,
      maxScale: 5.0,
      constrained: false,
      child: canvas,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final PatternChart chart;

  _ChartPainter({required this.chart});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    _drawCells(canvas);
    _drawGrid(canvas);
    _drawHeaders(canvas);
  }

  void _drawBackground(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(
        _headerW,
        _headerH,
        chart.cols * _cellW,
        chart.rows * _cellH,
      ),
      paint,
    );
  }

  void _drawCells(Canvas canvas) {
    for (int r = 0; r < chart.rows; r++) {
      for (int c = 0; c < chart.cols; c++) {
        final cell = chart.grid[r][c];
        final rect = Rect.fromLTWH(
          _headerW + c * _cellW,
          _headerH + r * _cellH,
          _cellW,
          _cellH,
        );

        if (chart.mode == ChartMode.color) {
          if (cell.color != null) {
            canvas.drawRect(rect, Paint()..color = cell.color!);
          }
        } else {
          if (cell.symbolId != null) {
            final sym = KnitSymbolLibrary.byId(cell.symbolId!);
            if (sym != null) {
              _drawSymbol(canvas, rect, sym.unicode);
            }
          }
        }
      }
    }
  }

  void _drawSymbol(Canvas canvas, Rect rect, String unicode) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 13,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const Color(0xFF1A1A2E), fontSize: 13))
      ..addText(unicode);

    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));

    final dy = rect.top + (rect.height - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(rect.left, dy));
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final gridLeft = _headerW;
    final gridTop = _headerH;
    final gridRight = _headerW + chart.cols * _cellW;
    final gridBottom = _headerH + chart.rows * _cellH;

    for (int c = 0; c <= chart.cols; c++) {
      final x = gridLeft + c * _cellW;
      canvas.drawLine(Offset(x, gridTop), Offset(x, gridBottom), paint);
    }
    for (int r = 0; r <= chart.rows; r++) {
      final y = gridTop + r * _cellH;
      canvas.drawLine(Offset(gridLeft, y), Offset(gridRight, y), paint);
    }
  }

  void _drawHeaders(Canvas canvas) {
    final style = ui.TextStyle(
      color: const Color(0xFF9CA3AF),
      fontSize: 9,
      fontWeight: ui.FontWeight.w500,
    );

    for (int c = 0; c < chart.cols; c++) {
      final label = '${c + 1}';
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText(label);
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: _cellW));
      final x = _headerW + c * _cellW;
      final dy = (_headerH - p.height) / 2;
      canvas.drawParagraph(p, Offset(x, dy.clamp(0, _headerH)));
    }

    for (int r = 0; r < chart.rows; r++) {
      final label = '${r + 1}';
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText(label);
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: _headerW - 2));
      final y = _headerH + r * _cellH + (_cellH - p.height) / 2;
      canvas.drawParagraph(p, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.chart != chart || !identical(old.chart.grid, chart.grid);
}
