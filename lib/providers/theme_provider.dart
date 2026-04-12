import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

enum AppThemeMode {
  lavender,
  earthy,
  moyangi,
  jwiChuni,
  todori,
  pinkRabbit,
  chocoNyangi,
  moriRed,
  moriGreen,
  moriYellow,
  moriNavy,
  moriMono,
  moriCream,
  moriMint,
  moriLime,
}

extension AppThemeModeExt on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.lavender:    return '모리라벤더';
      case AppThemeMode.earthy:      return '모리테라코타';
      case AppThemeMode.moyangi:     return '모리피치';
      case AppThemeMode.jwiChuni:    return '모리스틸';
      case AppThemeMode.todori:      return '모리골드';
      case AppThemeMode.pinkRabbit:  return '모리핑크';
      case AppThemeMode.chocoNyangi: return '모리초코';
      case AppThemeMode.moriRed:     return '모리레드';
      case AppThemeMode.moriGreen:   return '모리그린';
      case AppThemeMode.moriYellow:  return '모리옐로우';
      case AppThemeMode.moriNavy:    return '모리네이비';
      case AppThemeMode.moriMono:    return '모리모노';
      case AppThemeMode.moriCream:   return '모리크림';
      case AppThemeMode.moriMint:    return '모리민트';
      case AppThemeMode.moriLime:    return '모리라임';
    }
  }

  String get labelEn {
    switch (this) {
      case AppThemeMode.lavender:    return 'MoriLavender';
      case AppThemeMode.earthy:      return 'MoriTerra';
      case AppThemeMode.moyangi:     return 'MoriPeach';
      case AppThemeMode.jwiChuni:    return 'MoriSteel';
      case AppThemeMode.todori:      return 'MoriGold';
      case AppThemeMode.pinkRabbit:  return 'MoriPink';
      case AppThemeMode.chocoNyangi: return 'MoriChoco';
      case AppThemeMode.moriRed:     return 'MoriRed';
      case AppThemeMode.moriGreen:   return 'MoriGreen';
      case AppThemeMode.moriYellow:  return 'MoriYellow';
      case AppThemeMode.moriNavy:    return 'MoriNavy';
      case AppThemeMode.moriMono:    return 'MoriMono';
      case AppThemeMode.moriCream:   return 'MoriCream';
      case AppThemeMode.moriMint:    return 'MoriMint';
      case AppThemeMode.moriLime:    return 'MoriLime';
    }
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeNotifier() : super(_readSaved());

  static AppThemeMode _readSaved() {
    if (kIsWeb) return AppThemeMode.lavender;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('settings');
      final saved = raw == null ? null : raw['theme_mode'] as String?;
      return AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.lavender,
      );
    } catch (_) {
      return AppThemeMode.lavender;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    final current = Map<String, dynamic>.from(box.get('settings') ?? <String, dynamic>{});
    current['theme_mode'] = mode.name;
    await box.put('settings', current);
  }

  Future<void> resetTheme() async {
    await setTheme(AppThemeMode.lavender);
  }
}

final appThemeProvider = StateNotifierProvider<AppThemeNotifier, AppThemeMode>((ref) {
  return AppThemeNotifier();
});
