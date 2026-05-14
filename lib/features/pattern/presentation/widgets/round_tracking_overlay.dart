// lib/features/pattern/presentation/widgets/round_tracking_overlay.dart
//
// 이슈 #665 후속 — 원형 도안뷰어 트래킹/헤어라인 오버레이.
// 사각 도안의 가로 트래킹바·세로 헤어라인 대응 컴포넌트:
//   1) RoundTrackingArc  : 현재 라운드(R)를 두꺼운 호로 강조 + 진행 세그먼트는 더 진하게
//   2) RoundHairlineRay  : 중심에서 외곽으로 가는 방사선 (시계/반시계 회전)
//
// RoundChartPainter의 정적 헬퍼(cellHeight, radiusFor, positionFor)와 동일한
// 좌표 계산 규약을 따른다 → 같은 캔버스 위에 정확히 정렬.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/round_chart.dart';
import 'round_chart_painter.dart';

// ── 상수 ──────────────────────────────────────────────────────────────────────

/// RoundChartPainter와 동일 비율 — 내부 빈 공간(magic ring) 반지름 비율.
const double _kInnerRadiusRatio = 0.05;

/// RoundChartPainter와 동일 비율 — 외곽 반지름 비율.
const double _kTotalRadiusRatio = 0.45;

// ── 트래킹 호 ─────────────────────────────────────────────────────────────────

/// 현재 라운드를 강조하는 두꺼운 호 + 진행 세그먼트는 더 진하게 표시.
///
/// 사용 예:
/// ```dart
/// Stack([
///   RoundChartView(chart: chart, symbolPicture: cache.pictureFor),
///   Positioned.fill(
///     child: RoundTrackingArc(
///       chart: roundData,
///       currentRound: 3,
///       currentSegment: 5,
///       canvasSize: size,
///     ),
///   ),
/// ]);
/// ```
class RoundTrackingArc extends StatelessWidget {
  /// 원형 도안 데이터.
  final RoundChart chart;

  /// 현재 라운드 (1-base).
  final int currentRound;

  /// 현재 세그먼트 (0-base, -1 또는 음수면 전체 라운드 호만 표시).
  final int currentSegment;

  /// 부모(Stack/Positioned.fill) 캔버스 크기. null이면 LayoutBuilder로 자동 측정.
  final Size? canvasSize;

  /// 강조 색상 (기본: C.lv).
  final Color color;

  /// 진행 호 두께(px).
  final double strokeWidth;

