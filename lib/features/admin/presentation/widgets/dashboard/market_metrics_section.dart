// 이슈 #814 — 마켓 거래량 + 금액 + 환불.
//
// 환불은 별도 컬렉션이 없어 현재는 플레이스홀더 카드로만 노출.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../data/dashboard_metrics_provider.dart';
import 'metric_card.dart';

class MarketMetricsSection extends ConsumerWidget {
  const MarketMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(marketTransactionsProvider);

    return MoriBlockShell(
      label: '마켓 거래',
      icon: Icons.shopping_bag_rounded,
      accent: C.lm,
      child: MetricGrid(
        children: [
          _dailyCountCard(tx),
          _weeklyCountCard(tx),
          _monthlyAmountCard(tx),
          _refundCard(),
        ],
      ),
    );
  }

  Widget _dailyCountCard(AsyncValue<MarketTxMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '오늘 거래',
        icon: Icons.receipt_long_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '오늘 거래',
        icon: Icons.receipt_long_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '오늘 거래',
            icon: Icons.receipt_long_rounded,
            placeholderMessage: 'collectionGroup 인덱스 필요',
          );
        }
        return MetricCard(
          title: '오늘 거래',
          icon: Icons.receipt_long_rounded,
          value: _formatNumber(m.daily),
          unit: '건',
          subtitle: '${_formatKRW(m.dailyAmount)}원',
        );
      },
    );
  }

  Widget _weeklyCountCard(AsyncValue<MarketTxMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '주간 거래',
        icon: Icons.event_available_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '주간 거래',
        icon: Icons.event_available_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '주간 거래',
            icon: Icons.event_available_rounded,
            placeholderMessage: 'collectionGroup 인덱스 필요',
          );
        }
        return MetricCard(
          title: '주간 거래',
          icon: Icons.event_available_rounded,
          value: _formatNumber(m.weekly),
          unit: '건',
          subtitle: '${_formatKRW(m.weeklyAmount)}원',
          trend: m.weekly > 0 ? MetricTrend.up : MetricTrend.flat,
        );
      },
    );
  }

  Widget _monthlyAmountCard(AsyncValue<MarketTxMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: '월간 매출',
        icon: Icons.payments_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: '월간 매출',
        icon: Icons.payments_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null) {
          return const MetricCard.placeholder(
            title: '월간 매출',
            icon: Icons.payments_rounded,
            placeholderMessage: 'collectionGroup 인덱스 필요',
          );
        }
        return MetricCard(
          title: '월간 매출',
          icon: Icons.payments_rounded,
          value: _formatKRW(m.monthlyAmount),
          unit: '원',
          subtitle: '${_formatNumber(m.monthly)}건',
        );
      },
    );
  }

  Widget _refundCard() {
    // 환불 컬렉션 미구현 — 항상 플레이스홀더.
    return const MetricCard.placeholder(
      title: '환불',
      icon: Icons.undo_rounded,
      placeholderMessage: '환불 컬렉션 미구현',
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

String _formatKRW(num n) => _formatNumber(n);
