// lib/features/pattern_generator/presentation/widgets/step_diagrams/sleeve_separation_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 6: 소매 분리 도식.
// 자투리실에 옮긴 소매 코 + 겨드랑이 감아코 표현.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 소매 분리 도식.
/// 몸통(원) + 양옆에 자투리실로 옮긴 소매 코 표시 + 겨드랑이 감아코 위치.
class SleeveSeparationDiagram extends StatelessWidget {
  /// 소매 한쪽에서 옮긴 코수.
  final int sleeveStitches;

  /// 겨드랑이 감아코 (양쪽 각).
  final int underarmCastOn;

  const SleeveSeparationDiagram({
    super.key,
    required this.sleeveStitches,
    required this.underarmCastOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('소매 분리 + 겨드랑이 감아코', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SleeveSeparationPainter(
                outline: C.tx,
                bodyColor: C.lv,
                wasteColor: C.mu,
                castOnColor: C.pk,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '쉬어둔 소매 $sleeveStitches 코 × 2 · 감아코 $underarmCastOn 코 × 2',
            style: T.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SleeveSeparationPainter extends CustomPainter {
  final Color outline;
  final Color bodyColor;
  final Color wasteColor;
  final Color castOnColor;

  _SleeveSeparationPainter({
    required this.outline,
    required this.bodyColor,
    required this.wasteColor,
    required this.castOnColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bodyR = size.height * 0.35;

    // 몸통 (중앙 원)
    final bodyPaint = Paint()
      ..color = bodyColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final bodyBorder = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), bodyR, bodyPaint);
    canvas.drawCircle(Offset(cx, cy), bodyR, bodyBorder);

    // 양옆 자투리실 표시 (지그재그 선 = 자투리실)
    final wastePaint = Paint()
      ..color = wasteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    void drawWasteYarn(double startX, double endX) {
      final path = Path()..moveTo(startX, cy);
      const segments = 6;
      final segLen = (endX - startX) / segments;
      for (int i = 1; i <= segments; i++) {
        final yOff = i.isEven ? -4.0 : 4.0;
        path.lineTo(startX + segLen * i, cy + yOff);
      }
      canvas.drawPath(path, wastePaint);
    }

    drawWasteYarn(8, cx - bodyR);
    drawWasteYarn(cx + bodyR, size.width - 8);

    // 겨드랑이 감아코 위치 (몸통 양옆 아치 형태)
    final castOnPaint = Paint()
      ..color = castOnColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // 좌측 감아코
    final leftArc = Path()
      ..moveTo(cx - bodyR, cy - 6)
      ..quadraticBezierTo(cx - bodyR - 8, cy, cx - bodyR, cy + 6);
    canvas.drawPath(leftArc, castOnPaint);

    // 우측 감아코
    final rightArc = Path()
      ..moveTo(cx + bodyR, cy - 6)
      ..quadraticBezierTo(cx + bodyR + 8, cy, cx + bodyR, cy + 6);
    canvas.drawPath(rightArc, castOnPaint);

    // 라벨
    _drawText(canvas, '몸통', Offset(cx, cy), outline, bold: true);
    _drawText(canvas, '소매', Offset(20, cy - 12), wasteColor);
    _drawText(canvas, '소매', Offset(size.width - 20, cy - 12), wasteColor);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SleeveSeparationPainter old) =>
      old.outline != outline ||
      old.bodyColor != bodyColor ||
      old.wasteColor != wasteColor ||
      old.castOnColor != castOnColor;
}
