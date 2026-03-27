import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/project/data/project_repository.dart';
import '../features/project/domain/project_model.dart';
import 'auth_provider.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

// 로그인 상태에서 전체 프로젝트 목록을 구독합니다.
final projectListProvider = StreamProvider<List<ProjectModel>>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(projectRepositoryProvider).watchProjects();
});

final projectCountProvider = Provider<int>((ref) {
  return ref.watch(projectListProvider).valueOrNull?.length ?? 0;
});

final projectLimitReachedProvider = Provider<bool>((ref) {
  final gates = ref.watch(featureGatesProvider);
  final count = ref.watch(projectCountProvider);
  return !gates.canAddProject(count);
});

// 완료되지 않은 프로젝트만 따로 보여줄 때 사용합니다.
final activeProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final list = ref.watch(projectListProvider).valueOrNull ?? [];
  return list.where((p) => p.status != ProjectStatus.finished.value).toList();
});

final projectByIdProvider = StreamProvider.family<ProjectModel?, String>((ref, id) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value(null);
  return ref.watch(projectRepositoryProvider).watchProject(id);
});

class ProjectInputNotifier extends StateNotifier<ProjectModel> {
  ProjectInputNotifier(String uid) : super(ProjectModel.empty(uid: uid));

  void setTitle(String value) => state = state.copyWith(title: value);
  void setDescription(String value) => state = state.copyWith(description: value);
  void setStatus(String value) => state = state.copyWith(status: value);
  void setProgress(double value) => state = state.copyWith(progressPercent: value);
  void setYarnBrand(String id, String name) =>
      state = state.copyWith(yarnBrandId: id, yarnBrandName: name);
  void setYarnName(String value) => state = state.copyWith(yarnName: value);
  void setYarnColor(String value) => state = state.copyWith(yarnColor: value);
  void setYarnWeight(String value) => state = state.copyWith(yarnWeight: value);
  void setNeedleSize(double value) => state = state.copyWith(needleSize: value);
  void setNeedleBrand(String value) => state = state.copyWith(needleBrandName: value);
  void setSwatchId(String value) => state = state.copyWith(swatchId: value);
  void setMemo(String value) => state = state.copyWith(memo: value);
  void setStartDate(DateTime? value) => state = state.copyWith(startDate: value);
  void setTargetDate(DateTime? value) => state = state.copyWith(targetDate: value);
  void setCoverPhoto(String url) => state = state.copyWith(coverPhotoUrl: url);

  void load(ProjectModel project) => state = project;
  void reset(String uid) => state = ProjectModel.empty(uid: uid);

  String? get validationError {
    if (state.title.trim().isEmpty) return '프로젝트 이름을 입력해주세요.';
    return null;
  }
}

final projectInputProvider = StateNotifierProvider.autoDispose<ProjectInputNotifier, ProjectModel>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return ProjectInputNotifier(user?.uid ?? '');
});
