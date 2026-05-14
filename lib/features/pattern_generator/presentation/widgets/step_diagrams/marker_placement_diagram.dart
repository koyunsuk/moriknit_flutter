// lib/features/pattern_generator/presentation/widgets/step_diagrams/marker_placement_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 3 (핵심): 마커 배치 도식.
// 원형 + 9구간 (뒷판½/래글런/소매/래글런/앞판/래글런/소매/래글런/뒷판½) + 마커 8개.
// 도안 책 스타일 참고.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 셋업단 마커 배치 도식 (원형 9구간).
/// 뒷판 절반 - 래글런 - 소매 - 래글런 - 앞판 - 래글런 - 소매 - 래글런 - 뒷판 절반.
class MarkerPlacementDiagram extends StatelessWidget {
  /// 총 콧수 (= front + back×2 + sleeve×2 + raglan×4).
  final int totalStitches;

  /// 앞판 콧수.
  final int frontStitches;

  /// 뒷판 한쪽 콧수 (전체의 절반).
  final int backEachStitches;

  /// 소매 한쪽 콧수.
  final int sleeveEachStitches;

  /// 래글런 콧수 (각 1개당, 보통 2).
  final int raglanStitches;

  const MarkerPlacementDiagram({
    super.key,
    required this.totalStitches,
    required this.frontStitches,
    required this.backEachStitches,
    required this.sleeveEachStitches,
    required this.raglanStitches,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('셋업단 마커 배치', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MarkerPlacementPainter(
                totalStitches: totalStitches,
                frontStitches: frontStitches,
                backEachStitches: backEachStitches,
                sleeveEachStitches: sleeveEachStitches,
                raglanStitches: raglanStitches,
                outline: C.tx,
                raglanColor: C.lv,
                markerColor: C.pk,
                muted: C.mu,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '총 $totalStitches 코 · 마커 8개',
            style: T.caption,
          ),
        ],
      ),
    );
  }
}

class _MarkerPlacementPainter extends CustomPainter {
  final int totalStitches;
  final int frontStitches;
  final int backEachStitches;
  final int sleeveEachStitches;
  final int raglanStitches;
  final Color outline;
  final Color raglanColor;
  final Color markerColor;
  final Color muted;

  _MarkerPlacementPainter({
    required this.totalStitches,
    required this.frontStitches,
    required this.backEachStitches,
    required this.sleeveEachStitches,
    required this.raglanStitches,
    required this.outline,
    required this.raglanColor,
    required this.markerColor,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 28;

    // 9구간 콧수 (셋업단 시작점이 뒷판 중앙이므로 뒷판이 절반씩 양끝에 분배)
    final segments = <_Seg>[
      _Seg('뒤', backEachStitches, muted),
      _Seg('R', raglanStitches, raglanColor),
      _Seg('소매', sleeveEachStitches, muted),
      _Seg('R', raglanStitches, raglanColor),
      _Seg('앞', frontStitches, muted),
      _Seg('R', raglanStitches, raglanColor),
      _Seg('소매', sleeveEachStitches, muted),
      _Seg('R', raglanStitches, raglanColor),
      _Seg('뒤', backEachStitches, muted),
    ];

    final total = segments.fold<int>(0, (s, e) => s + e.count);
    if (total == 0) return;

    // 원 외곽
    final outlinePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, outlinePaint);

    // 각 구간을 호로 그리기 (뒷판 절반이 양쪽 끝 → 12시 시작)
    double startAngle = -math.pi / 2; // 12시 방향
    for (final seg in segments) {
      final sweep = (seg.count / total) * 2 * math.pi;

      final segPaint = Paint()
        ..color = seg.color == raglanColor
            ? raglanColor
            : seg.color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = seg.color == raglanColor ? 6.0 : 4.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        segPaint,
      );

      // 구간 중앙 라벨
      final midAngle = startAngle + sweep / 2;
      final labelRadius = radius + 14;
      final lx = center.dx + labelRadius * math.cos(midAngle);
      final ly = center.dy + labelRadius * math.sin(midAngle);
      _drawText(canvas, seg.label, Offset(lx, ly), seg.color);

      startAngle += sweep;
    }

    // 마커 8개 그리기 (구간 경계 중 래글런 양옆)
    final markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;
    double angle = -math.pi / 2;
    for (int i = 0; i < segments.length - 1; i++) {
      angle += (segments[i].count / total) * 2 * math.pi;
      // 래글런 양옆 마커 (8개)
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 4.0, markerPaint);
    }

    // 중앙 영역 라벨
    _drawText(canvas, 'FRONT', Offset(center.dx, center.dy + 8), outline,
        size: 10, bold: true);
    _drawText(canvas, 'BACK', Offset(center.dx, center.dy - 8), outline,
        size: 10, bold: true);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double size = 9,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MarkerPlacementPainter old) =>
      old.totalStitches != totalStitches ||
      old.frontStitches != frontStitches ||
      old.backEachStitches != backEachStitches ||
      old.sleeveEachStitches != sleeveEachStitches ||
      old.raglanStitches != raglanStitches;
}

class _Seg {
  final String label;
  final int count;
  final Color color;
  const _Seg(this.label, this.count, this.color);
}
