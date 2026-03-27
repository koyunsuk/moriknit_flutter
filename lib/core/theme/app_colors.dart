// lib/core/theme/app_colors.dart
// 와이어프레임 CSS 변수 100% 반영

import 'package:flutter/material.dart';

class C {
  // ── 메인 컬러 ──────────────────────────────────────────────
  static const Color pk     = Color(0xFFF472B6); // --pk  핑크
  static const Color pkD    = Color(0xFFDB2777); // --pk-d
  static const Color pkL    = Color(0x21F472B6); // --pk-l rgba(244,114,182,0.13)

  static const Color lv     = Color(0xFFC084FC); // --lv  라벤더
  static const Color lvD    = Color(0xFF9333EA); // --lv-d
  static const Color lvL    = Color(0x21C084FC); // --lv-l rgba(192,132,252,0.13)

  static const Color lm     = Color(0xFFA3E635); // --lm  라임
  static const Color lmD    = Color(0xFF65A30D); // --lm-d
  static const Color lmG    = Color(0x57A3E635); // --lm-g rgba(163,230,53,0.34)

  static const Color og     = Color(0xFFFB923C); // --og  오렌지

  // ── 텍스트 ─────────────────────────────────────────────────
  static const Color tx     = Color(0xFF1E0A35); // --tx  본문
  static const Color tx2    = Color(0xFF6B4F8A); // --tx2 보조
  static const Color mu     = Color(0xFFA78BB8); // --mu  뮤트

  // ── 배경 ───────────────────────────────────────────────────
  static const Color bg     = Color(0xFFFCF0FF); // --bg

  // ── 글래스모피즘 ───────────────────────────────────────────
  static const Color gx     = Color(0xA3FFFFFF); // --gx rgba(255,255,255,0.64)
  static const Color bd     = Color(0xDEFFFFFF); // --bd rgba(255,255,255,0.87)
  static const Color bd2    = Color(0x30C8A0E6); // --bd2 rgba(200,160,230,0.19)

  // ── 그라디언트 ─────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCF0FF), Color(0xFFF0E8FF)],
  );

  static const LinearGradient pkLvGradient = LinearGradient(
    colors: [pk, lv],
  );

  static const LinearGradient lvLmGradient = LinearGradient(
    colors: [lv, lm],
  );

  // ── 그라디언트 배경 오브 ───────────────────────────────────
  // 와이어프레임의 .pbg 방울 효과
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 40,
      offset: const Offset(0, 14),
    ),
  ];

  // ── 글래스 카드 데코 ───────────────────────────────────────
  // .mc.g 클래스 — 와이어프레임 주요 카드 스타일
  static BoxDecoration get glassCard => BoxDecoration(
    color: gx,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: bd, width: 1),
    boxShadow: [
      BoxShadow(
        color: lv.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // 강조 글래스 카드 (라벤더 테두리)
  static BoxDecoration glassCardAccent({Color? borderColor}) => BoxDecoration(
    color: gx,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: borderColor ?? lv.withValues(alpha: 0.28),
      width: 1.5,
    ),
  );

  // ── 탭바 배경 ──────────────────────────────────────────────
  static BoxDecoration get tabBarDeco => BoxDecoration(
    color: gx,
    border: Border(top: BorderSide(color: bd2, width: 1)),
    boxShadow: [
      BoxShadow(
        color: lv.withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, -4),
      ),
    ],
  );

  // ── 선택된 탭 배경 ─────────────────────────────────────────
  static BoxDecoration get selectedTab => BoxDecoration(
    color: lvL,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: lv.withValues(alpha: 0.22)),
  );

  // ── 한도 경고 바 ───────────────────────────────────────────
  static BoxDecoration get limitBar => BoxDecoration(
    color: og.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: og.withValues(alpha: 0.25)),
  );
}
