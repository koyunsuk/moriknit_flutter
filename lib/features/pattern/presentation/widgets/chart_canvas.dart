import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';

/// 도안 모드에서 현재 작업 중인 레이어 (색상 / 기호)
enum DrawLayer { color, symbol }

const double _cellW = 36.0;
const double _cellH = 24.0;
const double _headerW = 20.0;
const double _headerH = 20.0;

class ChartCanvas extends ConsumerStatefulWidget {
  final PatternChart chart;
  final ChartTool tool;
  final Color activeColor;
  final String? activeSymbolId;
  final DrawLayer activeLayer;
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
    required this.activeLayer,
    required this.onChartChanged,
    this.transformationController,
    this.fitToScreenNotifier,
  });

  @override
  ConsumerState<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends ConsumerState<ChartCanvas> {
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
    // Flutter hit testing이 InteractiveViewer transform을 자동 역변환하므로
    // localPos는 이미 캔버스 좌표계 → 별도 역변환 불필요
    final x = localPos.dx - _headerW;
    final y = localPos.dy - _headerH;
    if (x < 0 || y < 0) return null;
    final col = (x / _cellW).floor();
    final row = (y / _cellH).floor();
    if (row < 0 || row >= widget.chart.rows) return null;
    if (col < 0 || col >= widget.chart.cols) return null;
    return (row, col);
  }


  CellData get _activeCell {
    if (widget.activeLayer == DrawLayer.symbol) {
      return CellData(symbolId: widget.activeSymbolId);
    }
    return CellData(color: widget.activeColor);
  }

  void _handleTap(Offset localPos) {
    final hit = _hitCell(localPos);
    if (hit == null) return;
    final (row, col) = hit;
    final byId = ref.read(knitSymbolByIdProvider);
    switch (widget.tool) {
      case ChartTool.draw:
        if (widget.activeLayer == DrawLayer.symbol) {
          // 기호 레이어 — 기존 span 로직 유지
          final sym = widget.activeSymbolId != null ? byId[widget.activeSymbolId] : null;
          final sw = sym?.spanWidth ?? 1;
          final sh = sym?.spanHeight ?? 1;
          if (sw == 1 && sh == 1) {
            widget.onChartChanged(widget.chart.setCellSymbol(row, col, widget.activeSymbolId));
          } else {
            widget.onChartChanged(widget.chart.setSpanCell(row, col, _activeCell, sw, sh));
          }
        } else {
          // 색상 레이어 — 기호 보존
          widget.onChartChanged(widget.chart.setCellColor(row, col, widget.activeColor));
        }
      case ChartTool.erase:
        widget.onChartChanged(widget.chart.eraseSpanCell(row, col));
      case ChartTool.fill:
        // fill은 span 심볼 배치 시 무시
        final sym = widget.activeSymbolId != null ? byId[widget.activeSymbolId] : null;
        if (widget.activeLayer == DrawLayer.symbol &&
            ((sym?.spanWidth ?? 1) > 1 || (sym?.spanHeight ?? 1) > 1)) break;
        final filled = _floodFill(widget.chart, row, col, _activeCell, widget.activeLayer);
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
    final byId = ref.read(knitSymbolByIdProvider);
    if (widget.tool == ChartTool.draw) {
      if (widget.activeLayer == DrawLayer.symbol) {
        final sym = widget.activeSymbolId != null ? byId[widget.activeSymbolId] : null;
        final sw = sym?.spanWidth ?? 1;
        final sh = sym?.spanHeight ?? 1;
        if (sw == 1 && sh == 1) {
          widget.onChartChanged(widget.chart.setCellSymbol(row, col, widget.activeSymbolId));
        } else {
          widget.onChartChanged(widget.chart.setSpanCell(row, col, _activeCell, sw, sh));
        }
      } else {
        widget.onChartChanged(widget.chart.setCellColor(row, col, widget.activeColor));
      }
    } else if (widget.tool == ChartTool.erase) {
      widget.onChartChanged(widget.chart.eraseSpanCell(row, col));
    }
  }

  PatternChart _floodFill(
      PatternChart chart, int startRow, int startCol, CellData newCell, DrawLayer layer) {
    if (layer == DrawLayer.color) {
      final targetColor = chart.grid[startRow][startCol].color;
      if (targetColor?.toARGB32() == newCell.color?.toARGB32()) return chart;
      final newGrid = [for (final row in chart.grid) List<CellData>.from(row)];
      final queue = Queue<(int, int)>();
      queue.add((startRow, startCol));
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeFirst();
        if (r < 0 || r >= chart.rows || c < 0 || c >= chart.cols) continue;
        if (newGrid[r][c].color?.toARGB32() != targetColor?.toARGB32()) continue;
        final existing = newGrid[r][c];
        newGrid[r][c] = CellData(
          color: newCell.color,
          symbolId: existing.symbolId,
          spanW: existing.spanW,
          spanH: existing.spanH,
          anchorRow: existing.anchorRow,
          anchorCol: existing.anchorCol,
        );
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
    } else {
      // 기호 레이어 fill
      final targetSymbol = chart.grid[startRow][startCol].symbolId;
      if (targetSymbol == newCell.symbolId) return chart;
      final newGrid = [for (final row in chart.grid) List<CellData>.from(row)];
      final queue = Queue<(int, int)>();
      queue.add((startRow, startCol));
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeFirst();
        if (r < 0 || r >= chart.rows || c < 0 || c >= chart.cols) continue;
        if (newGrid[r][c].symbolId != targetSymbol) continue;
        if (newGrid[r][c].isOccupied) continue;
        final existing = newGrid[r][c];
        newGrid[r][c] = CellData(color: existing.color, symbolId: newCell.symbolId);
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
  }

  bool get _interactiveEnabled => widget.tool == ChartTool.move;

  /// symbolId → SVG URL 변환 (abbreviation 우선, id fallback)
  String? _svgUrl(String symbolId, Map<String, String> svgUrls) {
    final sym = KnitSymbolLibrary.byId(symbolId);
    if (sym != null) {
      final abbrKey = sym.abbr.toLowerCase().replaceAll(' ', '_');
      if (svgUrls.containsKey(abbrKey)) return svgUrls[abbrKey];
    }
    final idKey = symbolId.toLowerCase().replaceAll(' ', '_');
    return svgUrls[idKey];
  }

  @override
  Widget build(BuildContext context) {
    final svgUrls = ref.watch(knitSymbolSvgUrlProvider);
    final canvasWidth = _headerW + widget.chart.cols * _cellW;
    final canvasHeight = _headerH + widget.chart.rows * _cellH;

    // narrative 제외 항상 SVG 오버레이 표시 — 앵커 셀만 렌더링, span 크기 적용
    final overlays = <Widget>[];
    if (widget.chart.mode != ChartMode.narrative) {
      for (int r = 0; r < widget.chart.rows; r++) {
        for (int c = 0; c < widget.chart.cols; c++) {
          final cell = widget.chart.grid[r][c];
          // 점유 셀(occupied)은 앵커에서 이미 그리므로 건너뜀
          if (!cell.isAnchor) continue;
          final url = _svgUrl(cell.symbolId!, svgUrls);
          if (url == null) continue;
          final sw = cell.spanW ?? 1;
          final sh = cell.spanH ?? 1;
          overlays.add(Positioned(
            left: _headerW + c * _cellW + 2,
            top: _headerH + r * _cellH + 2,
            width: _cellW * sw - 4,
            height: _cellH * sh - 4,
            child: SvgPicture.network(url, fit: BoxFit.contain),
          ));
        }
      }
    }

    Widget canvas = SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(canvasWidth, canvasHeight),
            painter: _ChartPainter(chart: widget.chart),
          ),
          ...overlays,
        ],
      ),
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
      scaleEnabled: true,   // 항상 핀치줌 허용 (전체화면 후 줌아웃 가능)
      minScale: 0.1,
      maxScale: 5.0,
      constrained: false,
      child: canvas,
    );
  }
}

