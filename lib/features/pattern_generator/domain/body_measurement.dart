// lib/features/pattern_generator/domain/body_measurement.dart
//
// 이슈 #638 — 치수+게이지 기반 래글런 도안 자동 생성기 (상용화 핵심).
//
// 사용자 입력 치수 (cm). 인형/성인/아동 모두 지원.

/// 도안 생성에 필요한 인체 치수 (cm 단위).
class BodyMeasurement {
  /// 가슴 둘레 (필수) — 래글런의 가장 중요한 기준.
  final double chestCm;

  /// 목 둘레 (필수) — 코잡기 기준.
  final double neckCm;

  /// 옷 길이 (필수) — 목 밑 ~ 밑단.
  final double bodyLengthCm;

  /// 소매 길이 (필수) — 어깨 ~ 손목.
  final double sleeveLengthCm;

  /// 상완 둘레 (선택) — 소매 둘레 여유 확인용. null이면 가슴 비율로 추정.
  final double? upperArmCm;

  /// 손목 둘레 (선택) — 소매 코줄임 목표. null이면 상완의 60% 추정.
  final double? wristCm;

  /// 어깨 폭 (선택) — 래글런에서는 직접 쓰이지 않으나 참고용.
  final double? shoulderCm;

  /// 겨드랑이 깊이 (선택) — null이면 가슴 비율 추정.
  final double? armholeDepthCm;

  const BodyMeasurement({
    required this.chestCm,
    required this.neckCm,
    required this.bodyLengthCm,
    required this.sleeveLengthCm,
    this.upperArmCm,
    this.wristCm,
    this.shoulderCm,
    this.armholeDepthCm,
  });

  /// 상완 둘레 추정 (직접 입력 없을 때).
  /// 성인 표준: 상완 ≈ 가슴 × 0.32. 인형/아동도 비슷한 비율.
  double get effectiveUpperArmCm => upperArmCm ?? chestCm * 0.32;

  /// 손목 둘레 추정.
  double get effectiveWristCm => wristCm ?? effectiveUpperArmCm * 0.6;

  /// 겨드랑이 깊이 추정 — 가슴 둘레의 약 17%.
  double get effectiveArmholeDepthCm =>
      armholeDepthCm ?? chestCm * 0.17;

  /// 입력 치수가 **논리적으로** 성립하는지만 검사.
  /// 사용자를 막지 않는다 — 실제 수치 문제는 `RaglanPatternGenerator`가
  /// 자동 보정 + 경고로 감당한다. 예외적으로 말이 안 되는 경우만 거절.
  String? validate() {
    if (chestCm < 1) return 'chestCm must be >= 1cm';
    if (neckCm < 1) return 'neckCm must be >= 1cm';
    if (bodyLengthCm < 1) return 'bodyLengthCm must be >= 1cm';
    if (sleeveLengthCm < 0.5) return 'sleeveLengthCm must be >= 0.5cm';
    if (chestCm <= neckCm) return 'chestCm must be greater than neckCm';
    return null;
  }
}

/// 사용자 게이지 — 10cm 단위.
class UserGauge {
  /// 10cm 당 코수 (메리야스뜨기 기준).
  final double stitchesPer10cm;

  /// 10cm 당 단수.
  final double rowsPer10cm;

  const UserGauge({
    required this.stitchesPer10cm,
    required this.rowsPer10cm,
  });

  /// cm → 코수.
  int stitchesFromCm(double cm) => (cm * stitchesPer10cm / 10).round();

  /// cm → 단수.
  int rowsFromCm(double cm) => (cm * rowsPer10cm / 10).round();

  /// 2의 배수로 올림 (원통 뜨개 + 고무단 대응).
  int roundToEven(int n) => n.isEven ? n : n + 1;
}

/// 여유분 (ease) — 의복 여유.
/// 일반 스웨터: +2~6cm (가슴 기준). 인형용: +0.5~2cm.
/// 음수 = slim fit.
class EaseSettings {
  /// 가슴 여유 (cm).
  final double chestEaseCm;

  /// 상완 여유 (cm).
  final double upperArmEaseCm;

  /// 목 여유 (cm).
  final double neckEaseCm;

  const EaseSettings({
    this.chestEaseCm = 4,
    this.upperArmEaseCm = 3,
    this.neckEaseCm = 1,
  });

  /// 인형용 기본 ease (매우 작음).
  static const doll = EaseSettings(
    chestEaseCm: 1.5,
    upperArmEaseCm: 1,
    neckEaseCm: 0.5,
  );

  /// 성인 스탠다드 ease.
  static const adultStandard = EaseSettings(
    chestEaseCm: 4,
    upperArmEaseCm: 3,
    neckEaseCm: 1,
  );

  /// 슬림 핏 ease.
  static const slim = EaseSettings(
    chestEaseCm: 0,
    upperArmEaseCm: 0.5,
    neckEaseCm: 0.5,
  );

  /// 루즈 핏 ease.
  static const loose = EaseSettings(
    chestEaseCm: 8,
    upperArmEaseCm: 5,
    neckEaseCm: 2,
  );

  /// Banul 스타일 극단 오버사이즈 크롭 (+60cm 가슴 여유).
  /// 원본 Banul 메리노블렌드 DK 트위드 크롭 레글런 탑다운 재현용.
  static const oversizedCrop = EaseSettings(
    chestEaseCm: 60,
    upperArmEaseCm: 25,
    neckEaseCm: 4,
  );
}
