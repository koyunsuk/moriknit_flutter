import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/project/data/project_step_repository.dart';
import '../features/project/domain/project_step.dart';

final projectStepRepositoryProvider = Provider<ProjectStepRepository>((ref) => ProjectStepRepository());

final projectStepsProvider = StreamProvider.family<List<ProjectStep>, String>((ref, projectId) {
  return ref.watch(projectStepRepositoryProvider).watchSteps(projectId);
});

// (projectId, stepId) 쌍으로 단일 스텝을 구독합니다.
final projectStepByIdProvider = StreamProvider.family<ProjectStep?, ({String projectId, String stepId})>((ref, args) {
  return ref.watch(projectStepRepositoryProvider).watchStep(args.projectId, args.stepId);
});
