// 이슈 #814 — Hosting / Storage / Firestore 사용량 그룹.
//
// Cloud Functions 집계 문서가 적재되기 전까지는 플레이스홀더 카드 표시.
// 데이터가 들어오면 자동으로 값 카드로 전환.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../data/dashboard_metrics_provider.dart';
import 'metric_card.dart';

class UsageMetricsSection extends ConsumerWidget {
  const UsageMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosting = ref.watch(hostingTrafficProvider);
    final storage = ref.watch(storageUsageProvider);
    final firestore = ref.watch(firestoreUsageProvider);

    return MoriBlockShell(
      label: '인프라 사용량',
      icon: Icons.cloud_rounded,
      accent: C.lv,
      child: MetricGrid(
        children: [
          _hostingVisitsCard(hosting),
          _hostingBandwidthCard(hosting),
          _storageBytesCard(storage),
          _firestoreReadsCard(firestore),
        ],
      ),
    );
  }

  Widget _hostingVisitsCard(AsyncValue<HostingTrafficMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: 'Hosting 일일 방문',
        icon: Icons.public_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: 'Hosting 일일 방문',
        icon: Icons.public_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.dailyVisits == null) {
          return const MetricCard.placeholder(
            title: 'Hosting 일일 방문',
            icon: Icons.public_rounded,
            placeholderMessage: 'Cloud Function 연동 예정',
          );
        }
        return MetricCard(
          title: 'Hosting 일일 방문',
          icon: Icons.public_rounded,
          value: _formatNumber(m.dailyVisits!),
          unit: '회',
          subtitle: m.monthlyVisits != null
              ? '월간 ${_formatNumber(m.monthlyVisits!)}회'
              : null,
        );
      },
    );
  }

  Widget _hostingBandwidthCard(AsyncValue<HostingTrafficMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: 'Hosting 대역폭',
        icon: Icons.speed_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: 'Hosting 대역폭',
        icon: Icons.speed_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        final daily = m?.dailyBandwidthMb;
        if (m == null || daily == null) {
          return const MetricCard.placeholder(
            title: 'Hosting 대역폭',
            icon: Icons.speed_rounded,
            placeholderMessage: 'Cloud Function 연동 예정',
          );
        }
        return MetricCard(
          title: 'Hosting 대역폭 (일)',
          icon: Icons.speed_rounded,
          value: daily.toStringAsFixed(1),
          unit: 'MB',
          subtitle: m.monthlyBandwidthMb != null
              ? '월간 ${m.monthlyBandwidthMb!.toStringAsFixed(1)} MB'
              : null,
        );
      },
    );
  }

  Widget _storageBytesCard(AsyncValue<StorageUsageMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: 'Storage 사용량',
        icon: Icons.storage_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: 'Storage 사용량',
        icon: Icons.storage_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.totalBytes == null) {
          return const MetricCard.placeholder(
            title: 'Storage 사용량',
            icon: Icons.storage_rounded,
            placeholderMessage: 'Cloud Function 연동 예정',
          );
        }
        return MetricCard(
          title: 'Storage 사용량',
          icon: Icons.storage_rounded,
          value: _formatBytes(m.totalBytes!),
          subtitle: m.objectCount != null
              ? '${_formatNumber(m.objectCount!)} 파일'
              : null,
        );
      },
    );
  }

  Widget _firestoreReadsCard(AsyncValue<FirestoreUsageMetric?> async) {
    return async.when(
      loading: () => const MetricCard.placeholder(
        title: 'Firestore 일일 R/W',
        icon: Icons.dataset_rounded,
        placeholderMessage: '불러오는 중...',
      ),
      error: (_, _) => MetricCard.placeholder(
        title: 'Firestore 일일 R/W',
        icon: Icons.dataset_rounded,
        color: C.og,
        placeholderMessage: '조회 실패',
      ),
      data: (m) {
        if (m == null || m.dailyReads == null) {
          return const MetricCard.placeholder(
            title: 'Firestore 일일 R/W',
            icon: Icons.dataset_rounded,
            placeholderMessage: 'Cloud Function 연동 예정',
          );
        }
        return MetricCard(
          title: 'Firestore 일일 R/W',
          icon: Icons.dataset_rounded,
          value: _formatNumber(m.dailyReads!),
          unit: 'reads',
          subtitle: m.dailyWrites != null
              ? '쓰기 ${_formatNumber(m.dailyWrites!)}'
              : null,
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

String _formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
