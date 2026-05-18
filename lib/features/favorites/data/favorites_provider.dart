// lib/features/favorites/data/favorites_provider.dart
//
// 즐겨찾기 Riverpod 프로바이더.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

/// 즐겨찾기 전체 목록 (정렬: 추가된 순서).
final favoriteScreensProvider = StreamProvider<List<FavoriteScreen>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.watchAll();
});

/// 특정 화면이 즐겨찾기인지 동기 조회.
final favoriteScreenIdsProvider = Provider<Set<String>>((ref) {
  final list =
      ref.watch(favoriteScreensProvider).valueOrNull ?? const <FavoriteScreen>[];
  return list.map((e) => e.screenId).toSet();
});

/// #730/#766 — 현재 화면의 즐겨찾기 후보 메타데이터.
/// AppShellScaffold가 빌드될 때 화면별 favoriteScreenId/title/icon/path/accent를 등록.
/// 메인셸 퀵바의 ⭐ 토글 버튼이 이 값을 읽어 활성화 여부 판단.
final currentScreenFavoriteProvider = StateProvider<FavoriteScreen?>((ref) => null);

/// #781 — 홈 초기 탭 인덱스 (0: 홈, 1: 즐겨찾기).
/// 퀵사이드바의 별표 아이콘 탭 시 1로 설정 + 홈으로 이동.
final homeInitialTabProvider = StateProvider<int>((ref) => 0);
