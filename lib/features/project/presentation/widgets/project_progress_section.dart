import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../counter/domain/counter_model.dart';
import '../../../../providers/counter_provider.dart';
import '../../../../providers/project_step_provider.dart';
import '../../domain/project_model.dart';

/// 프로젝트 진행률 섹션 — 단계 + 카운터 동시 표시 (공통 위젯)
/// 사용처: project_detail_screen, project_list_screen (활성 프로젝트 요약카드)
class ProjectProgressSection extends ConsumerWidget {
  final ProjectModel project;

  const ProjectProgressSection({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    // 단계 진행률
    final steps = ref.watch(projectStepsProvider(project.id)).valueOrNull ?? [];
    final hasSteps = steps.isNotEmpty;
    final completedSteps = steps.where((s) => s.isDone).length;
    final stepProgress = hasSteps ? completedSteps / steps.length : 0.0;
    final stepPct = '${(stepProgress * 100).toStringAsFixed(0)}%';

    // 카운터 진행률
    final counters = ref.watch(countersByProjectProvider(project.id)).valueOrNull ?? [];
    final counter = counters.where((c) => c.targetRowCount > 0).firstOrNull;
    final counterProgress = counter?.rowProgress ?? 0.0;
    final counterPct = counter != null ? '${(counterProgress * 100).toStringAsFixed(0)}%' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isKorean ? '진행률' : 'Progress', style: T.captionBold.copyWith(color: C.mu)),
        const SizedBox(height: 8),

        // 단계 진행률
        Row(
          children: [
            Icon(Icons.format_list_numbered_rounded, size: 13, color: C.lv),
            const SizedBox(width: 4),
            Text(isKorean ? '단계' : 'Steps', style: T.caption.copyWith(color: C.mu)),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: stepProgress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: C.lv.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(C.lv),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hasSteps
                  ? '$completedSteps/${steps.length} ($stepPct)'
                  : (isKorean ? '단계 없음' : 'No steps'),
              style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // 카운터 진행률
        Row(
          children: [
            Icon(Icons.pin_rounded, size: 13, color: C.lmD),
            const SizedBox(width: 4),
            Text(isKorean ? '카운터' : 'Counter', style: T.caption.copyWith(color: C.mu)),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: counterProgress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: C.lmD.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(C.lmD),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              counter != null
                  ? '${counter.rowCount}/${counter.targetRowCount}단 ($counterPct)'
                  : (isKorean ? '목표 없음' : 'No target'),
              style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
