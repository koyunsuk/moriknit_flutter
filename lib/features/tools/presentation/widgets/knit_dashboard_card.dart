// lib/features/tools/presentation/widgets/knit_dashboard_card.dart
//
// 이슈 #649 Phase 2 — 뜨개 대시보드 카드.
// 프로젝트별 누적 작업시간(이름·시간·마지막 작업일)을 한곳에 모아 보여줍니다.
// 데이터 소스: PatternSession.totalSeconds + PatternSession.projectId 기준 그룹화.
// 정렬: 최근 작업순 / 시간 많은 순 토글.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_data_view.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../providers/project_provider.dart';
import '../../../pattern/data/pattern_session_repository.dart';
import '../../../project/domain/project_model.dart';

enum _SortMode { recent, longest }

class KnitDashboardCard extends ConsumerStatefulWidget {
  final bool isKorean;
  const KnitDashboardCard({super.key, required this.isKorean});

  @override
  ConsumerState<KnitDashboardCard> createState() => _KnitDashboardCardState();
}

class _KnitDashboardCardState extends ConsumerState<KnitDashboardCard> {
  _SortMode _sort = _SortMode.recent;

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return widget.isKorean ? '오늘' : 'Today';
    if (diff.inDays == 1) return widget.isKorean ? '어제' : 'Yesterday';
    if (diff.inDays < 7) {
      return widget.isKorean ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
    }
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final aggAsync = ref.watch(patternTimeByProjectProvider);
    final projects = ref.watch(projectListProvider).valueOrNull ?? const <ProjectModel>[];

    // 이슈 #723 — MoriBlockShell 표준으로 통일. 헤더 아이콘/라벨은 props로 이동.
    return MoriBlockShell(
      label: isKorean ? '뜨개 대시보드' : 'Knit Dashboard',
      icon: Icons.dashboard_rounded,
      accent: C.lvD,
      moreLabel: isKorean ? '새로고침' : 'Refresh',
      onMoreTap: () => ref.invalidate(patternTimeByProjectProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean
                ? '프로젝트별 누적 작업시간을 한눈에 확인해요.'
                : 'View accumulated work time per project.',
            style: T.caption.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 12),
          // 정렬 토글
          Row(
            children: [
              _SortChip(
                label: isKorean ? '최근 작업순' : 'Recent',
                selected: _sort == _SortMode.recent,
                onTap: () => setState(() => _sort = _SortMode.recent),
              ),
              const SizedBox(width: 6),
              _SortChip(
                label: isKorean ? '시간 많은 순' : 'Longest',
                selected: _sort == _SortMode.longest,
                onTap: () => setState(() => _sort = _SortMode.longest),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 본문 — 이슈 #721/#722: AsyncDataView로 로딩/장애/플레이스홀더 통일.
          AsyncDataView<Map<String, ProjectTimeAggregate>>(
            async: aggAsync,
            placeholderRows: 3,
            rowHeight: 50,
            onRetry: () => ref.invalidate(patternTimeByProjectProvider),
            isEmpty: (aggMap) => aggMap.isEmpty || projects.isEmpty,
            emptyBuilder: () => _buildPlaceholder(isKorean),
            builder: (aggMap) => _buildList(aggMap, projects, isKorean),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    Map<String, ProjectTimeAggregate> aggMap,
    List<ProjectModel> projects,
    bool isKorean,
  ) {
    if (aggMap.isEmpty || projects.isEmpty) {
      return _buildPlaceholder(isKorean);
    }

    // 프로젝트와 매칭 + 정렬
    final rows = <_DashboardRow>[];
    final pById = {for (final p in projects) p.id: p};
    aggMap.forEach((pid, agg) {
      final project = pById[pid];
      if (project == null) return; // 삭제된 프로젝트 제외
      rows.add(_DashboardRow(
        projectId: pid,
        title: project.title.isEmpty
            ? (isKorean ? '이름 없는 프로젝트' : 'Untitled project')
            : project.title,
        totalSeconds: agg.totalSeconds,
        lastWorkedAt: agg.lastWorkedAt,
        coverPhotoUrl: project.coverPhotoUrl,
      ));
    });

    if (rows.isEmpty) return _buildPlaceholder(isKorean);

    if (_sort == _SortMode.recent) {
      rows.sort((a, b) {
        final at = a.lastWorkedAt;
        final bt = b.lastWorkedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    } else {
      rows.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
    }

    final visible = rows.take(5).toList();
    return Column(
      children: [
        for (final r in visible)
          _DashboardRowTile(
            row: r,
            formatHms: _formatHms,
            formatDate: _formatDate,
            isKorean: isKorean,
          ),
        if (rows.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isKorean
                  ? '+ ${rows.length - 5}개 프로젝트 더 보기'
                  : '+ ${rows.length - 5} more projects',
              style: T.caption.copyWith(color: C.mu),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(bool isKorean) {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd.withValues(alpha: 0.5)),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          isKorean
              ? '도안 뷰어의 ⏱️ 타이머로 작업하면 여기 누적돼요.'
              : 'Use the ⏱️ timer in pattern viewer to accumulate time.',
          style: T.caption.copyWith(color: C.mu, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DashboardRow {
  final String projectId;
  final String title;
  final int totalSeconds;
  final DateTime? lastWorkedAt;
  final String coverPhotoUrl;
  const _DashboardRow({
    required this.projectId,
    required this.title,
    required this.totalSeconds,
    required this.lastWorkedAt,
    required this.coverPhotoUrl,
  });
}

class _DashboardRowTile extends StatelessWidget {
  final _DashboardRow row;
  final String Function(int) formatHms;
  final String Function(DateTime) formatDate;
  final bool isKorean;

  const _DashboardRowTile({
    required this.row,
    required this.formatHms,
    required this.formatDate,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/project/${row.projectId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // 썸네일/아이콘
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: row.coverPhotoUrl.isNotEmpty
                  ? Image.network(
                      row.coverPhotoUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholderIcon(),
                    )
                  : _placeholderIcon(),
            ),
            const SizedBox(width: 12),
            // 이름 + 마지막 작업일
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: T.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.lastWorkedAt == null
                        ? (isKorean ? '작업 기록 없음' : 'No history')
                        : (isKorean
                            ? '마지막: ${formatDate(row.lastWorkedAt!)}'
                            : 'Last: ${formatDate(row.lastWorkedAt!)}'),
                    style: T.caption.copyWith(color: C.mu),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 누적 시간
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formatHms(row.totalSeconds),
                style: T.captionBold.copyWith(
                  color: C.lvD,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() => Container(
        width: 36,
        height: 36,
        color: C.lv.withValues(alpha: 0.10),
        child: Icon(Icons.folder_rounded, color: C.lvD, size: 20),
      );
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? Colors.white : C.lvD,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
