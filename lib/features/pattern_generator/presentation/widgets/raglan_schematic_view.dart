// lib/features/pattern_generator/presentation/widgets/raglan_schematic_view.dart
//
// 이슈 #664 Phase 4 — 래글런 도안 결과 시각화 도식 위젯.
//
// RaglanGeneratedPattern 의 치수+게이지+계산결과를 받아서
// 앞면/뒷면 사다리꼴 + 사선 래글런 + 펼친 소매를 한눈에 보여주는 SVG 스타일 도식.
//
// 컬러 채색: 사용자 yarnColor (반투명 fill).
// 외곽선: 진한 색.
// 치수 라벨: 가슴/총장/소매길이/목둘레.
// 고무단 영역: 점선 패턴 (목/몸통/소매).

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/raglan_generated_pattern.dart';

/// 래글런 도안 도식 뷰.
///
/// 사용 예:
/// ```dart
/// RaglanSchematicView(
///   pattern: generatedPattern,
///   yarnColor: const Color(0xFF8B7AB8),
///   showLabels: true,
/// )
/// ```
class RaglanSchematicView extends StatelessWidget {
  /// 생성된 래글런 도안 결과.
  final RaglanGeneratedPattern pattern;

  /// 옷 채색용 실 색상 (반투명 fill 처리).
  final Color yarnColor;

  /// 치수 라벨 표시 여부.
  final bool showLabels;

  const RaglanSchematicView({
    super.key,
    required this.pattern,
    this.yarnColor = const Color(0xFF8B7AB8),
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 가용 너비 활용. 비례를 위해 height = width * 0.62 정도.
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final h = w * 0.62;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 도식 본체
            SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  // 도식 캔버스 (앞면 + 뒷면 나란히)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RaglanSchematicPainter(
                        pattern: pattern,
                        yarnColor: yarnColor,
                        showLabels: showLabels,
                        outlineColor: C.tx,
                        labelColor: C.tx2,
                        ribLineColor: C.tx2,
                      ),
                    ),
                  ),
                  // 좌/우 캡션 (앞면 / 뒷면)
                  if (showLabels)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text('앞면', style: T.captionBold),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text('뒷면', style: T.captionBold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 치수 요약 (실측 결과 기반)
            if (showLabels) ...[
              const SizedBox(height: 12),
              _MeasurementLegend(pattern: pattern),
            ],
          ],
        );
      },
    );
  }
}

/// 도식 하단 치수 요약 범례 — 입력값 + 계산 결과를 한 줄씩.
class _MeasurementLegend extends StatelessWidget {
  final RaglanGeneratedPattern pattern;
  const _MeasurementLegend({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final m = pattern.measurements;
    final ease = pattern.ease;
    final actualChest = pattern.actualChestCm.toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.lv.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _LegendItem(label: '가슴', value: '$actualChest cm (+${ease.chestEaseCm.toStringAsFixed(1)})'),
          _LegendItem(label: '총장', value: '${m.bodyLengthCm.toStringAsFixed(1)} cm'),
          _LegendItem(label: '소매', value: '${m.sleeveLengthCm.toStringAsFixed(1)} cm'),
          _LegendItem(label: '목', value: '${m.neckCm.toStringAsFixed(1)} cm'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final String value;
  const _LegendItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: T.caption),
        Text(value, style: T.captionBold.copyWith(color: C.lvD)),
      ],
    );
  }
}

/// 래글런 도식 페인터 — 앞면/뒷면 모두 그림.
class _RaglanSchematicPainter extends CustomPainter {
  final RaglanGeneratedPattern pattern;
  final Color yarnColor;
  final bool showLabels;
  final Color outlineColor;
  final Color labelColor;
  final Color ribLineColor;

