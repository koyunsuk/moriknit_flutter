import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/round_chart.dart';

/// 원형(라운드) 도안 전용 CustomPainter.
///
/// 마법의 원(magic ring) 시작점을 중심으로 라운드(R)와 세그먼트(S) 좌표계로
/// 셀을 동심원 위에 배치한다. SVG 심볼은 [symbolPicture] 콜백으로 가져와
/// `ui.Picture`를 그대로 그린다 (외부 SvgSymbolCache.pictureFor() 연결).
class RoundChartPainter extends CustomPainter {
  /// 원형 도안 데이터.
  final RoundChart chart;

  /// 호버/스냅 미리보기 셀.
  final RoundCellKey? hoveredCell;

  /// 사용자가 선택한 편집 대상 셀.
  final RoundCellKey? selectedCell;

  /// 점선 동심원 + 방사선 가이드 표시 여부.
  final bool showGuides;

  /// 라운드 라벨 (R1, R2, ...) 표시 여부.
  final bool showRoundLabels;

  /// SvgSymbolCache.pictureFor() 콜백. null 반환 시 폴백 처리(현재는 생략).
  final ui.Picture? Function(String) symbolPicture;

  RoundChartPainter({
    required this.chart,
    this.hoveredCell,
    this.selectedCell,
    this.showGuides = true,
    this.showRoundLabels = true,
    required this.symbolPicture,
  });

  // ── 좌표/기하 상수 ────────────────────────────────────────────────
  /// 가운데 빈 공간(마법의 원) 반지름 비율.
  static const double _kInnerRadiusRatio = 0.05;

  /// 외곽 반지름 비율 (캔버스 짧은 변 기준).
  static const double _kTotalRadiusRatio = 0.45;

  /// SVG 뷰박스 (심볼 원본 크기).
  static const double _kSvgViewBox = 24.0;

  // ── 정적 좌표 헬퍼 (외부 스냅 함수에서도 활용) ──────────────────────────
  /// 캔버스 크기 + 라운드 수에 따른 셀(라운드 폭) 높이.
  static double cellHeight(Size canvasSize, int rounds) {
    if (rounds <= 0) return 0;
    final inner = canvasSize.shortestSide * _kInnerRadiusRatio;
    final total = canvasSize.shortestSide * _kTotalRadiusRatio;
    return (total - inner) / rounds;
  }

  /// R번째 라운드의 셀 중심 반지름.
  static double radiusFor(RoundChart chart, int round, double cellHeight) {
    final inner = cellHeight > 0 ? cellHeight * 0 : 0; // 형태 보존용
    // innerRadius 자체는 cellHeight 계산에서 분리되어 있음 → 동일 비율 재계산.
    // 외부에서는 보통 positionFor를 사용하므로 inner는 별도 인자로 받지 않는다.
    final innerEstimate = inner; // 0 (사용 안 함)
    return innerEstimate + (round - 0.5) * cellHeight;
  }

  /// (R, S)의 각도 (라디안). 12시 방향이 -π/2.
  static double angleFor(RoundChart chart, int round, int segment) {
    if (round < 1 || round > chart.rounds) return -math.pi / 2;
    final segCount = _stitchCountAt(chart, round);
    if (segCount <= 0) return -math.pi / 2;
    final base = _startOffsetAt(chart, round);
    return base + 2 * math.pi * segment / segCount;
  }

  /// (R, S)의 캔버스 좌표.
  static Offset positionFor(
    RoundChart chart,
    int round,
    int segment,
    Size canvasSize,
  ) {
    final inner = canvasSize.shortestSide * _kInnerRadiusRatio;
    final ch = cellHeight(canvasSize, chart.rounds);
    final radius = inner + (round - 0.5) * ch;
    final angle = angleFor(chart, round, segment);
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    return center + Offset(radius * math.cos(angle), radius * math.sin(angle));
  }

