import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/project_model.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final statusColor = _statusColor(project.statusEnum);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: C.glassCard,
        child: Column(
          children: [
            if (project.coverPhotoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(project.coverPhotoUrl, height: 140, width: double.infinity, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 10),
                Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: project.progressPercent / 100, backgroundColor: C.lv.withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation(C.lv), minHeight: 5))), const SizedBox(width: 8), Text(project.progressDisplay, style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600))]),
                if (project.needleSize > 0 || project.yarnBrandName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [if (project.needleSize > 0) ...[const Icon(Icons.circle_outlined, size: 12, color: C.mu), const SizedBox(width: 3), Text(project.needleSize % 1 == 0 ? '${project.needleSize.toInt()}mm' : '${project.needleSize}mm', style: T.caption.copyWith(color: C.mu)), const SizedBox(width: 10)], if (project.yarnBrandName.isNotEmpty) ...[const Icon(Icons.texture, size: 12, color: C.mu), const SizedBox(width: 3), Text(project.yarnBrandName, style: T.caption.copyWith(color: C.mu))]]),
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
      case ProjectStatus.inProgress: return C.lm;
      case ProjectStatus.blocking: return C.og;
      case ProjectStatus.finished: return C.pk;
    }
  }
}

class ProjectEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const ProjectEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.folder_rounded, color: C.lv, size: 36)),
          const SizedBox(height: 16),
          Text(isKorean ? '첫 프로젝트를 시작해보세요' : 'Start your first project', style: T.bodyBold),
          const SizedBox(height: 6),
          Text(isKorean ? '뜨개 계획과 진행률을 한곳에서 기록할 수 있어요.' : 'Track your knitting plans and progress in one place.', style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: const Icon(Icons.add, size: 20), label: Text(isKorean ? '프로젝트 만들기' : 'New project'), onPressed: onAdd),
        ],
      ),
    );
  }
}
