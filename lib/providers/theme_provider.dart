import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

enum AppThemeMode {
  lavender,
  earthy,
  monochrome,
  moyangi,
  jwiChuni,
  todori,
  pinkRabbit,
  creamSnail,
  jimungmungi,
  chocoNyangi,
  eunsulNyangi,
}

extension AppThemeModeExt on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.lavender:
        return '모리니트 테마';
      case AppThemeMode.earthy:
        return '달곰이의 테마';
      case AppThemeMode.monochrome:
        return '김도치쌤 테마';
      case AppThemeMode.moyangi:
        return '모냥이의 테마';
      case AppThemeMode.jwiChuni:
        return '쥐춘이의 테마';
      case AppThemeMode.todori:
        return '토도리의 테마';
      case AppThemeMode.pinkRabbit:
        return '핑크 왕자테마';
      case AppThemeMode.creamSnail:
        return '크림팽이 테마';
      case AppThemeMode.jimungmungi:
        return '지멍뭉이 테마';
      case AppThemeMode.chocoNyangi:
        return '초코냥이 테마';
      case AppThemeMode.eunsulNyangi:
        return '은설이냥 테마';
    }
  }

  String get labelEn {
    switch (this) {
      case AppThemeMode.lavender:
        return 'MoriKnit Theme';
      case AppThemeMode.earthy:
        return 'Dalgomi Theme';
      case AppThemeMode.monochrome:
        return 'Kimdochi Theme';
      case AppThemeMode.moyangi:
        return 'Moyangi Theme';
      case AppThemeMode.jwiChuni:
        return 'Jwichuni Theme';
      case AppThemeMode.todori:
        return 'Todori Theme';
      case AppThemeMode.pinkRabbit:
        return 'Pink Prince Theme';
      case AppThemeMode.creamSnail:
        return 'Cream Snail Theme';
      case AppThemeMode.jimungmungi:
        return 'Jimungmungi Theme';
      case AppThemeMode.chocoNyangi:
        return 'Choco Nyangi Theme';
      case AppThemeMode.eunsulNyangi:
        return 'Eunsul Nyangi Theme';
    }
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeNotifier() : super(_readSaved());

  static AppThemeMode _readSaved() {
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
