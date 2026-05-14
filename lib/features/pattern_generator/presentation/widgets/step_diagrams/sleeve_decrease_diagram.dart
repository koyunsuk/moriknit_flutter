// lib/features/pattern_generator/presentation/widgets/step_diagrams/sleeve_decrease_diagram.dart
//
// 이슈 #664 Phase 6 — 단계 11: 소매 코줄임 도식.
// 사다리꼴(위 넓고 아래 좁음) + 양옆 코줄임 위치 마커.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 소매 코줄임 도식.
/// 사다리꼴 모양 소매 + 양옆 코줄임 위치 마커 + "X회 (Y단마다)" 라벨.
class SleeveDecreaseDiagram extends StatelessWidget {
  /// 코줄임 횟수.
  final int decreaseCount;

  /// 코줄임 간격(단수).
  final int intervalRows;

  const SleeveDecreaseDiagram({
    super.key,
    required this.decreaseCount,
    required this.intervalRows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text('소매 코줄임', style: T.bodyBold),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SleeveDecreasePainter(
                decreaseCount: decreaseCount,
                outline: C.tx,
                sleeveColor: C.lv,
                markerColor: C.og,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$decreaseCount 회 코줄임 · $intervalRows 단마다',
            style: T.caption,
          ),
        ],
      ),
    );
  }
}

class _SleeveDecreasePainter extends CustomPainter {
  final int decreaseCount;
  final Color outline;
  final Color sleeveColor;
  final Color markerColor;

  _SleeveDecreasePainter({
    required this.decreaseCount,
    required this.outline,
    required this.sleeveColor,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final topInset = w * 0.08;
    final bottomInset = w * 0.30;

    // 사다리꼴 (위가 넓음, 아래가 좁음 = 코줄임)
    final sleevePaint = Paint()
      ..color = sleeveColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final sleeveBorder = Paint()
      ..color = sleeveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final path = Path()
      ..moveTo(topInset, 6)
      ..lineTo(w - topInset, 6)
      ..lineTo(w - bottomInset, h - 6)
      ..lineTo(bottomInset, h - 6)
      ..close();
    canvas.drawPath(path, sleevePaint);
    canvas.drawPath(path, sleeveBorder);

    // 양옆 코줄임 마커 (decreaseCount만큼, 최대 8개 시각화)
    final visible = decreaseCount.clamp(1, 8);
    final markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < visible; i++) {
      // 위→아래 균등 분포 (양 끝 여백)
      final t = (i + 1) / (visible + 1);
      // 좌측 사선 위 점
      final leftStart = Offset(topInset, 6);
      final leftEnd = Offset(bottomInset, h - 6);
      final lx = leftStart.dx + (leftEnd.dx - leftStart.dx) * t;
      final ly = leftStart.dy + (leftEnd.dy - leftStart.dy) * t;
      canvas.drawCircle(Offset(lx, ly), 3.2, markerPaint);

      // 우측 사선 위 점
      final rightStart = Offset(w - topInset, 6);
      final rightEnd = Offset(w - bottomInset, h - 6);
      final rx = rightStart.dx + (rightEnd.dx - rightStart.dx) * t;
      final ry = rightStart.dy + (rightEnd.dy - rightStart.dy) * t;
      canvas.drawCircle(Offset(rx, ry), 3.2, markerPaint);
    }

    // 가운데 화살표 (위→아래 방향 = 코줄임 진행 방향)
    final arrowPaint = Paint()
      ..color = outline.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final cx = w / 2;
    canvas.drawLine(Offset(cx, 12), Offset(cx, h - 16), arrowPaint);
    final tip = Path()
      ..moveTo(cx, h - 8)
      ..lineTo(cx - 4, h - 14)
      ..lineTo(cx + 4, h - 14)
      ..close();
    canvas.drawPath(
      tip,
      Paint()..color = outline.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _SleeveDecreasePainter old) =>
      old.decreaseCount != decreaseCount ||
      old.outline != outline ||
      old.sleeveColor != sleeveColor ||
      old.markerColor != markerColor;
}
