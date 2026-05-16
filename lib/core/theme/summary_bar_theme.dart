// 이슈 #723 — 요약바 외형 토큰.
// SummaryCard_Main / SummaryCard_Detail 가 참조.

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class SummaryBarTheme extends ThemeExtension<SummaryBarTheme> {
  /// 카드 라운드 반경.
  final double radius;

  /// 보더 색상 (기본).
  final Color borderColor;

  /// 카드 내부 콘텐츠 padding.
  final EdgeInsetsGeometry contentPadding;

  /// 값 텍스트 폰트 크기.
  final double valueFontSize;

  /// 값 텍스트 폰트 weight.
  final FontWeight valueFontWeight;

  /// 라벨 텍스트 폰트 크기.
  final double labelFontSize;

  /// 라벨 텍스트 색상.
  final Color labelColor;

  /// +추가 버튼 배경색.
  final Color addButtonColor;

  /// +추가 버튼 라운드.
  final double addButtonRadius;

  const SummaryBarTheme({
    required this.radius,
    required this.borderColor,
    required this.contentPadding,
    required this.valueFontSize,
    required this.valueFontWeight,
    required this.labelFontSize,
    required this.labelColor,
    required this.addButtonColor,
    required this.addButtonRadius,
  });

  /// 표준값 — 기존 외형 유지 (회귀 0).
  static SummaryBarTheme get standard => SummaryBarTheme(
        radius: 18,
        borderColor: C.bd,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        valueFontSize: 17,
        valueFontWeight: FontWeight.w800,
        labelFontSize: 10,
        labelColor: C.mu,
        addButtonColor: C.lv,
        addButtonRadius: 20,
      );

  @override
  SummaryBarTheme copyWith({
    double? radius,
    Color? borderColor,
    EdgeInsetsGeometry? contentPadding,
    double? valueFontSize,
    FontWeight? valueFontWeight,
    double? labelFontSize,
    Color? labelColor,
    Color? addButtonColor,
    double? addButtonRadius,
  }) =>
      SummaryBarTheme(
        radius: radius ?? this.radius,
        borderColor: borderColor ?? this.borderColor,
        contentPadding: contentPadding ?? this.contentPadding,
        valueFontSize: valueFontSize ?? this.valueFontSize,
        valueFontWeight: valueFontWeight ?? this.valueFontWeight,
        labelFontSize: labelFontSize ?? this.labelFontSize,
        labelColor: labelColor ?? this.labelColor,
        addButtonColor: addButtonColor ?? this.addButtonColor,
        addButtonRadius: addButtonRadius ?? this.addButtonRadius,
      );

  @override
  SummaryBarTheme lerp(ThemeExtension<SummaryBarTheme>? other, double t) {
    if (other is! SummaryBarTheme) return this;
    return SummaryBarTheme(
      radius: radius + (other.radius - radius) * t,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      contentPadding:
          EdgeInsetsGeometry.lerp(contentPadding, other.contentPadding, t)!,
      valueFontSize:
          valueFontSize + (other.valueFontSize - valueFontSize) * t,
      valueFontWeight: t < 0.5 ? valueFontWeight : other.valueFontWeight,
      labelFontSize:
          labelFontSize + (other.labelFontSize - labelFontSize) * t,
      labelColor: Color.lerp(labelColor, other.labelColor, t)!,
      addButtonColor: Color.lerp(addButtonColor, other.addButtonColor, t)!,
      addButtonRadius:
          addButtonRadius + (other.addButtonRadius - addButtonRadius) * t,
    );
  }

  static SummaryBarTheme of(BuildContext context) =>
      Theme.of(context).extension<SummaryBarTheme>() ?? standard;
}
