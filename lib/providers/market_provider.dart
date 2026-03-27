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

final myMarketSalesProvider = StreamProvider<List<MarketPurchase>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchMySales(user.uid);
});
