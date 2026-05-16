// 이슈 #723 후속 — Dropbox 브랜드 외형 토큰.
// Dropbox 색상이 인라인 하드코딩된 12곳을 한 곳에서 제어.

import 'package:flutter/material.dart';

@immutable
class DropboxTheme extends ThemeExtension<DropboxTheme> {
  /// Dropbox 브랜드 블루.
  final Color brandColor;

  /// 아이콘 박스 배경 alpha (brandColor 기준).
  final double iconBoxBgAlpha;

  /// 아이콘 박스 보더 alpha.
  final double iconBoxBorderAlpha;

  /// 아이콘 박스 라운드.
  final double iconBoxRadius;

  /// 기본 아이콘 (Material).
  final IconData icon;

  /// 라벨 폰트 weight.
  final FontWeight labelWeight;

  const DropboxTheme({
    required this.brandColor,
    required this.iconBoxBgAlpha,
    required this.iconBoxBorderAlpha,
    required this.iconBoxRadius,
    required this.icon,
    required this.labelWeight,
  });

  /// Dropbox 브랜드 표준 (0xFF0061FF, 현재 하드코딩 값).
  static const DropboxTheme standard = DropboxTheme(
    brandColor: Color(0xFF0061FF),
    iconBoxBgAlpha: 0.10,
    iconBoxBorderAlpha: 0.20,
    iconBoxRadius: 12,
    icon: Icons.cloud_rounded,
    labelWeight: FontWeight.w700,
  );

  @override
  DropboxTheme copyWith({
    Color? brandColor,
    double? iconBoxBgAlpha,
    double? iconBoxBorderAlpha,
    double? iconBoxRadius,
    IconData? icon,
    FontWeight? labelWeight,
  }) =>
      DropboxTheme(
        brandColor: brandColor ?? this.brandColor,
        iconBoxBgAlpha: iconBoxBgAlpha ?? this.iconBoxBgAlpha,
        iconBoxBorderAlpha: iconBoxBorderAlpha ?? this.iconBoxBorderAlpha,
        iconBoxRadius: iconBoxRadius ?? this.iconBoxRadius,
        icon: icon ?? this.icon,
        labelWeight: labelWeight ?? this.labelWeight,
      );

  @override
  DropboxTheme lerp(ThemeExtension<DropboxTheme>? other, double t) {
    if (other is! DropboxTheme) return this;
    return DropboxTheme(
      brandColor: Color.lerp(brandColor, other.brandColor, t)!,
      iconBoxBgAlpha: iconBoxBgAlpha + (other.iconBoxBgAlpha - iconBoxBgAlpha) * t,
      iconBoxBorderAlpha:
          iconBoxBorderAlpha + (other.iconBoxBorderAlpha - iconBoxBorderAlpha) * t,
      iconBoxRadius: iconBoxRadius + (other.iconBoxRadius - iconBoxRadius) * t,
      icon: t < 0.5 ? icon : other.icon,
      labelWeight: t < 0.5 ? labelWeight : other.labelWeight,
    );
  }

  static DropboxTheme of(BuildContext context) =>
      Theme.of(context).extension<DropboxTheme>() ?? standard;
}
