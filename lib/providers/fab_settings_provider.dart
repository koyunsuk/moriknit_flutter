import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

class FabSettings {
  final bool transparent;
  final double bottomOffset; // body Stack 하단 기준 px

  const FabSettings({
    this.transparent = true,
    this.bottomOffset = 24.0,
  });

  FabSettings copyWith({bool? transparent, double? bottomOffset}) => FabSettings(
        transparent: transparent ?? this.transparent,
        bottomOffset: bottomOffset ?? this.bottomOffset,
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
}

final fabSettingsProvider =
    StateNotifierProvider<FabSettingsNotifier, FabSettings>((ref) => FabSettingsNotifier());
