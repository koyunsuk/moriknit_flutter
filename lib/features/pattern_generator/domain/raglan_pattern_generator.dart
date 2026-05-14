// lib/features/pattern_generator/domain/raglan_pattern_generator.dart
//
// 이슈 #638 — 치수+게이지 기반 래글런 도안 자동 생성기 (Opus 심층 구현).
//
// 핵심 공식:
//   목 코잡기 = round(neck_cm × gauge/10), 2의 배수 + 레글런 8 확보
//   목 배분: back_each=neck×0.14, front=neck×0.30, sleeve_each=neck×0.10 (대략)
//   target_chest_stitches = (chest_cm + ease) × gauge/10 (2의 배수)
//   N = round((target_chest - init_front - 2×init_back - 2×underarm) / 4)
//       단 N ≥ 1 보장, 소매 상완 조건도 검증
//   under_arm = round(init_sleeve × 0.25), 최소 2, 짝수.
//
// Banul XS 검증:
//   neck=44cm(여유 18cm), gauge=21×29 — 인체는 작은 편
//   또는 Banul 데이터를 역으로 검증:
//     init_front=46, init_back=23(각), init_sleeve=16(각), raglan=8, 합=132
//     target_chest_stitches=316 → N=(316-46-46-8)/4=54? 실제 N=23
//   이 수식은 Banul과 정확히 일치하지 않음 — Banul은 XL+에서 추가 보정.
//   본 생성기는 "일반 래글런 단순 모델"로 근사. 복잡한 쉐이핑은 사용자 수정에 맡김.

import 'dart:math' as math;

import 'body_measurement.dart';
import 'raglan_generated_pattern.dart';

class RaglanPatternGenerator {
  final BodyMeasurement measurements;
  final UserGauge gauge;
  final EaseSettings ease;

  /// 최소 래글런 늘림 반복 (극소 사이즈 보장).
  final int minRaglanRepeat;

  const RaglanPatternGenerator({
    required this.measurements,
    required this.gauge,
    this.ease = EaseSettings.adultStandard,
    this.minRaglanRepeat = 1,
  });

