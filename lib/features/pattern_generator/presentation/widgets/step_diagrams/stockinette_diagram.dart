// lib/features/pattern_generator/presentation/widgets/step_diagrams/stockinette_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 7/11: 메리야스 도식.
// 평면 메리야스(V자 코) 패턴 + 단수/cm 라벨.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 메리야스(stockinette) 도식.
/// V자 무늬 격자 + "X단 (약 Ycm)" 라벨.
class StockinetteDiagram extends StatelessWidget {
  /// 단수.
  final int rows;

  /// 약 cm.
  final double cm;

  const StockinetteDiagram({
    super.key,
    required this.rows,
    required this.cm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('메리야스', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _StockinettePainter(
                outline: C.tx,
                stitchColor: C.lv,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$rows단 (약 ${cm.toStringAsFixed(1)}cm)',
            style: T.caption,
          ),
        ],
      ),
    );
  }
}

class _StockinettePainter extends CustomPainter {
  final Color outline;
  final Color stitchColor;

  _StockinettePainter({required this.outline, required this.stitchColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 외곽 박스
    final borderPaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // V자 무늬 격자
    const cols = 12;
    const rows = 5;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final vPaint = Paint()
      ..color = stitchColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = c * cellW;
        final y = r * cellH;
        // V자: 좌상→중하, 우상→중하
        final cx = x + cellW / 2;
        final by = y + cellH * 0.85;
        canvas.drawLine(Offset(x + cellW * 0.15, y + cellH * 0.15),
            Offset(cx, by), vPaint);
        canvas.drawLine(Offset(x + cellW * 0.85, y + cellH * 0.15),
            Offset(cx, by), vPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StockinettePainter old) =>
      old.outline != outline || old.stitchColor != stitchColor;
}
