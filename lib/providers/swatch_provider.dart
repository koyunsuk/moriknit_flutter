import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/swatch/data/swatch_repository.dart';
import '../features/swatch/domain/swatch_model.dart';
import 'auth_provider.dart';

final swatchRepositoryProvider = Provider<SwatchRepository>((ref) {
  return SwatchRepository();
});

final swatchListProvider = StreamProvider<List<SwatchModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(swatchRepositoryProvider).watchSwatches();
});

final swatchCountProvider = Provider<int>((ref) {
  return ref.watch(swatchListProvider).valueOrNull?.length ?? 0;
});

final swatchLimitReachedProvider = Provider<bool>((ref) {
  final gates = ref.watch(featureGatesProvider);
  final count = ref.watch(swatchCountProvider);
  return !gates.canAddSwatch(count);
});

final swatchLimitProgressProvider = Provider<double>((ref) {
  final gates = ref.watch(featureGatesProvider);
  if (!gates.isFree) return 0.0;
  final count = ref.watch(swatchCountProvider);
  return count / 5.0;
});

final swatchesByProjectIdProvider = Provider.family<List<SwatchModel>, String>((ref, projectId) {
  final swatches = ref.watch(swatchListProvider).valueOrNull ?? [];
  return swatches.where((s) => s.projectId == projectId).toList();
});

final swatchByIdProvider = StreamProvider.family<SwatchModel?, String>((ref, id) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value(null);
  return ref.watch(swatchRepositoryProvider).watchSwatch(id);
});

class SwatchInputNotifier extends StateNotifier<SwatchModel> {
  SwatchInputNotifier(String uid) : super(SwatchModel.empty(uid: uid).copyWith(beforeStitchCount: 25, beforeRowCount: 20));

  void updateSwatchName(String name) => state = state.copyWith(swatchName: name);
  void updateYarnBrand(String id, String name) => state = state.copyWith(yarnBrandId: id, yarnBrandName: name);
  void updateNeedleBrand(String id, String name) => state = state.copyWith(needleBrandId: id, needleBrandName: name);
  void updateNeedleSize(double size) => state = state.copyWith(needleSize: size);
  void updateBeforeStitchCount(int count) => state = state.copyWith(beforeStitchCount: count);
  void updateBeforeRowCount(int count) => state = state.copyWith(beforeRowCount: count);
  void toggleAfterWash(bool value) => state = state.copyWith(hasAfterWash: value);

  void updateAfterStitchCount(int count) {
    state = state.copyWith(
      afterStitchCount: count,
      shrinkageRate: state.copyWith(afterStitchCount: count).calculateShrinkageRate(),
    );
  }

  void updateAfterRowCount(int count) => state = state.copyWith(afterRowCount: count);
  void updateMemo(String memo) => state = state.copyWith(memo: memo);
  void updateBeforePhotoUrl(String url) => state = state.copyWith(beforePhotoUrl: url);
  void updateAfterPhotoUrl(String url) => state = state.copyWith(afterPhotoUrl: url);

  void updateProjectId(String projectId) => state = state.copyWith(projectId: projectId);

  void setMyNeedle(String needleId, String brandName, double size) {
    state = state.copyWith(myNeedleId: needleId, needleBrandName: brandName, needleSize: size);
  }

  void setArchived(bool isArchived, DateTime? date) {
    state = state.copyWith(isArchived: isArchived, archivedDate: date);
  }

  void loadSwatch(SwatchModel swatch) => state = swatch;
  void reset(String uid) => state = SwatchModel.empty(uid: uid);

  bool get isValid => state.beforeStitchCount > 0 && state.beforeRowCount > 0;

  String? get validationError {
    if (state.beforeStitchCount == 0) return 'Please enter stitches.';
    if (state.beforeRowCount == 0) return 'Please enter rows.';
    return null;
  }
}

final swatchInputProvider = StateNotifierProvider.autoDispose<SwatchInputNotifier, SwatchModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return SwatchInputNotifier(user?.uid ?? '');
});
