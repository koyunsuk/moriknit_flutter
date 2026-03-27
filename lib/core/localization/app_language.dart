import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:moriknit_flutter/core/constants/subscription_constants.dart';
import 'package:moriknit_flutter/core/localization/app_strings.dart';
import 'package:moriknit_flutter/core/localization/strings/app_strings_en.dart';
import 'package:moriknit_flutter/core/localization/strings/app_strings_ko.dart';

enum AppLanguage { ko, en }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.ko:
        return 'ko';
      case AppLanguage.en:
        return 'en';
    }
  }

  Locale get locale => Locale(code);

  String get label {
    switch (this) {
      case AppLanguage.ko:
        return '한국어';
      case AppLanguage.en:
        return 'English';
    }
  }

  bool get isKorean => this == AppLanguage.ko;
}

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(_readSaved());

  static AppLanguage _readSaved() {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('settings');
      final code = raw == null ? null : raw['language'] as String?;
      return _fromCode(code);
    } catch (_) {
      return AppLanguage.ko;
    }
  }

  static AppLanguage _fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLanguage.en;
      case 'ko':
      default:
        return AppLanguage.ko;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    final current = Map<String, dynamic>.from(box.get('settings') ?? <String, dynamic>{});
    current['language'] = language.code;
    await box.put('settings', current);
  }
}

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

final appLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(appLanguageProvider).locale;
});

final supportedAppLocales = <Locale>[
  const Locale('ko'),
  const Locale('en'),
];

Locale resolveSupportedLocale(Locale? locale) {
  if (locale == null) return const Locale('ko');
  return locale.languageCode == 'en' ? const Locale('en') : const Locale('ko');
}

AppStrings lookupAppStrings(AppLanguage language) {
  switch (language) {
    case AppLanguage.ko:
      return const AppStringsKo();
    case AppLanguage.en:
      return const AppStringsEn();
  }
}

final appStringsProvider = Provider<AppStrings>((ref) {
  return lookupAppStrings(ref.watch(appLanguageProvider));
});

