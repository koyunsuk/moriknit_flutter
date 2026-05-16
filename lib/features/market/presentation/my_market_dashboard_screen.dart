import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/localization/app_language.dart';
import '../domain/market_item.dart';

class MyMarketDashboardScreen extends ConsumerWidget {
  const MyMarketDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final myItemsAsync = ref.watch(myMarketItemsProvider);
    final salesAsync = ref.watch(myMarketSalesProvider);
    final purchasesAsync = ref.watch(myPurchasesProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const BgOrbs(),
            SafeArea(
              child: Column(
                children: [
                  MoriPageHeaderShell(
                    child: MoriWideHeader(
                      title: isKorean ? '내 마켓' : 'My Market',
                      subtitle: isKorean ? '판매·구매 한눈에 보기' : 'Sales and purchases at a glance',
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        isKorean ? '로그인이 필요해요.' : 'Login required.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sales = salesAsync.valueOrNull ?? const [];
    final myItems = myItemsAsync.valueOrNull ?? const [];
    final purchases = purchasesAsync.valueOrNull ?? const [];
    final pendingItems = myItems.where((i) => !i.isSoldOut).toList();
    final soldItems = myItems.where((i) => i.isSoldOut).toList();
    final totalRevenue = sales.fold<int>(0, (sum, s) => sum + s.price);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                // 공통 헤더 (상단 고정)
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '내 마켓' : 'My Market',
                    subtitle: isKorean ? '판매 대기·구매 도안' : 'Pending sales & purchases',
                  ),
                ),
                // 상단 요약카드 (나의 실 라이브러리 패턴)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SummaryCard_Main(
                    headers: [
                      isKorean ? '판매대기' : 'Pending',
                      isKorean ? '판매완료' : 'Sold',
                      isKorean ? '구매' : 'Bought',
                    ],
                    rows: [
                      LibrarySummaryRowData(
                        badge: isKorean ? '내 마켓' : 'My Market',
                        badgeColor: C.lv,
                        values: [
                          '${pendingItems.length}',
                          '${soldItems.length}',
                          '${purchases.length}',
                        ],
                        valueColors: [C.lvD, C.pkD, C.og],
                      ),
                      LibrarySummaryRowData(
                        badge: isKorean ? '수익' : 'Revenue',
                        badgeColor: C.pkD,
                        values: [
                          '${myItems.length}${isKorean ? '개' : ''}',
                          '$totalRevenue원',
                          '-',
                        ],
                        valueColors: [C.lvD, C.pkD, C.mu],
                      ),
                    ],
                  ),
                ),
                // 스크롤 바디
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      // 섹션 1: 판매 대기중
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: C.lv.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isKorean ? '판매 대기' : 'Pending',
                                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(isKorean ? '🛍️ 내가 올린 도안' : '🛍️ My Listings', style: T.bodyBold),
                              ],
                            ),
                            const SizedBox(height: 12),
                            myItemsAsync.when(
                              loading: () => AsyncLoadingFriendly(
                                isKorean: isKorean,
                                onRetry: () => ref.invalidate(myMarketItemsProvider),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                compact: true,
                              ),
                              error: (e, _) => AsyncDelayedFriendly(
                                isKorean: isKorean,
                                onRetry: () => ref.invalidate(myMarketItemsProvider),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                compact: true,
                              ),
                              data: (items) {
                                if (items.isEmpty) {
                                  return MoriEmptyState(
                                    icon: Icons.storefront_rounded,
                                    iconColor: C.lv,
                                    title: isKorean ? '아직 판매 중인 도안이 없어요' : 'No items listed yet',
                                    subtitle: isKorean
                                        ? '도안을 만들어 마켓에 올려보세요.\n도안에디터에서 시작할 수 있어요.'
                                        : 'Create a pattern and list it in the market.\nStart from the pattern editor.',
                                  );
                                }
                                return Column(
                                  children: items
                                      .map((item) => _MyItemRow(item: item, isKorean: isKorean))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 섹션 2: 구매한 아이템
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: C.og.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isKorean ? '구매' : 'Purchases',
                                    style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(isKorean ? '🧾 구매한 도안' : '🧾 My Purchases', style: T.bodyBold),
                              ],
                            ),
                            const SizedBox(height: 12),
                            purchasesAsync.when(
                              loading: () => AsyncLoadingFriendly(
                                isKorean: isKorean,
                                onRetry: () => ref.invalidate(myPurchasesProvider),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                compact: true,
                              ),
                              error: (e, _) => AsyncDelayedFriendly(
                                isKorean: isKorean,
                                onRetry: () => ref.invalidate(myPurchasesProvider),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                compact: true,
                              ),
                              data: (purchases) {
                                if (purchases.isEmpty) {
                                  return MoriEmptyState(
                                    icon: Icons.shopping_bag_rounded,
                                    iconColor: C.og,
                                    title: isKorean ? '아직 구매한 도안이 없어요' : 'No purchases yet',
                                    subtitle: isKorean
                                        ? '마켓에서 마음에 드는 도안을 찾아보세요.\n구매한 도안은 여기에서 확인할 수 있어요.'
                                        : 'Browse the market for patterns you love.\nPurchases will appear here.',
                                  );
                                }
                                return Column(
                                  children: purchases
                                      .map((p) => _PurchaseRow(
                                            title: p.title,
                                            price: p.price,
                                            purchasedAt: p.purchasedAt,
                                            isKorean: isKorean,
                                          ))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _MyItemRow extends StatelessWidget {
  final MarketItem item;
  final bool isKorean;

  const _MyItemRow({required this.item, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final isSoldOut = item.isSoldOut;
    final createdAt = item.createdAt;
    final dateStr = createdAt != null
        ? '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, color: C.lv, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: T.bodyBold, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${item.category}  •  ${item.price} 모리',
                  style: T.caption.copyWith(color: C.mu),
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.og.withValues(alpha: 0.25)),
              ),
              child: Text(
                isKorean ? '품절' : 'Sold Out',
                style: T.chip.copyWith(color: C.og),
              ),
            ),
        ],
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  final String title;
  final int price;
  final DateTime? purchasedAt;
  final bool isKorean;

  const _PurchaseRow({
    required this.title,
    required this.price,
    required this.purchasedAt,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = purchasedAt != null
        ? '${purchasedAt!.year}.${purchasedAt!.month.toString().padLeft(2, '0')}.${purchasedAt!.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.pk.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_outlined, color: C.pk, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '$price 모리${dateStr.isNotEmpty ? '  •  $dateStr' : ''}',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

