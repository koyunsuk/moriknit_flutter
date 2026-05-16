import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'block_theme.dart';

class T {
  static const List<String> fallbackFonts = [
    'sans-serif',
    'Roboto',
    'Noto Sans CJK KR',
    'Noto Sans KR',
    'Noto Sans CJK SC',
    'Noto Sans Arabic',
  ];

  static TextStyle get h1 => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: C.tx,
        letterSpacing: -0.4,
        height: 1.2,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: C.tx,
        height: 1.25,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get h3 => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: C.tx,
        height: 1.3,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get body => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: C.tx,
        height: 1.6,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get bodyBold => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: C.tx,
        height: 1.4,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get sm => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: C.tx2,
        height: 1.45,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: C.mu,
        height: 1.35,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get captionBold => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: C.mu,
        height: 1.35,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get numXL => TextStyle(
        fontSize: 58,
        fontWeight: FontWeight.w300,
        color: C.tx,
        letterSpacing: -2,
        height: 1,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get numLG => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w300,
        color: C.tx,
        height: 1,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get chip => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.2,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get tabOn => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: C.lvD,
        height: 1.2,
        fontFamilyFallback: fallbackFonts,
      );

  static TextStyle get tabOff => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: C.mu,
        height: 1.2,
        fontFamilyFallback: fallbackFonts,
      );
}

class AppTheme {
  static ThemeData get current => light;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.dark(
          primary: C.lv,
          secondary: C.pk,
          tertiary: C.lm,
          surface: C.gx,
          error: const Color(0xFFDC2626),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: C.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: C.tx,
            fontFamilyFallback: T.fallbackFonts,
          ),
          iconTheme: IconThemeData(color: C.tx, size: 22),
        ),
        textTheme: TextTheme(
          bodyLarge: T.body,
          bodyMedium: T.body,
          bodySmall: T.caption,
          titleLarge: T.h1,
          titleMedium: T.h2,
          titleSmall: T.h3,
          labelLarge: T.bodyBold,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamilyFallback: T.fallbackFonts),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: C.lm,
          foregroundColor: const Color(0xFF1a3000),
          elevation: 6,
          shape: const StadiumBorder(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.gx,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.bd2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.bd)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.lv, width: 1.6)),
          hintStyle: T.body.copyWith(color: C.mu),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.lv : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.lv.withValues(alpha: 0.4) : C.bd2),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.gx,
          contentTextStyle: TextStyle(color: C.tx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: C.gx,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      );

  static ThemeData get adminLight => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF84CC16),
          secondary: Color(0xFFA3E635),
          tertiary: Color(0xFF65A30D),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF8FAFC),
          onPrimary: Color(0xFF0F172A),
          error: Color(0xFFDC2626),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white, size: 22),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 0,
        ),
        dividerColor: const Color(0xFF334155),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF84CC16), width: 1.6),
          ),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF84CC16),
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF84CC16)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF84CC16),
            side: const BorderSide(color: Color(0xFF84CC16)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF84CC16) : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF84CC16).withValues(alpha: 0.4)
                  : const Color(0xFF334155)),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF84CC16) : Colors.transparent),
          checkColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: Color(0xFF84CC16),
          labelColor: Color(0xFF84CC16),
          unselectedLabelColor: Color(0xFF64748B),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg,
        // 이슈 #723 — 블록 외형 토큰 (CSS 변수 개념). BlockTheme 한 곳만 수정하면 전체 반영.
        extensions: const <ThemeExtension<dynamic>>[BlockTheme.standard],
        colorScheme: ColorScheme.light(
          primary: C.lv,
          secondary: C.pk,
          tertiary: C.lm,
          surface: C.gx,
          error: const Color(0xFFDC2626),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: C.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: C.tx,
            fontFamilyFallback: T.fallbackFonts,
          ),
          iconTheme: IconThemeData(color: C.tx, size: 22),
        ),
        textTheme: TextTheme(
          bodyLarge: T.body,
          bodyMedium: T.body,
          bodySmall: T.caption,
          titleLarge: T.h1,
          titleMedium: T.h2,
          titleSmall: T.h3,
          labelLarge: T.bodyBold,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamilyFallback: T.fallbackFonts),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: C.lm,
          foregroundColor: const Color(0xFF1a3000),
          elevation: 6,
          shape: const StadiumBorder(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.74),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: C.bd2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: C.bd),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: C.lv, width: 1.6),
          ),
          hintStyle: T.body.copyWith(color: C.mu),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? C.lv : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? C.lv.withValues(alpha: 0.4)
                  : C.bd2),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.tx,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: C.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      );
}
