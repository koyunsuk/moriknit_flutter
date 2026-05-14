// lib/features/pattern_generator/domain/raglan_generated_pattern.dart
//
// 이슈 #638 — 도안 생성 결과 스펙.

import 'body_measurement.dart';

/// 래글런 도안 생성 결과.
/// 사용자 치수 + 게이지로 계산된 완성형 스펙.
class RaglanGeneratedPattern {
  /// 원본 입력.
  final BodyMeasurement measurements;
  final UserGauge gauge;
  final EaseSettings ease;

  // ── 목둘레 ────────────────────────────────
  /// 목둘레 총 코잡기.
  final int neckCastOn;

  /// 구간별 초기 코수 (레글런 코 2×4=8 별도).
  final int initFront;
  final int initBackEach;
  final int initSleeveEach;
  final int raglanStitches; // 2 × 4 = 8

  // ── 래글런 늘림 ───────────────────────────
  /// 래글런 늘림 반복 횟수 (N).
  final int raglanRepeat;

  /// 앞목 쉐이핑 단수 (기본 11단).
  final int frontNeckShapingRows;

  /// 가슴 짧은단 보정 (옵션 C — 인형/소형 사이즈에서 N=상완 기준일 때).
  /// 0이면 보정 불필요. 양수면 추가 짧은단 단수.
  final int chestShortRows;

  /// 가슴 부족분 (코) — 짧은단으로 채워야 할 양 (검증·표시용).
  final int chestDeficitStitches;

  /// 분리 직후 한쪽 소매에서 즉시 줄여야 할 코수 (옵션 B — 성인 사이즈에서 가슴 기준 N → 소매 과대).
  /// 0이면 보정 불필요.
  final int sleeveAdjustDecrease;

  // ── 소매 분리 시점 ────────────────────────
  /// 소매 분리 후 최종 구간별 코수.
  final int finalFront;
  final int finalBackEach;
  final int finalSleeveEach;

  /// 겨드랑이 감아코 (양쪽 각).
  final int underarmCastOn;

  // ── 몸통 ──────────────────────────────────
  /// 몸통 총 코수 (소매 분리 + 감아코 후).
  final int bodyTotalStitches;

  /// 몸통 메리야스 단수 (소매 분리 ~ 고무단 전).
  final int bodyRows;

  /// 몸통 고무단 단수.
  final int bodyRibRows;

  // ── 소매 ──────────────────────────────────
  /// 소매 총 코수 (쉬어둔 코 + 겨드랑이 줍기).
  final int sleeveTotalStitches;

  /// 소매 메리야스 단수 (분리~고무단 전).
  final int sleeveRows;

  /// 소매 고무단 단수.
  final int sleeveRibRows;

  /// 소매 코줄임 횟수.
  final int sleeveDecreaseCount;

  /// 소매 코줄임 간격 (단수).
  final int sleeveDecreaseIntervalRows;

  // ── 경고 ──────────────────────────────────
  /// 생성 중 발견된 경고 (사용자에게 표시).
  final List<String> warnings;

  const RaglanGeneratedPattern({
    required this.measurements,
    required this.gauge,
    required this.ease,
    required this.neckCastOn,
    required this.initFront,
    required this.initBackEach,
    required this.initSleeveEach,
    required this.raglanStitches,
    required this.raglanRepeat,
    required this.frontNeckShapingRows,
    this.chestShortRows = 0,
    this.chestDeficitStitches = 0,
    this.sleeveAdjustDecrease = 0,
    required this.finalFront,
    required this.finalBackEach,
    required this.finalSleeveEach,
    required this.underarmCastOn,
    required this.bodyTotalStitches,
    required this.bodyRows,
    required this.bodyRibRows,
    required this.sleeveTotalStitches,
    required this.sleeveRows,
    required this.sleeveRibRows,
    required this.sleeveDecreaseCount,
    required this.sleeveDecreaseIntervalRows,
    this.warnings = const [],
  });

  /// 실제 몸통 가슴 둘레 (cm) — 검증용.
  double get actualChestCm =>
      bodyTotalStitches * 10 / gauge.stitchesPer10cm;

  /// 실제 상완 둘레 (cm) — 한쪽 소매 한 바퀴 코수 / 게이지.
  /// (사용자 정정 #2 — 한쪽 소매 = finalSleeveEach + 라글런 2 흡수 + 감아코 1쪽)
  double get actualUpperArmCm =>
      (finalSleeveEach + 2 + underarmCastOn) * 10 / gauge.stitchesPer10cm;

