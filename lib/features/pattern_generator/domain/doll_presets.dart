// lib/features/pattern_generator/domain/doll_presets.dart
//
// 이슈 #639 — 인형 치수 빌트인 프리셋 (Barbie · Tammy · Paola Reina).
// #638 래글런 도안 생성기의 실전 테스트 대상.

import 'body_measurement.dart';

/// 인형 프리셋 — 치수 + 권장 게이지 + 권장 ease 묶음.
class DollPreset {
  final String id;
  final String nameKo;
  final String nameEn;
  final double heightCm;
  final BodyMeasurement measurement;
  final UserGauge suggestedGauge;
  final EaseSettings suggestedEase;
  final String suggestedYarn;
  final String suggestedNeedle;
  final String descriptionKo;

  const DollPreset({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.heightCm,
    required this.measurement,
    required this.suggestedGauge,
    required this.suggestedEase,
    required this.suggestedYarn,
    required this.suggestedNeedle,
    required this.descriptionKo,
  });
}

/// Barbie (29.21cm) — 대표적인 패션 인형.
/// 출처: Barbiemedia 공식 치수 데이터.
const DollPreset barbieDoll = DollPreset(
  id: 'barbie',
  nameKo: '바비 인형',
  nameEn: 'Barbie',
  heightCm: 29.21,
  measurement: BodyMeasurement(
    chestCm: 13.46,
    neckCm: 6.0, // 추정 — 가슴의 약 45%
    bodyLengthCm: 10, // 어깨~힙 추정 (크롭 기준)
    sleeveLengthCm: 7, // 어깨~손목 추정
    upperArmCm: 4,
    wristCm: 2.5,
    shoulderCm: 6,
    armholeDepthCm: 2.5,
  ),
  suggestedGauge: UserGauge(stitchesPer10cm: 36, rowsPer10cm: 44),
  suggestedEase: EaseSettings.doll,
  suggestedYarn: '3ply 코튼 또는 아크릴 레이스사',
  suggestedNeedle: '2.0~2.5mm',
  descriptionKo: '패션 인형의 대표 주자. 날씬한 실루엣과 긴 팔·다리로 성인 스타일 재현이 쉬움.',
);

/// Tammy's Little Sister (Pepper, 1963, 11.5inch/29.2cm).
/// 출처: 사용자 제공 재봉용 공식 측정치 (2026-04-24 갱신).
const DollPreset tammyDoll = DollPreset(
  id: 'tammy',
  nameKo: '태미의 작은 동생 (1963)',
  nameEn: "Tammy's Little Sister",
  heightCm: 29.2, // 11.5 inch
  measurement: BodyMeasurement(
    chestCm: 13.5,               // Bust
    neckCm: 6.5,                 // Neck circumference
    bodyLengthCm: 8,             // collar to waist 5.1 + 여유 (crop 기준)
    sleeveLengthCm: 7.7,         // shoulder seam to cuff
    upperArmCm: 4.8,             // upper arm bicep
    wristCm: 3,                  // 추정 (공식 값 없음)
    shoulderCm: 2.5,             // neck to shoulder seam
    armholeDepthCm: 2.9,         // underarm to true waist
  ),
  suggestedGauge: UserGauge(stitchesPer10cm: 40, rowsPer10cm: 50),
  suggestedEase: EaseSettings.doll,
  suggestedYarn: 'vincent 3ply 또는 유사한 초극세사',
  suggestedNeedle: 'US0 (2.0mm) 4개 DPN',
  descriptionKo: '빈티지한 비율. 11.5인치 키에 정교한 디테일. 재봉용 공식 측정치 기반이라 원피스·블라우스·팬츠까지 폭넓게 활용.',
);

/// Paola Reina (33.7cm) — 스페인 공예 인형.
/// 출처: kasatkadolls.ru / Лифенко Оксана 측정.
const DollPreset paolaReinaDoll = DollPreset(
  id: 'paola_reina',
  nameKo: '파올라 레이나',
  nameEn: 'Paola Reina',
  heightCm: 33.7,
  measurement: BodyMeasurement(
    chestCm: 15.5,
    neckCm: 8, // 추정
    bodyLengthCm: 15, // 어깨~허리(9.6) + 힙 여유 (크롭 기준 15)
    sleeveLengthCm: 8.5, // 추정
    upperArmCm: 5.5,
    wristCm: 3.5,
    shoulderCm: 7,
    armholeDepthCm: 3.5,
  ),
  suggestedGauge: UserGauge(stitchesPer10cm: 32, rowsPer10cm: 40),
  suggestedEase: EaseSettings.doll,
  suggestedYarn: '3~4ply 코튼 · 메리노 블렌드',
  suggestedNeedle: '2.5~3.0mm',
  descriptionKo: '친근한 아동 체형. 통통한 실루엣으로 니트 옷 잘 어울리고 초심자에게 권장.',
);

/// 빌트인 인형 프리셋 목록.
const List<DollPreset> builtinDollPresets = [
  barbieDoll,
  tammyDoll,
  paolaReinaDoll,
];
