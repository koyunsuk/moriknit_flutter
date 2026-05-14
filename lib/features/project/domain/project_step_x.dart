// lib/features/project/domain/project_step_x.dart
//
// 이슈 #687 (Phase B-2) — ProjectStep ↔ StepUnit 어댑터.
//
// 원칙:
// - 기존 `project_step.dart`는 무수정. extension만 별도 파일에 추가.
// - 양방향 변환 (toStepUnit / fromStepUnit) — 정보 손실 없도록 신중히 매핑.
// - ProjectStep은 항상 사용자 인스턴스 → StepUnit.progress != null.

import '../../../core/domain/step_unit/step_unit.dart';
import '../../../core/domain/step_unit/step_unit_origin.dart';
import '../../../core/domain/step_unit/step_unit_progress.dart';
import '../../../core/domain/step_unit/step_unit_source.dart';
import 'project_step.dart';

extension ProjectStepStepUnitX on ProjectStep {
  /// ProjectStep → StepUnit 변환 (사용자 인스턴스).
  ///
  /// 매핑:
  /// - id, order, name, description, targetRow, isDone, doneAt, photoUrl, note
  /// - sourceSectionId · sourcePatternChartId → StepUnitOrigin
  /// - createdAt → createdAt
  /// - blockType은 StepUnit 모델에 없음 → 호출부에서 별도 보존 필요 (정보 손실 가능성)
  ///
  /// 변환 결과는 항상 인스턴스 (progress != null).
  StepUnit toStepUnit() {
    final hasOrigin = sourceSectionId != null || sourcePatternChartId != null;
    return StepUnit(
      id: id,
      order: order,
      title: name,
      // description은 소제목 — instruction으로 사용
      instruction: description,
      targetRows: targetRow,
      source: hasOrigin ? StepUnitSource.ai : StepUnitSource.manual,
      origin: hasOrigin
          ? StepUnitOrigin(
              patternChartId: sourcePatternChartId,
              sectionId: sourceSectionId,
            )
          : null,
      progress: StepUnitProgress(
        isDone: isDone,
        doneAt: doneAt,
        photoUrl: photoUrl,
        note: note.isEmpty ? null : note,
        currentRow: 0,
      ),
      createdAt: createdAt,
    );
  }

  /// StepUnit → ProjectStep 역변환 (저장 시 사용).
  ///
  /// 정보 손실 점검:
  /// - StepUnit.titleKo/titleEn/instructionKo/instructionEn/tags → ProjectStep에 없음
  /// - StepUnit.progress.currentRow / linkedCounterId → ProjectStep에 없음 (카운터 모델에서 보유)
  /// - StepUnit.source가 'manual'이 아니어도 ProjectStep은 출처를 origin으로만 추적
  /// - blockType은 [defaultBlockType] 으로 지정 (기본 text).
  ///
  /// [defaultBlockType] StepUnit에는 없는 ProjectStep 전용 필드. 호출부에서 기존 값을 전달하지 않으면 text.
  static ProjectStep fromStepUnit(
    StepUnit unit, {
    StepBlockType defaultBlockType = StepBlockType.text,
  }) {
    final progress = unit.progress;
    return ProjectStep(
      id: unit.id,
      name: unit.title,
      description: unit.instruction,
      isDone: progress?.isDone ?? false,
      note: progress?.note ?? '',
      order: unit.order,
      createdAt: unit.createdAt,
      doneAt: progress?.doneAt,
      photoUrl: progress?.photoUrl,
      targetRow: unit.targetRows,
      blockType: defaultBlockType,
      sourceSectionId: unit.origin?.sectionId,
      sourcePatternChartId: unit.origin?.patternChartId,
    );
  }
}

/// `List<ProjectStep>` → `List<StepUnit>` 변환 헬퍼.
extension ProjectStepListStepUnitX on List<ProjectStep> {
  /// ProjectStep 리스트 → StepUnit 리스트 (order 보존).
  List<StepUnit> toStepUnits() => map((s) => s.toStepUnit()).toList();
}
