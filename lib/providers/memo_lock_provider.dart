import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _kBoxName = 'memo_lock_box';
const _kLockEnabled = 'memo_lock_enabled';
const _kLockPin = 'memo_lock_pin';

class MemoLockNotifier extends StateNotifier<bool> {
  MemoLockNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = await Hive.openBox(_kBoxName);
      state = box.get(_kLockEnabled, defaultValue: false) as bool;
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    final box = await Hive.openBox(_kBoxName);
    await box.put(_kLockEnabled, value);
    state = value;
  }

  Future<bool> isEnabled() async {
    final box = await Hive.openBox(_kBoxName);
    return box.get(_kLockEnabled, defaultValue: false) as bool;
  }

  Future<bool> hasPin() async {
    final box = await Hive.openBox(_kBoxName);
    final pin = box.get(_kLockPin, defaultValue: '') as String;
    return pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final box = await Hive.openBox(_kBoxName);
    await box.put(_kLockPin, pin);
  }

  Future<bool> verifyPin(String input) async {
    final box = await Hive.openBox(_kBoxName);
    final stored = box.get(_kLockPin, defaultValue: '') as String;
    return stored == input;
  }

  Future<void> clearPin() async {
    final box = await Hive.openBox(_kBoxName);
    await box.delete(_kLockPin);
    await box.put(_kLockEnabled, false);
    state = false;
  }
}

final memoLockProvider = StateNotifierProvider<MemoLockNotifier, bool>(
  (ref) => MemoLockNotifier(),
);
