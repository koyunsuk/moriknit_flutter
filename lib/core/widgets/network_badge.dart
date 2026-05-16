// 이슈 #704 Phase 5 — 오프라인/동기화 상태 표시 배지.
//
// AppShellScaffold 헤더 trailing 앞에 자동 prepend되어 표시.
//
// 표시 규칙:
// - offline                    → "오프라인 [N]" (주황 칩)
// - online + pending > 0       → "동기화 중 N개" (라벤더 칩, 진행 인디케이터)
// - online + pending == 0      → SizedBox.shrink() (공간 차지 X)
// - unknown                    → SizedBox.shrink() (낙관적)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/network_status.dart';
import '../sync/sync_queue.dart';
import '../theme/app_colors.dart';

/// 오프라인/동기화 상태 배지.
/// AppShellScaffold가 자동으로 trailing 앞에 prepend.
/// 화면 코드에서 직접 사용할 일은 없음.
class NetworkBadge extends ConsumerWidget {
  const NetworkBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(networkStatusProvider);
    final status = statusAsync.asData?.value ?? NetworkStatus.unknown;
    final queueSize = ref.watch(syncQueueSizeProvider).asData?.value ?? 0;

    // offline: 항상 표시 (대기 카운트 포함)
    if (status == NetworkStatus.offline) {
      return _OfflineChip(queueSize: queueSize);
    }

    // online + pending > 0: 동기화 중 표시
    if (status == NetworkStatus.online && queueSize > 0) {
      return _SyncingChip(queueSize: queueSize);
    }

    // online + 0 또는 unknown: 표시 X
    return const SizedBox.shrink();
  }
}

class _OfflineChip extends StatelessWidget {
  const _OfflineChip({required this.queueSize});
  final int queueSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.og.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.og.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 14, color: C.og),
            const SizedBox(width: 4),
            Text(
              '오프라인',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.og,
              ),
            ),
            if (queueSize > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: C.og,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$queueSize',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncingChip extends StatelessWidget {
  const _SyncingChip({required this.queueSize});
  final int queueSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.lv.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.lv.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(C.lv),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '동기화 중 $queueSize개',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.lv,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
