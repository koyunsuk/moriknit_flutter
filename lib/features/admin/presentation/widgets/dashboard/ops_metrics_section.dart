// 이슈 #814 — 운영 지표 (미해결 버그/문의/미검수 도안).
//
// 모든 카드는 빨간 카운트 뱃지 + 클릭 시 해당 탭으로 이동.
// 탭 이동은 onTabChange 콜백을 통해 부모(AdminScreen)에서 처리.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../data/dashboard_metrics_provider.dart';
import 'metric_card.dart';

/// 운영 지표 섹션.
///
/// [onOpenBugReports]/[onOpenInquiries]/[onOpenPendingPatterns] 콜백을 주면
/// 카드 클릭 시 해당 탭으로 전환할 수 있다. null이면 단순 표시만.
class OpsMetricsSection extends ConsumerWidget {
  final VoidCallback? onOpenBugReports;
  final VoidCallback? onOpenInquiries;
  final VoidCallback? onOpenPendingPatterns;

  const OpsMetricsSection({
    super.key,
    this.onOpenBugReports,
    this.onOpenInquiries,
    this.onOpenPendingPatterns,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugs = ref.watch(bugReportsCountProvider);
    final inquiries = ref.watch(inquiriesCountProvider);
    final pending = ref.watch(pendingPatternsCountProvider);

    return MoriBlockShell(
      label: '운영 지표',
      icon: Icons.assignment_late_rounded,
      accent: C.og,
      child: MetricGrid(
        children: [
          _opCard(
            async: bugs,
            title: '미해결 버그',
            icon: Icons.bug_report_rounded,
            onTap: onOpenBugReports,
            actionLabel: '바로 처리',
          ),
          _opCard(
            async: inquiries,
            title: '미응답 1:1 문의',
            icon: Icons.mail_rounded,
            onTap: onOpenInquiries,
            actionLabel: '바로 답변',
          ),
          _opCard(
            async: pending,
            title: '미검수 도안',
            icon: Icons.fact_check_rounded,
            onTap: onOpenPendingPatterns,
            actionLabel: '바로 검수',
          ),
        ],
      ),
    );
  }

  Widget _opCard({
    required AsyncValue<int?> async,
    required String title,
    required IconData icon,
    required String actionLabel,
    VoidCallback? onTap,
  }) {
    return async.when(
      loading: () => MetricCard.placeholder(
        title: title,
        icon: icon,
        color: C.og,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: title,
        icon: icon,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (count) {
        final n = count ?? 0;
        if (count == null) {
          return MetricCard.placeholder(
            title: title,
            icon: icon,
            color: C.og,
            placeholderMessage: '데이터 수집 중',
            onTap: onTap,
          );
        }
        return MetricCard(
          title: title,
          icon: icon,
          color: n > 0 ? C.og : C.lm,
          value: _formatNumber(n),
          unit: '건',
          badgeCount: n,
          subtitle: n > 0 ? '클릭하면 $actionLabel' : '처리 완료',
          onTap: onTap,
        );
      },
    );
  }
}

String _formatNumber(num n) {
  final s = n.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
