import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../project/domain/project_model.dart';
import '../domain/counter_model.dart';
import 'counter_group_screen.dart';

/// 카운터 라이브러리 — 요약 화면.
///
/// 사용자 원칙: "모든 화면 초입 = 요약".
/// 평면 카운터 리스트가 아닌, 프로젝트별 묶음 + 자유 카운터 묶음 카드 제공.
/// 카드 클릭 → CounterGroupScreen (필터링된 상세).
class CounterListScreen extends ConsumerWidget {
  const CounterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counterListAsync = ref.watch(counterListProvider);
    final projectListAsync = ref.watch(projectListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '카운터' : 'Counters',
                subtitle:
                    isKorean ? '프로젝트별 카운터 모음' : 'Counter groups by project',
              ),
            ),
            Expanded(
              child: counterListAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: C.lmD)),
                error: (e, _) => Center(child: Text('$e', style: T.body)),
                data: (counters) {
                  final projects = projectListAsync.valueOrNull ?? [];

                  // 카운터 분류
                  final byProject = <String, List<CounterModel>>{};
                  final freeCounters = <CounterModel>[];
                  for (final c in counters) {
                    if (c.projectId.isNotEmpty) {
                      byProject.putIfAbsent(c.projectId, () => []).add(c);
                    } else {
                      freeCounters.add(c);
                    }
                  }

                  // 표시할 프로젝트 = 카운터가 있는 프로젝트 + 사용자의 활성 프로젝트
                  // (카운터가 없는 프로젝트도 카드로 보여서 추가 동선 제공)
                  final projectMap = {for (final p in projects) p.id: p};
                  final allProjectIds = <String>{
                    ...byProject.keys,
                    ...projects.map((p) => p.id),
                  };

                  // 정렬: 카운터 많은 순 → 최근 업데이트 순
                  final projectGroups = allProjectIds
                      .where((id) => projectMap.containsKey(id))
                      .map((id) {
                    final p = projectMap[id]!;
                    final list = byProject[id] ?? const <CounterModel>[];
                    return _ProjectGroup(project: p, counters: list);
                  }).toList()
                    ..sort((a, b) {
                      final byCount =
                          b.counters.length.compareTo(a.counters.length);
                      if (byCount != 0) return byCount;
                      final aT = a.project.updatedAt ?? DateTime(0);
                      final bT = b.project.updatedAt ?? DateTime(0);
                      return bT.compareTo(aT);
                    });

                  bool isCounterDone(CounterModel c) {
                    if (c.hasTargets &&
                        c.stitchProgress >= 1.0 &&
                        c.rowProgress >= 1.0) {
                      return true;
                    }
                    if (c.projectId.isNotEmpty) {
                      final proj = projectMap[c.projectId];
                      if (proj != null && proj.status == 'finished') {
                        return true;
                      }
                    }
                    return false;
                  }

                  final totalCounters = counters.length;
                  final doneCount = counters.where(isCounterDone).length;
                  final activeCount = totalCounters - doneCount;

                  return Stack(
                    children: [
                      const BgOrbs(),
                      Positioned.fill(
                        child: _SummaryView(
                          isKorean: isKorean,
                          totalCounters: totalCounters,
                          activeCount: activeCount,
                          doneCount: doneCount,
                          projectGroups: projectGroups,
                          freeCounters: freeCounters,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGroup {
  final ProjectModel project;
  final List<CounterModel> counters;
  const _ProjectGroup({required this.project, required this.counters});
}

class _SummaryView extends StatelessWidget {
  final bool isKorean;
  final int totalCounters;
  final int activeCount;
  final int doneCount;
  final List<_ProjectGroup> projectGroups;
  final List<CounterModel> freeCounters;

  const _SummaryView({
    required this.isKorean,
    required this.totalCounters,
    required this.activeCount,
    required this.doneCount,
    required this.projectGroups,
    required this.freeCounters,
  });

  void _openGroup(BuildContext context, String projectId, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CounterGroupScreen(projectId: projectId, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 빈 상태도 섹션 자체는 항상 표시 (플레이스홀더 원칙)
    final hasAny = totalCounters > 0 || projectGroups.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // 요약 카드
        LibrarySummaryCard(
          headers: [
            isKorean ? '전체' : 'Total',
            isKorean ? '진행' : 'Active',
            isKorean ? '완료' : 'Done',
          ],
          rows: [
            LibrarySummaryRowData(
              badge: isKorean ? '카운터' : 'Counter',
              badgeColor: C.lmD,
              values: ['$totalCounters', '$activeCount', '$doneCount'],
              valueColors: [C.tx, C.lv, C.pkD],
            ),
            LibrarySummaryRowData(
              badge: isKorean ? '프로젝트' : 'Project',
              badgeColor: C.lv,
              values: [
                '${projectGroups.length}',
                '${projectGroups.where((g) => g.counters.isNotEmpty).length}',
                '${freeCounters.length}',
              ],
              valueColors: [C.tx, C.lv, C.lmD],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 자유 카운터 카드 (눈에 띄게 상단)
        SectionTitle(title: isKorean ? '자유 카운터' : 'Free Counters'),
        const SizedBox(height: 8),
        _FreeCountersCard(
          isKorean: isKorean,
          counters: freeCounters,
          onTap: () => _openGroup(
            context,
            '',
            isKorean ? '자유 카운터' : 'Free Counters',
          ),
        ),
        const SizedBox(height: 18),

        // 프로젝트별 카드
        SectionTitle(title: isKorean ? '프로젝트별' : 'By Project'),
        const SizedBox(height: 8),
        if (projectGroups.isEmpty)
          _EmptyProjectsPlaceholder(isKorean: isKorean)
        else
          ...projectGroups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProjectGroupCard(
                isKorean: isKorean,
                project: g.project,
                counters: g.counters,
                onTap: () => _openGroup(context, g.project.id, g.project.title),
              ),
            ),
          ),

        if (!hasAny) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              isKorean
                  ? '아직 카운터가 없어요. 카드로 진입해 추가해보세요.'
                  : 'No counters yet. Tap a card to add one.',
              style: T.caption.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

// ── 자유 카운터 카드 ───────────────────────────────────────────────────
class _FreeCountersCard extends StatelessWidget {
  final bool isKorean;
  final List<CounterModel> counters;
  final VoidCallback onTap;

  const _FreeCountersCard({
    required this.isKorean,
    required this.counters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.lmD.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.lmD.withValues(alpha: 0.28)),
            ),
            child: Icon(Icons.bookmark_outline_rounded,
                color: C.lmD, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKorean ? '자유 카운터' : 'Free Counters',
                  style: T.bodyBold,
                ),
                const SizedBox(height: 4),
                Text(
                  isKorean
                      ? '프로젝트와 연결되지 않은 카운터'
                      : 'Counters not linked to any project',
                  style: T.caption.copyWith(color: C.mu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: C.lmD.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${counters.length}',
              style: T.bodyBold.copyWith(color: C.lmD),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

// ── 프로젝트 그룹 카드 ─────────────────────────────────────────────────
class _ProjectGroupCard extends StatelessWidget {
  final bool isKorean;
  final ProjectModel project;
  final List<CounterModel> counters;
  final VoidCallback onTap;

  const _ProjectGroupCard({
    required this.isKorean,
    required this.project,
    required this.counters,
    required this.onTap,
  });

  String _statusLabel(BuildContext context) {
    final s = ProjectStatusExt.fromValue(project.status);
    return s.localizedLabel(isKorean);
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = project.coverPhotoUrl.isNotEmpty;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          // 표지 또는 아이콘
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: hasCover
                  ? Image.network(
                      project.coverPhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackIcon(),
                    )
                  : _fallbackIcon(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title.isEmpty
                      ? (isKorean ? '(이름 없음)' : '(Untitled)')
                      : project.title,
                  style: T.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: C.lv.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        _statusLabel(context),
                        style: T.caption.copyWith(
                            color: C.lvD, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isKorean
                          ? '카운터 ${counters.length}'
                          : '${counters.length} counters',
                      style: T.caption.copyWith(color: C.mu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: counters.isEmpty
                  ? C.bd2
                  : C.lmD.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${counters.length}',
              style: T.bodyBold.copyWith(
                color: counters.isEmpty ? C.mu : C.lmD,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }

  Widget _fallbackIcon() => Container(
        color: C.lmD.withValues(alpha: 0.12),
        child: Icon(Icons.folder_rounded, color: C.lmD, size: 26),
      );
}

// ── 빈 프로젝트 플레이스홀더 ─────────────────────────────────────────────
class _EmptyProjectsPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _EmptyProjectsPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    // 빈 행 3개로 공간 고정 (플레이스홀더 원칙)
    return GlassCard(
      child: Column(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) Divider(height: 12, color: C.bd.withValues(alpha: 0.6)),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.bd2.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 10,
                        decoration: BoxDecoration(
                          color: C.bd2.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 70,
                        height: 8,
                        decoration: BoxDecoration(
                          color: C.bd2.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            isKorean
                ? '프로젝트를 만들면 자동으로 묶음으로 나타나요.'
                : 'Create a project to see groups here.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
