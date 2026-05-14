// lib/features/pattern/domain/ai_pattern_section_x.dart
//
// 이슈 #687 (Phase B-1) — AiSection · AiStep ↔ StepUnitGroup · StepUnit 어댑터.
//
// 원칙:
// - 기존 `ai_pattern_section.dart`는 무수정. extension만 별도 파일에 추가.
// - 양방향 변환 (toStepUnit*/fromStepUnit*) — 정보 손실 없도록 신중히 매핑.
// - 호출부 0건 변경. 신규 추상화로 노출만.

import '../../../core/domain/step_unit/step_unit.dart';
import '../../../core/domain/step_unit/step_unit_group.dart';
import '../../../core/domain/step_unit/step_unit_origin.dart';
import '../../../core/domain/step_unit/step_unit_progress.dart';
import '../../../core/domain/step_unit/step_unit_source.dart';
import 'ai_pattern_section.dart';

extension AiStepStepUnitX on AiStep {
  /// AI 단계 → StepUnit 변환 (청사진 view).
  ///
  /// 매핑:
  /// - id ↔ id
  /// - instruction ↔ instruction (영문 기준)
  /// - instructionKo ↔ instructionKo (선택)
  /// - isCompleted ↔ progress.isDone (인스턴스로 노출 시 사용)
  ///
  /// [order] AiSection.steps 내 순번.
  /// [origin] 도안·섹션 역참조 메타. patternChartId / sectionId 채워서 전달 권장.
  /// [asInstance] true면 progress(isDone=isCompleted) 인스턴스로, false면 청사진(progress=null).
  /// 기본 false — AI 결과 자체는 청사진. 사용자에 매핑된 시점에 인스턴스화.
  StepUnit toStepUnit({
    required int order,
    StepUnitOrigin? origin,
    bool asInstance = false,
    DateTime? createdAt,
  }) {
    return StepUnit(
      id: id,
      order: order,
      title: instruction,
      titleKo: instructionKo,
      instruction: instruction,
      instructionKo: instructionKo,
      source: StepUnitSource.ai,
      origin: origin,
      progress: asInstance
          ? StepUnitProgress(isDone: isCompleted)
          : null,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// StepUnit → AiStep 역변환 (저장 시 사용).
  ///
  /// 정보 손실 점검:
  /// - StepUnit.titleEn / instructionEn / targetRows / tags / order 는 AiStep에 없음 → 무시
  /// - progress가 있으면 isCompleted로 환원 (progress.isDone)
  /// - instruction 우선순위: instruction → title (fallback)
  /// - instructionKo 우선순위: instructionKo → titleKo
  static AiStep fromStepUnit(StepUnit unit) {
    final inst = unit.instruction.isNotEmpty ? unit.instruction : unit.title;
    return AiStep(
      id: unit.id,
      instruction: inst,
      instructionKo: unit.instructionKo ?? unit.titleKo,
      isCompleted: unit.progress?.isDone ?? false,
    );
  }
}

extension AiSectionStepUnitX on AiSection {
  /// AI 섹션 → StepUnitGroup 변환 (청사진 view).
  ///
  /// 매핑:
  /// - id ↔ id
  /// - title ↔ title (영문 기준), titleKo ↔ titleKo
  /// - steps ↔ units (각 AiStep → StepUnit 청사진)
  ///
  /// [order] 부모 PatternChart.aiSections 내 순번.
  /// [patternChartId] 역참조 origin 자동 세팅용 (선택).
  /// [asInstance] units 내부를 인스턴스로 (isCompleted → progress.isDone) 노출할지 여부.
  StepUnitGroup toStepUnitGroup({
    int order = 0,
    String? patternChartId,
    bool asInstance = false,
  }) {
    final origin = patternChartId == null
        ? null
        : StepUnitOrigin(
            patternChartId: patternChartId,
            sectionId: id,
          );
    return StepUnitGroup(
      id: id,
      title: title,
      titleKo: titleKo,
      order: order,
      origin: origin,
      units: [
        for (int i = 0; i < steps.length; i++)
          steps[i].toStepUnit(
            order: i,
            origin: origin,
            asInstance: asInstance,
          ),
      ],
    );
  }

  /// StepUnitGroup → AiSection 역변환 (저장 시 사용).
  ///
  /// 정보 손실 점검:
  /// - StepUnitGroup.order / titleEn / origin → AiSection에 없음 (외부 컨텍스트에 남김)
  /// - units 내 StepUnit의 source/tags/targetRows → AiStep에 없음
  static AiSection fromStepUnitGroup(StepUnitGroup group) {
    return AiSection(
      id: group.id,
      title: group.title,
      titleKo: group.titleKo,
      steps: group.units
          .map((u) => AiStepStepUnitX.fromStepUnit(u))
          .toList(),
    );
  }
}

/// `List<AiSection>` ↔ `List<StepUnitGroup>` 변환 헬퍼.
extension AiSectionListStepUnitX on List<AiSection> {
  /// AI 섹션 리스트 → StepUnitGroup 리스트 (PatternChart.aiSections 기준).
  ///
  /// [patternChartId] 모든 그룹의 origin.patternChartId에 자동 세팅.
  /// [asInstance] true면 모든 unit이 인스턴스(progress) 형태로 노출.
  List<StepUnitGroup> toStepUnitGroups({
    String? patternChartId,
    bool asInstance = false,
  }) {
    return [
      for (int i = 0; i < length; i++)
        this[i].toStepUnitGroup(
          order: i,
          patternChartId: patternChartId,
          asInstance: asInstance,
        ),
    ];
  }
}
