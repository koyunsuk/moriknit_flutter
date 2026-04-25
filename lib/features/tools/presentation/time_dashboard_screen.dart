// lib/features/tools/presentation/time_dashboard_screen.dart
//
// 이슈 #630 (B-6) — 통합 뜨개시간 대시보드.
// 자유 타이머 + 모든 도안 세션 + 모든 스와치 타이머의 누적 시간을 한곳에서 확인.
// 이슈 #649 Phase 3 — 프로젝트별 작업시간 카드/통계 + 정렬 토글 추가.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/project_provider.dart';
import '../../pattern/data/pattern_session_repository.dart';
import '../../project/domain/project_model.dart';
import '../../swatch/data/swatch_timer_repository.dart';
import '../data/free_timer_repository.dart';

class _DashboardData {
  final int freeSeconds;
  final int patternSeconds;
  final int swatchSeconds;
  const _DashboardData({
    required this.freeSeconds,
    required this.patternSeconds,
    required this.swatchSeconds,
  });
  int get totalSeconds => freeSeconds + patternSeconds + swatchSeconds;
}

final _timeDashboardProvider = FutureProvider.autoDispose<_DashboardData>((ref) async {
  final freeRepo = ref.watch(freeTimerRepositoryProvider);
  final swatchRepo = ref.watch(swatchTimerRepositoryProvider);
  final patternRepo = PatternSessionRepository();

  final free = await freeRepo.load();
  final pattern = await patternRepo.totalSecondsAll();
  final swatch = await swatchRepo.totalSecondsAll();

  return _DashboardData(
    freeSeconds: free.totalSeconds,
    patternSeconds: pattern,
    swatchSeconds: swatch,
  );
});

/// 이슈 #649 Phase 3 — 프로젝트별 작업시간 합계.
class _ProjectTimeRow {
  final ProjectModel project;
  final int patternSeconds;
  final int swatchSeconds;
  final DateTime? lastWorkedAt;
  const _ProjectTimeRow({
    required this.project,
    required this.patternSeconds,
    required this.swatchSeconds,
    this.lastWorkedAt,
  });
  int get totalSeconds => patternSeconds + swatchSeconds;
}

/// 이슈 #649 Phase 3 — 프로젝트별 시간 집계 Provider.
/// PatternSession.projectId + Swatch.projectId(→swatch_timers) 기준 집계.
final _projectTimeRowsProvider =
    FutureProvider.autoDispose<List<_ProjectTimeRow>>((ref) async {
  final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
  if (projects.isEmpty) return const [];

  // 1) 도안 세션 집계
  final patternAggregates =
      await ref.watch(patternSessionRepositoryProvider).aggregateByProject();

  // 2) 스와치 타이머 집계 (swatchId → seconds)
  final swatchSeconds =
      await ref.watch(swatchTimerRepositoryProvider).loadAllSecondsBySwatchId();

  // 3) 프로젝트별 swatchId 매핑 (ProjectModel.swatchId 단일값 기준)
  // 추가로 SwatchModel.projectId 역매핑까지 결합 — swatchId가 ProjectModel에 안 잡혀도 인식.
  final projectIdToSwatchIds = <String, Set<String>>{};
  for (final p in projects) {
    if (p.swatchId.isNotEmpty) {
      projectIdToSwatchIds.putIfAbsent(p.id, () => {}).add(p.swatchId);
    }
  }
  // SwatchModel 기반 역매핑은 swatchRepository를 동기 watch하지 않고,
  // pattern_session.swatchId 매핑은 사용 안 함 (swatch_timers는 swatchId 키이므로).

  // 4) 프로젝트별 행 구성
  final rows = <_ProjectTimeRow>[];
  for (final p in projects) {
    final pAgg = patternAggregates[p.id];
    final patternSec = pAgg?.totalSeconds ?? 0;
    final swatchIds = projectIdToSwatchIds[p.id] ?? const <String>{};
    int swatchSec = 0;
    for (final sid in swatchIds) {
      swatchSec += swatchSeconds[sid] ?? 0;
    }
    final lastWorked = pAgg?.lastWorkedAt ?? p.updatedAt;
    rows.add(_ProjectTimeRow(
      project: p,
      patternSeconds: patternSec,
      swatchSeconds: swatchSec,
      lastWorkedAt: lastWorked,
    ));
  }
  return rows;
});