  /// 결과를 서술형 도안 12단계로 변환 (프로젝트 단계로그 생성용).
  List<String> toNarrativeSteps({bool isKorean = true}) {
    return [
      // 1. 목둘레 코잡기
      isKorean
          ? '3.5mm 대바늘(또는 한 단계 가는 바늘)로 총 $neckCastOn 코 원형 코잡기. 시작 마커 설치.'
          : 'Cast on $neckCastOn stitches in the round. Place BOR marker.',
      // 2. 목 고무단
      isKorean
          ? '1코 고무뜨기로 ${gauge.rowsFromCm(6)}단 (6cm). 겹단 처리.'
          : '1×1 rib for ${gauge.rowsFromCm(6)} rows (6cm). Fold hem.',
      // 3. 셋업단 + 앞목 쉐이핑
      isKorean
          ? '셋업단: 마커 9개 배치 (뒷판 $initBackEach / 레글런 2 / 소매 $initSleeveEach / 레글런 2 / 앞판 $initFront / 레글런 2 / 소매 $initSleeveEach / 레글런 2 / 뒷판 $initBackEach). 독일식 짧은단 턴 포함 앞목 쉐이핑 $frontNeckShapingRows단.'
          : 'Setup round: place 9 markers. Front-neck shaping with German short rows for $frontNeckShapingRows rows.',
      // 4. 래글런 늘림 반복
      isKorean
          ? '래글런 늘림 세트 (1단 +8코 / 2단 유지): 총 $raglanRepeat회 반복.'
          : 'Raglan increase set (+8 stitches per set): repeat $raglanRepeat times.',
      // 5. 레글런 후 콧수 확인
      isKorean
          ? '레글런 끝 콧수 확인: 앞판 $finalFront / 뒷판 각 $finalBackEach / 소매 각 $finalSleeveEach / 레글런 8.'
          : 'After raglan: front $finalFront / back each $finalBackEach / sleeve each $finalSleeveEach / raglan 8.',
      // 6. 소매 분리
      isKorean
          ? '소매 분리: 소매 $finalSleeveEach 코를 자투리 실로 옮김 + 겨드랑이 감아코 $underarmCastOn 코 × 2. 몸통 총 $bodyTotalStitches 코.'
          : 'Separate sleeves: rest $finalSleeveEach sts on waste yarn + cast on $underarmCastOn underarm sts × 2. Body total $bodyTotalStitches sts.',
      // 7. 몸통 메리야스
      isKorean
          ? '원통 메리야스 $bodyRows단 (약 ${(bodyRows * 10 / gauge.rowsPer10cm).toStringAsFixed(1)}cm).'
          : 'Stockinette for $bodyRows rows.',
      // 8. 몸통 고무단
      isKorean
          ? '3.5mm로 교체 후 1코 고무뜨기 $bodyRibRows단 (7cm).'
          : 'Switch to smaller needle, 1×1 rib for $bodyRibRows rows (7cm).',
      // 9. 몸통 마무리
      isKorean
          ? '돗바늘 코막음으로 몸통 마무리.'
          : 'Sewn bind-off for body.',
      // 10. 소매 시작
      isKorean
          ? '쉬어둔 소매 $finalSleeveEach 코 + 겨드랑이에서 $underarmCastOn 코 줍기 = 총 $sleeveTotalStitches 코.'
          : 'Pick up sleeve $finalSleeveEach sts + $underarmCastOn from underarm = total $sleeveTotalStitches sts.',
      // 11. 소매 뜨기 + 코줄임
      isKorean
          ? '원통 메리야스 + $sleeveDecreaseIntervalRows단마다 k2tog/ssk 코줄임 $sleeveDecreaseCount회. 총 $sleeveRows단.'
          : 'Stockinette in the round + k2tog/ssk decrease every $sleeveDecreaseIntervalRows rows × $sleeveDecreaseCount. Total $sleeveRows rows.',
      // 12. 소매 마무리
      isKorean
          ? '3.5mm 1코 고무뜨기 $sleeveRibRows단 + 돗바늘 마무리. 꼬리실 정리 + 겨드랑이 봉합.'
          : 'Rib $sleeveRibRows rows + sewn bind-off. Weave in ends, sew underarm.',
    ];
  }
}
