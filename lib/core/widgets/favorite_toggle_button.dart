// lib/core/widgets/favorite_toggle_button.dart
//
// 헤더 우상단 별표 토글 버튼 — 현재 화면을 즐겨찾기에 추가/제거.
//
// 사용:
// ```dart
// AppShellScaffold(
//   trailing: [
//     FavoriteToggleButton(
//       screenId: 'swatch_list',
//       title: '스와치 목록',
//       icon: Icons.grid_view_rounded,
//       path: Routes.swatchList,
//       accent: C.lvD,
//     ),
//   ],
// )
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../../features/favorites/data/favorites_provider.dart';
import '../../features/favorites/data/favorites_repository.dart';

class FavoriteToggleButton extends ConsumerWidget {
  final String screenId;
  final String title;
  final IconData icon;
  final String path;
  final Color accent;

  /// 한국어 여부 (toast 메시지용). null이면 toast 미표시.
  final bool? isKorean;

  const FavoriteToggleButton({
    super.key,
    required this.screenId,
    required this.title,
    required this.icon,
    required this.path,
    required this.accent,
    this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoriteScreenIdsProvider);
    final isFavorite = ids.contains(screenId);

    return IconButton(
      tooltip: isFavorite
          ? (isKorean == false ? 'Remove from favorites' : '즐겨찾기 해제')
          : (isKorean == false ? 'Add to favorites' : '즐겨찾기 추가'),
      icon: Icon(
        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isFavorite ? C.og : C.tx2,
      ),
      onPressed: () async {
        final repo = ref.read(favoritesRepositoryProvider);
        final added = await repo.toggle(
          FavoriteScreen(
            screenId: screenId,
            title: title,
            icon: icon,
            path: path,
            accent: accent,
            addedAt: DateTime.now(),
          ),
        );
        if (!context.mounted) return;
        if (isKorean == null) return;
        final korean = isKorean!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              content: Text(
                added
                    ? (korean ? '즐겨찾기에 추가됐어요.' : 'Added to favorites.')
                    : (korean ? '즐겨찾기에서 해제됐어요.' : 'Removed from favorites.'),
              ),
            ),
          );
      },
    );
  }
}
