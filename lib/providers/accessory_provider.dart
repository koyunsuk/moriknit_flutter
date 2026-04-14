import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/my/data/accessory_repository.dart';
import '../features/my/domain/accessory_model.dart';
import 'auth_provider.dart';

final accessoryRepositoryProvider = Provider<AccessoryRepository>((ref) {
  return AccessoryRepository();
});

final accessoryListProvider = StreamProvider<List<AccessoryModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(accessoryRepositoryProvider).watchAccessories();
});

class AccessoryInputNotifier extends StateNotifier<AccessoryModel> {
  AccessoryInputNotifier(String uid) : super(AccessoryModel.empty(uid: uid));

  void setType(String value) => state = state.copyWith(type: value);
  void setBrand(String value) => state = state.copyWith(brandName: value);
  void setName(String value) => state = state.copyWith(name: value);
  void setQuantity(int value) => state = state.copyWith(quantity: value);
  void setPrice(int value) => state = state.copyWith(price: value);
  void setPurchasePlace(String value) => state = state.copyWith(purchasePlace: value);
  void setPurchaseDate(DateTime? value) => state = state.copyWith(purchaseDate: value);
  void setMemo(String value) => state = state.copyWith(memo: value);

  void load(AccessoryModel item) => state = item;
  void reset(String uid) => state = AccessoryModel.empty(uid: uid);
}

final accessoryInputProvider =
    StateNotifierProvider.autoDispose<AccessoryInputNotifier, AccessoryModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return AccessoryInputNotifier(user?.uid ?? '');
});
