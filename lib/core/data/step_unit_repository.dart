// lib/core/data/step_unit_repository.dart
//
// 이슈 #687 (Phase C) — 공통 StepUnit Repository.
//
// 4개 단계 개념(단계로그/섹션/AI단계/템플릿)을 통합한 단일 view 진입점.
// 기존 4개 repository를 변경하지 않고, 신규 진입점에서 어댑터로 노출.
//
// 원칙:
// - 호출부 0건 변경. 본 클래스를 선택적으로 사용하는 신규 화면만 의존.
// - 미러링 진입점은 기존 ProjectStepRepository.addPatternSectionStepsWithCounters 호출.
//   (이중 구현 금지 — 기존 흐름을 단일 진입점으로 통일)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pattern/domain/ai_pattern_section_x.dart';
import '../../features/pattern/domain/pattern_chart.dart';
import '../../features/project/domain/project_step_x.dart';
import '../../providers/counter_provider.dart';
import '../../providers/parsed_pattern_provider.dart';
import '../../providers/project_step_provider.dart';
import '../domain/step_unit/step_unit.dart';
import '../domain/step_unit/step_unit_group.dart';

/// 4개 단계 개념을 통합한 view repository.
///
/// 읽기 전용 view 위주. 쓰기는 기존 repository(ProjectStepRepository 등)에 위임.
class StepUnitRepository {
  StepUnitRepository(this._ref);
  final Ref _ref;

  // ---------------------------------------------------------------------------
  // 읽기 view — 4개 모델을 StepUnit/StepUnitGroup로 통일된 형태로 노출
  // ---------------------------------------------------------------------------

  /// 도안 차트의 모든 그룹·단위.
  /// PatternChart.aiSections → StepUnitGroup 리스트로 변환된 stream.
  ///
  /// 도안 자체는 청사진이지만 호출부가 사용자 인스턴스로 보고 싶을 수 있으므로
  /// [asInstance] 로 노출 방식을 선택.
  Stream<List<StepUnitGroup>> watchChartGroups(
    String chartId, {
    bool asInstance = false,
  }) {
    final stream =
        _ref.read(patternConverterRepositoryProvider).watchAiPattern(chartId);
    return stream.map((chart) {
      if (chart == null) return const <StepUnitGroup>[];
      final sections = chart.aiSections ?? const [];
      return sections.toStepUnitGroups(
        patternChartId: chart.id,
        asInstance: asInstance,
      );
    });
  }

  /// 프로젝트 단계로그 — ProjectStep → StepUnit 인스턴스 stream.
  Stream<List<StepUnit>> watchProjectUnits(String projectId) {
    final stream =
        _ref.read(projectStepRepositoryProvider).watchSteps(projectId);
    return stream.map((steps) => steps.toStepUnits());
  }

  // ---------------------------------------------------------------------------
  // 미러링 — 도안 그룹을 프로젝트 단계로 (단계로그 자동 생성)
  // ---------------------------------------------------------------------------

  /// 도안의 섹션을 프로젝트 단계로그로 미러링 + 단계별 카운터 자동 생성.
  ///
  /// 본 메서드는 기존 [ProjectStepRepository.addPatternSectionStepsWithCounters] 호출의
  /// 어댑터. 이중 구현 금지 — 기존 흐름을 단일 진입점으로 통일하는 목적.
  ///
  /// 게이트 (이슈 #626):
  /// - 도안이 draft 이면 (chart.isComplete == false) no-op.
  /// - 빈 섹션은 기존 함수 내부에서 skip.
  Future<void> mirrorGroupsToProject({
    required String projectId,
    required PatternChart chart,
    required bool isKorean,
  }) async {
    final stepRepo = _ref.read(projectStepRepositoryProvider);
    final counterRepo = _ref.read(counterRepositoryProvider);
    await stepRepo.addPatternSectionStepsWithCounters(
      projectId,
      chart,
      isKorean,
      counterRepo,
    );
  }
}