/// 그리드 배경·셀(컬러모드)·격자·헤더 전용 Painter
/// 기호 모드 셀은 SVG 오버레이로 처리하므로 Canvas 심볼 코드 없음
class _ChartPainter extends CustomPainter {
  final PatternChart chart;

  const _ChartPainter({required this.chart});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    _drawCells(canvas);
    _drawGrid(canvas);
    _drawHeaders(canvas);
  }

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(_headerW, _headerH, chart.cols * _cellW, chart.rows * _cellH),
      Paint()..color = Colors.white,
    );
  }

  void _drawCells(Canvas canvas) {
    // narrative 모드는 그리드를 그리지 않음. 그 외 항상 색상 렌더링.
    if (chart.mode == ChartMode.narrative) return;
    for (int r = 0; r < chart.rows; r++) {
      for (int c = 0; c < chart.cols; c++) {
        final cell = chart.grid[r][c];
        if (cell.color == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(_headerW + c * _cellW, _headerH + r * _cellH, _cellW, _cellH),
          Paint()..color = cell.color!,
        );
      }
    }
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
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('${c + 1}');
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: _cellW));
      final x = _headerW + c * _cellW;
      final dy = (_headerH - p.height) / 2;
      canvas.drawParagraph(p, Offset(x, dy.clamp(0, _headerH)));
    }

    for (int r = 0; r < chart.rows; r++) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('${r + 1}');
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: _headerW - 2));
      final y = _headerH + r * _cellH + (_cellH - p.height) / 2;
      canvas.drawParagraph(p, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) {
    if (old is _ChartPainter) {
      return old.chart != chart || !identical(old.chart.grid, chart.grid);
    }
    return true;
  }
}
