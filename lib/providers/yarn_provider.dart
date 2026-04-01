import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/yarn/data/yarn_repository.dart';
import '../features/yarn/domain/yarn_model.dart';
import 'auth_provider.dart';

final yarnRepositoryProvider =
    Provider<YarnRepository>((ref) => YarnRepository());

final yarnListProvider = StreamProvider<List<YarnModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(yarnRepositoryProvider).watchYarns();
});

final yarnCountProvider = Provider<int>((ref) {
  return ref.watch(yarnListProvider).valueOrNull?.length ?? 0;
});

// ── 입력 폼 상태 ─────────────────────────────────────────
class YarnInputNotifier extends StateNotifier<YarnModel> {
  YarnInputNotifier(String uid) : super(YarnModel.empty(uid: uid));

  void updateBrandName(String v) => state = state.copyWith(brandName: v);
  void updateName(String v) => state = state.copyWith(name: v);
  void updateColor(String v) => state = state.copyWith(color: v);
  void updateWeight(String v) => state = state.copyWith(weight: v);
  void updateAmountGrams(int v) => state = state.copyWith(amountGrams: v);
  void updateMemo(String v) => state = state.copyWith(memo: v);
  void updatePhotoUrl(String v) => state = state.copyWith(photoUrl: v);
  void updatePurchaseDate(DateTime? v) => state = state.copyWith(purchaseDate: v);
  void updateMaterial(String v) => state = state.copyWith(material: v);
  void updateColorCode(String v) => state = state.copyWith(colorCode: v);
  void updateYarnLength(String v) => state = state.copyWith(yarnLength: v);
  void updateLotNumber(String v) => state = state.copyWith(lotNumber: v);
  void updatePrice(int v) => state = state.copyWith(price: v);
  void updatePurchasePlace(String v) => state = state.copyWith(purchasePlace: v);
  void loadYarn(YarnModel yarn) => state = yarn;
  void reset(String uid) => state = YarnModel.empty(uid: uid);
}

final yarnInputProvider =
    StateNotifierProvider.autoDispose<YarnInputNotifier, YarnModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return YarnInputNotifier(user?.uid ?? '');
});
