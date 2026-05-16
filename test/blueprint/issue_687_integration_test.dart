// 이슈 #687 (4개 개념 통합) 검증 테스트.
//
// 검증 시나리오:
//   1) 도안 → 단계로그 자동 미러링 (aiSections → groups+units)
//   2) AI 변환 → 단계 자동 연결 (시나리오 1과 동일 경로)
//   3) 재분석 시 같은 문서 덮어쓰기 (blueprint.id == chart.id 보장)
//   4) 차트(grid) 또는 서술형(narrativeText) → 행별 unit 자동 생성
//
// 검증 범위: Firestore 의존 없는 순수 로직만.
//   - StepBlueprintRepository.adaptFromPatternChart (정적 메서드)
//   - ChartToUnitsConverter.convert / convertFromNarrativeText (정적 메서드)

import 'package:flutter_test/flutter_test.dart';

import 'package:moriknit_flutter/features/blueprint/data/chart_to_units_converter.dart';
import 'package:moriknit_flutter/features/blueprint/data/step_blueprint_repository.dart';
import 'package:moriknit_flutter/features/pattern/domain/ai_pattern_section.dart';
import 'package:moriknit_flutter/features/pattern/domain/pattern_chart.dart';

PatternChart _baseChart({
  String id = 'pat-1',
  String title = '테스트 도안',
  List<AiSection>? aiSections,
  String narrativeText = '',
  ChartMode mode = ChartMode.symbol,
}) {
  return PatternChart(
    id: id,
    title: title,
    rows: 0,
    cols: 0,
    mode: mode,
    grid: const [],
    narrativeText: narrativeText,
    aiSections: aiSections,
  );
}

