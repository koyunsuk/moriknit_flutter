// 이슈 #814 — DAU / MAU / 신규가입 / 실시간접속 그룹.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../data/dashboard_metrics_provider.dart';
import 'metric_card.dart';

class TrafficMetricsSection extends ConsumerWidget {
  const TrafficMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dau = ref.watch(dailyActiveUsersProvider);
    final signups = ref.watch(newSignupsProvider);

    return MoriBlockShell(
      label: '사용자 트래픽',
      icon: Icons.people_alt_rounded,
      accent: C.pk,
      child: MetricGrid(
        children: [
          _dauCard(dau),
          _mauCard(dau),
          _weeklySignupsCard(signups),
          _monthlySignupsCard(signups),
        ],
      ),
    );
  }

  Widget _dauCard(AsyncValue<ActiveUsersMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '주간 활성 사용자',
        icon: Icons.group_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '주간 활성 사용자',
        icon: Icons.group_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '주간 활성 사용자',
            icon: Icons.group_rounded,
            placeholderMessage: 'lastSeenAt 추적 미시작',
          );
        }
        return MetricCard(
          title: '주간 활성 사용자',
          icon: Icons.group_rounded,
          value: _formatNumber(m.weekly),
          unit: '명',
          subtitle: '최근 7일',
        );
      },
    );
  }

  Widget _mauCard(AsyncValue<ActiveUsersMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '월간 활성 사용자',
        icon: Icons.groups_2_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '월간 활성 사용자',
        icon: Icons.groups_2_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '월간 활성 사용자',
            icon: Icons.groups_2_rounded,
            placeholderMessage: 'lastSeenAt 추적 미시작',
          );
        }
        return MetricCard(
          title: '월간 활성 사용자',
          icon: Icons.groups_2_rounded,
          value: _formatNumber(m.monthly),
          unit: '명',
          subtitle: '최근 30일',
        );
      },
    );
  }

  Widget _weeklySignupsCard(AsyncValue<SignupsMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '신규 가입 (주)',
        icon: Icons.person_add_alt_1_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '신규 가입 (주)',
        icon: Icons.person_add_alt_1_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '신규 가입 (주)',
            icon: Icons.person_add_alt_1_rounded,
            placeholderMessage: '데이터 수집 중',
          );
        }
        return MetricCard(
          title: '신규 가입 (주)',
          icon: Icons.person_add_alt_1_rounded,
          value: _formatNumber(m.weekly),
          unit: '명',
          subtitle: '최근 7일',
          trend: m.weekly > 0 ? MetricTrend.up : MetricTrend.flat,
        );
      },
    );
  }

  Widget _monthlySignupsCard(AsyncValue<SignupsMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '신규 가입 (월)',
        icon: Icons.person_add_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '신규 가입 (월)',
        icon: Icons.person_add_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '신규 가입 (월)',
            icon: Icons.person_add_rounded,
            placeholderMessage: '데이터 수집 중',
          );
        }
        return MetricCard(
          title: '신규 가입 (월)',
          icon: Icons.person_add_rounded,
          value: _formatNumber(m.monthly),
          unit: '명',
          subtitle: '최근 30일',
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
