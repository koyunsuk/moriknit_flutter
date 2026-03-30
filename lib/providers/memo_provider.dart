import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/tools/data/memo_repository.dart';
import '../features/tools/domain/memo_model.dart';
import 'auth_provider.dart';

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepository();
});

final memoListProvider = StreamProvider<List<MemoModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(memoRepositoryProvider).watchMemos();
});

// ── 저장/수정/삭제 Notifier ────────────────────────────────
class MemoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create(MemoModel memo, {List<Uint8List> newImages = const []}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(memoRepositoryProvider);
      List<String> uploadedUrls = [];
      if (newImages.isNotEmpty) {
        uploadedUrls = await repo.uploadImages(newImages);
      }
      final withUrls = memo.copyWith(imageUrls: [...memo.imageUrls, ...uploadedUrls]);
      await repo.createMemo(withUrls);
    });
  }

  Future<void> save(MemoModel memo, {List<Uint8List> newImages = const []}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(memoRepositoryProvider);
      List<String> uploadedUrls = [];
      if (newImages.isNotEmpty) {
        uploadedUrls = await repo.uploadImages(newImages);
      }
      final withUrls = memo.copyWith(imageUrls: [...memo.imageUrls, ...uploadedUrls]);
      await repo.updateMemo(withUrls);
    });
  }

  Future<void> delete(String memoId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(memoRepositoryProvider).deleteMemo(memoId);
    });
  }
}

final memoNotifierProvider = AsyncNotifierProvider<MemoNotifier, void>(
  MemoNotifier.new,
);