  /// #680 — 터치 위치가 셀 중앙(cellArea)인지 라인(onLine) 부근인지 힌트 반환.
  /// 셀 중심 ± ch×0.25 반경 = 중앙 / 그 외 = 라인.
  static ({RoundCellKey key, bool isLineTouch})? snapToCellWithHint(
    RoundChart chart,
    Offset point,
    Size canvasSize, {
    double thresholdMultiplier = 0.5,
  }) {
    final key = snapToCell(chart, point, canvasSize,
        thresholdMultiplier: thresholdMultiplier);
    if (key == null) return null;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final inner = canvasSize.shortestSide * _kInnerRadiusRatio;
    final cellH = cellHeight(canvasSize, chart.rounds);
    final centerRadius = inner + (key.round - 0.5) * cellH;
    final centerZone = cellH * 0.25;
    final isLineTouch = (dist - centerRadius).abs() > centerZone;
    return (key: key, isLineTouch: isLineTouch);
  }

  /// 캔버스 좌표 → 가장 가까운 (R, S) 셀 키.
  ///
  /// [thresholdMultiplier]는 셀 크기 대비 허용 거리 (기본 0.5 = 셀 반경 이내).
  /// 도안 모양(roundFull/half/sector) 밖 영역은 null 반환.
  static RoundCellKey? snapToCell(
    RoundChart chart,
    Offset point,
    Size canvasSize, {
    double thresholdMultiplier = 0.5,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final inner = canvasSize.shortestSide * _kInnerRadiusRatio;
    final ch = cellHeight(canvasSize, chart.rounds);
    if (ch <= 0) return null;

    // 가장 가까운 라운드 추정 (1-base).
    final raw = ((dist - inner) / ch) + 0.5;
    final round = raw.round();
    if (round < 1 || round > chart.rounds) return null;

    // 각도 (라디안). atan2는 -π~π.
    var theta = math.atan2(dy, dx);
    final segCount = _stitchCountAt(chart, round);
    if (segCount <= 0) return null;
    final base = _startOffsetAt(chart, round);

    // 모양 제한 검사.
    if (!_angleInsideShape(chart, theta)) return null;

    // base 기준 정규화 → 0~2π.
    var rel = theta - base;
    rel = rel % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;
    final segIdx = (rel / (2 * math.pi) * segCount).round() % segCount;

    // 거리 임계치 검사 (스냅 반경).
    final cellRadius = ch * thresholdMultiplier;
    final target = positionFor(chart, round, segIdx, canvasSize);
    final ddx = target.dx - point.dx;
    final ddy = target.dy - point.dy;
    if (math.sqrt(ddx * ddx + ddy * ddy) > cellRadius * 2) {
      // 너무 먼 경우 거부 (반경 2배까지는 허용 — 라운드 단위로 끌림).
      return null;
    }
    return RoundCellKey(round: round, segment: segIdx);
  }

  // ── 내부 헬퍼 ────────────────────────────────────────────────────
  /// R번째 라운드의 코수.
  static int _stitchCountAt(RoundChart chart, int round) {
    final idx = round - 1;
    if (idx < 0) return 0;
    if (idx < chart.stitchCounts.length) return chart.stitchCounts[idx];
    if (chart.autoIncreasePerRound) {
      // baseStitchCount * round (ex: 6, 12, 18, ...)
      return chart.baseStitchCount * round;
    }
    return chart.baseStitchCount;
  }

  /// R번째 라운드의 시작 각도 오프셋.
  static double _startOffsetAt(RoundChart chart, int round) {
    final idx = round - 1;
    if (idx >= 0 && idx < chart.startAngleOffsets.length) {
      return chart.startAngleOffsets[idx];
    }
    return -math.pi / 2; // 12시 방향 기본
  }

  /// shape에 따른 각도 허용 범위 검사.
  static bool _angleInsideShape(RoundChart chart, double theta) {
    switch (chart.shape) {
      case ChartShape.rect:
      case ChartShape.guidePath:
      case ChartShape.roundFull:
        return true;
      case ChartShape.roundHalf:
        // 위쪽 반원 = -π ~ 0
        return theta >= -math.pi && theta <= 0;
      case ChartShape.roundSector:
        var t = theta;
        // sector 범위 내 정규화.
        final s = chart.sectorAngleStart;
        final e = chart.sectorAngleEnd;
        if (s <= e) {
          return t >= s && t <= e;
        } else {
          // wrap-around (예: 5π/4 → π/4)
          return t >= s || t <= e;
        }
    }
  }

  // ── paint ────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final inner = size.shortestSide * _kInnerRadiusRatio;
    final total = size.shortestSide * _kTotalRadiusRatio;
    final ch = cellHeight(size, chart.rounds);

    // 1) 가이드 (점선 동심원 + 방사선 + 가운데 ⊙)
    if (showGuides) {
      _drawGuides(canvas, center, inner, total, ch);
      _drawMagicRing(canvas, center, inner);
    }

    // 2) 셀 그리기
    _drawCells(canvas, size, center, inner, ch);

    // 3) 라운드 라벨
    if (showRoundLabels) {
      _drawRoundLabels(canvas, size, center, inner, ch);
    }

    // 4) 호버/선택 하이라이트 (셀 위에 덮어 그림)
    if (hoveredCell != null) {
      _drawHighlight(canvas, size, hoveredCell!, const Color(0xFFFFD700), 2.0);
    }
    if (selectedCell != null) {
      _drawHighlight(canvas, size, selectedCell!, C.lvD, 3.0);
    }
  }