  const RoundTrackingArc({
    super.key,
    required this.chart,
    required this.currentRound,
    this.currentSegment = -1,
    this.canvasSize,
    this.color = const Color(0xFF7C5CFF), // C.lv 기본값
    this.strokeWidth = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    if (canvasSize != null) {
      return IgnorePointer(
        child: CustomPaint(
          size: canvasSize!,
          painter: RoundTrackingArcPainter(
            chart: chart,
            currentRound: currentRound,
            currentSegment: currentSegment,
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      );
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return CustomPaint(
            size: size,
            painter: RoundTrackingArcPainter(
              chart: chart,
              currentRound: currentRound,
              currentSegment: currentSegment,
              color: color,
              strokeWidth: strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class RoundTrackingArcPainter extends CustomPainter {
  final RoundChart chart;
  final int currentRound;
  final int currentSegment;
  final Color color;
  final double strokeWidth;

  RoundTrackingArcPainter({
    required this.chart,
    required this.currentRound,
    required this.currentSegment,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentRound < 1 || currentRound > chart.rounds) return;

    final center = Offset(size.width / 2, size.height / 2);
    final inner = size.shortestSide * _kInnerRadiusRatio;
    final ch = RoundChartPainter.cellHeight(size, chart.rounds);
    if (ch <= 0) return;

    // 현재 라운드의 셀 중심 반지름.
    final radius = inner + (currentRound - 0.5) * ch;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final stitchCount = _stitchCountAt(chart, currentRound);
    if (stitchCount <= 0) return;

    // 시작 각도 — 라운드별 startAngleOffset(기본 -π/2 = 12시).
    final startAngle = _startOffsetAt(chart, currentRound);

    // shape별 sweep 범위.
    final fullSweep = _sweepFor(chart);
    if (fullSweep <= 0) return;

    // 1) 현재 라운드 전체 호 — 연한 강조 (진행 가이드)
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, fullSweep, false, basePaint);

    // 2) 진행한 세그먼트(0..currentSegment)는 진하게 — currentSegment >= 0 인 경우만
    if (currentSegment >= 0 && currentSegment < stitchCount) {
      final segAngle = (2 * math.pi) / stitchCount;
      final progressSweep = (currentSegment + 1) * segAngle;
      // shape sweep으로 클램프 (반원/섹터 도안일 때 넘어가지 않도록).
      final clamped = math.min(progressSweep, fullSweep);
      final progressPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth + 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, clamped, false, progressPaint);
    }

    // 3) 현재 세그먼트 위치에 작은 점 마커
    if (currentSegment >= 0 && currentSegment < stitchCount) {
      final pos = RoundChartPainter.positionFor(
        chart,
        currentRound,
        currentSegment,
        size,
      );
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(pos, strokeWidth * 0.9, dotPaint);
      // 흰색 안쪽 점 (가독성)
      final innerDot = Paint()..color = Colors.white;
      canvas.drawCircle(pos, strokeWidth * 0.35, innerDot);
    }
  }

  /// shape별 한 바퀴 sweep 범위(라디안).
  double _sweepFor(RoundChart chart) {
    switch (chart.shape) {
      case ChartShape.rect:
      case ChartShape.guidePath:
      case ChartShape.roundFull:
        return 2 * math.pi;
      case ChartShape.roundHalf:
        return math.pi;
      case ChartShape.roundSector:
        var sw = chart.sectorAngleEnd - chart.sectorAngleStart;
        if (sw <= 0) sw += 2 * math.pi;
        return sw;
    }
  }

  static int _stitchCountAt(RoundChart chart, int round) {
    final idx = round - 1;
    if (idx < 0) return 0;
    if (idx < chart.stitchCounts.length) return chart.stitchCounts[idx];
    if (chart.autoIncreasePerRound) {
      return chart.baseStitchCount * round;
    }
    return chart.baseStitchCount;
  }

  static double _startOffsetAt(RoundChart chart, int round) {
    final idx = round - 1;
    if (idx >= 0 && idx < chart.startAngleOffsets.length) {
      return chart.startAngleOffsets[idx];
    }
    return -math.pi / 2;
  }

  @override
  bool shouldRepaint(covariant RoundTrackingArcPainter old) {
    return old.chart != chart ||
        old.currentRound != currentRound ||
        old.currentSegment != currentSegment ||
        old.color != color ||
        old.strokeWidth != strokeWidth;
  }
}

// ── 회전 헤어라인 ─────────────────────────────────────────────────────────────

/// 중심에서 외곽으로 그려지는 방사선 (각도 회전형 헤어라인).
///
/// 사각 도안의 세로 헤어라인 대응. angleRadians 으로 시계/반시계 회전.
class RoundHairlineRay extends StatelessWidget {
  /// 원형 도안 데이터.
  final RoundChart chart;

  /// 현재 각도 (라디안). -π/2 = 12시 방향.
  final double angleRadians;

  /// 부모 캔버스 크기. null이면 LayoutBuilder로 자동 측정.
  final Size? canvasSize;

  /// 선 두께(px).
  final double widthPx;

  /// 선 색상 (기본: C.pkD).
  final Color color;

  /// 끝부분에 화살표 표시 여부.
  final bool showArrow;

  const RoundHairlineRay({
    super.key,
    required this.chart,
    required this.angleRadians,
    this.canvasSize,
    this.widthPx = 2.0,
    this.color = const Color(0xFFD93B7E), // C.pkD 기본값
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (canvasSize != null) {
      return IgnorePointer(
        child: CustomPaint(
          size: canvasSize!,
          painter: RoundHairlineRayPainter(
            chart: chart,
            angleRadians: angleRadians,
            widthPx: widthPx,
            color: color,
            showArrow: showArrow,
          ),
        ),
      );
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return CustomPaint(
            size: size,
            painter: RoundHairlineRayPainter(
              chart: chart,
              angleRadians: angleRadians,
              widthPx: widthPx,
              color: color,
              showArrow: showArrow,
            ),
          );
        },
      ),
    );
  }
}

class RoundHairlineRayPainter extends CustomPainter {
  final RoundChart chart;
  final double angleRadians;
  final double widthPx;
  final Color color;
  final bool showArrow;

  RoundHairlineRayPainter({
    required this.chart,
    required this.angleRadians,
    required this.widthPx,
    required this.color,
    required this.showArrow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final inner = size.shortestSide * _kInnerRadiusRatio;
    final outer = size.shortestSide * _kTotalRadiusRatio;

    // 중심에서 살짝 떨어진 곳(magic ring 바로 바깥)부터 외곽까지 그리기.
    final start = center +
        Offset(inner * math.cos(angleRadians), inner * math.sin(angleRadians));
    final end = center +
        Offset(outer * math.cos(angleRadians), outer * math.sin(angleRadians));

    // 1) 외곽 그림자 (가독성용 흰색 외곽선)
    final shadow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = widthPx + 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, shadow);

    // 2) 본선
    final paint = Paint()
      ..color = color
      ..strokeWidth = widthPx
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);

    // 3) 끝 화살표 (옵션)
    if (showArrow) {
      _drawArrow(canvas, center, end, angleRadians, paint);
    }

    // 4) 중심점 표시
    final centerDot = Paint()..color = color;
    canvas.drawCircle(center, widthPx * 1.4, centerDot);
  }

  /// 외곽 끝에 화살표 머리 그리기.
  void _drawArrow(
    Canvas canvas,
    Offset center,
    Offset tip,
    double angle,
    Paint basePaint,
  ) {
    final headLen = widthPx * 4.0;
    final headHalfWidth = widthPx * 2.2;

    // 화살촉의 양쪽 baseline (방사선과 직각인 두 점).
    final perp = angle + math.pi / 2;
    final baseCenter = tip -
        Offset(headLen * math.cos(angle), headLen * math.sin(angle));
    final left = baseCenter +
        Offset(
          headHalfWidth * math.cos(perp),
          headHalfWidth * math.sin(perp),
        );
    final right = baseCenter -
        Offset(
          headHalfWidth * math.cos(perp),
          headHalfWidth * math.sin(perp),
        );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant RoundHairlineRayPainter old) {
    return old.chart != chart ||
        old.angleRadians != angleRadians ||
        old.widthPx != widthPx ||
        old.color != color ||
        old.showArrow != showArrow;
  }
}
