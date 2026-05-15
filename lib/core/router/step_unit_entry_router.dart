import 'package:flutter/material.dart';

import '../../features/blueprint/presentation/step_log_screen.dart';
import '../../features/pattern/domain/pattern_chart.dart';
import '../../features/pattern/presentation/pattern_editor_screen.dart';
import '../../features/pattern_converter/presentation/pattern_converter_screen.dart';

/// 이슈 #687 (Phase F) — 도안 섹션 편집 진입점 분기 라우터.
///
/// 도안 [PatternType] 과 AI 변환 여부(`aiSections` 존재)에 따라
/// 진입 화면을 다르게 결정한다. 호출부는 본 헬퍼만 사용.
///
/// 분기 규칙:
/// - `PatternType.chart` → [PatternEditorScreen] (도안에디터)
/// - `PatternType.pdf` / `image`
///   - `aiSections` 있음 → [StepLogScreen] (Phase D1: 단계로그 통일 화면)
///   - `aiSections` 없음 → [PatternConverterScreen] (AI 변환기)
class StepUnitEntryRouter {
  const StepUnitEntryRouter._();

  /// 도안의 섹션 편집 진입점을 결정해 push 한다.
  static Future<void> openSectionEditor(
    BuildContext context, {
    required PatternChart chart,
  }) {
    final hasAi = (chart.aiSections ?? const []).isNotEmpty;

    switch (chart.type) {
      case PatternType.chart:
        return Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatternEditorScreen(patternId: chart.id),
          ),
        );
      case PatternType.pdf:
      case PatternType.image:
        if (hasAi) {
          // Phase D1 (#687): AI 섹션은 step_blueprints/{chart.id}/units 로
          // 자동 미러링됨 (Phase B). blueprintId = chart.id 로 단계로그 통일
          // 화면 진입.
          return Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StepLogScreen(blueprintId: chart.id),
            ),
          );
        }
        return Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PatternConverterScreen(),
          ),
        );
    }
  }
}
