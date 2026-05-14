// lib/features/pattern_generator/presentation/widgets/step_diagrams/rib_pattern_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 2/8/12: 1×1 고무단 도식.
// 수직 K1P1 줄무늬 + 단수/cm 라벨.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 1×1 고무단(K1P1) 도식.
/// 수직 줄무늬 + "X단 (Ycm)" 라벨.
class RibPatternDiagram extends StatelessWidget {
  /// 고무단 단수.
  final int rows;

  /// 고무단 cm.
  final double cm;

  const RibPatternDiagram({
    super.key,
    required this.rows,
    required this.cm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('1코 고무뜨기', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _RibPainter(
                outline: C.tx,
                accent: C.lv,
                bg: C.bg,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$rows단 (${cm.toStringAsFixed(1)}cm)',
            style: T.caption,
          ),
        ],
      ),
    );
  }
}

class _RibPainter extends CustomPainter {
  final Color outline;
  final Color accent;
  final Color bg;

  _RibPainter({
    required this.outline,
    required this.accent,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 외곽 박스
    final borderPaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // K1P1 수직 줄무늬 (10줄)
    const stripeCount = 10;
    final stripeWidth = size.width / stripeCount;
    final knitPaint = Paint()..color = accent.withValues(alpha: 0.55);
    final purlPaint = Paint()..color = accent.withValues(alpha: 0.18);

    for (int i = 0; i < stripeCount; i++) {
      final paint = i.isEven ? knitPaint : purlPaint;
      canvas.drawRect(
        Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, size.height),
        paint,
      );
    }

    // 중앙 라벨용 가로선 (단수 표시 보조)
    final guidePaint = Paint()
      ..color = outline.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RibPainter oldDelegate) =>
      oldDelegate.outline != outline ||
      oldDelegate.accent != accent ||
      oldDelegate.bg != bg;
}
