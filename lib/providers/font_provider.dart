import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

/// 앱 전역 폰트 옵션 (한국어 호환 5종).
///
/// - [notoSansKr]: 기본. 외형 회귀 0 — 기존 fallbackFonts와 동일 톤.
/// - [gowunDodum]: 둥글둥글 친근.
/// - [nanumPenScript]: 손글씨 펜.
/// - [gugi]: 발랄/캐주얼.
/// - [jua]: 또렷한 둥근 헤드라인체.
enum AppFont {
  notoSansKr,
  gowunDodum,
  nanumPenScript,
  gugi,
  jua,
}

extension AppFontExt on AppFont {
  /// Hive 저장용 키.
  String get storageKey {
    switch (this) {
      case AppFont.notoSansKr:     return 'noto_sans_kr';
      case AppFont.gowunDodum:     return 'gowun_dodum';
      case AppFont.nanumPenScript: return 'nanum_pen_script';
      case AppFont.gugi:           return 'gugi';
      case AppFont.jua:            return 'jua';
    }
  }

  /// google_fonts API 메서드명 (GoogleFonts.getFont 인자).
  /// 한국어 패밀리는 띄어쓰기 포함된 정식 이름 사용.
  String get googleFontFamily {
    switch (this) {
      case AppFont.notoSansKr:     return 'Noto Sans KR';
      case AppFont.gowunDodum:     return 'Gowun Dodum';
      case AppFont.nanumPenScript: return 'Nanum Pen Script';
      case AppFont.gugi:           return 'Gugi';
      case AppFont.jua:            return 'Jua';
    }
  }

  String get labelKo {
    switch (this) {
      case AppFont.notoSansKr:     return '기본 (노토 산스)';
      case AppFont.gowunDodum:     return '고운 돋움';
      case AppFont.nanumPenScript: return '나눔 손글씨 펜';
      case AppFont.gugi:           return '꾸기';
      case AppFont.jua:            return '주아';
    }
  }

  String get labelEn {
    switch (this) {
      case AppFont.notoSansKr:     return 'Default (Noto Sans)';
      case AppFont.gowunDodum:     return 'Gowun Dodum';
      case AppFont.nanumPenScript: return 'Nanum Pen Script';
      case AppFont.gugi:           return 'Gugi';
      case AppFont.jua:            return 'Jua';
    }
  }
}

class FontNotifier extends StateNotifier<AppFont> {
  FontNotifier() : super(_readSaved());

  static AppFont _readSaved() {
    if (kIsWeb) return AppFont.notoSansKr;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('settings');
      final saved = raw == null ? null : raw['app_font'] as String?;
      return AppFont.values.firstWhere(
        (e) => e.storageKey == saved,
        orElse: () => AppFont.notoSansKr,
      );
    } catch (_) {
      return AppFont.notoSansKr;
    }
  }

  Future<void> setFont(AppFont font) async {
    state = font;
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    final current = Map<String, dynamic>.from(box.get('settings') ?? <String, dynamic>{});
    current['app_font'] = font.storageKey;
    await box.put('settings', current);
  }

  Future<void> resetFont() async {
    await setFont(AppFont.notoSansKr);
  }
}

final fontProvider = StateNotifierProvider<FontNotifier, AppFont>((ref) {
  return FontNotifier();
});
