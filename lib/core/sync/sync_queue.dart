// 이슈 #704 Phase 1 — 오프라인 작업 큐.
//
// 오프라인 상태에서 발생한 쓰기 작업(create/update/delete)을 Hive 큐에 보관.
// 온라인 복귀 시 Repository 레이어가 pending()을 읽어 서버에 재시도.
//
// Hive box 'sync_queue' 는 main.dart에서 이미 열려 있음 (Box<Map>).
//
// 큐 op 모델:
// - id: 큐 항목 고유 ID (uuid)
// - entity: 'swatch' | 'project' | 'pattern' | 'counter' 등
// - docId: 대상 도큐먼트 ID
// - op: 'create' | 'update' | 'delete'
// - data: 페이로드 (Map<String, dynamic>)
// - createdAt: 큐에 넣은 시각
// - retries: 재시도 횟수 (Phase 2에서 사용)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../constants/subscription_constants.dart';

/// 큐에 적재된 단일 동기화 작업.
class SyncOp {
  final String id;
  final String entity;
  final String docId;
  final String op;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retries;

  const SyncOp({
    required this.id,
    required this.entity,
    required this.docId,
    required this.op,
    required this.data,
    required this.createdAt,
    this.retries = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity': entity,
        'docId': docId,
        'op': op,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retries': retries,
      };

  static SyncOp fromMap(Map map) {
    return SyncOp(
      id: map['id'] as String,
      entity: map['entity'] as String,
      docId: map['docId'] as String,
      op: map['op'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? const {}),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      retries: (map['retries'] as num?)?.toInt() ?? 0,
    );
  }

  SyncOp copyWith({int? retries}) => SyncOp(
        id: id,
        entity: entity,
        docId: docId,
        op: op,
        data: data,
        createdAt: createdAt,
        retries: retries ?? this.retries,
      );
}

/// 오프라인 동기화 큐.
/// Hive 'sync_queue' box 위에 얇은 래퍼.
/// box가 열리지 않은 환경(웹 등)에서는 in-memory fallback.
class SyncQueue {
  Box<Map>? _box;
  final List<SyncOp> _memQueue = [];
  final StreamController<int> _sizeController =
      StreamController<int>.broadcast();

  /// 큐 크기 변화 스트림 (UI 배지 업데이트용).
  Stream<int> get sizeStream => _sizeController.stream;

  Box<Map>? _resolveBox() {
    if (_box != null) return _box;
    if (Hive.isBoxOpen(SubscriptionConstants.boxSyncQueue)) {
      _box = Hive.box<Map>(SubscriptionConstants.boxSyncQueue);
      return _box;
    }
    return null;
  }

  /// 작업을 큐에 추가.
  Future<void> enqueue(SyncOp op) async {
    final box = _resolveBox();
    if (box != null) {
      await box.put(op.id, op.toMap());
    } else {
      _memQueue.add(op);
    }
    _emitSize();
  }

  /// 대기 중인 모든 작업을 반환 (createdAt 오름차순).
  Future<List<SyncOp>> pending() async {
    final box = _resolveBox();
    final List<SyncOp> list;
    if (box != null) {
      list = box.values
          .whereType<Map>()
          .map((m) => SyncOp.fromMap(m))
          .toList(growable: false);
    } else {
      list = List<SyncOp>.from(_memQueue);
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 처리 완료된 작업 제거.
  Future<void> markDone(String opId) async {
    final box = _resolveBox();
    if (box != null) {
      await box.delete(opId);
    } else {
      _memQueue.removeWhere((o) => o.id == opId);
    }
    _emitSize();
  }

  /// 재시도 카운트 증가 (Phase 2에서 사용).
  Future<void> bumpRetry(String opId) async {
    final box = _resolveBox();
    if (box != null) {
      final raw = box.get(opId);
      if (raw == null) return;
      final op = SyncOp.fromMap(raw).copyWith(retries: 0);
      final next = op.copyWith(retries: op.retries + 1);
      await box.put(opId, next.toMap());
    } else {
      final idx = _memQueue.indexWhere((o) => o.id == opId);
      if (idx == -1) return;
      _memQueue[idx] = _memQueue[idx].copyWith(retries: _memQueue[idx].retries + 1);
    }
  }

  /// 큐 크기.
  Future<int> size() async {
    final box = _resolveBox();
    if (box != null) return box.length;
    return _memQueue.length;
  }

  /// 동기 크기 (배지 표시용 — 박스가 열려 있을 때만 정확).
  int sizeSync() {
    final box = _resolveBox();
    if (box != null) return box.length;
    return _memQueue.length;
  }

  /// 큐 전체 비우기 (테스트용).
  Future<void> clear() async {
    final box = _resolveBox();
    if (box != null) {
      await box.clear();
    } else {
      _memQueue.clear();
    }
    _emitSize();
  }

  void _emitSize() {
    if (_sizeController.isClosed) return;
    _sizeController.add(sizeSync());
  }

  Future<void> dispose() async {
    await _sizeController.close();
  }
}

/// 글로벌 SyncQueue 인스턴스.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final q = SyncQueue();
  ref.onDispose(() {
    // ignore: discarded_futures
    q.dispose();
  });
  return q;
});

/// 큐 크기 스트림 Provider (UI 배지용).
final syncQueueSizeProvider = StreamProvider<int>((ref) async* {
  final q = ref.watch(syncQueueProvider);
  yield q.sizeSync();
  yield* q.sizeStream;
});
