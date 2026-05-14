// lib/features/pattern_generator/presentation/widgets/step_diagrams/bind_off_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 9/12: 돗바늘 마무리 도식.
// 고리 + 화살표로 돗바늘 코막음 표현.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 돗바늘 마무리(코막음) 도식.
/// 코 고리 + 돗바늘 통과 화살표.
class BindOffDiagram extends StatelessWidget {
  /// 코막음 콧수.
  final int stitchCount;

  const BindOffDiagram({super.key, required this.stitchCount});

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
          Text('돗바늘 마무리', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BindOffPainter(
                outline: C.tx,
                loopColor: C.lv,
                arrowColor: C.pk,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('$stitchCount 코 마무리', style: T.caption),
        ],
      ),
    );
  }
}

class _BindOffPainter extends CustomPainter {
  final Color outline;
  final Color loopColor;
  final Color arrowColor;

  _BindOffPainter({
    required this.outline,
    required this.loopColor,
    required this.arrowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const loopCount = 8;
    final loopW = size.width / (loopCount + 2);
    final loopH = size.height * 0.45;

    final loopPaint = Paint()
      ..color = loopColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // 고리들
    for (int i = 0; i < loopCount; i++) {
      final cx = loopW * (i + 1.5);
      final rect = Rect.fromCenter(
        center: Offset(cx, cy + 8),
        width: loopW * 0.7,
        height: loopH,
      );
      canvas.drawArc(rect, 3.14, 3.14, false, loopPaint);
    }

    // 돗바늘 (긴 직선 + 끝에 바늘귀)
    final needlePaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final needleY = cy - 6;
    canvas.drawLine(
      Offset(8, needleY),
      Offset(size.width - 16, needleY),
      needlePaint,
    );

    // 바늘 끝 화살표
    final arrowFill = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill;
    final tip = Path()
      ..moveTo(size.width - 6, needleY)
      ..lineTo(size.width - 14, needleY - 4)
      ..lineTo(size.width - 14, needleY + 4)
      ..close();
    canvas.drawPath(tip, arrowFill);

    // 바늘귀 (작은 원)
    final eyePaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(12, needleY), 3, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _BindOffPainter old) =>
      old.outline != outline ||
      old.loopColor != loopColor ||
      old.arrowColor != arrowColor;
}
