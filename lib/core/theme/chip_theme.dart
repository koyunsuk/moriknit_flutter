// 이슈 #723 후속 — 칩 외형 토큰.
// MoriChip / MoriOptionChips / MoriToggleChip 참조.

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class MoriChipTheme extends ThemeExtension<MoriChipTheme> {
  /// 칩 라운드 반경.
  final double radius;

  /// 칩 패딩.
  final EdgeInsetsGeometry padding;

  /// 선택 상태 폰트 weight.
  final FontWeight selectedWeight;

  /// 미선택 상태 폰트 weight.
  final FontWeight unselectedWeight;

  /// 선택 상태 보더 alpha (accent 기준, 1.0이면 그대로).
  final double selectedBorderAlpha;

  /// 미선택 상태 보더 alpha (accent 기준).
  final double unselectedBorderAlpha;

  /// 미선택 상태 배경색 (accent와 별개).
  final Color unselectedBgColor;

  const MoriChipTheme({
    required this.radius,
    required this.padding,
    required this.selectedWeight,
    required this.unselectedWeight,
    required this.selectedBorderAlpha,
    required this.unselectedBorderAlpha,
    required this.unselectedBgColor,
  });

  /// 기본값 — project_input_screen.dart _StatusSelector 기준.
  static MoriChipTheme get standard => MoriChipTheme(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        selectedWeight: FontWeight.w700,
        unselectedWeight: FontWeight.w500,
        selectedBorderAlpha: 1.0,
        unselectedBorderAlpha: 0.20,
        unselectedBgColor: C.lvL,
      );

  @override
  MoriChipTheme copyWith({
    double? radius,
    EdgeInsetsGeometry? padding,
    FontWeight? selectedWeight,
    FontWeight? unselectedWeight,
    double? selectedBorderAlpha,
    double? unselectedBorderAlpha,
    Color? unselectedBgColor,
  }) =>
      MoriChipTheme(
        radius: radius ?? this.radius,
        padding: padding ?? this.padding,
        selectedWeight: selectedWeight ?? this.selectedWeight,
        unselectedWeight: unselectedWeight ?? this.unselectedWeight,
        selectedBorderAlpha: selectedBorderAlpha ?? this.selectedBorderAlpha,
        unselectedBorderAlpha:
            unselectedBorderAlpha ?? this.unselectedBorderAlpha,
        unselectedBgColor: unselectedBgColor ?? this.unselectedBgColor,
      );

  @override
  MoriChipTheme lerp(ThemeExtension<MoriChipTheme>? other, double t) {
    if (other is! MoriChipTheme) return this;
    return MoriChipTheme(
      radius: radius + (other.radius - radius) * t,
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t)!,
      selectedWeight: t < 0.5 ? selectedWeight : other.selectedWeight,
      unselectedWeight: t < 0.5 ? unselectedWeight : other.unselectedWeight,
      selectedBorderAlpha: selectedBorderAlpha +
          (other.selectedBorderAlpha - selectedBorderAlpha) * t,
      unselectedBorderAlpha: unselectedBorderAlpha +
          (other.unselectedBorderAlpha - unselectedBorderAlpha) * t,
      unselectedBgColor:
          Color.lerp(unselectedBgColor, other.unselectedBgColor, t)!,
    );
  }

  static MoriChipTheme of(BuildContext context) =>
      Theme.of(context).extension<MoriChipTheme>() ?? standard;
}
