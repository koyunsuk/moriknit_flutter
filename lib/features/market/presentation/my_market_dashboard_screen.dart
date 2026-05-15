import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/localization/app_language.dart';

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
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.bg,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(isKorean ? '내 마켓' : 'My Market', style: T.h3),
        ),
        body: Center(
          child: Text(
            isKorean ? '로그인이 필요해요.' : 'Login required.',
            style: T.body.copyWith(color: C.mu),
          ),
        ),
      );
    }

    final sales = salesAsync.valueOrNull ?? const [];
    final myItems = myItemsAsync.valueOrNull ?? const [];
    final totalRevenue = sales.fold<int>(0, (sum, s) => sum + s.price);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(isKorean ? '내 마켓' : 'My Market', style: T.h3),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _SummaryCards(
                isKorean: isKorean,
                salesCount: sales.length,
                totalRevenue: totalRevenue,
                itemCount: myItems.length,
              ),
              const SizedBox(height: 24),
              SectionTitle(title: isKorean ? '내 상품 목록' : 'My Items'),
              const SizedBox(height: 10),
              myItemsAsync.when(
                loading: () => AsyncLoadingFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(myMarketItemsProvider),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
                error: (e, _) => AsyncDelayedFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(myMarketItemsProvider),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
                data: (items) => items.isEmpty
                    ? _ItemsEmptyPlaceholder(isKorean: isKorean)
                    : Column(
                        children: items
                            .map((item) => _MyItemRow(item: item, isKorean: isKorean))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 24),
              SectionTitle(title: isKorean ? '구매 내역' : 'Purchase History'),
              const SizedBox(height: 10),
              purchasesAsync.when(
                loading: () => AsyncLoadingFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(myPurchasesProvider),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
                error: (e, _) => AsyncDelayedFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(myPurchasesProvider),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
                data: (purchases) => purchases.isEmpty
                    ? _PurchasesEmptyPlaceholder(isKorean: isKorean)
                    : Column(
                        children: purchases
                            .map((p) => _PurchaseRow(
                                  title: p.title,
                                  price: p.price,
                                  purchasedAt: p.purchasedAt,
                                  isKorean: isKorean,
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final bool isKorean;
  final int salesCount;
  final int totalRevenue;
  final int itemCount;

  const _SummaryCards({
    required this.isKorean,
    required this.salesCount,
    required this.totalRevenue,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: isKorean ? '총 판매' : 'Sales',
            value: '$salesCount',
            unit: isKorean ? '건' : '',
            color: C.lv,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: isKorean ? '총 수익' : 'Revenue',
            value: '$totalRevenue',
            unit: isKorean ? ' 모리' : ' M',
            color: C.pk,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: isKorean ? '내 상품' : 'Items',
            value: '$itemCount',
            unit: isKorean ? '개' : '',
            color: C.lm.withValues(alpha: 1.0),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: T.h2.copyWith(color: color)),
                TextSpan(text: unit, style: T.caption.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: T.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MyItemRow extends StatelessWidget {
  final dynamic item;
  final bool isKorean;

  const _MyItemRow({required this.item, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final isSoldOut = item.isSoldOut as bool;
    final createdAt = item.createdAt as DateTime?;
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
                Text(item.title as String, style: T.bodyBold, overflow: TextOverflow.ellipsis),
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

class _ItemsEmptyPlaceholder extends StatelessWidget {
  final bool isKorean;

  const _ItemsEmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Icon(Icons.store_outlined, color: C.mu, size: 32),
          const SizedBox(height: 10),
          Text(
            isKorean ? '등록된 상품이 없어요' : 'No items listed',
            style: T.sm.copyWith(color: C.mu),
          ),
          const SizedBox(height: 4),
          Text(
            isKorean ? '마켓에서 상품을 등록해 보세요.' : 'Add your first item to the market.',
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ),
    );
  }
}

class _PurchasesEmptyPlaceholder extends StatelessWidget {
  final bool isKorean;

  const _PurchasesEmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: C.mu, size: 32),
          const SizedBox(height: 10),
          Text(
            isKorean ? '구매 내역이 없어요' : 'No purchases yet',
            style: T.sm.copyWith(color: C.mu),
          ),
          const SizedBox(height: 4),
          Text(
            isKorean ? '마켓에서 도안을 구매해 보세요.' : 'Browse the market to find patterns.',
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ),
    );
  }
}