  /// 점선 동심원 + 방사선.
  void _drawGuides(
    Canvas canvas,
    Offset center,
    double inner,
    double total,
    double ch,
  ) {
    final ringPaint = Paint()
      ..color = C.tx.withValues(alpha: 0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final spokePaint = Paint()
      ..color = C.mu.withValues(alpha: 0.15)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // 동심원 (점선) — 각 라운드 경계 (R 0~rounds)
    for (int r = 0; r <= chart.rounds; r++) {
      final radius = inner + r * ch;
      _drawDashedCircle(canvas, center, radius, ringPaint, 4.0, 3.0);
    }

    // 방사선 — 가장 바깥 라운드의 코수 기준 (가독성을 위해 전체 셀 방사선은 생략)
    final outerSegCount = _stitchCountAt(chart, chart.rounds);
    if (outerSegCount <= 0) return;
    final base = _startOffsetAt(chart, chart.rounds);
    for (int s = 0; s < outerSegCount; s++) {
      final angle = base + 2 * math.pi * s / outerSegCount;
      // shape 범위 검사
      if (!_angleInsideShape(chart, angle)) continue;
      final p1 = center +
          Offset(inner * math.cos(angle), inner * math.sin(angle));
      final p2 = center +
          Offset(total * math.cos(angle), total * math.sin(angle));
      canvas.drawLine(p1, p2, spokePaint);
    }
  }

  /// 마법의 원 표시 (가운데 ⊙).
  void _drawMagicRing(Canvas canvas, Offset center, double inner) {
    final ringPaint = Paint()
      ..color = C.lv.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = C.lv.withValues(alpha: 0.7);
    final ringR = inner * 0.6;
    canvas.drawCircle(center, ringR, ringPaint);
    canvas.drawCircle(center, ringR * 0.25, dotPaint);
  }

  /// 셀 (배경 + 심볼) 그리기. span 처리 포함.
  /// #680 — 심볼을 셀 사각 영역에 contain (BoxFit.contain). 사각 그리드와 동일.
  void _drawCells(
    Canvas canvas,
    Size size,
    Offset center,
    double inner,
    double ch,
  ) {
    chart.cells.forEach((key, cell) {
      if (key.round < 1 || key.round > chart.rounds) return;
      final segCount = _stitchCountAt(chart, key.round);
      if (segCount <= 0) return;
      if (key.segment < 0 || key.segment >= segCount) return;

      final angle = angleFor(chart, key.round, key.segment);
      if (!_angleInsideShape(chart, angle)) return;

      // 셀 한 개의 호 너비(라디안). span 적용 시 묶인 셀 폭 확대.
      final span = cell.spanS.clamp(1, segCount).toInt();
      final cellArc = 2 * math.pi / segCount;
      final centerAngle = angle + (span - 1) / 2 * cellArc;

      final cellMidRadius = inner + (key.round - 0.5) * ch;
      // 셀의 라운드 폭(px) = ch.
      final cellRadialPx = ch;

      final pos = center +
          Offset(cellMidRadius * math.cos(centerAngle),
              cellMidRadius * math.sin(centerAngle));

      // #680/일관성 — 셀 영역을 정사각(ch×ch)으로 강제.
      //   라운드별 호 너비 차이로 인한 크기 변동 제거.
      //   안쪽 라운드는 옆 셀 살짝 겹칠 수 있지만 일관성 우선.
      //   span 적용 시 호 방향 폭만 확장.
      final cellAreaW = cellRadialPx * span.toDouble();
      final cellAreaH = cellRadialPx;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      final rotation =
          (cell.autoRotate ? centerAngle + math.pi / 2 : 0.0) +
              cell.rotationDelta;
      canvas.rotate(rotation);

      // 회전 후 좌표계: x = 호 방향, y = 반지름 방향(외곽 - 중심).
      // 셀 영역 사각: (-w/2, -h/2) ~ (w/2, h/2).
      final cellRect = Rect.fromLTWH(
        -cellAreaW / 2,
        -cellAreaH / 2,
        cellAreaW,
        cellAreaH,
      );

      // 배경색 — 셀 영역 그대로.
      if (cell.color != null) {
        final bgPaint = Paint()..color = cell.color!;
        canvas.drawRect(cellRect, bgPaint);
      }

      // 심볼 — align 모드에 따라 다르게.
      if (cell.symbolId != null) {
        final picture = symbolPicture(cell.symbolId!);
        if (picture != null) {
          if (cell.align == CellAlign.cellArea) {
            // (1) 셀 사각 영역에 contain (사각 그리드와 동일 — 기본).
            //     SVG 24x24 viewBox를 셀 영역의 짧은 변에 맞춤 (비율 유지).
            final shortSide = math.min(cellAreaW, cellAreaH) * 0.92;
            _drawPictureContain(canvas, picture, shortSide, shortSide,
                cell.symbolColor);
          } else {
            // (2) #680 onLine: 안쪽 호(이전 라운드 외곽 = 현 라운드 안쪽)에 baseline.
            //     심볼 밑면이 호 위에 닿고, 외곽(+y) 방향으로 솟음.
            //     회전된 좌표계에서 안쪽 호 위치 = y = -cellRadialPx/2 (셀 중앙에서 -h/2).
            //     심볼은 라인보다 외곽 방향으로 그려져야 하므로 (-w/2, baseline) 시작.
            final symbolH = cellRadialPx * 0.92; // 심볼 높이 = 셀 라디알 폭
            final symbolW = math.min(cellAreaW * 0.92, symbolH);
            final innerLineY = -cellRadialPx / 2; // 안쪽 호 좌표 (회전 후)
            canvas.save();
            // 심볼 밑면이 innerLineY에 닿게: y축 시작점 = innerLineY,
            //  외곽(+y) 방향 = 셀 안쪽으로 솟음. 즉 바닥 = innerLineY, 윗쪽 = innerLineY + symbolH
            // → translate(-w/2, innerLineY) 하면 0~symbolH 영역이 그려지는데 +y가 외곽.
            canvas.translate(-symbolW / 2, innerLineY);
            _drawPictureContain(
                canvas, picture, symbolW, symbolH, cell.symbolColor);
            canvas.restore();
          }
        }
      }

      canvas.restore();
    });
  }

  /// #680 — Picture를 주어진 영역에 BoxFit.contain (비율 유지, 중앙 정렬).
  /// origin (0, 0)에서 (w, h) 영역.
  void _drawPictureContain(
    Canvas canvas,
    ui.Picture picture,
    double w,
    double h,
    Color? tint,
  ) {
    final scale = math.min(w / _kSvgViewBox, h / _kSvgViewBox);
    final scaledW = _kSvgViewBox * scale;
    final scaledH = _kSvgViewBox * scale;
    final offsetX = (w - scaledW) / 2;
    final offsetY = (h - scaledH) / 2;
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);
    if (tint != null) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, _kSvgViewBox, _kSvgViewBox),
        Paint(),
      );
      canvas.drawPicture(picture);
      final tintPaint = Paint()
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _kSvgViewBox, _kSvgViewBox),
        tintPaint,
      );
      canvas.restore();
    } else {
      canvas.drawPicture(picture);
    }
    canvas.restore();
  }

  /// R1, R2, ... 라벨 (12시 방향 기준).
  void _drawRoundLabels(
    Canvas canvas,
    Size size,
    Offset center,
    double inner,
    double ch,
  ) {
    final style = ui.TextStyle(
      color: C.lv,
      fontSize: 9,
      fontWeight: ui.FontWeight.w600,
    );
    for (int r = 1; r <= chart.rounds; r++) {
      final base = _startOffsetAt(chart, r);
      // 라벨 위치 = 라운드 중심 반지름 × 시작 각도 (보통 12시)
      final radius = inner + (r - 0.5) * ch;
      final pos = center +
          Offset(radius * math.cos(base), radius * math.sin(base));
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 9),
      )
        ..pushStyle(style)
        ..addText('R$r');
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: 24));
      // 라벨을 셀 옆으로 살짝 비켜서 표시 (좌측 상단 약간 오프셋)
      canvas.drawParagraph(p, pos + const Offset(-12, -ui.kTextHeightNone * 6 - 6));
    }
  }

  /// 셀 외곽 하이라이트 링.
  void _drawHighlight(
    Canvas canvas,
    Size size,
    RoundCellKey key,
    Color color,
    double strokeWidth,
  ) {
    if (key.round < 1 || key.round > chart.rounds) return;
    final segCount = _stitchCountAt(chart, key.round);
    if (segCount <= 0 || key.segment < 0 || key.segment >= segCount) return;
    final pos = positionFor(chart, key.round, key.segment, size);
    final ch = cellHeight(size, chart.rounds);
    final radius = ch * 0.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, radius, paint);
  }

  /// 점선 원 (가이드 동심원).
  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    double dashLen,
    double dashGap,
  ) {
    if (radius <= 0) return;
    final dashAngle = dashLen / radius;
    final gapAngle = dashGap / radius;
    double angle = 0;
    bool drawing = true;
    while (angle < 2 * math.pi) {
      final segAngle = drawing ? dashAngle : gapAngle;
      final endAngle = math.min(angle + segAngle, 2 * math.pi);
      if (drawing) {
        // shape 범위 안일 때만 그림 (필요 시 — 가이드는 항상 풀원)
        final p1 = center +
            Offset(radius * math.cos(angle), radius * math.sin(angle));
        final p2 = center +
            Offset(radius * math.cos(endAngle), radius * math.sin(endAngle));
        // 호 길이가 짧으므로 직선 근사
        canvas.drawLine(p1, p2, paint);
      }
      angle = endAngle;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant RoundChartPainter old) {
    return old.chart != chart ||
        old.hoveredCell != hoveredCell ||
        old.selectedCell != selectedCell ||
        old.showGuides != showGuides ||
        old.showRoundLabels != showRoundLabels ||
        !identical(old.symbolPicture, symbolPicture);
  }
}

