// 이슈 #723 — 블록(MoriBlockShell) 외형 토큰 (CSS 변수 개념).
// 한 곳만 수정하면 모든 블록에 즉시 반영.
//
// 기준 블록: 내작업실의 "진행중 프로젝트" 블록 (tools_screen.dart:94).

import 'package:flutter/material.dart';

@immutable
class BlockTheme extends ThemeExtension<BlockTheme> {
  /// 컨테이너 라운드 반경 (GlassCard radius).
  final double containerRadius;

  /// 보더 색상 alpha (accent.withValues(alpha: borderAlpha)).
  final double borderAlpha;

  /// 헤더 padding (icon + label + moreLabel 영역).
  final EdgeInsetsGeometry headerPadding;

  /// 본문 기본 padding.
  final EdgeInsetsGeometry bodyPadding;

  /// 아이콘 박스 크기 (정사각형).
  final double iconBoxSize;

  /// 아이콘 박스 라운드 반경.
  final double iconBoxRadius;

  /// 아이콘 박스 배경 alpha.
  final double iconBoxBgAlpha;

  /// 아이콘 자체 크기.
  final double iconSize;

  /// 헤더-본문 사이 구분선 두께.
  final double dividerThickness;

  /// 아이콘과 라벨 간격.
  final double iconLabelGap;

  const BlockTheme({
    required this.containerRadius,
    required this.borderAlpha,
    required this.headerPadding,
    required this.bodyPadding,
    required this.iconBoxSize,
    required this.iconBoxRadius,
    required this.iconBoxBgAlpha,
    required this.iconSize,
    required this.dividerThickness,
    required this.iconLabelGap,
  });

  /// 기본값 — 진행중 프로젝트 블록 외형 기준.
  static const BlockTheme standard = BlockTheme(
    containerRadius: 18,
    borderAlpha: 0.25,
    headerPadding: EdgeInsets.fromLTRB(14, 12, 12, 10),
    bodyPadding: EdgeInsets.fromLTRB(14, 12, 14, 14),
    iconBoxSize: 30,
    iconBoxRadius: 10,
    iconBoxBgAlpha: 0.12,
    iconSize: 17,
    dividerThickness: 1.5,
    iconLabelGap: 10,
  );

  @override
  BlockTheme copyWith({
    double? containerRadius,
    double? borderAlpha,
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? bodyPadding,
    double? iconBoxSize,
    double? iconBoxRadius,
    double? iconBoxBgAlpha,
    double? iconSize,
    double? dividerThickness,
    double? iconLabelGap,
  }) {
    return BlockTheme(
      containerRadius: containerRadius ?? this.containerRadius,
      borderAlpha: borderAlpha ?? this.borderAlpha,
      headerPadding: headerPadding ?? this.headerPadding,
      bodyPadding: bodyPadding ?? this.bodyPadding,
      iconBoxSize: iconBoxSize ?? this.iconBoxSize,
      iconBoxRadius: iconBoxRadius ?? this.iconBoxRadius,
      iconBoxBgAlpha: iconBoxBgAlpha ?? this.iconBoxBgAlpha,
      iconSize: iconSize ?? this.iconSize,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      iconLabelGap: iconLabelGap ?? this.iconLabelGap,
    );
  }

  @override
  BlockTheme lerp(ThemeExtension<BlockTheme>? other, double t) {
    if (other is! BlockTheme) return this;
    return BlockTheme(
      containerRadius: _lerpDouble(containerRadius, other.containerRadius, t),
      borderAlpha: _lerpDouble(borderAlpha, other.borderAlpha, t),
      headerPadding: EdgeInsetsGeometry.lerp(headerPadding, other.headerPadding, t)!,
      bodyPadding: EdgeInsetsGeometry.lerp(bodyPadding, other.bodyPadding, t)!,
      iconBoxSize: _lerpDouble(iconBoxSize, other.iconBoxSize, t),
      iconBoxRadius: _lerpDouble(iconBoxRadius, other.iconBoxRadius, t),
      iconBoxBgAlpha: _lerpDouble(iconBoxBgAlpha, other.iconBoxBgAlpha, t),
      iconSize: _lerpDouble(iconSize, other.iconSize, t),
      dividerThickness: _lerpDouble(dividerThickness, other.dividerThickness, t),
      iconLabelGap: _lerpDouble(iconLabelGap, other.iconLabelGap, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  /// context에서 BlockTheme 조회. 없으면 standard 반환.
  static BlockTheme of(BuildContext context) {
    return Theme.of(context).extension<BlockTheme>() ?? standard;
  }
}
