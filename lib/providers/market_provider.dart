import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/market/data/market_repository.dart';
import '../features/market/domain/market_item.dart';
import 'auth_provider.dart';

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository();
});

final marketItemsProvider = StreamProvider<List<MarketItem>>((ref) {
  return ref.watch(marketRepositoryProvider).watchItems();
});

final popularPatternItemsProvider = StreamProvider<List<MarketItem>>((ref) {
  return ref.watch(marketRepositoryProvider).watchPopularPatterns();
});

final latestPatternItemsProvider = StreamProvider<List<MarketItem>>((ref) {
  return ref.watch(marketRepositoryProvider).watchLatestPatterns();
});

final myMarketItemsProvider = StreamProvider<List<MarketItem>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchMyItems(user.uid);
});

final myPurchasesProvider = StreamProvider<List<MarketPurchase>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchMyPurchases(user.uid);
});

final ownedPurchasedPatternItemsProvider = StreamProvider<List<MarketItem>>((ref) {
  final purchases = ref.watch(myPurchasesProvider).valueOrNull ?? const <MarketPurchase>[];
  final itemIds = purchases
      .where((purchase) => purchase.category == 'pattern')
      .map((purchase) => purchase.itemId)
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (itemIds.isEmpty) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchItemsByIds(itemIds).map(
        (items) => items.where((item) => item.category == 'pattern').toList(),
      );
});

/// 구매 기록은 있으나 도안이 삭제된 orphan 구매 목록
final orphanPurchasesProvider = Provider<List<MarketPurchase>>((ref) {
  final purchases = ref.watch(myPurchasesProvider).valueOrNull ?? const <MarketPurchase>[];
  final loadedItems = ref.watch(ownedPurchasedPatternItemsProvider).valueOrNull ?? const <MarketItem>[];
  final loadedIds = loadedItems.map((i) => i.id).toSet();
  return purchases
      .where((p) => p.category == 'pattern' && p.itemId.isNotEmpty && !loadedIds.contains(p.itemId))
      .toList();
});

final myMarketSalesProvider = StreamProvider<List<MarketPurchase>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchMySales(user.uid);
});
