// lib/core/cache/local_cache.dart
//
// #685 — 모바일 영속 캐시 공통 유틸. Hive 기반.
// 웹에서는 no-op (Firestore IndexedDB persistence가 대체).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';

class LocalCache<T> {
  LocalCache({
    required this.boxName,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
  });

  final String boxName;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final String Function(T) idOf;

  Box<Map>? _box;

  Box<Map>? _open() {
    if (kIsWeb) return null;
    if (_box != null && _box!.isOpen) return _box;
    if (!Hive.isBoxOpen(boxName)) return null;
    _box = Hive.box<Map>(boxName);
    return _box;
  }

  /// 캐시 전체 읽기. 손상/빈 박스 시 빈 리스트 반환 (예외 X).
  List<T> readAll() {
    final box = _open();
    if (box == null) return const [];
    try {
      return box.values
          .map((m) => fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 단건 읽기.
  T? readOne(String id) {
    final box = _open();
    if (box == null) return null;
    try {
      final raw = box.get(id);
      if (raw == null) return null;
      return fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// 전체 덮어쓰기 (clear → putAll).
  Future<void> writeAll(List<T> items) async {
    final box = _open();
    if (box == null) return;
    try {
      await box.clear();
      final entries = <String, Map<String, dynamic>>{
        for (final item in items) idOf(item): toJson(item),
      };
      await box.putAll(entries);
    } catch (_) {
      // 캐시 실패는 무음 (UX 영향 X)
    }
  }

  /// 단건 쓰기.
  Future<void> writeOne(T item) async {
    final box = _open();
    if (box == null) return;
    try {
      await box.put(idOf(item), toJson(item));
    } catch (_) {}
  }

  Future<void> clear() async {
    final box = _open();
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {}
  }

  bool get isEmpty {
    final box = _open();
    return box == null || box.isEmpty;
  }
}
