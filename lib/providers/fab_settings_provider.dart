import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

class FabSettings {
  final bool transparent;
  final double bottomOffset; // body Stack 하단 기준 px
  final bool particleEnabled; // 헤더 파티클 효과 on/off
  final String particleType; // 파티클 종류: 'mori', 'heart', 'cat', 'star', 'rainbow'

  const FabSettings({
    this.transparent = true,
    this.bottomOffset = 24.0,
    this.particleEnabled = true,
    this.particleType = 'mori',
  });

  FabSettings copyWith({bool? transparent, double? bottomOffset, bool? particleEnabled, String? particleType}) => FabSettings(
        transparent: transparent ?? this.transparent,
        bottomOffset: bottomOffset ?? this.bottomOffset,
        particleEnabled: particleEnabled ?? this.particleEnabled,
        particleType: particleType ?? this.particleType,
      );
}

class FabSettingsNotifier extends StateNotifier<FabSettings> {
  FabSettingsNotifier() : super(_readSaved());

  static FabSettings _readSaved() {
    if (kIsWeb) return const FabSettings();
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('fab_settings');
      if (raw == null) return const FabSettings();
      return FabSettings(
        transparent: raw['transparent'] as bool? ?? true,
        bottomOffset: (raw['bottom_offset'] as num?)?.toDouble() ?? 24.0,
        particleEnabled: raw['particle_enabled'] as bool? ?? true,
        particleType: raw['particle_type'] as String? ?? 'mori',
      );
    } catch (_) {
      return const FabSettings();
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    await box.put('fab_settings', {
      'transparent': state.transparent,
      'bottom_offset': state.bottomOffset,
      'particle_enabled': state.particleEnabled,
      'particle_type': state.particleType,
    });
  }

  Future<void> setTransparent(bool value) async {
    state = state.copyWith(transparent: value);
    await _save();
  }

  Future<void> setPreset(String preset) async {
    final offset = preset == 'top' ? 460.0 : preset == 'middle' ? 230.0 : 24.0;
    state = state.copyWith(bottomOffset: offset);
    await _save();
  }

  Future<void> setBottomOffset(double value) async {
    state = state.copyWith(bottomOffset: value.clamp(8.0, 550.0));
    await _save();
  }

  Future<void> setParticleEnabled(bool value) async {
    state = state.copyWith(particleEnabled: value);
    await _save();
  }

  Future<void> setParticleType(String type) async {
    state = state.copyWith(particleType: type);
    await _save();
  }
}

final fabSettingsProvider =
    StateNotifierProvider<FabSettingsNotifier, FabSettings>((ref) => FabSettingsNotifier());
