// 어드민 테이블/목록 외형 토큰 (CSS 변수 개념).
// AdminListShell이 참조. 한 곳 수정으로 모든 어드민 목록에 즉시 반영.

import 'package:flutter/material.dart';

@immutable
class AdminTableTheme extends ThemeExtension<AdminTableTheme> {
  /// 헤더 row 높이 (컬럼명).
  final double headerHeight;

  /// 본문 row 높이 (한 줄 row).
  final double rowHeight;

  /// 헤더 배경.
  final Color headerBg;

  /// 헤더 텍스트 색.
  final Color headerText;

  /// 본문 row 배경.
  final Color rowBg;

  /// 본문 row hover 배경.
  final Color rowHoverBg;

  /// 선택된 row 배경.
  final Color rowSelectedBg;

  /// row 구분선 색.
  final Color divider;

  /// row 좌우 padding.
  final double rowPaddingHorizontal;

  /// 컬럼 셀 간 spacing.
  final double cellGap;

  /// 본문 텍스트 색.
  final Color cellText;

  /// 부가 텍스트 (subtitle/meta) 색.
  final Color cellMuted;

  /// 검색바 + 카운트 영역 padding.
  final EdgeInsetsGeometry toolbarPadding;

  const AdminTableTheme({
    required this.headerHeight,
    required this.rowHeight,
    required this.headerBg,
    required this.headerText,
    required this.rowBg,
    required this.rowHoverBg,
    required this.rowSelectedBg,
    required this.divider,
    required this.rowPaddingHorizontal,
    required this.cellGap,
    required this.cellText,
    required this.cellMuted,
    required this.toolbarPadding,
  });

  /// 어드민 다크 톤(슬레이트/라임 액센트) 기준 표준값.
  static const AdminTableTheme standard = AdminTableTheme(
    headerHeight: 38,
    rowHeight: 56,
    headerBg: Color(0xFFF1F5F9),     // slate-100
    headerText: Color(0xFF334155),   // slate-700
    rowBg: Colors.white,
    rowHoverBg: Color(0xFFF8FAFC),   // slate-50
    rowSelectedBg: Color(0xFFEEF2FF), // indigo-50
    divider: Color(0xFFE2E8F0),       // slate-200
    rowPaddingHorizontal: 14,
    cellGap: 10,
    cellText: Color(0xFF1A1A2E),
    cellMuted: Color(0xFF64748B),
    toolbarPadding: EdgeInsets.fromLTRB(16, 12, 16, 10),
  );

  @override
  AdminTableTheme copyWith({
    double? headerHeight,
    double? rowHeight,
    Color? headerBg,
    Color? headerText,
    Color? rowBg,
    Color? rowHoverBg,
    Color? rowSelectedBg,
    Color? divider,
    double? rowPaddingHorizontal,
    double? cellGap,
    Color? cellText,
    Color? cellMuted,
    EdgeInsetsGeometry? toolbarPadding,
  }) {
    return AdminTableTheme(
      headerHeight: headerHeight ?? this.headerHeight,
      rowHeight: rowHeight ?? this.rowHeight,
      headerBg: headerBg ?? this.headerBg,
      headerText: headerText ?? this.headerText,
      rowBg: rowBg ?? this.rowBg,
      rowHoverBg: rowHoverBg ?? this.rowHoverBg,
      rowSelectedBg: rowSelectedBg ?? this.rowSelectedBg,
      divider: divider ?? this.divider,
      rowPaddingHorizontal: rowPaddingHorizontal ?? this.rowPaddingHorizontal,
      cellGap: cellGap ?? this.cellGap,
      cellText: cellText ?? this.cellText,
      cellMuted: cellMuted ?? this.cellMuted,
      toolbarPadding: toolbarPadding ?? this.toolbarPadding,
    );
  }

  @override
  AdminTableTheme lerp(ThemeExtension<AdminTableTheme>? other, double t) {
    if (other is! AdminTableTheme) return this;
    return AdminTableTheme(
      headerHeight: _ld(headerHeight, other.headerHeight, t),
      rowHeight: _ld(rowHeight, other.rowHeight, t),
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      headerText: Color.lerp(headerText, other.headerText, t)!,
      rowBg: Color.lerp(rowBg, other.rowBg, t)!,
      rowHoverBg: Color.lerp(rowHoverBg, other.rowHoverBg, t)!,
      rowSelectedBg: Color.lerp(rowSelectedBg, other.rowSelectedBg, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      rowPaddingHorizontal: _ld(rowPaddingHorizontal, other.rowPaddingHorizontal, t),
      cellGap: _ld(cellGap, other.cellGap, t),
      cellText: Color.lerp(cellText, other.cellText, t)!,
      cellMuted: Color.lerp(cellMuted, other.cellMuted, t)!,
      toolbarPadding: EdgeInsetsGeometry.lerp(toolbarPadding, other.toolbarPadding, t)!,
    );
  }

  static double _ld(double a, double b, double t) => a + (b - a) * t;

  static AdminTableTheme of(BuildContext context) {
    return Theme.of(context).extension<AdminTableTheme>() ?? standard;
  }
}
