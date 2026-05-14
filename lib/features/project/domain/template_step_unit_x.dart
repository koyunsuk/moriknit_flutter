// lib/features/project/domain/template_step_unit_x.dart
//
// 이슈 #687 (Phase B-3) — BuiltinTemplate · UserTemplate ↔ StepUnit/StepUnitGroup 어댑터.
//
// 원칙:
// - 기존 `builtin_template.dart` / `user_template.dart`는 무수정.
// - 템플릿은 청사진 (progress == null) — 사용자가 프로젝트에 적용 시 인스턴스화.
// - 사용자 지시문 표기는 `lib/features/template/` 였으나 실제 코드 위치는
//   `lib/features/project/domain/`. 같은 의도이므로 본 위치에 추가.

import 'package:uuid/uuid.dart';

import '../../../core/domain/step_unit/step_unit.dart';
import '../../../core/domain/step_unit/step_unit_group.dart';
import '../../../core/domain/step_unit/step_unit_origin.dart';
import '../../../core/domain/step_unit/step_unit_source.dart';
import 'builtin_template.dart';
import 'user_template.dart';

extension BuiltinTemplateStepUnitX on BuiltinTemplate {
  /// BuiltinTemplate → StepUnitGroup 변환 (청사진 view).
  ///
  /// 매핑:
  /// - id ↔ id
  /// - titleKo/titleEn ↔ titleKo/titleEn
  /// - stepsKo[i] · stepsEn[i] · stepNotesKo[i] · stepNotesEn[i] · stepTargetRows[i]
  ///   → StepUnit (한·영 동시 보존)
  ///
  /// [isKorean] 기본 제목 결정 (true → 한국어가 title)
  /// 정보 손실: kind / descKo/En / iconName / colorHex / measurementData / order / isActive
  /// (그룹 메타데이터로 origin·태그에 옮길 수 있으나 본 어댑터는 단계만 노출)
  StepUnitGroup toStepUnitGroup({bool isKorean = true}) {
    final groupTitle = isKorean ? titleKo : titleEn;
    final origin = StepUnitOrigin(templateId: id);

    final names = isKorean ? stepsKo : stepsEn;
    final notes = isKorean ? stepNotesKo : stepNotesEn;

    return StepUnitGroup(
      id: id,
      title: groupTitle,
      titleKo: titleKo,
      titleEn: titleEn,
      order: order,
      origin: origin,
      units: [
        for (int i = 0; i < names.length; i++)
          StepUnit(
            id: '${id}_step_$i',
            order: i,
            title: names[i],
            titleKo: i < stepsKo.length ? stepsKo[i] : null,
            titleEn: i < stepsEn.length ? stepsEn[i] : null,
            instruction: i < notes.length ? notes[i] : '',
            instructionKo: i < stepNotesKo.length ? stepNotesKo[i] : null,
            instructionEn: i < stepNotesEn.length ? stepNotesEn[i] : null,
            targetRows: i < stepTargetRows.length ? stepTargetRows[i] : 0,
            source: StepUnitSource.template,
            origin: origin,
            createdAt: DateTime.now(),
          ),
      ],
    );
  }

  /// BuiltinTemplate → 청사진 StepUnit 리스트 (그룹 정보 불필요할 때).
  List<StepUnit> toStepUnits({bool isKorean = true}) =>
      toStepUnitGroup(isKorean: isKorean).units;
}

extension UserTemplateStepUnitX on UserTemplate {
  /// UserTemplate → StepUnitGroup 변환 (청사진 view).
  ///
  /// 매핑:
  /// - id ↔ id
  /// - title ↔ title (UserTemplate은 단일 언어)
  /// - stepTitles[i] / stepDescs[i] → StepUnit.title / instruction
  ///
  /// 정보 손실: description / photoUrl / updatedAt → 본 어댑터는 단계만 노출.
  StepUnitGroup toStepUnitGroup() {
    final origin = StepUnitOrigin(templateId: id);
    return StepUnitGroup(
      id: id,
      title: title,
      units: [
        for (int i = 0; i < stepTitles.length; i++)
          StepUnit(
            id: '${id}_step_$i',
            order: i,
            title: stepTitles[i],
            instruction: i < stepDescs.length ? stepDescs[i] : '',
            source: StepUnitSource.template,
            origin: origin,
            createdAt: createdAt,
          ),
      ],
      origin: origin,
    );
  }

  List<StepUnit> toStepUnits() => toStepUnitGroup().units;

  /// StepUnit 리스트 → UserTemplate 역변환 (저장 시 사용).
  ///
  /// 정보 손실 점검:
  /// - StepUnit.targetRows / tags / instructionKo·En / source / origin → UserTemplate에 없음
  /// - StepUnit.progress (있어도 청사진화하며 버려짐)
  ///
  /// [title] · [description] · [photoUrl] 은 호출부 명시 전달.
  static UserTemplate fromStepUnits({
    required List<StepUnit> units,
    required String title,
    String description = '',
    String photoUrl = '',
    String? id,
    DateTime? createdAt,
  }) {
    final sorted = [...units]..sort((a, b) => a.order.compareTo(b.order));
    return UserTemplate(
      id: id ?? const Uuid().v4(),
      title: title,
      description: description,
      stepTitles: sorted.map((u) => u.title).toList(),
      stepDescs: sorted.map((u) => u.instruction).toList(),
      photoUrl: photoUrl,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}
