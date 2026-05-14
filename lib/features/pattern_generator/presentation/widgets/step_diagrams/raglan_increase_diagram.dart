// lib/features/pattern_generator/presentation/widgets/step_diagrams/raglan_increase_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 4: 래글런 늘림 도식.
// 사선 4개 (래글런 라인) + 양옆 화살표 (늘림) + "X회 반복" 라벨.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 래글런 늘림 도식.
/// 사다리꼴 형태로 4개 래글런 라인 + 양옆 화살표(늘림).
class RaglanIncreaseDiagram extends StatelessWidget {
  /// 래글런 늘림 반복 횟수 (N).
  final int repeatCount;

  const RaglanIncreaseDiagram({super.key, required this.repeatCount});

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
          Text('래글런 늘림', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _RaglanIncreasePainter(
                outline: C.tx,
                raglanColor: C.lv,
                arrowColor: C.pk,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('+8 코 / 세트 · $repeatCount 회 반복', style: T.caption),
        ],
      ),
    );
  }
}

class _RaglanIncreasePainter extends CustomPainter {
  final Color outline;
  final Color raglanColor;
  final Color arrowColor;

  _RaglanIncreasePainter({
    required this.outline,
    required this.raglanColor,
    required this.arrowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 사다리꼴 외곽 (위 좁고 아래 넓음 = 래글런 늘림)
    final w = size.width;
    final h = size.height;
    final topInset = w * 0.18;
    final bottomInset = 0.0;

    final outlinePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(topInset, 6)
      ..lineTo(w - topInset, 6)
      ..lineTo(w - bottomInset, h - 6)
      ..lineTo(bottomInset, h - 6)
      ..close();
    canvas.drawPath(path, outlinePaint);

    // 4개 래글런 사선 (안쪽에 4등분)
    final raglanPaint = Paint()
      ..color = raglanColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final innerW = w * 0.55;
    final innerLeft = (w - innerW) / 2;
    // 2개 외곽 사선 + 2개 내부 사선 = 4개
    final lines = [
      [Offset(topInset + 4, 8), Offset(4, h - 8)], // 좌외곽
      [Offset(w - topInset - 4, 8), Offset(w - 4, h - 8)], // 우외곽
      [Offset(innerLeft + innerW * 0.30, 8),
       Offset(innerLeft + innerW * 0.20, h - 8)], // 좌내부
      [Offset(innerLeft + innerW * 0.70, 8),
       Offset(innerLeft + innerW * 0.80, h - 8)], // 우내부
    ];
    for (final pair in lines) {
      canvas.drawLine(pair[0], pair[1], raglanPaint);
    }

    // 양옆 화살표 (늘림 표시)
    final arrowPaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final arrowFill = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill;

    // 좌 화살표 (←)
    final lArrowY = h / 2;
    canvas.drawLine(Offset(w * 0.10, lArrowY), Offset(w * 0.04, lArrowY),
        arrowPaint);
    final lTip = Path()
      ..moveTo(w * 0.04, lArrowY)
      ..lineTo(w * 0.07, lArrowY - 3)
      ..lineTo(w * 0.07, lArrowY + 3)
      ..close();
    canvas.drawPath(lTip, arrowFill);

    // 우 화살표 (→)
    canvas.drawLine(Offset(w * 0.90, lArrowY), Offset(w * 0.96, lArrowY),
        arrowPaint);
    final rTip = Path()
      ..moveTo(w * 0.96, lArrowY)
      ..lineTo(w * 0.93, lArrowY - 3)
      ..lineTo(w * 0.93, lArrowY + 3)
      ..close();
    canvas.drawPath(rTip, arrowFill);
  }

  @override
  bool shouldRepaint(covariant _RaglanIncreasePainter old) =>
      old.outline != outline ||
      old.raglanColor != raglanColor ||
      old.arrowColor != arrowColor;
}
