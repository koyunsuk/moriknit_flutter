// lib/features/project/presentation/widgets/project_time_summary_card.dart
//
// 이슈 #630 — 프로젝트의 도안+스와치 작업 시간 집계 카드.
// 도안 타이머(PatternSession.totalSeconds) + 스와치 타이머(SwatchTimer)를 합산해서 표시.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../pattern/data/pattern_session_repository.dart';
import '../../../swatch/data/swatch_timer_repository.dart';

final _projectTimeTotalProvider =
    FutureProvider.family<_ProjectTimeBreakdown, _ProjectTimeArgs>(
        (ref, args) async {
  final patternRepo = PatternSessionRepository();
  final swatchRepo = ref.watch(swatchTimerRepositoryProvider);

  final patternSeconds = await patternRepo.totalSecondsForProject(args.projectId);
  final swatchSeconds = await swatchRepo.totalForSwatchIds(args.swatchIds);

  return _ProjectTimeBreakdown(
    patternSeconds: patternSeconds,
    swatchSeconds: swatchSeconds,
  );
});

class _ProjectTimeArgs {
  final String projectId;
  final List<String> swatchIds;
  const _ProjectTimeArgs({required this.projectId, required this.swatchIds});

  @override
  bool operator ==(Object other) =>
      other is _ProjectTimeArgs &&
      other.projectId == projectId &&
      _listEq(other.swatchIds, swatchIds);

  @override
  int get hashCode => Object.hash(projectId, Object.hashAll(swatchIds));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _ProjectTimeBreakdown {
  final int patternSeconds;
  final int swatchSeconds;

  const _ProjectTimeBreakdown({
    required this.patternSeconds,
    required this.swatchSeconds,
  });

  int get totalSeconds => patternSeconds + swatchSeconds;
}

class ProjectTimeSummaryCard extends ConsumerWidget {
  final String projectId;
  final List<String> swatchIds;
  final bool isKorean;

  const ProjectTimeSummaryCard({
    super.key,
    required this.projectId,
    required this.swatchIds,
    required this.isKorean,
  });

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _ProjectTimeArgs(projectId: projectId, swatchIds: swatchIds);
    final async = ref.watch(_projectTimeTotalProvider(args));

    return GlassCard(
      child: async.when(
        loading: () => SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator(color: C.lv, strokeWidth: 2)),
        ),
        error: (e, _) => SizedBox(
          height: 64,
          child: Center(
            child: Text(
              isKorean ? '작업 시간 불러오기 실패' : 'Failed to load time',
              style: T.caption.copyWith(color: C.og),
            ),
          ),
        ),
        data: (breakdown) => _buildBody(context, ref, breakdown),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, _ProjectTimeBreakdown b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, color: C.lvD, size: 18),
            const SizedBox(width: 8),
            Text(
              isKorean ? '작업 시간' : 'Work Time',
              style: T.bodyBold,
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 18, color: C.mu),
              tooltip: isKorean ? '새로고침' : 'Refresh',
              onPressed: () {
                ref.invalidate(_projectTimeTotalProvider(
                  _ProjectTimeArgs(projectId: projectId, swatchIds: swatchIds),
                ));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 총 누적시간 (대형)
        Text(
          _formatHms(b.totalSeconds),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: C.tx,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        // 분할 표시
        Row(
          children: [
            _segment(
              label: isKorean ? '스와치' : 'Swatch',
              value: _formatHms(b.swatchSeconds),
              icon: Icons.grid_view_rounded,
              color: C.pkD,
            ),
            const SizedBox(width: 8),
            _segment(
              label: isKorean ? '도안' : 'Pattern',
              value: _formatHms(b.patternSeconds),
              icon: Icons.grid_on_rounded,
              color: C.lvD,
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: T.caption.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: T.bodyBold.copyWith(color: C.tx),
            ),
          ],
        ),
      ),
    );
  }
}
