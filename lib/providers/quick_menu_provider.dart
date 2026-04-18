import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants/subscription_constants.dart';

class QuickMenuItem {
  final int iconCode;
  final String label;
  final String route;
  const QuickMenuItem({required this.iconCode, required this.label, required this.route});
}

class QuickMenuNotifier extends StateNotifier<List<QuickMenuItem>> {
  QuickMenuNotifier() : super(_readSaved());

  static List<QuickMenuItem> _readSaved() {
    if (kIsWeb) return [];
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('quick_menu_items');
      if (raw == null) return [];
      final list = raw['items'] as List?;
      if (list == null) return [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return QuickMenuItem(
          iconCode: (m['icon'] as num).toInt(),
          label: m['label'] as String,
          route: m['route'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxUser);
    await box.put('quick_menu_items', {
      'items': state
          .map((e) => {'icon': e.iconCode, 'label': e.label, 'route': e.route})
          .toList(),
    });
  }

  Future<void> addItem(QuickMenuItem item) async {
    if (state.any((e) => e.route == item.route)) return;
    state = [...state, item];
    await _save();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= state.length) return;
    final updated = [...state];
    updated.removeAt(index);
    state = updated;
    await _save();
  }

  Future<void> clear() async {
    state = [];
    await _save();
  }
}

final quickMenuProvider = StateNotifierProvider<QuickMenuNotifier, List<QuickMenuItem>>(
  (ref) => QuickMenuNotifier(),
);
