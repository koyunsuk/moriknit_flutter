import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/market_provider.dart';
import '../../../core/localization/app_language.dart';
import '../domain/market_item.dart';

class SellerItemsScreen extends ConsumerWidget {
  final String sellerUid;
  final String sellerName;

  const SellerItemsScreen({
    super.key,
    required this.sellerUid,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final itemsAsync = ref.watch(sellerItemsProvider(sellerUid));

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: sellerName,
                    subtitle: isKorean ? '판매자 상품 목록' : 'Seller items',
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: isKorean ? '뒤로' : 'Back',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: itemsAsync.when(
                    loading: () => AsyncLoadingFriendly(
                      isKorean: isKorean,
                      onRetry: () =>
                          ref.invalidate(sellerItemsProvider(sellerUid)),
                    ),
                    error: (e, _) => AsyncDelayedFriendly(
                      isKorean: isKorean,
                      onRetry: () =>
                          ref.invalidate(sellerItemsProvider(sellerUid)),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return _EmptyState(isKorean: isKorean);
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _SellerItemCard(item: items[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerItemCard extends StatelessWidget {
  final MarketItem item;

  const _SellerItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _ThumbnailPlaceholder(item: item),
                      )
                    : _ThumbnailPlaceholder(item: item),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(category: item.category),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: T.bodyBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.price == 0 ? '무료' : '${item.price} 모리',
                    style: T.sm.copyWith(color: C.lv, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final MarketItem item;

  const _ThumbnailPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.lvL,
      child: Center(
        child: Icon(
          item.category == 'pattern' ? Icons.auto_awesome : Icons.shopping_bag_outlined,
          color: C.lv,
          size: 36,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  static const _labels = <String, String>{
    'pattern': '도안',
    'yarn': '실',
    'tool': '도구',
    'kit': '키트',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[category] ?? category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: C.lv.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: T.chip.copyWith(color: C.lvD),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isKorean;

  const _EmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.store_outlined, color: C.lv, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              isKorean ? '등록된 상품이 없어요' : 'No items listed',
              style: T.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isKorean ? '판매자가 아직 상품을 등록하지 않았어요.' : 'This seller has no items yet.',
              style: T.caption.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

