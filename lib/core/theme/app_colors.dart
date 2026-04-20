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

  static bool get isMono => _mode == AppThemeMode.moriMono;

  // tint: alpha 색상 반환
  static Color tint(Color base, double alpha) => base.withValues(alpha: alpha);

  // 테마별 헤더 배경색
  static Color get headerBg {
    // 모리모노: 순백 배경 위 그레이 헤더
    if (_mode == AppThemeMode.moriMono) return _p.bd;
    // 모리크림: 크림색 헤더
    if (_mode == AppThemeMode.moriCream) return _p.bg;
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
      case AppThemeMode.moriCream:   _p = _moriCream;   break;
      case AppThemeMode.moriMint:    _p = _moriMint;    break;
      case AppThemeMode.moriLime:    _p = _moriLime;    break;
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
  static LinearGradient get bgGradient => isMono
      ? LinearGradient(colors: [_p.bg, _p.bg])
      : LinearGradient(
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
    pk: Color(0xFF7C3AED),   // 미디엄 라벤더
    pkD: Color(0xFF5B21B6),
    pkL: Color(0x247C3AED),
    lv: Color(0xFF8B5CF6),   // 라벤더 메인
    lvD: Color(0xFF6D28D9),
    lvL: Color(0x248B5CF6),
    lm: Color(0xFFDDD6FE),   // 아주 연한 라벤더
    lmD: Color(0xFFC4B5FD),
    lmG: Color(0x57DDD6FE),
    og: Color(0xFFEC4899),   // 핑크 (대비/경고)
    tx: Color(0xFF1E1B4B),   // 딥 인디고
    tx2: Color(0xFF4C3D8A),
    mu: Color(0xFF7C5CBF),
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

  // 모리크림 — 크림 배경 + 딥블루 포인트
  static const _Palette _moriCream = _Palette(
    pk: Color(0xFF1D4ED8),   // 딥 블루
    pkD: Color(0xFF1E3A8A),
    pkL: Color(0x201D4ED8),
    lv: Color(0xFF2563EB),   // 미디엄 블루
    lvD: Color(0xFF1D4ED8),
    lvL: Color(0x202563EB),
    lm: Color(0xFF3B82F6),   // 블루
    lmD: Color(0xFF1D4ED8),
    lmG: Color(0x573B82F6),
    og: Color(0xFF1E40AF),   // 딥 네이비
    tx: Color(0xFF0F172A),
    tx2: Color(0xFF334155),
    mu: Color(0xFF64748B),
    bg: Color(0xFFFFF8E8),   // 크림 배경
    gx: Color(0xD9FFFCF0),
    bd: Color(0xE8E8D8B8),
    bd2: Color(0x301D4ED8),
  );

  // 모리옐로우 — 레몬옐로우 파스텔 (갈색/앰버 없음)
  static const _Palette _moriYellow = _Palette(
    pk: Color(0xFFFACC15),   // yellow-400 (선명한 레몬옐로우)
    pkD: Color(0xFFEAB308),  // yellow-500 (선명한 옐로우, 골드 아님)
    pkL: Color(0x20FACC15),
    lv: Color(0xFFFDE047),   // yellow-300 (밝은 옐로우)
    lvD: Color(0xFFFACC15),
    lvL: Color(0x20FDE047),
    lm: Color(0xFFFDE047),   // yellow-300 — FAB 선명한 옐로우
    lmD: Color(0xFFFACC15),
    lmG: Color(0x57FDE047),
    og: Color(0xFFEAB308),   // yellow-500
    tx: Color(0xFF1C1917),   // 거의 블랙 (옐로우와 대비)
    tx2: Color(0xFF44403C),
    mu: Color(0xFF78716C),
    bg: Color(0xFFFEFCE8),   // yellow-50
    gx: Color(0xD9FEFDF0),
    bd: Color(0xE8FEF08A),
    bd2: Color(0x30FACC15),
  );

  // 모리네이비 — 딥다크 네이비 계열 (스틸과 명확히 구분)
  static const _Palette _moriNavy = _Palette(
    pk: Color(0xFF1E3A8A),   // blue-900 (진한 네이비)
    pkD: Color(0xFF172554),  // 더 어두운 네이비
    pkL: Color(0x201E3A8A),
    lv: Color(0xFF1D4ED8),   // blue-700
    lvD: Color(0xFF1E3A8A),
    lvL: Color(0x201D4ED8),
    lm: Color(0xFF1E40AF),   // blue-800 — FAB이 네이비색으로
    lmD: Color(0xFF1E3A8A),
    lmG: Color(0x571E40AF),
    og: Color(0xFF7C3AED),   // 퍼플 액센트 (네이비와 대비)
    tx: Color(0xFF0F172A),   // 거의 블랙
    tx2: Color(0xFF1E3A8A),
    mu: Color(0xFF3B82F6),   // blue-500
    bg: Color(0xFFF0F4FF),   // 쿨 라벤더-블루 배경
    gx: Color(0xD9F4F6FF),
    bd: Color(0xE8C7D2FE),
    bd2: Color(0x301E3A8A),
  );

  // 모리모노 — 순백 배경 + 검정 포인트 (극명한 흑백 대비)
  static const _Palette _moriMono = _Palette(
    pk: Color(0xFF111111),   // 거의 검정 (포인트)
    pkD: Color(0xFF000000),  // 순검정 (강조)
    pkL: Color(0x20111111),
    lv: Color(0xFF333333),   // 다크 그레이
    lvD: Color(0xFF111111),
    lvL: Color(0x20333333),
    lm: Color(0xFFE5E7EB),   // 라이트 그레이 (배경 구분)
    lmD: Color(0xFF9CA3AF),
    lmG: Color(0x57E5E7EB),
    og: Color(0xFF374151),   // gray-700
    tx: Color(0xFF000000),   // 순검정 텍스트
    tx2: Color(0xFF374151),
    mu: Color(0xFF6B7280),
    bg: Color(0xFFFFFFFF),   // 순백 배경 (오버레이 없음)
    gx: Color(0xFFFFFFFF),   // 순백
    bd: Color(0xFFE5E7EB),   // gray-200
    bd2: Color(0xFFD1D5DB),
  );

  // 모리민트 — 민트/틸 계열
  static const _Palette _moriMint = _Palette(
    pk: Color(0xFF06B6D4),   // cyan-500
    pkD: Color(0xFF0E7490),  // cyan-700
    pkL: Color(0x1406B6D4),
    lv: Color(0xFF22D3EE),   // cyan-400
    lvD: Color(0xFF0891B2),  // cyan-600
    lvL: Color(0x1422D3EE),
    lm: Color(0xFFA5F3FC),   // cyan-200
    lmD: Color(0xFF67E8F9),  // cyan-300
    lmG: Color(0x57A5F3FC),
    og: Color(0xFF0284C7),   // sky-600 (대비)
    tx: Color(0xFF083344),   // cyan-950
    tx2: Color(0xFF155E75),  // cyan-800
    mu: Color(0xFF0E7490),   // cyan-700 (가독성 확보)
    bg: Color(0xFFECFEFF),   // cyan-50
    gx: Color(0xD9F0FDFF),
    bd: Color(0xE8A5F3FC),   // cyan-200
    bd2: Color(0x3006B6D4),
  );

  // 모리라임 — 라임/연두 계열
  static const _Palette _moriLime = _Palette(
    pk: Color(0xFF65A30D),   // lime-600 (더 진해서 가독성 확보)
    pkD: Color(0xFF4D7C0F),  // lime-700
    pkL: Color(0x2065A30D),
    lv: Color(0xFF84CC16),   // lime-400
    lvD: Color(0xFF65A30D),  // lime-600
    lvL: Color(0x2084CC16),
    lm: Color(0xFFD9F99D),   // lime-200
    lmD: Color(0xFFBEF264),  // lime-300
    lmG: Color(0x57D9F99D),
    og: Color(0xFF16A34A),   // green-600 (대비)
    tx: Color(0xFF1A2E05),   // lime-950
    tx2: Color(0xFF365314),  // lime-900
    mu: Color(0xFF65A30D),   // lime-600 (가독성 확보)
    bg: Color(0xFFF7FEE7),   // lime-50
    gx: Color(0xD9FAFFF0),
    bd: Color(0xE8ECFCCB),   // lime-100
    bd2: Color(0x3065A30D),
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