/// 원형 도안 표시용 StatelessWidget 래퍼.
///
/// 사용 예 (PatternEditorScreen):
/// ```dart
/// final cache = ref.watch(svgSymbolCacheProvider);
/// return RoundChartView(
///   chart: roundChart,
///   hoveredCell: hovered,
///   selectedCell: selected,
///   symbolPicture: cache.pictureFor,
/// );
/// ```
class RoundChartView extends StatelessWidget {
  final RoundChart chart;
  final RoundCellKey? hoveredCell;
  final RoundCellKey? selectedCell;
  final bool showGuides;
  final bool showRoundLabels;
  final ui.Picture? Function(String) symbolPicture;

  /// SvgSymbolCache의 ChangeNotifier를 repaint 트리거로 연결할 때 사용.
  final Listenable? repaint;

  const RoundChartView({
    super.key,
    required this.chart,
    required this.symbolPicture,
    this.hoveredCell,
    this.selectedCell,
    this.showGuides = true,
    this.showRoundLabels = true,
    this.repaint,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RoundChartPainter(
        chart: chart,
        hoveredCell: hoveredCell,
        selectedCell: selectedCell,
        showGuides: showGuides,
        showRoundLabels: showRoundLabels,
        symbolPicture: symbolPicture,
      ),
      // CustomPaint는 painter.repaint를 직접 받지 않으므로
      // 필요하다면 상위에서 ListenableBuilder로 감싸 repaint 트리거.
    );
  }
}
