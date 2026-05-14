// lib/providers/step_run_provider.dart
//
// 이슈 #687 (Phase G) — StepRun Provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/blueprint/data/step_run_repository.dart';
import '../features/blueprint/domain/step_run.dart';
import '../features/blueprint/domain/step_run_progress.dart';
import 'auth_provider.dart';

final stepRunRepositoryProvider = Provider<StepRunRepository>(
  (ref) => StepRunRepository(),
);

/// 단일 실행 구독.
final stepRunByIdProvider =
    StreamProvider.family<StepRun?, String>((ref, rid) {
  return ref.watch(stepRunRepositoryProvider).watch(rid);
});

/// 내 모든 실행.
final myStepRunsProvider = StreamProvider<List<StepRun>>((ref) {
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return Stream.value(const []);
  return ref.watch(stepRunRepositoryProvider).watchMine();
});

/// 청사진별 내 실행.
final stepRunsByBlueprintProvider =
    StreamProvider.family<List<StepRun>, String>((ref, blueprintId) {
  return ref
      .watch(stepRunRepositoryProvider)
      .watchByBlueprint(blueprintId);
});

/// 프로젝트별 내 실행.
final stepRunsByProjectProvider =
    StreamProvider.family<List<StepRun>, String>((ref, projectId) {
  return ref.watch(stepRunRepositoryProvider).watchByProject(projectId);
});

/// 실행 단계별 진행 전체.
final runProgressProvider =
    StreamProvider.family<List<StepRunProgress>, String>((ref, rid) {
  return ref.watch(stepRunRepositoryProvider).watchProgress(rid);
});

/// 실행의 특정 단계 진행.
final runProgressByUnitProvider = StreamProvider.family<
    StepRunProgress?, ({String runId, String unitId})>((ref, args) {
  return ref
      .watch(stepRunRepositoryProvider)
      .watchProgressUnit(args.runId, args.unitId);
});