void main() {
  group('#687 시나리오 1·2: 도안/AI 섹션 → StepBlueprint 자동 미러링', () {
    test('aiSections이 있는 차트는 groups + unitIds로 미러링된다', () {
      final step1 = AiStep(id: 'st-1', instruction: '코늘림 2단마다');
      final step2 = AiStep(id: 'st-2', instruction: '본단 30단');
      final section = AiSection(
        id: 'sec-1',
        title: 'Body',
        titleKo: '본단',
        steps: [step1, step2],
      );

      final chart = _baseChart(
        id: 'pat-a',
        title: '래글런 도안',
        aiSections: [section],
      );

      final blueprint = StepBlueprintRepository.adaptFromPatternChart(
        chart,
        ownerUid: 'uid-A',
      );

      expect(blueprint.id, 'pat-a',
          reason: 'blueprint.id는 chart.id와 동일해야 함 (1:1 매핑)');
      expect(blueprint.title, '래글런 도안');
      expect(blueprint.ownerUid, 'uid-A');
      expect(blueprint.groups.length, 1);
      expect(blueprint.groups[0].id, 'sec-1');
      expect(blueprint.groups[0].title, 'Body');
      expect(blueprint.groups[0].titleKo, '본단');
      expect(blueprint.groups[0].unitIds, ['st-1', 'st-2'],
          reason: 'aiSections의 각 step.id가 group.unitIds로 보존되어야 함');
      expect(blueprint.sourcePatternChartId, 'pat-a');
      expect(blueprint.chartAssetId, 'pat-a');
    });

    test('여러 섹션이 순서대로 groups에 매핑된다', () {
      final chart = _baseChart(
        id: 'pat-b',
        aiSections: [
          AiSection(
            id: 's1',
            title: '코늘림',
            steps: [AiStep(id: 'st-a', instruction: '+2')],
          ),
          AiSection(
            id: 's2',
            title: '본단',
            steps: [AiStep(id: 'st-b', instruction: '평단')],
          ),
          AiSection(
            id: 's3',
            title: '코줄임',
            steps: [AiStep(id: 'st-c', instruction: '-2')],
          ),
        ],
      );

      final bp = StepBlueprintRepository.adaptFromPatternChart(
        chart,
        ownerUid: 'u',
      );

      expect(bp.groups.length, 3);
      expect(bp.groups.map((g) => g.title).toList(),
          ['코늘림', '본단', '코줄임']);
      expect(bp.groups.map((g) => g.order).toList(), [0, 1, 2],
          reason: '섹션 입력 순서대로 order 부여');
    });

    test('aiSections이 비어 있으면 groups도 비어 있다', () {
      final chart = _baseChart(id: 'pat-c', aiSections: null);
      final bp = StepBlueprintRepository.adaptFromPatternChart(
        chart,
        ownerUid: 'u',
      );
      expect(bp.groups, isEmpty);
      expect(bp.id, 'pat-c');
    });
  });

  group('#687 시나리오 3: 재분석 시 같은 ID로 덮어쓰기', () {
    test('동일 chart.id로 두 번 변환해도 blueprint.id가 항상 동일', () {
      final v1 = _baseChart(
        id: 'pat-x',
        title: '버전1',
        aiSections: [
          AiSection(
            id: 's1',
            title: '본단',
            steps: [AiStep(id: 'old-1', instruction: '구버전 단계')],
          ),
        ],
      );
      final v2 = _baseChart(
        id: 'pat-x', // 같은 chart.id
        title: '버전2',
        aiSections: [
          AiSection(
            id: 's2',
            title: '본단 (재분석)',
            steps: [
              AiStep(id: 'new-1', instruction: '신버전 단계 A'),
              AiStep(id: 'new-2', instruction: '신버전 단계 B'),
            ],
          ),
        ],
      );

      final bp1 = StepBlueprintRepository.adaptFromPatternChart(v1, ownerUid: 'u');
      final bp2 = StepBlueprintRepository.adaptFromPatternChart(v2, ownerUid: 'u');

      expect(bp1.id, bp2.id,
          reason: '재분석해도 blueprint.id가 같아야 Firestore set()이 덮어쓰기로 작동');
      expect(bp1.id, 'pat-x');
      expect(bp2.title, '버전2');
      expect(bp2.groups[0].unitIds.length, 2,
          reason: '재분석 결과의 새 unitIds로 갱신');
    });
  });

  group('#687 시나리오 4: 차트/서술형 → 행별 unit 자동 생성', () {
    test('서술형 narrativeText 다섯 줄 → 5개 unit 생성, order 0~4', () {
      const text = '1단: 메리야스 코늘림 +2\n'
          '2단: 평단\n'
          '3단: 코늘림 +2\n'
          '4단: 평단\n'
          '5단: 코줄임 -2';

      final units = ChartToUnitsConverter.convertFromNarrativeText(
        narrativeText: text,
        blueprintId: 'bp-narr',
        korean: true,
      );

      expect(units.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(units[i].order, i);
        expect(units[i].blueprintId, 'bp-narr');
        expect(units[i].title, '${i + 1}단');
        expect(units[i].id, 'bp-narr_n${i + 1}',
            reason: '서술형 unit id 규칙: ${'\${bpId}_n\${i+1}'}');
      }
      // 'auto:narrative' 태그가 들어가야 자동 생성 unit으로 식별됨
      expect(ChartToUnitsConverter.isAutoGenerated(units.first), isTrue);
    });

    test('빈 narrativeText는 0개 unit', () {
      final units = ChartToUnitsConverter.convertFromNarrativeText(
        narrativeText: '',
        blueprintId: 'bp-empty',
      );
      expect(units, isEmpty);
    });

    test('자동 생성 unit과 사용자 편집 unit이 태그로 구분된다 (재변환 보존 정책)', () {
      final auto = ChartToUnitsConverter.convertFromNarrativeText(
        narrativeText: '1단: 평단',
        blueprintId: 'bp-tag',
      ).first;

      // 자동 생성된 unit에는 'auto:narrative' 태그가 있어야 함
      expect(ChartToUnitsConverter.isAutoGenerated(auto), isTrue,
          reason: '자동 생성 unit은 재변환 시 사용자 편집과 구분하기 위해 태그 필수');
    });
  });

  group('#687 통합: aiSections이 있을 때 chart_to_units는 호출되지 않는 흐름', () {
    test('aiSections이 있는 chart는 변환기 없이 step.id 그대로 unitIds에 매핑', () {
      // pattern_repository._mirrorToBlueprint의 1번 분기 시뮬레이션:
      // aiSections이 있으면 step.id를 그대로 unit.id로 사용 (변환기 X).
      final chart = _baseChart(
        id: 'p-ai',
        aiSections: [
          AiSection(
            id: 'sec-A',
            title: '코늘림',
            steps: [
              AiStep(id: 'ai-st-1', instruction: '+2'),
              AiStep(id: 'ai-st-2', instruction: '+2 again'),
            ],
          ),
        ],
      );
      final bp = StepBlueprintRepository.adaptFromPatternChart(
        chart,
        ownerUid: 'u',
      );
      // 그룹의 unitIds가 step.id 그대로 사용되어야 함 (재분석 시 동일 id로 갱신 가능)
      expect(bp.groups[0].unitIds, ['ai-st-1', 'ai-st-2']);
    });
  });
}
