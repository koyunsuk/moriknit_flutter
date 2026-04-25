// lib/features/tools/data/free_timer_repository.dart
//
// 도구함 독립 뜨개 타이머 저장소 — `users/{uid}/free_timer/doc` 단일 문서에
// 누적 시간과 현재 실행 세션 시작 시각을 저장합니다.
//
// Facade 목적: 도안/프로젝트/스와치 통합 누적시간 대시보드 완성 전에
// 독립적으로 작동하는 타이머를 먼저 제공.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FreeTimerState {
  final int totalSeconds;
  final DateTime? currentSessionStart;
  final DateTime? lastUpdatedAt;
  // 이슈 #649 Phase 1 — 타이머 자동 이름 (자유 타이머 yyyy-MM-dd HH:mm). 사용자 편집 가능.
  final String? timerName;

  const FreeTimerState({
    this.totalSeconds = 0,
    this.currentSessionStart,
    this.lastUpdatedAt,
    this.timerName,
  });

  bool get isRunning => currentSessionStart != null;

  FreeTimerState copyWith({
    int? totalSeconds,
    DateTime? currentSessionStart,
    bool clearCurrentSessionStart = false,
    DateTime? lastUpdatedAt,
    String? timerName,
    bool clearTimerName = false,
  }) {
    return FreeTimerState(
      totalSeconds: totalSeconds ?? this.totalSeconds,
      currentSessionStart: clearCurrentSessionStart
          ? null
          : (currentSessionStart ?? this.currentSessionStart),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      timerName: clearTimerName ? null : (timerName ?? this.timerName),
    );
  }

  factory FreeTimerState.fromMap(Map<String, dynamic> data) {
    return FreeTimerState(
      totalSeconds: (data['totalSeconds'] as num?)?.toInt() ?? 0,
      currentSessionStart: _parseDate(data['currentSessionStart']),
      lastUpdatedAt: _parseDate(data['lastUpdatedAt']),
      timerName: data['timerName'] as String?,
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

class FreeTimerRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('free_timer').doc('doc');
  }

  Stream<FreeTimerState> watch() {
    final ref = _docRef;
    if (ref == null) {
      return Stream.value(const FreeTimerState());
    }
    return ref.snapshots().map((snap) {
      if (!snap.exists) return const FreeTimerState();
      return FreeTimerState.fromMap(snap.data() ?? {});
    });
  }

  Future<FreeTimerState> load() async {
    final ref = _docRef;
    if (ref == null) return const FreeTimerState();
    final snap = await ref.get();
    if (!snap.exists) return const FreeTimerState();
    return FreeTimerState.fromMap(snap.data() ?? {});
  }

  /// 타이머 시작 — currentSessionStart 기록
  /// 이슈 #649 Phase 1 — timerName이 비어 있으면 "자유 타이머 yyyy-MM-dd HH:mm" 자동 부여.
  Future<void> start() async {
    final ref = _docRef;
    if (ref == null) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? FreeTimerState.fromMap(snap.data() ?? {})
          : const FreeTimerState();
      final data = <String, dynamic>{
        'currentSessionStart': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (current.timerName == null || current.timerName!.trim().isEmpty) {
        data['timerName'] = _autoFreeTimerName(DateTime.now());
      }
      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  /// 타이머 이름 수동 변경
  Future<void> updateTimerName(String name) async {
    final ref = _docRef;
    if (ref == null) return;
    await ref.set({
      'timerName': name,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _autoFreeTimerName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
    return '자유 타이머 $stamp';
  }

  /// 타이머 정지 — 경과 세션을 totalSeconds에 더하고 currentSessionStart 삭제
  Future<void> pause(int elapsedSeconds) async {
    final ref = _docRef;
    if (ref == null) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? FreeTimerState.fromMap(snap.data() ?? {})
          : const FreeTimerState();
      final next = current.totalSeconds + elapsedSeconds;
      tx.set(
        ref,
        {
          'totalSeconds': next,
          'currentSessionStart': null,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 누적 시간 리셋 — 다음 시작 시 새 자동 이름이 부여되도록 timerName도 비움
  Future<void> reset() async {
    final ref = _docRef;
    if (ref == null) return;
    await ref.set({
      'totalSeconds': 0,
      'currentSessionStart': null,
      'timerName': null,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final freeTimerRepositoryProvider = Provider<FreeTimerRepository>((ref) {
  return FreeTimerRepository();
});

final freeTimerStreamProvider = StreamProvider<FreeTimerState>((ref) {
  return ref.watch(freeTimerRepositoryProvider).watch();
});
