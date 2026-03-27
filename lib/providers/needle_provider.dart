import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/my/data/needle_repository.dart';
import '../features/my/domain/needle_model.dart';
import 'auth_provider.dart';

final needleRepositoryProvider = Provider<NeedleRepository>((ref) {
  return NeedleRepository();
});

final needleListProvider = StreamProvider<List<NeedleModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(needleRepositoryProvider).watchNeedles();
});

class NeedleInputNotifier extends StateNotifier<NeedleModel> {
  NeedleInputNotifier(String uid) : super(NeedleModel.empty(uid: uid));

  void setSize(double value) => state = state.copyWith(size: value);
  void setBrand(String value) => state = state.copyWith(brandName: value);
  void setMaterial(String value) => state = state.copyWith(material: value);
  void setType(String value) => state = state.copyWith(type: value);
  void setQuantity(int value) => state = state.copyWith(quantity: value);
  void setMemo(String value) => state = state.copyWith(memo: value);

  void load(NeedleModel needle) => state = needle;
  void reset(String uid) => state = NeedleModel.empty(uid: uid);

  String? get validationError {
    if (state.size <= 0) return '바늘 사이즈를 선택해주세요.';
    return null;
  }
}

final needleInputProvider = StateNotifierProvider.autoDispose<NeedleInputNotifier, NeedleModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return NeedleInputNotifier(user?.uid ?? '');
});