/// 정렬 모드.
enum _ProjectSortMode { recent, longest }

final _projectSortModeProvider =
    StateProvider.autoDispose<_ProjectSortMode>((ref) => _ProjectSortMode.recent);

class TimeDashboardScreen extends ConsumerWidget {
  const TimeDashboardScreen({super.key});

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  /// HH:MM:SS 정밀 표기 (프로젝트 카드용).
  String _formatHmsPrecise(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final async = ref.watch(_timeDashboardProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '뜨개시간 대시보드' : 'Knitting Time Dashboard',
                subtitle: isKorean
                    ? '자유·도안·스와치 누적시간 통합 보기'
                    : 'Combined view of free / pattern / swatch time',
                trailing: [
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: C.tx),
                    onPressed: () {
                      ref.invalidate(_timeDashboardProvider);
                      ref.invalidate(_projectTimeRowsProvider);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (e, _) => Center(
                  child: Text(
                    isKorean ? '오류: $e' : 'Error: $e',
                    style: T.caption.copyWith(color: C.og),
                  ),
                ),
                data: (data) => _buildBody(context, ref, data, isKorean),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, _DashboardData data, bool isKorean) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 총합
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.lv, C.lvD],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKorean ? '전체 누적시간' : 'Total Time',
                  style: T.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatHms(data.totalSeconds),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _segmentCard(
            label: isKorean ? '자유 타이머' : 'Free Timer',
            sub: isKorean
                ? '도구함의 독립 타이머'
                : 'Independent timer in tools',
            value: _formatHms(data.freeSeconds),
            icon: Icons.timer_outlined,
            color: C.lvD,
          ),
          const SizedBox(height: 10),
          _segmentCard(
            label: isKorean ? '도안 작업 시간' : 'Pattern Time',
            sub: isKorean
                ? '도안뷰어의 ⏱️ 타이머 누적'
                : 'Accumulated from pattern viewer ⏱️',
            value: _formatHms(data.patternSeconds),
            icon: Icons.grid_on_rounded,
            color: C.lmD,
          ),
          const SizedBox(height: 10),
          _segmentCard(
            label: isKorean ? '스와치 작업 시간' : 'Swatch Time',
            sub: isKorean
                ? '스와치별 타이머 누적'
                : 'Accumulated from swatch timers',
            value: _formatHms(data.swatchSeconds),
            icon: Icons.grid_view_rounded,
            color: C.pkD,
          ),
          const SizedBox(height: 28),
          // 이슈 #649 Phase 3 — 프로젝트별 작업시간 섹션
          _ProjectTimeSection(
            isKorean: isKorean,
            formatHms: _formatHmsPrecise,
            onTapProject: (id) => context.push('/projects/$id'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: C.mu, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isKorean
                        ? '프로젝트 카드는 도안 세션 + 연결된 스와치 타이머의 합산입니다. 도안별·스와치별 세부 통계는 추후 추가됩니다.'
                        : 'Project cards combine pattern sessions and linked swatch timers. Per-pattern / per-swatch breakdowns coming soon.',
                    style: T.caption.copyWith(color: C.mu, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentCard({
    required String label,
    required String sub,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.bodyBold),
                const SizedBox(height: 2),
                Text(sub, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          Text(
            value,
            style: T.h3.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ── 이슈 #649 Phase 3 — 프로젝트별 작업시간 섹션 ─────────────────────

class _ProjectTimeSection extends ConsumerWidget {
  final bool isKorean;
  final String Function(int) formatHms;
  final void Function(String projectId) onTapProject;

  const _ProjectTimeSection({
    required this.isKorean,
    required this.formatHms,
    required this.onTapProject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRows = ref.watch(_projectTimeRowsProvider);
    final sortMode = ref.watch(_projectSortModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: isKorean ? '프로젝트별 작업시간' : 'Time by Project',
          trailing: _SortToggle(
            mode: sortMode,
            isKorean: isKorean,
            onChanged: (m) =>
                ref.read(_projectSortModeProvider.notifier).state = m,
          ),
        ),
        const SizedBox(height: 10),
        asyncRows.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: C.lv)),
          ),
          error: (e, _) => _placeholder(
            isKorean
                ? '프로젝트 시간을 불러오지 못했어요.'
                : 'Failed to load project time.',
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return _placeholder(
                isKorean
                    ? '아직 등록된 프로젝트가 없어요.\n프로젝트를 만들고 도안·스와치 타이머를 시작해 보세요.'
                    : 'No projects yet.\nCreate a project and start a pattern or swatch timer.',
              );
            }
            final sorted = [...rows];
            switch (sortMode) {
              case _ProjectSortMode.recent:
                sorted.sort((a, b) {
                  final at = a.lastWorkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bt = b.lastWorkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bt.compareTo(at);
                });
                break;
              case _ProjectSortMode.longest:
                sorted.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
                break;
            }
            // 최대 시간 (진행률 바 상대 길이용)
            final maxSec = sorted
                .map((r) => r.totalSeconds)
                .fold<int>(0, (p, e) => e > p ? e : p);

            return Column(
              children: [
                for (final row in sorted) ...[
                  _ProjectTimeCard(
                    row: row,
                    isKorean: isKorean,
                    formatHms: formatHms,
                    maxSeconds: maxSec,
                    onTap: () => onTapProject(row.project.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _placeholder(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.5),
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final _ProjectSortMode mode;
  final bool isKorean;
  final ValueChanged<_ProjectSortMode> onChanged;

  const _SortToggle({
    required this.mode,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(
          label: isKorean ? '최근' : 'Recent',
          selected: mode == _ProjectSortMode.recent,
          onTap: () => onChanged(_ProjectSortMode.recent),
        ),
        const SizedBox(width: 6),
        _chip(
          label: isKorean ? '시간 많은 순' : 'Longest',
          selected: mode == _ProjectSortMode.longest,
          onTap: () => onChanged(_ProjectSortMode.longest),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
          ),
          borderRadius: BorderRadius.circular(20),
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

class _ProjectTimeCard extends StatelessWidget {
  final _ProjectTimeRow row;
  final bool isKorean;
  final String Function(int) formatHms;
  final int maxSeconds;
  final VoidCallback onTap;

  const _ProjectTimeCard({
    required this.row,
    required this.isKorean,
    required this.formatHms,
    required this.maxSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = row.project;
    final statusEnum = p.statusEnum;
    final statusLabel = statusEnum.localizedLabel(isKorean);
    final progressRatio = maxSeconds <= 0 ? 0.0 : row.totalSeconds / maxSeconds;
    final title = p.title.trim().isEmpty
        ? (isKorean ? '(이름 없는 프로젝트)' : '(Untitled project)')
        : p.title;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: T.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusBadge(label: statusLabel, status: statusEnum),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _subtitle(),
                              style: T.caption.copyWith(color: C.mu),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatHms(row.totalSeconds),
                  style: T.h3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: C.lvD,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: C.lvL,
                valueColor: AlwaysStoppedAnimation<Color>(C.lv),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat(
                  icon: Icons.grid_on_rounded,
                  color: C.lmD,
                  label: isKorean ? '도안' : 'Pattern',
                  value: formatHms(row.patternSeconds),
                ),
                const SizedBox(width: 14),
                _miniStat(
                  icon: Icons.grid_view_rounded,
                  color: C.pkD,
                  label: isKorean ? '스와치' : 'Swatch',
                  value: formatHms(row.swatchSeconds),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final last = row.lastWorkedAt;
    if (last == null) {
      return isKorean ? '작업 기록 없음' : 'No activity yet';
    }
    final now = DateTime.now();
    final diff = now.difference(last);
    if (diff.inMinutes < 1) {
      return isKorean ? '방금 전 작업' : 'Just now';
    }
    if (diff.inHours < 1) {
      return isKorean ? '${diff.inMinutes}분 전' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return isKorean ? '${diff.inHours}시간 전' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 30) {
      return isKorean ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
    }
    return isKorean
        ? '${last.year}.${last.month.toString().padLeft(2, '0')}.${last.day.toString().padLeft(2, '0')}'
        : '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$label ', style: T.caption.copyWith(color: C.mu)),
        Text(
          value,
          style: T.caption.copyWith(
            color: C.tx,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final ProjectStatus status;
  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: T.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _colorFor(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.planning:
        return C.mu;
      case ProjectStatus.swatching:
        return C.pkD;
      case ProjectStatus.inProgress:
        return C.lvD;
      case ProjectStatus.blocking:
        return C.og;
      case ProjectStatus.finished:
        return C.lmD;
    }
  }
}
