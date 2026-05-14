// lib/features/pattern_generator/presentation/widgets/step_diagrams/cast_on_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 1: 원형 코잡기 도식.
// 입력 코수에 따라 원 둘레에 점(코)을 그려 시각화.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 원형 코잡기 도식.
/// 원 + N개 점(코) + "총 N코" 라벨을 그린다.
class CastOnDiagram extends StatelessWidget {
  /// 코잡기 콧수.
  final int stitchCount;

  const CastOnDiagram({super.key, required this.stitchCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('원형 코잡기', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _CastOnPainter(
                stitchCount: stitchCount,
                outline: C.tx,
                accent: C.lv,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('총 $stitchCount 코', style: T.caption),
        ],
      ),
    );
  }
}

class _CastOnPainter extends CustomPainter {
  final int stitchCount;
  final Color outline;
  final Color accent;

  _CastOnPainter({
    required this.stitchCount,
    required this.outline,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // 원 둘레 그리기
    final circlePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // 코(점) 그리기 — 너무 많으면 시각적 표현용으로 최대 48개로 제한
    final visibleCount = stitchCount.clamp(1, 48);
    final dotPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    for (int i = 0; i < visibleCount; i++) {
      final angle = (i / visibleCount) * 2 * math.pi - math.pi / 2;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 2.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CastOnPainter oldDelegate) =>
      oldDelegate.stitchCount != stitchCount ||
      oldDelegate.outline != outline ||
      oldDelegate.accent != accent;
}
