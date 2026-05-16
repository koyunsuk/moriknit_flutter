// 이슈 #722 후속 — 로딩/에러/빈 상태 외형 토큰.
// AsyncDataView / AsyncLoadingFriendly / AsyncDelayedFriendly가 참조.
// 한 곳 수정 = 모든 로딩/에러/빈 화면 일괄 반영.

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AsyncStateTheme extends ThemeExtension<AsyncStateTheme> {
  /// 로딩 → 친화 메시지로 전환되는 시간 (기본 5초).
  final Duration loadingTimeout;

  /// 스켈레톤 행 라운드 반경.
  final double placeholderRowRadius;

  /// 스켈레톤 행 보더 alpha (C.bd 기준).
  final double placeholderBorderAlpha;

  /// 스켈레톤 행 배경색.
  final Color placeholderRowColor;

  /// 에러 아이콘 색상.
  final Color errorIconColor;

  /// 에러 메시지 색상.
  final Color errorTextColor;

  /// 재시도 버튼 색상.
  final Color retryButtonColor;

  const AsyncStateTheme({
    required this.loadingTimeout,
    required this.placeholderRowRadius,
    required this.placeholderBorderAlpha,
    required this.placeholderRowColor,
    required this.errorIconColor,
    required this.errorTextColor,
    required this.retryButtonColor,
  });

  /// 기본값 — 현재 하드코딩 값 그대로 (회귀 0).
  static AsyncStateTheme get standard => AsyncStateTheme(
        loadingTimeout: const Duration(seconds: 5),
        placeholderRowRadius: 12,
        placeholderBorderAlpha: 0.5,
        placeholderRowColor: C.gx,
        errorIconColor: C.og,
        errorTextColor: C.og,
        retryButtonColor: C.lv,
      );

  @override
  AsyncStateTheme copyWith({
    Duration? loadingTimeout,
    double? placeholderRowRadius,
    double? placeholderBorderAlpha,
    Color? placeholderRowColor,
    Color? errorIconColor,
    Color? errorTextColor,
    Color? retryButtonColor,
  }) =>
      AsyncStateTheme(
        loadingTimeout: loadingTimeout ?? this.loadingTimeout,
        placeholderRowRadius: placeholderRowRadius ?? this.placeholderRowRadius,
        placeholderBorderAlpha:
            placeholderBorderAlpha ?? this.placeholderBorderAlpha,
        placeholderRowColor: placeholderRowColor ?? this.placeholderRowColor,
        errorIconColor: errorIconColor ?? this.errorIconColor,
        errorTextColor: errorTextColor ?? this.errorTextColor,
        retryButtonColor: retryButtonColor ?? this.retryButtonColor,
      );

  @override
  AsyncStateTheme lerp(ThemeExtension<AsyncStateTheme>? other, double t) {
    if (other is! AsyncStateTheme) return this;
    return AsyncStateTheme(
      loadingTimeout: t < 0.5 ? loadingTimeout : other.loadingTimeout,
      placeholderRowRadius: placeholderRowRadius +
          (other.placeholderRowRadius - placeholderRowRadius) * t,
      placeholderBorderAlpha: placeholderBorderAlpha +
          (other.placeholderBorderAlpha - placeholderBorderAlpha) * t,
      placeholderRowColor:
          Color.lerp(placeholderRowColor, other.placeholderRowColor, t)!,
      errorIconColor: Color.lerp(errorIconColor, other.errorIconColor, t)!,
      errorTextColor: Color.lerp(errorTextColor, other.errorTextColor, t)!,
      retryButtonColor:
          Color.lerp(retryButtonColor, other.retryButtonColor, t)!,
    );
  }

  static AsyncStateTheme of(BuildContext context) =>
      Theme.of(context).extension<AsyncStateTheme>() ?? standard;
}
