import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

/// 앱 전역 폰트 옵션 (한국어 호환 11종 — #756 확장).
enum AppFont {
  notoSansKr,
  gowunDodum,
  nanumPenScript,
  gugi,
  jua,
  blackHanSans,
  doHyeon,
  hiMelody,
  sunflower,
  cuteFont,
  singleDay,
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
      case AppFont.blackHanSans:   return 'black_han_sans';
      case AppFont.doHyeon:        return 'do_hyeon';
      case AppFont.hiMelody:       return 'hi_melody';
      case AppFont.sunflower:      return 'sunflower';
      case AppFont.cuteFont:       return 'cute_font';
      case AppFont.singleDay:      return 'single_day';
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
      case AppFont.blackHanSans:   return 'Black Han Sans';
      case AppFont.doHyeon:        return 'Do Hyeon';
      case AppFont.hiMelody:       return 'Hi Melody';
      case AppFont.sunflower:      return 'Sunflower';
      case AppFont.cuteFont:       return 'Cute Font';
      case AppFont.singleDay:      return 'Single Day';
    }
  }

  String get labelKo {
    switch (this) {
      case AppFont.notoSansKr:     return '기본 (노토 산스)';
      case AppFont.gowunDodum:     return '고운 돋움';
      case AppFont.nanumPenScript: return '나눔 손글씨 펜';
      case AppFont.gugi:           return '꾸기';
      case AppFont.jua:            return '주아';
      case AppFont.blackHanSans:   return '블랙 한 산스';
      case AppFont.doHyeon:        return '도현';
      case AppFont.hiMelody:       return '하이멜로디';
      case AppFont.sunflower:      return '선플라워';
      case AppFont.cuteFont:       return '큐트폰트';
      case AppFont.singleDay:      return '싱글데이';
    }
  }

  String get labelEn {
    switch (this) {
      case AppFont.notoSansKr:     return 'Default (Noto Sans)';
      case AppFont.gowunDodum:     return 'Gowun Dodum';
      case AppFont.nanumPenScript: return 'Nanum Pen Script';
      case AppFont.gugi:           return 'Gugi';
      case AppFont.jua:            return 'Jua';
      case AppFont.blackHanSans:   return 'Black Han Sans';
      case AppFont.doHyeon:        return 'Do Hyeon';
      case AppFont.hiMelody:       return 'Hi Melody';
      case AppFont.sunflower:      return 'Sunflower';
      case AppFont.cuteFont:       return 'Cute Font';
      case AppFont.singleDay:      return 'Single Day';
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
