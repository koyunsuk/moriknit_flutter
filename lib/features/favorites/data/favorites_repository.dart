// lib/features/favorites/data/favorites_repository.dart
//
// 홈 즐겨찾기 시스템 — 사용자가 별표한 화면 목록 관리.
// Hive box: 'favorites'. 키 = screenId, 값 = Map.
// 웹은 Hive 미사용이므로 In-memory 폴백.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/subscription_constants.dart';

@immutable
class FavoriteScreen {
  /// 라우트 식별자 (`swatch_list`, `counter_list`, `gauge` 등).
  final String screenId;

  /// 카드에 표시할 이름.
  final String title;

  /// 카드 아이콘.
  final IconData icon;

  /// 진입 라우트 경로 (`/swatch`, `/counters` 등).
  final String path;

  /// 카드 색상 (C.lv, C.pk, C.og 등).
  final Color accent;

  /// 추가된 시각.
  final DateTime addedAt;

  const FavoriteScreen({
    required this.screenId,
    required this.title,
    required this.icon,
    required this.path,
    required this.accent,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'screenId': screenId,
      'title': title,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
      'path': path,
      'accent': accent.toARGB32(),
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }

  static FavoriteScreen? fromMap(Map<dynamic, dynamic> raw) {
    try {
      final map = Map<String, dynamic>.from(raw);
      final screenId = map['screenId'] as String?;
      final title = map['title'] as String?;
      final codePoint = map['iconCodePoint'] as int?;
      final path = map['path'] as String?;
      final accentArgb = map['accent'] as int?;
      final addedAt = map['addedAt'] as int?;
      if (screenId == null || title == null || codePoint == null ||
          path == null || accentArgb == null || addedAt == null) {
        return null;
      }
      return FavoriteScreen(
        screenId: screenId,
        title: title,
        icon: IconData(
          codePoint,
          fontFamily: map['iconFontFamily'] as String?,
          fontPackage: map['iconFontPackage'] as String?,
          matchTextDirection: map['iconMatchTextDirection'] as bool? ?? false,
        ),
        path: path,
        accent: Color(accentArgb),
        addedAt: DateTime.fromMillisecondsSinceEpoch(addedAt),
      );
    } catch (_) {
      return null;
    }
  }
}

class FavoritesRepository {
  FavoritesRepository();

  // 웹용 In-memory 폴백 (Hive 미사용).
  static final Map<String, FavoriteScreen> _webStore = <String, FavoriteScreen>{};
  static final StreamController<List<FavoriteScreen>> _webController =
      StreamController<List<FavoriteScreen>>.broadcast();

  Box<Map>? get _box {
    if (kIsWeb) return null;
    if (!Hive.isBoxOpen(SubscriptionConstants.boxFavorites)) return null;
    return Hive.box<Map>(SubscriptionConstants.boxFavorites);
  }

  List<FavoriteScreen> _readAllSync() {
    if (kIsWeb) {
      final list = _webStore.values.toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
      return list;
    }
    final box = _box;
    if (box == null) return const [];
    final items = <FavoriteScreen>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final item = FavoriteScreen.fromMap(raw);
      if (item != null) items.add(item);
    }
    items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return items;
  }

  /// 즐겨찾기 추가 (이미 있으면 갱신).
  Future<void> add(FavoriteScreen item) async {
    if (kIsWeb) {
      _webStore[item.screenId] = item;
      _webController.add(_readAllSync());
      return;
    }
    final box = _box;
    if (box == null) return;
    await box.put(item.screenId, item.toMap());
  }

  /// 즐겨찾기 제거.
  Future<void> remove(String screenId) async {
    if (kIsWeb) {
      _webStore.remove(screenId);
      _webController.add(_readAllSync());
      return;
    }
    final box = _box;
    if (box == null) return;
    await box.delete(screenId);
  }

  /// 토글 — 있으면 제거, 없으면 추가.
  Future<bool> toggle(FavoriteScreen item) async {
    final exists = await isFavorite(item.screenId);
    if (exists) {
      await remove(item.screenId);
      return false;
    }
    await add(item);
    return true;
  }

  /// 특정 화면이 즐겨찾기인지 확인.
  Future<bool> isFavorite(String screenId) async {
    if (kIsWeb) return _webStore.containsKey(screenId);
    final box = _box;
    if (box == null) return false;
    return box.containsKey(screenId);
  }

  /// 즐겨찾기 목록 스트림.
  Stream<List<FavoriteScreen>> watchAll() {
    if (kIsWeb) {
      return Stream<List<FavoriteScreen>>.multi((controller) {
        controller.add(_readAllSync());
        final sub = _webController.stream.listen(controller.add);
        controller.onCancel = () => sub.cancel();
      });
    }
    final box = _box;
    if (box == null) return Stream.value(const <FavoriteScreen>[]);
    return Stream<List<FavoriteScreen>>.multi((controller) {
      controller.add(_readAllSync());
      final sub = box.watch().listen((_) {
        controller.add(_readAllSync());
      });
      controller.onCancel = () => sub.cancel();
    });
  }

  /// 즉시 읽기 (UI 빌드 시점).
  List<FavoriteScreen> readAll() => _readAllSync();
}