  _RaglanSchematicPainter({
    required this.pattern,
    required this.yarnColor,
    required this.showLabels,
    required this.outlineColor,
    required this.labelColor,
    required this.ribLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 캔버스 분할: 좌측 절반 = 앞면, 우측 절반 = 뒷면 ───────────
    // 하단에 캡션(앞면/뒷면) 자리를 18px 비워둠.
    const captionReserve = 18.0;
    final drawHeight = (size.height - captionReserve).clamp(40.0, size.height);
    final halfWidth = size.width / 2;

    final frontRect = Rect.fromLTWH(0, 0, halfWidth, drawHeight);
    final backRect = Rect.fromLTWH(halfWidth, 0, halfWidth, drawHeight);

    _drawPiece(canvas, frontRect, isFront: true);
    _drawPiece(canvas, backRect, isFront: false);
  }

  /// 한 면(앞 또는 뒤)을 그린다.
  void _drawPiece(Canvas canvas, Rect area, {required bool isFront}) {
    // ── 1. 비례 계산 ─────────────────────────────────────────────
    // 입력 치수 (cm 단위).
    final m = pattern.measurements;
    final chestWithEase = m.chestCm + pattern.ease.chestEaseCm;
    final bodyLen = m.bodyLengthCm;
    final sleeveLen = m.sleeveLengthCm;
    final upperArm = m.effectiveUpperArmCm + pattern.ease.upperArmEaseCm;
    final neckW = m.neckCm + pattern.ease.neckEaseCm;
    final armholeDepth = m.effectiveArmholeDepthCm;
    // 고무단 cm (목 6, 몸통 7, 소매 7) — 도식에서 점선 표시용.
    const ribNeckCm = 6.0;
    const ribBodyCm = 7.0;
    const ribSleeveCm = 7.0;

    // 도식 폭 = 가슴 폭 + 양쪽 소매 길이 (펼친 상태).
    // 실제 옷의 가슴 폭은 둘레의 절반 = chestWithEase / 2.
    final bodyHalfWidth = chestWithEase / 2;
    final totalCmWidth = bodyHalfWidth + sleeveLen * 2; // 좌소매 + 몸통 + 우소매
    final totalCmHeight = bodyLen;

    // 캔버스에 비례로 맞추기 (여백 14% 제외).
    final padding = math.min(area.width, area.height) * 0.08;
    final innerW = area.width - padding * 2;
    final innerH = area.height - padding * 2;
    final scale = math.min(innerW / totalCmWidth, innerH / totalCmHeight);

    // 실제 픽셀 폭/높이.
    final pxBodyHalfW = bodyHalfWidth * scale;
    final pxBodyLen = bodyLen * scale;
    final pxSleeveLen = sleeveLen * scale;
    // upperArm 은 손목 폭 산정에 간접적으로 사용 (effectiveWristCm 가 상완 비율).
    final _ = upperArm; // 비례 검증용 — 직접 사용은 안하지만 의도 표시.
    final pxNeckHalf = (neckW / 2) * scale;
    final pxArmholeDepth = armholeDepth * scale;
    final pxRibNeck = ribNeckCm * scale;
    final pxRibBody = ribBodyCm * scale;
    final pxRibSleeve = ribSleeveCm * scale;

    // 손목 폭(상완 → 손목 좁아짐).
    final wristW =
        (m.effectiveWristCm + pattern.ease.upperArmEaseCm * 0.4) * scale;

    // ── 2. 좌표 정의 ─────────────────────────────────────────────
    // 가운데 정렬. 옷 윗변(목) 기준.
    final centerX = area.left + area.width / 2;
    final topY = area.top + padding + 6; // 위에 약간 여백 (라벨 자리)
    final botY = topY + pxBodyLen;

    // 몸통 좌/우 외곽선 X.
    final bodyLeftX = centerX - pxBodyHalfW;
    final bodyRightX = centerX + pxBodyHalfW;

    // 목둘레 좌/우 X (윗변 중앙).
    final neckLeftX = centerX - pxNeckHalf;
    final neckRightX = centerX + pxNeckHalf;

    // 겨드랑이 Y (목 아래로 armholeDepth 만큼 내려옴).
    final armpitY = topY + pxArmholeDepth;

    // 소매 끝(손목) — 옷 양쪽으로 펼친다.
    // 소매는 어깨(목 코너)에서 시작 → 사선으로 겨드랑이 → 거기서 옆으로 펼쳐진 사다리꼴.
    // 단순화: 어깨선과 직각으로 옆으로 뻗는다고 가정.
    final sleeveTopY = topY + (pxArmholeDepth * 0.15); // 어깨 위쪽
    final sleeveBotY = armpitY;

    // 좌측 소매 (몸통 왼쪽으로 펼침).
    final leftSleeveTipTop = bodyLeftX - pxSleeveLen;
    final leftSleeveTipBot = leftSleeveTipTop;
    final leftSleeveTipMidY = (sleeveTopY + sleeveBotY) / 2;

    // 우측 소매.
    final rightSleeveTipTop = bodyRightX + pxSleeveLen;
    final rightSleeveTipBot = rightSleeveTipTop;
    final rightSleeveTipMidY = (sleeveTopY + sleeveBotY) / 2;

    // 손목 폭의 절반 — 사다리꼴 좁아지는 정도.
    final wristHalf = wristW / 2;

    // ── 3. 페인트 정의 ───────────────────────────────────────────
    final fillPaint = Paint()
      ..color = yarnColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    final raglanPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ribPaint = Paint()
      ..color = ribLineColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // ── 4. 옷 외곽 경로 (몸통 + 양쪽 소매 통합) ──────────────────
    final bodyPath = Path();

    // 시작: 좌측 목 위.
    bodyPath.moveTo(neckLeftX, topY);
    // 좌측 어깨 (목에서 살짝 내려와 어깨선) — 사선 래글런 시작점.
    // 어깨 코너 = 좌측 몸통 외곽선 위쪽 + 약간 위로.
    final leftShoulderX = bodyLeftX;
    final leftShoulderY = sleeveTopY;
    bodyPath.lineTo(leftShoulderX, leftShoulderY);
    // 좌측 소매 윗변 → 손목.
    bodyPath.lineTo(leftSleeveTipTop, leftSleeveTipMidY - wristHalf);
    // 손목 (좌).
    bodyPath.lineTo(leftSleeveTipBot, leftSleeveTipMidY + wristHalf);
    // 좌측 소매 아래변 → 겨드랑이.
    bodyPath.lineTo(bodyLeftX, armpitY);
    // 좌측 몸통 외곽선 → 밑단.
    bodyPath.lineTo(bodyLeftX, botY);
    // 밑단 (왼 → 오).
    bodyPath.lineTo(bodyRightX, botY);
    // 우측 몸통 외곽선 → 겨드랑이.
    bodyPath.lineTo(bodyRightX, armpitY);
    // 우측 소매 아래변 → 손목.
    bodyPath.lineTo(rightSleeveTipBot, rightSleeveTipMidY + wristHalf);
    // 손목 (우).
    bodyPath.lineTo(rightSleeveTipTop, rightSleeveTipMidY - wristHalf);
    // 우측 소매 윗변 → 어깨.
    final rightShoulderX = bodyRightX;
    final rightShoulderY = sleeveTopY;
    bodyPath.lineTo(rightShoulderX, rightShoulderY);
    // 우측 어깨 → 우측 목.
    bodyPath.lineTo(neckRightX, topY);
    // 목둘레 윗변 — 앞면은 살짝 곡선(앞목 쉐이핑), 뒷면은 직선.
    if (isFront) {
      // 앞목 곡선 (위로 약간 들어감).
      final neckMidX = centerX;
      final neckDipY = topY + (pxNeckHalf * 0.35); // 곡선 깊이
      bodyPath.quadraticBezierTo(neckMidX, neckDipY, neckLeftX, topY);
    } else {
      // 뒷목 직선.
      bodyPath.lineTo(neckLeftX, topY);
    }
    bodyPath.close();

    // 채색 + 외곽선.
    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(bodyPath, outlinePaint);

    // ── 5. 사선 래글런 라인 (목 코너 → 겨드랑이) ─────────────────
    // 좌측 래글런.
    canvas.drawLine(
      Offset(neckLeftX, topY),
      Offset(bodyLeftX, armpitY),
      raglanPaint,
    );
    // 우측 래글런.
    canvas.drawLine(
      Offset(neckRightX, topY),
      Offset(bodyRightX, armpitY),
      raglanPaint,
    );

    // ── 6. 고무단 점선 (목 / 몸통 / 소매) ────────────────────────
    // 6-1. 목 고무단 — 목둘레에서 아래로 ribNeck 만큼.
    _drawDashedLine(
      canvas,
      Offset(neckLeftX + 2, topY + pxRibNeck),
      Offset(neckRightX - 2, topY + pxRibNeck),
      ribPaint,
    );
    // 6-2. 몸통 고무단 — 밑단에서 위로 ribBody 만큼.
    _drawDashedLine(
      canvas,
      Offset(bodyLeftX + 2, botY - pxRibBody),
      Offset(bodyRightX - 2, botY - pxRibBody),
      ribPaint,
    );
    // 6-3. 소매 고무단 — 손목에서 안쪽으로 ribSleeve 만큼.
    final leftRibX = leftSleeveTipBot + pxRibSleeve;
    if (leftRibX < bodyLeftX) {
      _drawDashedLine(
        canvas,
        Offset(leftRibX, leftSleeveTipMidY - wristHalf + 2),
        Offset(leftRibX, leftSleeveTipMidY + wristHalf - 2),
        ribPaint,
      );
    }
    final rightRibX = rightSleeveTipBot - pxRibSleeve;
    if (rightRibX > bodyRightX) {
      _drawDashedLine(
        canvas,
        Offset(rightRibX, rightSleeveTipMidY - wristHalf + 2),
        Offset(rightRibX, rightSleeveTipMidY + wristHalf - 2),
        ribPaint,
      );
    }

    // ── 7. 치수 라벨 ─────────────────────────────────────────────
    if (showLabels) {
      // 목둘레 — 윗변 중앙 위.
      _drawLabel(
        canvas,
        '${pattern.measurements.neckCm.toStringAsFixed(0)}cm',
        Offset(centerX, topY - 4),
        align: TextAlign.center,
        anchor: _LabelAnchor.bottomCenter,
      );

      // 가슴 — 겨드랑이 라인 옆.
      _drawLabel(
        canvas,
        '${pattern.actualChestCm.toStringAsFixed(0)}cm',
        Offset((bodyLeftX + bodyRightX) / 2, armpitY + 8),
        align: TextAlign.center,
        anchor: _LabelAnchor.topCenter,
      );

      // 총장 — 우측 몸통 옆에 (약간 안쪽).
      _drawLabel(
        canvas,
        '${pattern.measurements.bodyLengthCm.toStringAsFixed(0)}cm',
        Offset(bodyRightX - 4, (armpitY + botY) / 2),
        align: TextAlign.right,
        anchor: _LabelAnchor.middleRight,
      );

      // 소매길이 — 우측 소매 위.
      _drawLabel(
        canvas,
        '${pattern.measurements.sleeveLengthCm.toStringAsFixed(0)}cm',
        Offset((bodyRightX + rightSleeveTipBot) / 2,
            rightSleeveTipMidY - wristHalf - 4),
        align: TextAlign.center,
        anchor: _LabelAnchor.bottomCenter,
      );
    }
  }

  /// 점선 그리기 헬퍼.
  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 4,
    double gap = 3,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 0.5) return;
    final dirX = dx / dist;
    final dirY = dy / dist;
    double drawn = 0;
    while (drawn < dist) {
      final segEnd = math.min(drawn + dashWidth, dist);
      canvas.drawLine(
        Offset(start.dx + dirX * drawn, start.dy + dirY * drawn),
        Offset(start.dx + dirX * segEnd, start.dy + dirY * segEnd),
        paint,
      );
      drawn = segEnd + gap;
    }
  }

  /// 텍스트 라벨 그리기.
  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position, {
    TextAlign align = TextAlign.center,
    _LabelAnchor anchor = _LabelAnchor.middleCenter,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: labelColor,
          fontFamilyFallback: T.fallbackFonts,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final dx = switch (anchor) {
      _LabelAnchor.topLeft ||
      _LabelAnchor.middleLeft ||
      _LabelAnchor.bottomLeft =>
        position.dx,
      _LabelAnchor.topCenter ||
      _LabelAnchor.middleCenter ||
      _LabelAnchor.bottomCenter =>
        position.dx - tp.width / 2,
      _LabelAnchor.topRight ||
      _LabelAnchor.middleRight ||
      _LabelAnchor.bottomRight =>
        position.dx - tp.width,
    };
    final dy = switch (anchor) {
      _LabelAnchor.topLeft ||
      _LabelAnchor.topCenter ||
      _LabelAnchor.topRight =>
        position.dy,
      _LabelAnchor.middleLeft ||
      _LabelAnchor.middleCenter ||
      _LabelAnchor.middleRight =>
        position.dy - tp.height / 2,
      _LabelAnchor.bottomLeft ||
      _LabelAnchor.bottomCenter ||
      _LabelAnchor.bottomRight =>
        position.dy - tp.height,
    };
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RaglanSchematicPainter old) {
    return old.pattern != pattern ||
        old.yarnColor != yarnColor ||
        old.showLabels != showLabels;
  }
}

enum _LabelAnchor {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleCenter,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}
