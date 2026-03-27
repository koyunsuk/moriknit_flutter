import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/counter/data/counter_repository.dart';
import '../features/counter/domain/counter_model.dart';
import 'auth_provider.dart';

final counterRepositoryProvider = Provider<CounterRepository>((ref) {
  return CounterRepository();
});

// 로그인 상태에서 전체 카운터 목록을 구독합니다.
final counterListProvider = StreamProvider<List<CounterModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(counterRepositoryProvider).watchCounters();
});

final counterCountProvider = Provider<int>((ref) {
  return ref.watch(counterListProvider).valueOrNull?.length ?? 0;
});

final counterLimitReachedProvider = Provider<bool>((ref) {
  final gates = ref.watch(featureGatesProvider);
  final count = ref.watch(counterCountProvider);
  return !gates.canAddCounter(count);
});

final counterByIdProvider = StreamProvider.family<CounterModel?, String>((ref, id) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value(null);
  return ref.watch(counterRepositoryProvider).watchCounter(id);
});

// 프로젝트별 카운터 목록입니다.
final countersByProjectProvider = StreamProvider.family<List<CounterModel>, String>((ref, projectId) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(counterRepositoryProvider).watchCountersByProject(projectId);
});

class CounterInputNotifier extends StateNotifier<CounterModel> {
  CounterInputNotifier(String uid) : super(CounterModel.empty(uid: uid));

  void setName(String name) => state = state.copyWith(name: name);
  void setProjectId(String id) => state = state.copyWith(projectId: id);
  void setTargetStitch(int value) => state = state.copyWith(targetStitchCount: value);
  void setTargetRow(int value) => state = state.copyWith(targetRowCount: value);

  void load(CounterModel counter) => state = counter;
  void reset(String uid) => state = CounterModel.empty(uid: uid);

  String? get validationError {
    if (state.name.trim().isEmpty) return '카운터 이름을 입력해주세요.';
    return null;
  }
}

final counterInputProvider = StateNotifierProvider.autoDispose<CounterInputNotifier, CounterModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return CounterInputNotifier(user?.uid ?? '');
});
