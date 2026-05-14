// lib/providers/step_unit_provider.dart
//
// 이슈 #687 (Phase D) — 공통 StepUnit Provider.
//
// StepUnitRepository를 노출하는 Riverpod provider.
// 기존 4개 provider(projectStepProvider/templateProvider 등)는 무수정.
// 신규 화면이 본 provider를 선택적으로 사용.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/step_unit_repository.dart';
import '../core/domain/step_unit/step_unit.dart';
import '../core/domain/step_unit/step_unit_group.dart';

final stepUnitRepositoryProvider = Provider<StepUnitRepository>(
  (ref) => StepUnitRepository(ref),
);

/// 도안 차트의 그룹 목록 — AiSection → StepUnitGroup view.
final chartGroupsProvider =
    StreamProvider.family<List<StepUnitGroup>, String>((ref, chartId) {
  return ref.watch(stepUnitRepositoryProvider).watchChartGroups(chartId);
});

/// 프로젝트 단계로그 — ProjectStep → StepUnit view.
final projectUnitsProvider =
    StreamProvider.family<List<StepUnit>, String>((ref, projectId) {
  return ref.watch(stepUnitRepositoryProvider).watchProjectUnits(projectId);
});
