// 이슈 #723 — 페이지 헤더 외형 토큰.
// MoriPageHeaderShell + MoriBrandHeader + MoriWideHeader 가 참조.
// 한 곳 수정 = 67개 화면 헤더 일괄 반영.

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class HeaderTheme extends ThemeExtension<HeaderTheme> {
  // ── PageHeaderShell ──────────────────────────────
  /// 헤더 외곽 배경.
  final Color shellBgColor;

  /// 헤더 외곽 보더.
  final Color shellBorderColor;

  /// 헤더 외곽 보더 두께.
  final double shellBorderWidth;

  /// 헤더 콘텐츠 최대 폭.
  final double shellMaxWidth;

  // ── BrandHeader (non-compact) ────────────────────
  /// non-compact 헤더 높이.
  final double nonCompactHeight;

  /// non-compact 로고 크기 (가로/세로 동일).
  final double nonCompactLogoSize;

  /// non-compact 타이틀 폰트 크기.
  final double nonCompactTitleFontSize;

  /// non-compact 타이틀 너비.
  final double nonCompactTitleWidth;

  /// non-compact 서브타이틀 폰트 크기.
  final double nonCompactSubtitleFontSize;

  // ── BrandHeader (compact) ────────────────────────
  /// compact 헤더 높이.
  final double compactHeight;

  /// compact 로고 크기.
  final double compactLogoSize;

  /// compact 타이틀 폰트 크기.
  final double compactTitleFontSize;

  /// compact 타이틀 너비.
  final double compactTitleWidth;

  /// compact 서브타이틀 폰트 크기.
  final double compactSubtitleFontSize;

  // ── 공통 ─────────────────────────────────────────
  /// 서브타이틀 폰트 weight.
  final FontWeight subtitleFontWeight;

  /// WideHeader trailing 위치 (top/right 동일).
  final double trailingOffset;

  const HeaderTheme({
    required this.shellBgColor,
    required this.shellBorderColor,
    required this.shellBorderWidth,
    required this.shellMaxWidth,
    required this.nonCompactHeight,
    required this.nonCompactLogoSize,
    required this.nonCompactTitleFontSize,
    required this.nonCompactTitleWidth,
    required this.nonCompactSubtitleFontSize,
    required this.compactHeight,
    required this.compactLogoSize,
    required this.compactTitleFontSize,
    required this.compactTitleWidth,
    required this.compactSubtitleFontSize,
    required this.subtitleFontWeight,
    required this.trailingOffset,
  });

  /// 표준값 — 현재 외형 그대로 (#718 축소 반영). 회귀 0.
  static HeaderTheme get standard => HeaderTheme(
        shellBgColor: C.headerBg,
        shellBorderColor: C.headerBorder,
        shellBorderWidth: 1.2,
        shellMaxWidth: 1380,
        // non-compact
        nonCompactHeight: 120,
        nonCompactLogoSize: 72,
        nonCompactTitleFontSize: 16,
        nonCompactTitleWidth: 144,
        nonCompactSubtitleFontSize: 11,
        // compact
        compactHeight: 72,
        compactLogoSize: 40,
        compactTitleFontSize: 12,
        compactTitleWidth: 78,
        compactSubtitleFontSize: 9,
        // 공통
        subtitleFontWeight: FontWeight.w600,
        trailingOffset: 8,
      );

  @override
  HeaderTheme copyWith({
    Color? shellBgColor,
    Color? shellBorderColor,
    double? shellBorderWidth,
    double? shellMaxWidth,
    double? nonCompactHeight,
    double? nonCompactLogoSize,
    double? nonCompactTitleFontSize,
    double? nonCompactTitleWidth,
    double? nonCompactSubtitleFontSize,
    double? compactHeight,
    double? compactLogoSize,
    double? compactTitleFontSize,
    double? compactTitleWidth,
    double? compactSubtitleFontSize,
    FontWeight? subtitleFontWeight,
    double? trailingOffset,
  }) =>
      HeaderTheme(
        shellBgColor: shellBgColor ?? this.shellBgColor,
        shellBorderColor: shellBorderColor ?? this.shellBorderColor,
        shellBorderWidth: shellBorderWidth ?? this.shellBorderWidth,
        shellMaxWidth: shellMaxWidth ?? this.shellMaxWidth,
        nonCompactHeight: nonCompactHeight ?? this.nonCompactHeight,
        nonCompactLogoSize: nonCompactLogoSize ?? this.nonCompactLogoSize,
        nonCompactTitleFontSize:
            nonCompactTitleFontSize ?? this.nonCompactTitleFontSize,
        nonCompactTitleWidth:
            nonCompactTitleWidth ?? this.nonCompactTitleWidth,
        nonCompactSubtitleFontSize:
            nonCompactSubtitleFontSize ?? this.nonCompactSubtitleFontSize,
        compactHeight: compactHeight ?? this.compactHeight,
        compactLogoSize: compactLogoSize ?? this.compactLogoSize,
        compactTitleFontSize: compactTitleFontSize ?? this.compactTitleFontSize,
        compactTitleWidth: compactTitleWidth ?? this.compactTitleWidth,
        compactSubtitleFontSize:
            compactSubtitleFontSize ?? this.compactSubtitleFontSize,
        subtitleFontWeight: subtitleFontWeight ?? this.subtitleFontWeight,
        trailingOffset: trailingOffset ?? this.trailingOffset,
      );

  @override
  HeaderTheme lerp(ThemeExtension<HeaderTheme>? other, double t) {
    if (other is! HeaderTheme) return this;
    double lr(double a, double b) => a + (b - a) * t;
    return HeaderTheme(
      shellBgColor: Color.lerp(shellBgColor, other.shellBgColor, t)!,
      shellBorderColor:
          Color.lerp(shellBorderColor, other.shellBorderColor, t)!,
      shellBorderWidth: lr(shellBorderWidth, other.shellBorderWidth),
      shellMaxWidth: lr(shellMaxWidth, other.shellMaxWidth),
      nonCompactHeight: lr(nonCompactHeight, other.nonCompactHeight),
      nonCompactLogoSize: lr(nonCompactLogoSize, other.nonCompactLogoSize),
      nonCompactTitleFontSize:
          lr(nonCompactTitleFontSize, other.nonCompactTitleFontSize),
      nonCompactTitleWidth:
          lr(nonCompactTitleWidth, other.nonCompactTitleWidth),
      nonCompactSubtitleFontSize:
          lr(nonCompactSubtitleFontSize, other.nonCompactSubtitleFontSize),
      compactHeight: lr(compactHeight, other.compactHeight),
      compactLogoSize: lr(compactLogoSize, other.compactLogoSize),
      compactTitleFontSize: lr(compactTitleFontSize, other.compactTitleFontSize),
      compactTitleWidth: lr(compactTitleWidth, other.compactTitleWidth),
      compactSubtitleFontSize:
          lr(compactSubtitleFontSize, other.compactSubtitleFontSize),
      subtitleFontWeight: t < 0.5 ? subtitleFontWeight : other.subtitleFontWeight,
      trailingOffset: lr(trailingOffset, other.trailingOffset),
    );
  }

  static HeaderTheme of(BuildContext context) =>
      Theme.of(context).extension<HeaderTheme>() ?? standard;
}
