// lib/features/pattern_generator/domain/standard_size_presets.dart
//
// 이슈 — 래글런 도안 생성 시 표준 사이즈 빠른 입력.
// 데이터 출처: 사이즈코리아 8차 인체치수조사 (KATS, 2020-2021) 평균값 + KS K 0050(여)/0051(남) 분류 기준.
// 옷길이는 표준 풀오버(신장 약 35~38%) 기준 권장값 — 사용자가 도안 종류(크롭/롱)에 따라 조정 가능.

import 'body_measurement.dart';

/// 한국인 성인 표준 사이즈 프리셋.
class StandardSizePreset {
  /// 사이즈 라벨 (예: '55 (S)', 'M (95)').
  final String label;

  /// 보조 설명 (예: '가슴 86 · 신장 160').
  final String hint;

  /// 입력 자동 채움용 치수.
  final BodyMeasurement measurement;

  const StandardSizePreset({
    required this.label,
    required this.hint,
    required this.measurement,
  });
}

/// 한국인 여성 표준 사이즈 — KS K 0050 분류.
const List<StandardSizePreset> womenStandardSizes = [
  StandardSizePreset(
    label: '44 (XS)',
    hint: '가슴82 · 신장152',
    measurement: BodyMeasurement(
      chestCm: 82,
      neckCm: 32,
      bodyLengthCm: 53,
      sleeveLengthCm: 50,
      upperArmCm: 25,
      wristCm: 14,
      shoulderCm: 36,
      armholeDepthCm: 18,
    ),
  ),
  StandardSizePreset(
    label: '55 (S)',
    hint: '가슴85 · 신장157',
    measurement: BodyMeasurement(
      chestCm: 85,
      neckCm: 33,
      bodyLengthCm: 55,
      sleeveLengthCm: 51,
      upperArmCm: 26,
      wristCm: 14.5,
      shoulderCm: 37,
      armholeDepthCm: 19,
    ),
  ),
  StandardSizePreset(
    label: '66 (M)',
    hint: '가슴88 · 신장162',
    measurement: BodyMeasurement(
      chestCm: 88,
      neckCm: 34,
      bodyLengthCm: 57,
      sleeveLengthCm: 52,
      upperArmCm: 27,
      wristCm: 15,
      shoulderCm: 38,
      armholeDepthCm: 19.5,
    ),
  ),
  StandardSizePreset(
    label: '77 (L)',
    hint: '가슴92 · 신장167',
    measurement: BodyMeasurement(
      chestCm: 92,
      neckCm: 35,
      bodyLengthCm: 59,
      sleeveLengthCm: 53,
      upperArmCm: 29,
      wristCm: 15.5,
      shoulderCm: 39,
      armholeDepthCm: 20.5,
    ),
  ),
  StandardSizePreset(
    label: '88 (XL)',
    hint: '가슴96 · 신장170',
    measurement: BodyMeasurement(
      chestCm: 96,
      neckCm: 36,
      bodyLengthCm: 61,
      sleeveLengthCm: 54,
      upperArmCm: 31,
      wristCm: 16,
      shoulderCm: 40,
      armholeDepthCm: 21.5,
    ),
  ),
];

/// 한국인 남성 표준 사이즈 — KS K 0051 분류.
const List<StandardSizePreset> menStandardSizes = [
  StandardSizePreset(
    label: '90 (S)',
    hint: '가슴90 · 신장168',
    measurement: BodyMeasurement(
      chestCm: 90,
      neckCm: 38,
      bodyLengthCm: 64,
      sleeveLengthCm: 57,
      upperArmCm: 29,
      wristCm: 16,
      shoulderCm: 41,
      armholeDepthCm: 22,
    ),
  ),
  StandardSizePreset(
    label: '95 (M)',
    hint: '가슴95 · 신장172',
    measurement: BodyMeasurement(
      chestCm: 95,
      neckCm: 39,
      bodyLengthCm: 66,
      sleeveLengthCm: 58,
      upperArmCm: 31,
      wristCm: 16.5,
      shoulderCm: 43,
      armholeDepthCm: 23,
    ),
  ),
  StandardSizePreset(
    label: '100 (L)',
    hint: '가슴100 · 신장176',
    measurement: BodyMeasurement(
      chestCm: 100,
      neckCm: 40,
      bodyLengthCm: 68,
      sleeveLengthCm: 59,
      upperArmCm: 33,
      wristCm: 17,
      shoulderCm: 44,
      armholeDepthCm: 24,
    ),
  ),
  StandardSizePreset(
    label: '105 (XL)',
    hint: '가슴105 · 신장180',
    measurement: BodyMeasurement(
      chestCm: 105,
      neckCm: 41,
      bodyLengthCm: 70,
      sleeveLengthCm: 60,
      upperArmCm: 35,
      wristCm: 17.5,
      shoulderCm: 45,
      armholeDepthCm: 25,
    ),
  ),
  StandardSizePreset(
    label: '110 (XXL)',
    hint: '가슴110 · 신장183',
    measurement: BodyMeasurement(
      chestCm: 110,
      neckCm: 42,
      bodyLengthCm: 72,
      sleeveLengthCm: 61,
      upperArmCm: 37,
      wristCm: 18,
      shoulderCm: 46,
      armholeDepthCm: 26,
    ),
  ),
];
