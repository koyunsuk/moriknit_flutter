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

// ── Phase I-C: legacy fallback providers ───────────────────────────────────
//
// 프로젝트의 신규 step_runs 문서를 우선 조회하고, 없으면 기존 ProjectStep
// 컬렉션을 합성 StepRun으로 어댑터 변환해 반환. 마이그레이션 전이라도
// 신규 모델 화면이 안전하게 동작하도록 보장.

/// 프로젝트 ID로 신규 StepRun을 조회하거나 기존 ProjectStep을 어댑터 변환.
/// 1회성 FutureProvider — 화면 진입 시 한 번만 조회.
final stepRunByProjectIdProvider =
    FutureProvider.family<StepRun?, String>((ref, projectId) async {
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return null;
  return ref
      .watch(stepRunRepositoryProvider)
      .getOrAdaptLegacyByProjectId(projectId);
});

/// 프로젝트의 progress 리스트 스트림 — 신규 컬렉션 또는 기존 ProjectStep 어댑터.
final runProgressByProjectIdProvider = StreamProvider.family<
    List<StepRunProgress>, ({String projectId, String? runId})>((ref, args) {
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return Stream.value(const []);
  return ref.watch(stepRunRepositoryProvider).watchProgressWithLegacy(
        projectId: args.projectId,
        runId: args.runId,
      );
});