  /// 메인 생성 함수.
  RaglanGeneratedPattern generate() {
    // #638 P0 — gauge 0/음수 가드 (ZeroDivisionError + NaN 방어)
    if (gauge.stitchesPer10cm <= 0 || gauge.rowsPer10cm <= 0) {
      throw ArgumentError(
        '게이지는 0보다 커야 합니다 (단/10cm: ${gauge.stitchesPer10cm}, 코/10cm: ${gauge.rowsPer10cm}).',
      );
    }

    final warnings = <String>[];

    // ── 1. 목 코잡기 ────────────────────────────
    final neckTargetCm = measurements.neckCm + ease.neckEaseCm;
    int neckCastOn = gauge.roundToEven(gauge.stitchesFromCm(neckTargetCm));

    // 레글런 구조상 최소 14코 필요 (front 2 + back 2 + sleeve 1×2 + raglan 8 = 14).
    if (neckCastOn < 14) {
      warnings.add(
          '목둘레가 너무 작아 최소 14코로 조정했습니다 (원래 $neckCastOn → 14).');
      neckCastOn = 14;
    }

    // ── 2. 목 배분 (레글런 8코 제외) ─────────────
    // 경험 비율 (Banul 도안 XS 기준 역산):
    //   front ≈ 35%, back each ≈ 17.5%, sleeve each ≈ 12%
    final remaining = neckCastOn - 8;
    int initFront = gauge.roundToEven((remaining * 0.35).round());
    int initBackEach = gauge.roundToEven((remaining * 0.175).round());
    int initSleeveEach = gauge.roundToEven(
      ((remaining - initFront - initBackEach * 2) / 2).round(),
    );

    // 최소 2 보장.
    if (initSleeveEach < 2) {
      initSleeveEach = 2;
      // front·back 재조정.
      final residual = remaining - initSleeveEach * 2;
      initFront = gauge.roundToEven((residual * 0.5).round());
      initBackEach = gauge.roundToEven(((residual - initFront) / 2).round());
    }
    if (initFront < 2) initFront = 2;
    if (initBackEach < 2) initBackEach = 2;

    // 합이 정확히 (neckCastOn - 8)이 되도록 미세 조정 (front로 보정).
    final currentSum = initFront + initBackEach * 2 + initSleeveEach * 2;
    final diff = remaining - currentSum;
    initFront += diff; // +/- 짝수 단위
    if (initFront < 2) {
      initFront = 2;
    }

    // ── 선제 방어 (2026-04-25): 극소형에서 최소치(2) 보장으로 합이 neck 초과 가능.
    // 불일치 시 neckCastOn을 실제 합으로 재설정 + 사용자 안내.
    final finalSum = initFront + initBackEach * 2 + initSleeveEach * 2 + 8;
    if (finalSum != neckCastOn) {
      warnings.add(
          '목둘레가 너무 작아 레글런 구조 최소치로 조정했습니다 '
          '($neckCastOn → $finalSum 코).');
      neckCastOn = finalSum;
    }

    // ── 3. 목표 가슴 코수 ──────────────────────
    final targetChestCm = measurements.chestCm + ease.chestEaseCm;
    final targetChestStitches =
        gauge.roundToEven(gauge.stitchesFromCm(targetChestCm));

    // ── 4. 겨드랑이 감아코 ──────────────────────
    // 초기 소매 코의 25% 정도, 최소 2, 짝수.
    int underarmCastOn = gauge.roundToEven((initSleeveEach * 0.25).round());
    if (underarmCastOn < 2) underarmCastOn = 2;

    // ── 5. 래글런 반복 N 계산 (사이즈별 분기) ──────────────────
    // 인형/소형 (옷길이 < 20cm): 옵션 C — N을 상완 기준으로 (가슴 부족분은 짧은단)
    // 성인 (옷길이 >= 20cm): 옵션 B — N을 가슴 기준으로 (소매 과대분은 분리 직후 줄임)
    final isSmallSize = measurements.bodyLengthCm < 20;
    final targetArmStitches = gauge.roundToEven(
      gauge.stitchesFromCm(measurements.effectiveUpperArmCm + ease.upperArmEaseCm),
    );
    int raglanRepeat;
    if (isSmallSize) {
      // 옵션 C: 한쪽 소매 한 바퀴 = (initSleeveEach + 2N) + 2 + underarm
      // → N = (targetArm − initSleeveEach − 2 − underarm) / 2
      final num = targetArmStitches - initSleeveEach - 2 - underarmCastOn;
      raglanRepeat = (num / 2).round();
    } else {
      // 옵션 B: 몸통 = (initFront + 2N) + 2(initBack + N) + 4 + 2×underarm
      // → N = (targetChest − initFront − 2×initBack − 4 − 2×underarm) / 4
      final num = targetChestStitches -
          initFront -
          initBackEach * 2 -
          4 -
          underarmCastOn * 2;
      raglanRepeat = (num / 4).round();
    }
    if (raglanRepeat < minRaglanRepeat) {
      warnings.add(
          '래글런 반복이 $raglanRepeat → $minRaglanRepeat로 보정 (너무 작음).');
      raglanRepeat = minRaglanRepeat;
    }

    // ── 6. 최종 구간별 코수 ──────────────────────
    final finalFront = initFront + 2 * raglanRepeat;
    final finalBackEach = initBackEach + raglanRepeat;
    final finalSleeveEach = initSleeveEach + 2 * raglanRepeat;

    // 실제 몸통 총코 (사용자 정정 — 라글런 8코는 1코씩 양옆 분배).
    // 4 라인 × 몸통쪽 1코 = 4코. 양옆 감아코 2개.
    final bodyTotalStitches =
        finalFront + finalBackEach * 2 + 4 + underarmCastOn * 2;

    // 가슴/소매 보정 — 사이즈별 분기.
    final actualChestCm = bodyTotalStitches * 10 / gauge.stitchesPer10cm;
    final chestDiff = actualChestCm - targetChestCm;
    int chestDeficitStitches = 0;
    int chestShortRows = 0;
    int sleeveAdjustDecrease = 0;

    if (isSmallSize) {
      // 인형/소형 — 가슴 부족 시 짧은단 보정.
      chestDeficitStitches =
          (targetChestStitches - bodyTotalStitches).clamp(0, 99999);
      // 짧은단 1세트(왕복 2단) = 양쪽 1코씩 = +2코
      chestShortRows = chestDeficitStitches > 0
          ? ((chestDeficitStitches / 2).ceil() * 2)
          : 0;
      if (chestDeficitStitches > 0) {
        final shortRowsCm = (chestShortRows * 10 / gauge.rowsPer10cm).toStringAsFixed(1);
        warnings.add(
            '⚠️ 가슴 ${(-chestDiff).toStringAsFixed(1)}cm 부족 — '
            '래글런 직후 짧은단 $chestShortRows단 (약 ${shortRowsCm}cm) 추가로 보정.');
      }
    } else {
      // 성인 — 소매 과대 시 분리 직후 즉시 줄임.
      final actualSleeveStitches = finalSleeveEach + 2 + underarmCastOn;
      sleeveAdjustDecrease =
          (actualSleeveStitches - targetArmStitches).clamp(0, 99999);
      if (sleeveAdjustDecrease > 0) {
        final actualArmCm = actualSleeveStitches * 10 / gauge.stitchesPer10cm;
        final targetArmCm = targetArmStitches * 10 / gauge.stitchesPer10cm;
        warnings.add(
            '⚠️ 소매 ${(actualArmCm - targetArmCm).toStringAsFixed(1)}cm 과대 — '
            '분리 직후 한쪽 소매에서 $sleeveAdjustDecrease코 즉시 줄임으로 보정.');
      }
      if (chestDiff.abs() > 1) {
        warnings.add(
            '목표 가슴 ${targetChestCm.toStringAsFixed(1)}cm vs 실제 ${actualChestCm.toStringAsFixed(1)}cm (차이 ${chestDiff.toStringAsFixed(1)}cm).');
      }
    }

    // ── 7. 소매 상완 둘레 검증 ──────────────────
    // 사용자 정정 #2 — 한쪽 소매 한 바퀴 코수 (작업 시작 시점):
    //   = finalSleeveEach (영역) + 2 (라글런 양옆 흡수) + underarmCastOn (한쪽 감아코)
    // 자투리실 분리 시는 finalSleeveEach + 2 = 10코 (감아코는 몸통 작업 후 줍기).
    final sleeveTotalStitches = finalSleeveEach + 2 + underarmCastOn;
    final actualUpperArmCm =
        sleeveTotalStitches * 10 / gauge.stitchesPer10cm;
    final targetUpperArmCm =
        measurements.effectiveUpperArmCm + ease.upperArmEaseCm;
    // #638 P0 — 인형/극소 사이즈 소매 과대 검증 (이전: 부족만 검증)
    final upperArmRatio = targetUpperArmCm > 0
        ? actualUpperArmCm / targetUpperArmCm
        : 1.0;
    if (actualUpperArmCm < targetUpperArmCm) {
      warnings.add(
          '소매 둘레 부족 — 목표 ${targetUpperArmCm.toStringAsFixed(1)}cm vs 실제 ${actualUpperArmCm.toStringAsFixed(1)}cm. 소매가 꽉 낄 수 있음.');
    } else if (upperArmRatio > 1.3) {
      // 130% 초과 시 경고 (인형 등 극소 사이즈 케이스)
      warnings.add(
          '⚠️ 소매가 과대 산출됐습니다 — 목표 ${targetUpperArmCm.toStringAsFixed(1)}cm vs 실제 ${actualUpperArmCm.toStringAsFixed(1)}cm '
          '(${(upperArmRatio * 100).toStringAsFixed(0)}%). 인형 등 극소 사이즈는 게이지/치수 재확인을 권장합니다.');
    }

    // ── 8. 몸통 단수 ────────────────────────────
    // 전체 옷길이에서 고무단(6cm 목) + 앞목 쉐이핑(약 11단) + 래글런 2 단수(2×N) 제외.
    // 인형/소형 사이즈 대응 — 옷길이가 짧으면 고무단·쉐이핑을 비례 축소.
    // (이슈 #661 — 인형 프리셋 적용 시 "몸통 메리야스 0단" 버그 보정)
    final neckRibCm = math.min(6.0, measurements.bodyLengthCm * 0.18);
    final bodyRibCm = math.min(7.0, measurements.bodyLengthCm * 0.20);
    final neckRibRows = gauge.rowsFromCm(neckRibCm);
    final bodyRibRows = gauge.rowsFromCm(bodyRibCm);
    final frontNeckShapingRows = measurements.bodyLengthCm < 20 ? 5 : 11;
    final raglan2Rows = raglanRepeat * 2;

    final totalRows = gauge.rowsFromCm(measurements.bodyLengthCm);
    final bodyRowsCalc = totalRows -
        neckRibRows -
        frontNeckShapingRows -
        raglan2Rows -
        bodyRibRows;
    // 음수/극소면 최소 5단 보장 + 경고
    final bodyRows = bodyRowsCalc < 5 ? 5 : bodyRowsCalc;
    if (bodyRowsCalc < 5) {
      warnings.add(
          '⚠️ 옷길이 ${measurements.bodyLengthCm}cm 가 짧아 몸통이 5단으로 보정됐어요. 옷길이를 늘려보세요.');
    }

    // ── 9. 소매 단수 ────────────────────────────
    // #670 — 인형/소형 사이즈 보정: 7cm 고정 고무단은 인형 소매(7~12cm)에 너무 큼.
    //         성인은 7cm 클램프 유지, 인형은 소매 길이의 20%로 비례 축소 (최소 1cm).
    final sleeveRibCm = math.min(7.0,
        math.max(1.0, measurements.sleeveLengthCm * 0.20));
    final sleeveRibRows = gauge.rowsFromCm(sleeveRibCm);
    final sleeveRows =
        gauge.rowsFromCm(measurements.sleeveLengthCm) - sleeveRibRows;

    // ── 10. 소매 코줄임 계산 ─────────────────────
    // 목표 손목 코수 = wrist_cm × gauge/10 (2의 배수, 최소 6).
    final wristStitchesTarget = gauge.roundToEven(
      gauge.stitchesFromCm(measurements.effectiveWristCm),
    );
    int sleeveDecreaseCount =
        ((sleeveTotalStitches - wristStitchesTarget) / 2).round().clamp(0, 1000);
    // #670 — 줄임 횟수가 (가용 단수 / 2)을 초과하면 자동 축소 (간격 ≥ 2단 보장).
    final maxDecreasesByRows = sleeveRows ~/ 2;
    if (sleeveDecreaseCount > maxDecreasesByRows && maxDecreasesByRows >= 0) {
      final original = sleeveDecreaseCount;
      sleeveDecreaseCount = maxDecreasesByRows;
      if (original != sleeveDecreaseCount) {
        warnings.add(
            '소매 단수가 짧아 코줄임 횟수를 $original → $sleeveDecreaseCount회로 축소했어요. '
            '실제 손목 코수가 목표($wristStitchesTarget 코)보다 클 수 있어요.');
      }
    }
    int sleeveDecreaseIntervalRows = sleeveDecreaseCount > 0
        ? (sleeveRows / sleeveDecreaseCount).floor()
        : 0;
    if (sleeveDecreaseIntervalRows < 2 && sleeveDecreaseCount > 0) {
      sleeveDecreaseIntervalRows = 2;
    }

    return RaglanGeneratedPattern(
      measurements: measurements,
      gauge: gauge,
      ease: ease,
      neckCastOn: neckCastOn,
      initFront: initFront,
      initBackEach: initBackEach,
      initSleeveEach: initSleeveEach,
      raglanStitches: 8,
      raglanRepeat: raglanRepeat,
      frontNeckShapingRows: frontNeckShapingRows,
      chestShortRows: chestShortRows,
      chestDeficitStitches: chestDeficitStitches,
      sleeveAdjustDecrease: sleeveAdjustDecrease,
      finalFront: finalFront,
      finalBackEach: finalBackEach,
      finalSleeveEach: finalSleeveEach,
      underarmCastOn: underarmCastOn,
      bodyTotalStitches: bodyTotalStitches,
      bodyRows: bodyRows < 0 ? 0 : bodyRows,
      bodyRibRows: bodyRibRows,
      sleeveTotalStitches: sleeveTotalStitches,
      sleeveRows: sleeveRows < 0 ? 0 : sleeveRows,
      sleeveRibRows: sleeveRibRows,
      sleeveDecreaseCount: sleeveDecreaseCount,
      sleeveDecreaseIntervalRows: sleeveDecreaseIntervalRows,
      warnings: warnings,
    );
  }
}
