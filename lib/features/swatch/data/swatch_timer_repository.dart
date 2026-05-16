// lib/features/swatch/data/swatch_timer_repository.dart
//
// 스와치별 작업 시간 누적 저장소 — `users/{uid}/swatch_timers/{swatchId}`
// SwatchModel(freezed)을 건드리지 않고 별도 컬렉션으로 분리 — 기존 스와치 스키마 보존.
// 프로젝트 작업시간 집계 시 projectId 기준으로 swatches → swatch_timers 조회하여 합산.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/firestore_timeout_extension.dart';

class SwatchTimerState {
  final String swatchId;
  final int totalSeconds;
  final DateTime? currentSessionStart;
  final DateTime? lastUpdatedAt;

  const SwatchTimerState({
    required this.swatchId,
    this.totalSeconds = 0,
    this.currentSessionStart,
    this.lastUpdatedAt,
  });

  bool get isRunning => currentSessionStart != null;

  factory SwatchTimerState.empty(String swatchId) =>
      SwatchTimerState(swatchId: swatchId);

  factory SwatchTimerState.fromMap(String swatchId, Map<String, dynamic> data) {
    return SwatchTimerState(
      swatchId: swatchId,
      totalSeconds: (data['totalSeconds'] as num?)?.toInt() ?? 0,
      currentSessionStart: _parseDate(data['currentSessionStart']),
      lastUpdatedAt: _parseDate(data['lastUpdatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class SwatchTimerRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _docRef(String swatchId) {
    final uid = _uid;
    if (uid == null || swatchId.isEmpty) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('swatch_timers')
        .doc(swatchId);
  }

  Stream<SwatchTimerState> watch(String swatchId) {
    final ref = _docRef(swatchId);
    if (ref == null) return Stream.value(SwatchTimerState.empty(swatchId));
    return ref.snapshots().map((snap) {
      if (!snap.exists) return SwatchTimerState.empty(swatchId);
      return SwatchTimerState.fromMap(swatchId, snap.data() ?? {});
    });
  }

  Future<SwatchTimerState> load(String swatchId) async {
    final ref = _docRef(swatchId);
    if (ref == null) return SwatchTimerState.empty(swatchId);
    final snap = await ref.get().withServerTimeout(op: 'load_swatch_timer');
    if (!snap.exists) return SwatchTimerState.empty(swatchId);
    return SwatchTimerState.fromMap(swatchId, snap.data() ?? {});
  }

  /// 여러 스와치의 누적시간을 합산 (프로젝트 집계용)
  Future<int> totalForSwatchIds(List<String> swatchIds) async {
    if (swatchIds.isEmpty) return 0;
    int sum = 0;
    for (final id in swatchIds) {
      final state = await load(id);
      sum += state.totalSeconds;
    }
    return sum;
  }

  /// 이슈 #630 (B-6) — 모든 스와치 타이머 누적시간 합계 (통합 대시보드용).
  Future<int> totalSecondsAll() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('swatch_timers')
        .get()
        .withServerTimeout(op: 'swatch_timer_total_all');
    int sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      sum += (data['totalSeconds'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  /// 이슈 #649 Phase 3 — 모든 스와치 타이머를 swatchId → totalSeconds 맵으로 반환.
  /// 호출 측에서 swatches 컬렉션의 projectId 매핑과 결합해 프로젝트별로 집계.
  Future<Map<String, int>> loadAllSecondsBySwatchId() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('swatch_timers')
        .get()
        .withServerTimeout(op: 'swatch_timer_load_all');
    final result = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final seconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      if (seconds > 0) {
        result[doc.id] = seconds;
      }
    }
    return result;
  }

  Future<void> start(String swatchId) async {
    final ref = _docRef(swatchId);
    if (ref == null) return;
    await ref.set({
      'currentSessionStart': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'swatch_timer_start');
  }

  Future<void> pause(String swatchId, int elapsedSeconds) async {
    final ref = _docRef(swatchId);
    if (ref == null) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? SwatchTimerState.fromMap(swatchId, snap.data() ?? {})
          : SwatchTimerState.empty(swatchId);
      tx.set(
        ref,
        {
          'totalSeconds': current.totalSeconds + elapsedSeconds,
          'currentSessionStart': null,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }).withServerTimeout(op: 'swatch_timer_pause_tx');
  }

  Future<void> reset(String swatchId) async {
    final ref = _docRef(swatchId);
    if (ref == null) return;
    await ref.set({
      'totalSeconds': 0,
      'currentSessionStart': null,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'swatch_timer_reset');
  }
}

final swatchTimerRepositoryProvider = Provider<SwatchTimerRepository>((ref) {
  return SwatchTimerRepository();
});

final swatchTimerStreamProvider =
    StreamProvider.family<SwatchTimerState, String>((ref, swatchId) {
  return ref.watch(swatchTimerRepositoryProvider).watch(swatchId);
});
