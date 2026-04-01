import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';

class _Palette {
  final Color pk, pkD, pkL;
  final Color lv, lvD, lvL;
  final Color lm, lmD, lmG;
  final Color og;
  final Color tx, tx2, mu;
  final Color bg, gx, bd, bd2;

  const _Palette({
    required this.pk,
    required this.pkD,
    required this.pkL,
    required this.lv,
    required this.lvD,
    required this.lvL,
    required this.lm,
    required this.lmD,
    required this.lmG,
    required this.og,
    required this.tx,
    required this.tx2,
    required this.mu,
    required this.bg,
    required this.gx,
    required this.bd,
    required this.bd2,
  });
}

class C {
  static _Palette _p = _lavender;

  static void apply(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.lavender:   _p = _lavender;  break;
      case AppThemeMode.earthy:     _p = _earthy;    break;
      case AppThemeMode.monochrome: _p = _mono;      break;
      case AppThemeMode.moyangi:    _p = _moyangi;   break;
      case AppThemeMode.jwiChuni:   _p = _jwiChuni;  break;
      case AppThemeMode.todori:     _p = _todori;    break;
      case AppThemeMode.pinkRabbit: _p = _pinkRabbit; break;
      case AppThemeMode.creamSnail: _p = _creamSnail; break;
      case AppThemeMode.jimungmungi: _p = _jimungmungi; break;
      case AppThemeMode.chocoNyangi: _p = _chocoNyangi; break;
      case AppThemeMode.eunsulNyangi: _p = _eunsulNyangi; break;
    }
  }

  // Color getters
  static Color get pk => _p.pk;
  static Color get pkD => _p.pkD;
  static Color get pkL => _p.pkL;

  static Color get lv => _p.lv;
  static Color get lvD => _p.lvD;
  static Color get lvL => _p.lvL;

  static Color get lm => _p.lm;
  static Color get lmD => _p.lmD;
  static Color get lmG => _p.lmG;

  static Color get og => _p.og;

  static Color get tx => _p.tx;
  static Color get tx2 => _p.tx2;
  static Color get mu => _p.mu;

  static Color get bg => _p.bg;
  static Color get gx => _p.gx;
  static Color get bd => _p.bd;
  static Color get bd2 => _p.bd2;

  // Gradient getters
  static LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_p.bg, Color.alphaBlend(_p.lv.withValues(alpha: 0.08), _p.bg)],
      );

  static LinearGradient get pkLvGradient => LinearGradient(
        colors: [_p.pk, _p.lv],
      );

  static LinearGradient get lvLmGradient => LinearGradient(
        colors: [_p.lv, _p.lm],
      );

  // Decoration helpers
  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 40,
          offset: const Offset(0, 14),
        ),
      ];

  static BoxDecoration get glassCard => BoxDecoration(
        color: _p.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _p.bd, width: 1),
        boxShadow: [
          BoxShadow(
            color: _p.lv.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration glassCardAccent({Color? borderColor}) => BoxDecoration(
        color: _p.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? _p.lv.withValues(alpha: 0.28),
          width: 1.5,
        ),
      );

  static BoxDecoration get tabBarDeco => BoxDecoration(
        color: _p.gx,
        border: Border(top: BorderSide(color: _p.bd2, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _p.lv.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      );

  static BoxDecoration get selectedTab => BoxDecoration(
        color: _p.lvL,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _p.lv.withValues(alpha: 0.22)),
      );

  static BoxDecoration get limitBar => BoxDecoration(
        color: _p.og.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _p.og.withValues(alpha: 0.25)),
      );

  // ── Palettes ─────────────────────────────────────────────────────────────

  static const _Palette _lavender = _Palette(
    pk: Color(0xFFF472B6),
    pkD: Color(0xFFBE185D),
    pkL: Color(0x21F472B6),
    lv: Color(0xFFC084FC),
    lvD: Color(0xFF7C3AED),
    lvL: Color(0x21C084FC),
    lm: Color(0xFFA3E635),
    lmD: Color(0xFF65A30D),
    lmG: Color(0x57A3E635),
    og: Color(0xFFFB923C),
    tx: Color(0xFF1A1A2E),
    tx2: Color(0xFF6B7280),
    mu: Color(0xFF9CA3AF),
    bg: Color(0xFFFCF0FF),
    gx: Color(0xD9FFFAFF),
    bd: Color(0xE8EDE9F5),
    bd2: Color(0x30C084FC),
  );

  static const _Palette _earthy = _Palette(
    pk: Color(0xFFC96F4A),
    pkD: Color(0xFF8B4513),
    pkL: Color(0x20C96F4A),
    lv: Color(0xFF8E9A6E),
    lvD: Color(0xFF5C6B47),
    lvL: Color(0x208E9A6E),
    lm: Color(0xFFD4A853),
    lmD: Color(0xFF8B6914),
    lmG: Color(0x57D4A853),
    og: Color(0xFFE07B39),
    tx: Color(0xFF2C1810),
    tx2: Color(0xFF7A6055),
    mu: Color(0xFF9C8B80),
    bg: Color(0xFFF5EEE4),
    gx: Color(0xD9FFF8F0),
    bd: Color(0xE8D7C4B0),
    bd2: Color(0x308E9A6E),
  );

  static const _Palette _mono = _Palette(
    pk: Color(0xFF444444),
    pkD: Color(0xFF111111),
    pkL: Color(0x20444444),
    lv: Color(0xFF777777),
    lvD: Color(0xFF333333),
    lvL: Color(0x20777777),
    lm: Color(0xFFAAAAAA),
    lmD: Color(0xFF666666),
    lmG: Color(0x57AAAAAA),
    og: Color(0xFF888888),
    tx: Color(0xFF111111),
    tx2: Color(0xFF666666),
    mu: Color(0xFF999999),
    bg: Color(0xFFFAFAFA),
    gx: Color(0xD9FFFFFF),
    bd: Color(0xE8E0E0E0),
    bd2: Color(0x30777777),
  );

  // 모냥이 테마 — 살구핑크 + 캣라벤더 + 민트
  static const _Palette _moyangi = _Palette(
    pk: Color(0xFFFF8FB1),
    pkD: Color(0xFFD94F7D),
    pkL: Color(0x20FF8FB1),
    lv: Color(0xFF8E7BFF),
    lvD: Color(0xFF5E43D6),
    lvL: Color(0x208E7BFF),
    lm: Color(0xFF78DCC3),
    lmD: Color(0xFF2C9B7F),
    lmG: Color(0x5778DCC3),
    og: Color(0xFFFFB36B),
    tx: Color(0xFF25131B),
    tx2: Color(0xFF7B5566),
    mu: Color(0xFFB18A98),
    bg: Color(0xFFFFF1F6),
    gx: Color(0xD9FFF9FC),
    bd: Color(0xE8F3D9E4),
    bd2: Color(0x308E7BFF),
  );

  // 쥐춘이 테마 — 슬리피블루 + 베이지 + 밤색
  static const _Palette _jwiChuni = _Palette(
    pk: Color(0xFF8FA9D8),
    pkD: Color(0xFF536F9F),
    pkL: Color(0x208FA9D8),
    lv: Color(0xFFB9A289),
    lvD: Color(0xFF7C6248),
    lvL: Color(0x20B9A289),
    lm: Color(0xFFD7C2A3),
    lmD: Color(0xFF9F805B),
    lmG: Color(0x57D7C2A3),
    og: Color(0xFFB17C57),
    tx: Color(0xFF221A1A),
    tx2: Color(0xFF685C63),
    mu: Color(0xFFA1979D),
    bg: Color(0xFFF5F3F0),
    gx: Color(0xD9FCFBFA),
    bd: Color(0xE8DDD7D1),
    bd2: Color(0x308FA9D8),
  );

  // 토도리테마 — 골드넛 + 메이플브라운 + 올리브
  static const _Palette _todori = _Palette(
    pk: Color(0xFFF4B942),
    pkD: Color(0xFFC67A12),
    pkL: Color(0x20F4B942),
    lv: Color(0xFFB56A2F),
    lvD: Color(0xFF7D4314),
    lvL: Color(0x24B56A2F),
    lm: Color(0xFFD9A441),
    lmD: Color(0xFF9D6713),
    lmG: Color(0x57D9A441),
    og: Color(0xFF8E4E20),
    tx: Color(0xFF2F1B0E),
    tx2: Color(0xFF7B5736),
    mu: Color(0xFFB18B63),
    bg: Color(0xFFFFF4E2),
    gx: Color(0xD9FFF8EC),
    bd: Color(0xE8EBCB9A),
    bd2: Color(0x30B56A2F),
  );

  static const _Palette _pinkRabbit = _Palette(
    pk: Color(0xFFFF6FB5),
    pkD: Color(0xFFD81B78),
    pkL: Color(0x24FF6FB5),
    lv: Color(0xFFFFA6D6),
    lvD: Color(0xFFE255A0),
    lvL: Color(0x24FFA6D6),
    lm: Color(0xFFFFC6E5),
    lmD: Color(0xFFFF78BF),
    lmG: Color(0x57FFC6E5),
    og: Color(0xFFFF8CC8),
    tx: Color(0xFF3A1630),
    tx2: Color(0xFF8A5679),
    mu: Color(0xFFB98DAA),
    bg: Color(0xFFFFF1F8),
    gx: Color(0xD9FFF9FC),
    bd: Color(0xE8F8D8EA),
    bd2: Color(0x30FF6FB5),
  );

  static const _Palette _creamSnail = _Palette(
    pk: Color(0xFF4B6FD6),
    pkD: Color(0xFF2447A8),
    pkL: Color(0x204B6FD6),
    lv: Color(0xFF79B8FF),
    lvD: Color(0xFF2D7FEA),
    lvL: Color(0x2479B8FF),
    lm: Color(0xFFF6EDD9),
    lmD: Color(0xFFD6C29A),
    lmG: Color(0x57F6EDD9),
    og: Color(0xFF8EA7E8),
    tx: Color(0xFF24314F),
    tx2: Color(0xFF6B7691),
    mu: Color(0xFFA3A9B8),
    bg: Color(0xFFFFFCF5),
    gx: Color(0xD9FFFDFC),
    bd: Color(0xE879B8FF),
    bd2: Color(0x5079B8FF),
  );

  static const _Palette _jimungmungi = _Palette(
    pk: Color(0xFF7B4DFF),
    pkD: Color(0xFF4322A3),
    pkL: Color(0x247B4DFF),
    lv: Color(0xFF1E1E24),
    lvD: Color(0xFF000000),
    lvL: Color(0x1F1E1E24),
    lm: Color(0xFFF4F2FF),
    lmD: Color(0xFFD8D2F0),
    lmG: Color(0x57F4F2FF),
    og: Color(0xFFA987FF),
    tx: Color(0xFF18141F),
    tx2: Color(0xFF5D5670),
    mu: Color(0xFF9B93AE),
    bg: Color(0xFFF7F4FF),
    gx: Color(0xD9FFFEFF),
    bd: Color(0xE8DED7F8),
    bd2: Color(0x407B4DFF),
  );

  static const _Palette _chocoNyangi = _Palette(
    pk: Color(0xFF7B4A2F),
    pkD: Color(0xFF4A2919),
    pkL: Color(0x247B4A2F),
    lv: Color(0xFF355C9A),
    lvD: Color(0xFF213B66),
    lvL: Color(0x20355C9A),
    lm: Color(0xFFF6EEDF),
    lmD: Color(0xFFD9C3A3),
    lmG: Color(0x57F6EEDF),
    og: Color(0xFF5B2E1A),
    tx: Color(0xFF2C1A13),
    tx2: Color(0xFF6E5A52),
    mu: Color(0xFFA4938B),
    bg: Color(0xFFFFFBF4),
    gx: Color(0xD9FFFDF9),
    bd: Color(0xE8E8DBCC),
    bd2: Color(0x40355C9A),
  );

  static const _Palette _eunsulNyangi = _Palette(
    pk: Color(0xFFFF9F1C),
    pkD: Color(0xFFC96A00),
    pkL: Color(0x24FF9F1C),
    lv: Color(0xFFA7E635),
    lvD: Color(0xFF6AA300),
    lvL: Color(0x24A7E635),
    lm: Color(0xFF2FAF5B),
    lmD: Color(0xFF1E7A3F),
    lmG: Color(0x572FAF5B),
    og: Color(0xFFFFC35C),
    tx: Color(0xFF21301D),
    tx2: Color(0xFF5F715A),
    mu: Color(0xFF9AAA93),
    bg: Color(0xFFFBFFF5),
    gx: Color(0xD9FEFFF9),
    bd: Color(0xE8DFF0D3),
    bd2: Color(0x40FF9F1C),
  );
}
