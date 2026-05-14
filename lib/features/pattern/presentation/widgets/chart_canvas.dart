import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/mori_symbol_view.dart';
import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/pattern_chart.dart';

/// 도안 모드에서 현재 작업 중인 레이어 (색상 / 기호)
enum DrawLayer { color, symbol }

const double _cellW = 24.0; // 코 가로
const double _cellH = 24.0; // 코 세로 (정사각형)
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
  /// 뷰어 모드 — 터치로 그리기 비활성화 (패닝/줌만 허용)
  final bool readOnly;
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
    this.readOnly = false,
  });

  @override
  ConsumerState<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends ConsumerState<ChartCanvas> {
  TransformationController? _ownedCtrl;
  TransformationController get _transformCtrl =>
      widget.transformationController ?? (_ownedCtrl ??= TransformationController());
  bool _isPainting = false;

  /// #680 — multi-touch 카운트 (두 손가락 이상이면 그리기 취소, InteractiveViewer가 핀치).
  final Set<int> _activePointers = {};

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
    final availableW = size.width - _headerW * 2; // 좌우 단수 헤더
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
    switch (widget.tool) {
      case ChartTool.draw:
        // 펜: 심볼 색상만 지정, 배경색은 setSpanCell에서 기존값 보존
        return CellData(symbolColor: widget.activeColor, symbolId: widget.activeSymbolId);
      case ChartTool.brush:
        return CellData(color: widget.activeColor);
      default:
        return CellData(color: widget.activeColor);
    }
  }

  void _handleTap(Offset localPos) {
    final hit = _hitCell(localPos);
    if (hit == null) return;
    final (row, col) = hit;
    final byId = ref.read(knitSymbolByIdProvider);
    final mirrorMode = widget.chart.mirrorMode;
    final mirrorCol = widget.chart.cols - 1 - col;

    PatternChart applyToCell(PatternChart chart, int r, int c) {
      switch (widget.tool) {
        case ChartTool.draw:
          final sym = widget.activeSymbolId != null ? byId[widget.activeSymbolId] : null;
          final sw = sym?.spanWidth ?? 1;
          final sh = sym?.spanHeight ?? 1;
          return chart.setSpanCell(r, c, _activeCell, sw, sh);
        case ChartTool.brush:
          return chart.setCellColor(r, c, widget.activeColor);
        case ChartTool.erase:
          return chart.eraseSpanCell(r, c);
        case ChartTool.fill:
          return _floodFill(chart, r, c, CellData(color: widget.activeColor), DrawLayer.color);
        default:
          return chart;
      }
    }

    switch (widget.tool) {
      case ChartTool.draw:
      case ChartTool.brush:
      case ChartTool.erase:
      case ChartTool.fill:
        var chart = applyToCell(widget.chart, row, col);
        if (mirrorMode && mirrorCol != col) {
          chart = applyToCell(chart, row, mirrorCol);
        }
        widget.onChartChanged(chart);
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
    final byId = ref.read(knitSymbolByIdProvider);
    final (row, col) = hit;
    final mirrorMode = widget.chart.mirrorMode;
    final mirrorCol = widget.chart.cols - 1 - col;

    var chart = widget.chart;
    switch (widget.tool) {
      case ChartTool.draw:
        // 펜: 심볼 + 활성 배경색 함께 적용
        final sym = widget.activeSymbolId != null ? byId[widget.activeSymbolId] : null;
        final sw = sym?.spanWidth ?? 1;
        final sh = sym?.spanHeight ?? 1;
        chart = chart.setSpanCell(row, col, _activeCell, sw, sh);
        if (mirrorMode && mirrorCol != col) {
          chart = chart.setSpanCell(row, mirrorCol, _activeCell, sw, sh);
        }
      case ChartTool.brush:
        chart = chart.setCellColor(row, col, widget.activeColor);
        if (mirrorMode && mirrorCol != col) {
          chart = chart.setCellColor(row, mirrorCol, widget.activeColor);
        }
      case ChartTool.erase:
        chart = chart.eraseSpanCell(row, col);
        if (mirrorMode && mirrorCol != col) {
          chart = chart.eraseSpanCell(row, mirrorCol);
        }
      default:
        break;
    }
    widget.onChartChanged(chart);
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

  /// move 도구 또는 readOnly 시 InteractiveViewer가 단일 터치 panning까지 처리.
  bool get _interactiveEnabled => widget.readOnly || widget.tool == ChartTool.move;

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _headerW + widget.chart.cols * _cellW + _headerW; // 좌우 단수 헤더
    final canvasHeight = _headerH + widget.chart.rows * _cellH;

    // narrative 제외 항상 SVG 오버레이 표시 — 앵커 셀만 렌더링, span 크기 적용
    // #672 — MoriSymbolView 단일 소스 사용 (이전: 직접 SvgPicture.network)
    final overlays = <Widget>[];
    if (widget.chart.mode != ChartMode.narrative) {
      for (int r = 0; r < widget.chart.rows; r++) {
        for (int c = 0; c < widget.chart.cols; c++) {
          final cell = widget.chart.grid[r][c];
          if (!cell.isAnchor) continue;
          final symId = cell.symbolId;
          if (symId == null) continue;
          final sw = cell.spanW ?? 1;
          final sh = cell.spanH ?? 1;
          final symColor = cell.symbolColor ?? Colors.black87;
          overlays.add(Positioned(
            left: _headerW + c * _cellW + 2,
            top: _headerH + r * _cellH + 2,
            width: _cellW * sw - 4,
            height: _cellH * sh - 4,
            child: MoriSymbolView(
              symbolId: symId,
              size: _cellW * sw - 4,
              color: symColor,
            ),
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
            painter: _ChartPainter(chart: widget.chart, mirrorMode: widget.chart.mirrorMode),
          ),
          ...overlays,
        ],
      ),
    );

    if (!_interactiveEnabled) {
      // #680 — Listener 사용 (gesture arena 참가 X) → InteractiveViewer가 핀치 자유.
      // multi-touch 시 그리기 자동 취소.
      canvas = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _activePointers.add(e.pointer);
          if (_activePointers.length == 1) {
            _isPainting = true;
            _handleTap(e.localPosition);
          } else {
            // 두 손가락 이상 → 그리기 취소, InteractiveViewer가 핀치 처리.
            _isPainting = false;
          }
        },
        onPointerMove: (e) {
          if (_isPainting && _activePointers.length == 1) {
            _handleDragUpdate(e.localPosition);
          }
        },
        onPointerUp: (e) {
          _activePointers.remove(e.pointer);
          if (_activePointers.isEmpty) _isPainting = false;
        },
        onPointerCancel: (e) {
          _activePointers.remove(e.pointer);
          if (_activePointers.isEmpty) _isPainting = false;
        },
        child: canvas,
      );
    }

    return InteractiveViewer(
      transformationController: _transformCtrl,
      panEnabled: _interactiveEnabled,
      scaleEnabled: true, // 항상 핀치줌 (도구 무관 — 모바일 표준).
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
  final bool mirrorMode;

  const _ChartPainter({required this.chart, this.mirrorMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    _drawCells(canvas);
    _drawGrid(canvas);
    _drawHeaders(canvas);
    if (mirrorMode) _drawMirrorLine(canvas);
    if (chart.repeatRegions.isNotEmpty) _drawRepeatBoxes(canvas);
  }

  void _drawMirrorLine(Canvas canvas) {
    final gridLeft = _headerW;
    final gridTop = _headerH;
    final gridBottom = _headerH + chart.rows * _cellH;
    final centerX = gridLeft + (chart.cols / 2) * _cellW;
    final mirrorLinePaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const dashHeight = 6.0;
    const dashSpace = 4.0;
    double startY = gridTop;
    while (startY < gridBottom) {
      final endY = (startY + dashHeight).clamp(gridTop, gridBottom);
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, endY),
        mirrorLinePaint,
      );
      startY += dashHeight + dashSpace;
    }
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
    // 독해 방향 화살표 색상
    final arrowPaintRS = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arrowPaintWS = Paint()
      ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int c = 0; c < chart.cols; c++) {
      final colLabel = chart.cols - c;
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('$colLabel');
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: _cellW));
      final x = _headerW + c * _cellW;
      final dy = (_headerH - p.height) / 2;
      canvas.drawParagraph(p, Offset(x, dy.clamp(0, _headerH)));
    }

    final gridRight = _headerW + chart.cols * _cellW;
    final isFlat = chart.knittingDirection == KnittingDirection.flatRows;

    for (int r = 0; r < chart.rows; r++) {
      final rowLabel = chart.rows - r;
      final y = _headerH + r * _cellH + (_cellH - 9) / 2;
      // 뜨개 관례: 아래부터 1단 → rowLabel 홀수 = RS, 짝수 = WS
      final isRS = !isFlat || rowLabel.isOdd;

      // 왼쪽 단수
      final pbL = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('$rowLabel');
      final pL = pbL.build()..layout(const ui.ParagraphConstraints(width: _headerW - 2));
      canvas.drawParagraph(pL, Offset(0, y));

      // 오른쪽 단수
      final pbR = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('$rowLabel');
      final pR = pbR.build()..layout(const ui.ParagraphConstraints(width: _headerW));
      canvas.drawParagraph(pR, Offset(gridRight + 2, y));

      // 독해 방향 화살표 (RS: 오른쪽 헤더에 ←, WS: 왼쪽 헤더에 →)
      final arrowY = _headerH + r * _cellH + _cellH * 0.5;
      final arrowPaint = isRS ? arrowPaintRS : arrowPaintWS;
      if (isRS) {
        // RS: 오른쪽→왼쪽 읽기 → 오른쪽 헤더에 ← 화살표
        final ax = gridRight + _headerW - 1;
        _drawArrow(canvas, ax, arrowY, ax - 7, arrowY, arrowPaint);
      } else {
        // WS: 왼쪽→오른쪽 읽기 → 왼쪽 헤더에 → 화살표
        _drawArrow(canvas, 1, arrowY, 8, arrowY, arrowPaint);
      }
    }
  }

  void _drawArrow(Canvas canvas, double fromX, double fromY, double toX, double toY, Paint paint) {
    canvas.drawLine(Offset(fromX, fromY), Offset(toX, toY), paint);
    // 화살촉
    final dx = toX - fromX;
    const headLen = 3.5;
    final sign = dx > 0 ? 1 : -1;
    canvas.drawLine(Offset(toX, toY), Offset(toX - sign * headLen, toY - headLen * 0.6), paint);
    canvas.drawLine(Offset(toX, toY), Offset(toX - sign * headLen, toY + headLen * 0.6), paint);
  }

  void _drawRepeatBoxes(Canvas canvas) {
    final borderPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final labelBg = Paint()..color = const Color(0xFFEF4444);
    const dashLen = 5.0;
    const dashGap = 3.0;

    for (final region in chart.repeatRegions) {
      final left = _headerW + region.startCol * _cellW;
      final top = _headerH + region.startRow * _cellH;
      final right = _headerW + (region.endCol + 1) * _cellW;
      final bottom = _headerH + (region.endRow + 1) * _cellH;
      final rect = Rect.fromLTRB(left, top, right, bottom);

      // 대시 테두리
      _drawDashedRect(canvas, rect, borderPaint, dashLen, dashGap);

      // 반복 횟수 라벨 (우상단)
      if (region.repeatCount > 1) {
        final label = '×${region.repeatCount}';
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 8))
          ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: 8, fontWeight: ui.FontWeight.w700))
          ..addText(label);
        final p = pb.build()..layout(const ui.ParagraphConstraints(width: 24));
        final labelX = right - 2 - 24;
        final labelY = top + 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(labelX - 1, labelY - 1, p.longestLine + 4, p.height + 2), const Radius.circular(3)),
          labelBg,
        );
        canvas.drawParagraph(p, Offset(labelX + 1, labelY));
      }
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double dashLen, double dashGap) {
    // top
    _drawDashedLine(canvas, Offset(rect.left, rect.top), Offset(rect.right, rect.top), paint, dashLen, dashGap);
    // bottom
    _drawDashedLine(canvas, Offset(rect.left, rect.bottom), Offset(rect.right, rect.bottom), paint, dashLen, dashGap);
    // left
    _drawDashedLine(canvas, Offset(rect.left, rect.top), Offset(rect.left, rect.bottom), paint, dashLen, dashGap);
    // right
    _drawDashedLine(canvas, Offset(rect.right, rect.top), Offset(rect.right, rect.bottom), paint, dashLen, dashGap);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint, double dashLen, double dashGap) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final total = (dx.abs() > dy.abs()) ? dx.abs() : dy.abs();
    final nx = total == 0 ? 0.0 : dx / total;
    final ny = total == 0 ? 0.0 : dy / total;
    double dist = 0;
    bool drawing = true;
    while (dist < total) {
      final segLen = drawing ? dashLen : dashGap;
      final end = (dist + segLen).clamp(0, total);
      if (drawing) {
        canvas.drawLine(
          Offset(from.dx + nx * dist, from.dy + ny * dist),
          Offset(from.dx + nx * end, from.dy + ny * end),
          paint,
        );
      }
      dist += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) {
    if (old is _ChartPainter) {
      return old.chart != chart ||
          !identical(old.chart.grid, chart.grid) ||
          old.mirrorMode != mirrorMode;
    }
    return true;
  }
}
