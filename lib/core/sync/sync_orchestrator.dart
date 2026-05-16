// 이슈 #704 Phase 2 — 동기화 라이프사이클 오케스트레이터 (dispatcher 구현).
//
// 앱 시작 / 포그라운드 복귀 / 백그라운드 진입 시점에 호출되는 진입점.
// SyncQueue 에 쌓인 SyncOp 들을 entity 별 Repository 의 pushFromSync 로 위임.
// 충돌 발견 시 ConflictResolver / ConflictInbox 와 연동.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// #704 Phase 2.5 — pushFromSync 구현 완료 → ConflictInbox / Repository 연동 활성화.
import '../../features/pattern/data/pattern_session_repository.dart';
import '../../features/sync/presentation/conflict_inbox_screen.dart'
    show ConflictItem, conflictInboxProvider;
import '../../providers/swatch_provider.dart';
import 'network_status.dart';
import 'sync_queue.dart';

/// 앱 라이프사이클 훅에서 호출되는 동기화 진입점.
///
/// 의존성:
/// - NetworkStatusService — 온라인 여부 판단
/// - SyncQueue — 대기 중 op 조회·완료 마킹
/// - Ref — repository / conflictInbox provider 접근
class SyncOrchestrator {
  final NetworkStatusService _network;
  final SyncQueue _queue;
  final Ref _ref;

  /// syncAll() 동시 호출 방지 (라이프사이클 훅이 중복 트리거되어도 1회만 실행).
  bool _running = false;

  SyncOrchestrator(this._network, this._queue, this._ref);

  /// 앱 시작 또는 포그라운드 복귀 시 호출.
  ///
  /// 흐름:
  /// 1. 네트워크 확인 → offline 이면 즉시 return
  /// 2. SyncQueue.pending() 가져옴
  /// 3. 각 op 를 _applyOp 로 dispatch
  /// 4. 성공 시 markDone, 실패 시 다음 사이클 재시도 (bumpRetry)
  Future<void> syncAll() async {
    if (_running) {
      debugPrint('[SyncOrchestrator] syncAll already running, skip');
      return;
    }
    _running = true;
    try {
      // 네트워크 unknown 은 낙관적으로 online 으로 간주.
      if (_network.isOffline) {
        debugPrint('[SyncOrchestrator] offline, skip sync');
        return;
      }
      final pending = await _queue.pending();
      if (pending.isEmpty) return;
      debugPrint('[SyncOrchestrator] syncing ${pending.length} ops');
      for (final op in pending) {
        try {
          await _applyOp(op);
          await _queue.markDone(op.id);
        } catch (e) {
          debugPrint('[SyncOrchestrator] op ${op.id} (${op.entity}/${op.op}) failed: $e');
          await _queue.bumpRetry(op.id);
        }
      }
    } finally {
      _running = false;
    }
  }

  /// 백그라운드 진입 시 호출. pending op flush 시도.
  Future<void> flushPending() async {
    await syncAll();
  }

  /// entity 별 dispatcher.
  Future<void> _applyOp(SyncOp op) async {
    switch (op.entity) {
      case 'swatch':
        await _swatchDispatcher(op);
        break;
      case 'pattern_session':
        await _patternSessionDispatcher(op);
        break;
      default:
        debugPrint('[SyncOrchestrator] unknown entity: ${op.entity}');
    }
  }

  Future<void> _swatchDispatcher(SyncOp op) async {
    // #704 Phase 2.5 — SwatchRepository.pushFromSync 위임. 충돌 시 인박스에 적재.
    final repo = _ref.read(swatchRepositoryProvider);
    await repo.pushFromSync(op, onConflict: _enqueueConflict);
  }

  Future<void> _patternSessionDispatcher(SyncOp op) async {
    // #704 Phase 2.5 — PatternSessionRepository.pushFromSync 위임.
    // totalSeconds 충돌은 sum 정책으로 자동 합산 (콜백 불필요).
    final repo = _ref.read(patternSessionRepositoryProvider);
    await repo.pushFromSync(op);
  }

  /// 충돌 발견 시 ConflictInbox 에 적재.
  /// 사용자는 동기화 화면 → 충돌 인박스에서 수동 해결.
  void _enqueueConflict(ConflictItem item) {
    try {
      _ref.read(conflictInboxProvider.notifier).add(item);
      debugPrint('[SyncOrchestrator] conflict enqueued: ${item.entity}/${item.docId}');
    } catch (e) {
      debugPrint('[SyncOrchestrator] inbox add failed: $e');
    }
  }
}

/// `SyncOrchestrator` 의 Riverpod provider.
final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final network = ref.watch(networkStatusServiceProvider);
  final queue = ref.watch(syncQueueProvider);
  return SyncOrchestrator(network, queue, ref);
});
