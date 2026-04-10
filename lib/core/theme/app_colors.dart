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
  static AppThemeMode _mode = AppThemeMode.lavender;

  // tint: alpha 색상 반환
  static Color tint(Color base, double alpha) => base.withValues(alpha: alpha);

  // 테마별 헤더 배경색
  static Color get headerBg {
    // 모리모노: 순백 배경 위 그레이 헤더
    if (_mode == AppThemeMode.moriMono) return _p.bd;
    // 쥐춘이: 슬레이트블루 강조
    if (_mode == AppThemeMode.jwiChuni) return Color.alphaBlend(_p.pk.withValues(alpha: 0.28), _p.bg);
    // 토도리 컨셉: pk 색을 0.22 alpha로 bg에 오버레이 → 테마 고유 색상이 헤더에 드러남
    return Color.alphaBlend(_p.pk.withValues(alpha: 0.22), _p.bg);
  }

  // 헤더 하단 구분선 색
  static Color get headerBorder {
    if (_mode == AppThemeMode.moriMono) return _p.lm;
    if (_mode == AppThemeMode.jwiChuni) return _p.pk.withValues(alpha: 0.35);
    return _p.pk.withValues(alpha: 0.30);
  }

  static void apply(AppThemeMode mode) {
    _mode = mode;
    switch (mode) {
      case AppThemeMode.lavender:    _p = _lavender;    break;
      case AppThemeMode.earthy:      _p = _earthy;      break;
      case AppThemeMode.moyangi:     _p = _moyangi;     break;
      case AppThemeMode.jwiChuni:    _p = _jwiChuni;    break;
      case AppThemeMode.todori:      _p = _todori;      break;
      case AppThemeMode.pinkRabbit:  _p = _pinkRabbit;  break;
      case AppThemeMode.chocoNyangi: _p = _chocoNyangi; break;
      case AppThemeMode.moriRed:     _p = _moriRed;     break;
      case AppThemeMode.moriGreen:   _p = _moriGreen;   break;
      case AppThemeMode.moriYellow:  _p = _moriYellow;  break;
      case AppThemeMode.moriNavy:    _p = _moriNavy;    break;
      case AppThemeMode.moriMono:    _p = _moriMono;    break;
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

  // 모리라벤더 — 전체 라벤더/연보라 계열
  static const _Palette _lavender = _Palette(
    pk: Color(0xFF9061F9),   // 미디엄 라벤더
    pkD: Color(0xFF6D28D9),
    pkL: Color(0x249061F9),
    lv: Color(0xFFA78BFA),   // 연한 라벤더
    lvD: Color(0xFF7C3AED),
    lvL: Color(0x24A78BFA),
    lm: Color(0xFFDDD6FE),   // 아주 연한 라벤더
    lmD: Color(0xFFC4B5FD),
    lmG: Color(0x57DDD6FE),
    og: Color(0xFFEC4899),   // 핑크 (대비/경고)
    tx: Color(0xFF1E1B4B),   // 딥 인디고
    tx2: Color(0xFF5B4E8A),
    mu: Color(0xFF9575CD),
    bg: Color(0xFFFCFAFF),   // 더 연한 라벤더 배경
    gx: Color(0xD9FAF8FF),
    bd: Color(0xE8E0D5F5),
    bd2: Color(0x309061F9),
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

  // 모리피치 — 전체 복숭아/살구 계열
  static const _Palette _moyangi = _Palette(
    pk: Color(0xFFFF8C69),   // 살몬 오렌지
    pkD: Color(0xFFE25C35),
    pkL: Color(0x24FF8C69),
    lv: Color(0xFFFFB39A),   // 연한 피치
    lvD: Color(0xFFFF7043),
    lvL: Color(0x24FFB39A),
    lm: Color(0xFFFFD9C8),   // 아주 연한 피치
    lmD: Color(0xFFFFAA8A),
    lmG: Color(0x57FFD9C8),
    og: Color(0xFFFF6B35),   // 브라이트 오렌지
    tx: Color(0xFF3D1505),   // 딥 브라운-레드
    tx2: Color(0xFF7A3020),
    mu: Color(0xFFBB8070),
    bg: Color(0xFFFFF5F0),   // 아주 연한 피치 배경
    gx: Color(0xD9FFF8F5),
    bd: Color(0xE8FFDDD0),
    bd2: Color(0x30FF8C69),
  );

  // 쥐춘이 테마 — 슬레이트블루(포인트) + 쿨 그레이(배경) — 크림팽이 웜크림과 온도 대비
  static const _Palette _jwiChuni = _Palette(
    pk: Color(0xFF4A6FA5),   // 슬레이트 블루 — 메인 컨셉 컬러
    pkD: Color(0xFF2D4E7E),
    pkL: Color(0x204A6FA5),
    lv: Color(0xFF6A8EBF),   // 미디엄 스틸 블루 (보조)
    lvD: Color(0xFF3D5E88),
    lvL: Color(0x206A8EBF),
    lm: Color(0xFFB0C4DE),   // 라이트 스틸 블루
    lmD: Color(0xFF708BA8),
    lmG: Color(0x57B0C4DE),
    og: Color(0xFFE07B52),   // 테라코타 (경고)
    tx: Color(0xFF1A2030),
    tx2: Color(0xFF4A5870),
    mu: Color(0xFF8A9BB0),
    bg: Color(0xFFF0F3F7),   // 쿨 블루-그레이 배경 (크림팽이 웜크림과 명확히 대비)
    gx: Color(0xD9F5F7FB),
    bd: Color(0xE8CDD6E8),
    bd2: Color(0x304A6FA5),
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

  static const _Palette _chocoNyangi = _Palette(
    pk: Color(0xFF7B4A2F),
    pkD: Color(0xFF4A2919),
    pkL: Color(0x247B4A2F),
    lv: Color(0xFF9B6B52),
    lvD: Color(0xFF7B4A2F),
    lvL: Color(0x209B6B52),
    lm: Color(0xFFF6EEDF),
    lmD: Color(0xFFD9C3A3),
    lmG: Color(0x57F6EEDF),
    og: Color(0xFF3D1508),
    tx: Color(0xFF2C1A13),
    tx2: Color(0xFF6E5A52),
    mu: Color(0xFFA4938B),
    bg: Color(0xFFFFFBF4),
    gx: Color(0xD9FFFDF9),
    bd: Color(0xE8E8DBCC),
    bd2: Color(0x407B4A2F),
  );

  // 모리레드 — 크림 배경 + 딥레드 포인트 + 검정 폰트
  static const _Palette _moriRed = _Palette(
    pk: Color(0xFFDC2626),   // 선명한 레드
    pkD: Color(0xFF991B1B),
    pkL: Color(0x20DC2626),
    lv: Color(0xFFEF4444),   // 코랄 레드
    lvD: Color(0xFFB91C1C),
    lvL: Color(0x20EF4444),
    lm: Color(0xFFFEE2E2),   // 연한 핑크-레드
    lmD: Color(0xFFFCA5A5),
    lmG: Color(0x57FEE2E2),
    og: Color(0xFFB45309),   // 앰버 (경고)
    tx: Color(0xFF111111),   // 순검정
    tx2: Color(0xFF555555),
    mu: Color(0xFF999999),
    bg: Color(0xFFFFF8E8),   // 크림 배경
    gx: Color(0xFFFFFCF5),
    bd: Color(0xFFEDE0CC),
    bd2: Color(0x30DC2626),
  );

  // 모리옐로우 — 전체 앰버/옐로우 계열
  static const _Palette _moriYellow = _Palette(
    pk: Color(0xFFF59E0B),   // amber-500
    pkD: Color(0xFFB45309),
    pkL: Color(0x20F59E0B),
    lv: Color(0xFFFBBF24),   // amber-400
    lvD: Color(0xFFD97706),
    lvL: Color(0x20FBBF24),
    lm: Color(0xFFFDE68A),   // amber-200
    lmD: Color(0xFFFCD34D),
    lmG: Color(0x57FDE68A),
    og: Color(0xFFD97706),   // amber-600
    tx: Color(0xFF1C1917),   // stone-950
    tx2: Color(0xFF44403C),
    mu: Color(0xFF78716C),
    bg: Color(0xFFFFFBEB),   // amber-50
    gx: Color(0xD9FFFDF5),
    bd: Color(0xE8FDE68A),
    bd2: Color(0x30F59E0B),
  );

  // 모리네이비 — 딥블루/네이비 계열
  static const _Palette _moriNavy = _Palette(
    pk: Color(0xFF1E40AF),   // blue-800
    pkD: Color(0xFF1E3A8A),
    pkL: Color(0x201E40AF),
    lv: Color(0xFF2563EB),   // blue-600
    lvD: Color(0xFF1D4ED8),
    lvL: Color(0x202563EB),
    lm: Color(0xFFBFDBFE),   // blue-200
    lmD: Color(0xFF93C5FD),
    lmG: Color(0x57BFDBFE),
    og: Color(0xFF0369A1),   // sky-700
    tx: Color(0xFF0F172A),   // 거의 블랙
    tx2: Color(0xFF1E3A8A),
    mu: Color(0xFF60A5FA),   // blue-400
    bg: Color(0xFFF0F6FF),   // 아주 연한 블루
    gx: Color(0xD9F5F9FF),
    bd: Color(0xE8BFDBFE),
    bd2: Color(0x301E40AF),
  );

  // 모리모노 — 순백 배경 + 그레이 헤더 (모노크롬)
  static const _Palette _moriMono = _Palette(
    pk: Color(0xFF374151),   // gray-700
    pkD: Color(0xFF1F2937),
    pkL: Color(0x20374151),
    lv: Color(0xFF6B7280),   // gray-500
    lvD: Color(0xFF4B5563),
    lvL: Color(0x206B7280),
    lm: Color(0xFFD1D5DB),   // gray-300
    lmD: Color(0xFF9CA3AF),
    lmG: Color(0x57D1D5DB),
    og: Color(0xFF4B5563),   // gray-600
    tx: Color(0xFF111827),   // gray-900
    tx2: Color(0xFF374151),
    mu: Color(0xFF9CA3AF),
    bg: Color(0xFFFFFFFF),   // 순백
    gx: Color(0xFFFFFFFF),
    bd: Color(0xFFE5E7EB),   // gray-200 — 헤더 색으로 사용
    bd2: Color(0xFFD1D5DB),
  );

  // 모리그린 — 전체 그린 계열 (모리핑크 스타일)
  static const _Palette _moriGreen = _Palette(
    pk: Color(0xFF16A34A),   // 비비드 그린
    pkD: Color(0xFF14532D),
    pkL: Color(0x2416A34A),
    lv: Color(0xFF4ADE80),   // 라이트 그린
    lvD: Color(0xFF15803D),
    lvL: Color(0x244ADE80),
    lm: Color(0xFFBBF7D0),   // 아주 연한 그린
    lmD: Color(0xFF86EFAC),
    lmG: Color(0x57BBF7D0),
    og: Color(0xFF65A30D),   // 옐로우-그린 (경고)
    tx: Color(0xFF052E16),   // 딥 다크 그린
    tx2: Color(0xFF166534),
    mu: Color(0xFF6EBF8A),
    bg: Color(0xFFF0FDF4),   // 아주 연한 그린 배경
    gx: Color(0xD9F0FFF4),
    bd: Color(0xE8BBF7D0),
    bd2: Color(0x3016A34A),
  );

}
