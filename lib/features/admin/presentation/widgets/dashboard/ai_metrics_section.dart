// 이슈 #814 — AI 토큰 사용량 + 비용 + 호출 수.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../data/dashboard_metrics_provider.dart';
import 'metric_card.dart';

class AiMetricsSection extends ConsumerWidget {
  const AiMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiTokenUsageProvider);

    return MoriBlockShell(
      label: 'AI 사용량',
      icon: Icons.auto_awesome_rounded,
      accent: C.lv,
      child: MetricGrid(
        children: [
          _totalTokensCard(ai),
          _callCountCard(ai),
          _promptCompletionCard(ai),
          _costCard(ai),
        ],
      ),
    );
  }

  Widget _totalTokensCard(AsyncValue<AiTokenMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '총 토큰 (30일)',
        icon: Icons.psychology_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '총 토큰 (30일)',
        icon: Icons.psychology_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.totalTokens == null) {
          return const MetricCard.placeholder(
            title: '총 토큰 (30일)',
            icon: Icons.psychology_rounded,
            placeholderMessage: 'ai_usage_logs 적재 대기',
          );
        }
        return MetricCard(
          title: '총 토큰 (30일)',
          icon: Icons.psychology_rounded,
          value: _formatNumber(m.totalTokens!),
          unit: 'tok',
          subtitle: '최근 30일',
        );
      },
    );
  }

  Widget _callCountCard(AsyncValue<AiTokenMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: 'AI 호출 (30일)',
        icon: Icons.bolt_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: 'AI 호출 (30일)',
        icon: Icons.bolt_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.callCount == null) {
          return const MetricCard.placeholder(
            title: 'AI 호출 (30일)',
            icon: Icons.bolt_rounded,
            placeholderMessage: 'ai_usage_logs 적재 대기',
          );
        }
        return MetricCard(
          title: 'AI 호출 (30일)',
          icon: Icons.bolt_rounded,
          value: _formatNumber(m.callCount!),
          unit: '회',
        );
      },
    );
  }

  Widget _promptCompletionCard(AsyncValue<AiTokenMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '입력/출력 토큰',
        icon: Icons.swap_vert_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '입력/출력 토큰',
        icon: Icons.swap_vert_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null ||
            (m.promptTokens == null && m.completionTokens == null)) {
          return const MetricCard.placeholder(
            title: '입력/출력 토큰',
            icon: Icons.swap_vert_rounded,
            placeholderMessage: 'ai_usage_logs 적재 대기',
          );
        }
        final p = m.promptTokens ?? 0;
        final c = m.completionTokens ?? 0;
        return MetricCard(
          title: '입력/출력 토큰',
          icon: Icons.swap_vert_rounded,
          value: '${_formatNumber(p)} / ${_formatNumber(c)}',
          subtitle: '입력 / 출력',
        );
      },
    );
  }

  Widget _costCard(AsyncValue<AiTokenMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '예상 비용 (30일)',
        icon: Icons.attach_money_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '예상 비용 (30일)',
        icon: Icons.attach_money_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.estimatedCost == null) {
          return const MetricCard.placeholder(
            title: '예상 비용 (30일)',
            icon: Icons.attach_money_rounded,
            placeholderMessage: 'cost 필드 적재 대기',
          );
        }
        return MetricCard(
          title: '예상 비용 (30일)',
          icon: Icons.attach_money_rounded,
          value: '\$${m.estimatedCost!.toStringAsFixed(2)}',
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
