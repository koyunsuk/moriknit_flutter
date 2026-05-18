import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/counter/domain/counter_model.dart';
import '../../../../providers/counter_provider.dart';
import '../../../../providers/project_step_provider.dart';
import '../../domain/project_model.dart';

class ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final bool compact;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final statusColor = _statusColor(project.statusEnum);

    // 단계 기반 진행률
    final stepsAsync = ref.watch(projectStepsProvider(project.id));
    final steps = stepsAsync.valueOrNull ?? [];
    final hasSteps = steps.isNotEmpty;
    final completedSteps = steps.where((s) => s.isDone).length;
    final stepProgress = hasSteps ? completedSteps / steps.length : null;
    final stepLabel = hasSteps
        ? (isKorean ? '$completedSteps/${steps.length}단계 완료' : '$completedSteps/${steps.length} steps done')
        : null;

    // 카운터 기반 진행률
    final countersAsync = ref.watch(countersByProjectProvider(project.id));
    final counters = countersAsync.valueOrNull ?? [];
    final counterWithTarget = counters.where((c) => c.targetRowCount > 0);
    final hasCounter = counterWithTarget.isNotEmpty;
    final counter = hasCounter ? counterWithTarget.first : null;
    final counterProgress = counter?.rowProgress;
    final counterLabel = counter == null ? null
        : (isKorean ? '${counter.rowCount}/${counter.targetRowCount}단' : '${counter.rowCount}/${counter.targetRowCount} rows');

    // 표시할 진행률: 단계 우선, 없으면 카운터, 둘 다 없으면 stored value
    final displayProgress = stepProgress ?? counterProgress ?? (project.progressPercent / 100);
    final displayLabel = stepLabel ?? counterLabel ?? project.progressDisplay;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: compact ? 0 : 12),
        decoration: C.glassCard,
        child: Column(
          children: [
            if (project.coverPhotoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: CachedNetworkImage(
                  imageUrl: project.coverPhotoUrl,
                  height: compact ? 112 : 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel(project.statusEnum, isKorean), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(project.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                if (project.description.isNotEmpty) ...[const SizedBox(height: 4), Text(project.description, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis)],
                SizedBox(height: compact ? 8 : 10),
                Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: displayProgress.clamp(0.0, 1.0), backgroundColor: C.lv.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(C.lv), minHeight: 5))), const SizedBox(width: 8), Text(displayLabel, style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600))]),
                // 단계와 카운터 둘 다 있으면 카운터도 추가 표시
                if (hasSteps && hasCounter) ...[
                  const SizedBox(height: 4),
                  Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: counterProgress!.clamp(0.0, 1.0), backgroundColor: C.lmD.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(C.lmD), minHeight: 3))), const SizedBox(width: 8), Text(counterLabel!, style: T.caption.copyWith(color: C.lmD, fontSize: 10))]),
                ],
                if (project.needleSize > 0 || project.yarnBrandName.isNotEmpty) ...[
                  SizedBox(height: compact ? 6 : 8),
                  Row(children: [if (project.needleSize > 0) ...[Icon(Icons.circle_outlined, size: 12, color: C.mu), const SizedBox(width: 3), Text('${project.needleSize.toStringAsFixed(2)}mm', style: T.caption.copyWith(color: C.mu)), const SizedBox(width: 10)], if (project.yarnBrandName.isNotEmpty) ...[Icon(Icons.texture, size: 12, color: C.mu), const SizedBox(width: 3), Text(project.yarnBrandName, style: T.caption.copyWith(color: C.mu))]]),
                ],
                if (project.yarnColor.isNotEmpty || project.yarnName.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Row(children: [
                    if (project.yarnColor.isNotEmpty) ...[
                      Icon(Icons.circle, size: 10, color: C.pk),
                      const SizedBox(width: 4),
                      Text(project.yarnColor, style: T.caption.copyWith(color: C.mu)),
                      if (project.yarnName.isNotEmpty) const SizedBox(width: 10),
                    ],
                    if (project.yarnName.isNotEmpty) ...[
                      Icon(Icons.fiber_manual_record_rounded, size: 10, color: C.mu),
                      const SizedBox(width: 4),
                      Flexible(child: Text(project.yarnName, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(ProjectStatus status, bool isKorean) {
    if (!isKorean) return status.label;
    switch (status) {
      case ProjectStatus.planning: return '계획 중';
      case ProjectStatus.swatching: return '스와치 중';
      case ProjectStatus.inProgress: return '진행 중';
      case ProjectStatus.blocking: return '보류';
      case ProjectStatus.finished: return '완료';
    }
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning: return C.mu;
      case ProjectStatus.swatching: return C.lv;
      case ProjectStatus.inProgress: return C.lmD;
      case ProjectStatus.blocking: return C.og;
      case ProjectStatus.finished: return C.pk;
    }
  }
}

class ProjectEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenCommunity;
  final VoidCallback? onOpenSwatches;

  const ProjectEmptyState({
    super.key,
    required this.onAdd,
    this.onOpenMarket,
    this.onOpenCommunity,
    this.onOpenSwatches,
  });

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isKorean ? '오늘은 무엇을 해볼까요?' : 'What would you like to do today?', style: T.bodyBold),
          const SizedBox(height: 6),
          Text(isKorean ? '프로젝트가 없어도 도안 구경, 첫 인사, 스와치 기록부터 시작할 수 있어요.' : 'Even without a project, you can browse patterns, say hello, or start with a swatch.', style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (onOpenMarket != null)
                OutlinedButton.icon(onPressed: onOpenMarket, icon: const Icon(Icons.storefront_rounded, size: 18), label: Text(isKorean ? '마켓에서 도안 구경하기' : 'Browse market')),
              if (onOpenCommunity != null)
                OutlinedButton.icon(onPressed: onOpenCommunity, icon: const Icon(Icons.people_alt_rounded, size: 18), label: Text(isKorean ? '첫 인사하기' : 'Say hello')),
              if (onOpenSwatches != null)
                OutlinedButton.icon(onPressed: onOpenSwatches, icon: const Icon(Icons.grid_view_rounded, size: 18), label: Text(isKorean ? '스와치부터 해보기' : 'Start with a swatch')),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: Icon(Icons.add, size: 20), label: Text(isKorean ? '프로젝트 만들기' : 'New project'), onPressed: onAdd),
        ],
      ),
    );
  }
}
