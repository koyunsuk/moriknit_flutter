import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

enum DefaultAvatarPreset { moyangi, dalgomi, kimdochi, jwichuni }

extension DefaultAvatarPresetExt on DefaultAvatarPreset {
  String get label {
    switch (this) {
      case DefaultAvatarPreset.moyangi:
        return '모냥이';
      case DefaultAvatarPreset.dalgomi:
        return '달곰이';
      case DefaultAvatarPreset.kimdochi:
        return '김도치';
      case DefaultAvatarPreset.jwichuni:
        return '쥐춘이';
    }
  }

  String get labelEn {
    switch (this) {
      case DefaultAvatarPreset.moyangi:
        return 'Moyangi';
      case DefaultAvatarPreset.dalgomi:
        return 'Dalgomi';
      case DefaultAvatarPreset.kimdochi:
        return 'Kimdochi';
      case DefaultAvatarPreset.jwichuni:
        return 'JwiChuni';
    }
  }
}

class AvatarPresetNotifier extends StateNotifier<DefaultAvatarPreset> {
  AvatarPresetNotifier() : super(_readSaved());

  static DefaultAvatarPreset _readSaved() {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('settings');
      final saved = raw == null ? null : raw['avatar_preset'] as String?;
      return DefaultAvatarPreset.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => DefaultAvatarPreset.moyangi,
      );
    } catch (_) {
      return DefaultAvatarPreset.moyangi;
    }
  }

  Future<void> setPreset(DefaultAvatarPreset preset) async {
    state = preset;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    final current = Map<String, dynamic>.from(
      box.get('settings') ?? <String, dynamic>{},
    );
    current['avatar_preset'] = preset.name;
    await box.put('settings', current);
  }
}

final avatarPresetProvider =
    StateNotifierProvider<AvatarPresetNotifier, DefaultAvatarPreset>((ref) {
  return AvatarPresetNotifier();
});
