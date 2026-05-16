// lib/features/pattern/data/pattern_session_repository.dart
//
// 도안 뷰어 세션 Firestore 동기화 Repository.
// 경로: users/{uid}/pattern_sessions/{sessionId}
// 세션은 patternChartId 당 1개만 존재 (patternChartId == sessionId 로 사용).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/network_errors.dart';
import '../domain/pattern_session.dart';

class PatternSessionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _sessionsRef =>
      _db.collection('users').doc(_uid).collection('pattern_sessions');

  // ── GET OR CREATE ──────────────────────────────────────────
  /// patternChartId를 문서 ID로 사용해 1:1 매핑 보장.
  Future<PatternSession> getOrCreate(String patternChartId) async {
    if (_uid.isEmpty) {
      return PatternSession.empty(uid: '', patternChartId: patternChartId);
    }
    final docRef = _sessionsRef.doc(patternChartId);
    final snap = await docRef.get();
    if (snap.exists) {
      return PatternSession.fromFirestore(snap);
    }
    final initial = PatternSession.empty(
      uid: _uid,
      patternChartId: patternChartId,
    ).copyWith(id: patternChartId);
    await docRef.set({
      ...initial.toJson(),
      'id': patternChartId,
      'uid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return initial;
  }

  // ── WATCH ──────────────────────────────────────────────────
  Stream<PatternSession?> watch(String patternChartId) {
    if (_uid.isEmpty) return Stream.value(null);
    return _sessionsRef.doc(patternChartId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PatternSession.fromFirestore(doc);
    });
  }

  // ── UPDATE: RULER ──────────────────────────────────────────
  Future<void> updateRuler(String sessionId, double y) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'rulerY': y,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── UPDATE: HAIRLINE ───────────────────────────────────────
  Future<void> updateHairline(String sessionId, double x) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'hairlineX': x,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── UPDATE: STROKES ────────────────────────────────────────
  Future<void> updateStrokes(String sessionId, List<StrokeData> strokes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'strokes': strokes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 이슈 #663-A — 스티키 노트 다중 지원: List 통째로 덮어쓰기 (추가/이동/삭제 한꺼번에).
  Future<void> setStickyNotes(String sessionId, List<StickyNote> notes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'stickyNotes': notes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── UPDATE: STICKY NOTE (upsert by id) ─────────────────────
  Future<void> updateStickyNote(String sessionId, StickyNote note) async {
    if (_uid.isEmpty) return;
    final docRef = _sessionsRef.doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      List<StickyNote> notes = const [];
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        notes = (data['stickyNotes'] as List?)
                ?.map((e) =>
                    StickyNote.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [];
      }
      final idx = notes.indexWhere((n) => n.id == note.id);
      final updated = List<StickyNote>.from(notes);
      if (idx >= 0) {
        updated[idx] = note;
      } else {
        updated.add(note);
      }
      tx.set(
          docRef,
          {
            'stickyNotes': updated.map((e) => e.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> replaceStickyNotes(
      String sessionId, List<StickyNote> notes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'stickyNotes': notes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── UPDATE: TIMER NAME (이슈 #649 Phase 1) ─────────────────────
  Future<void> updateTimerName(String sessionId, String name) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'timerName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── UPDATE: TOTAL SECONDS (타이머 누적시간) ─────────────────────
  Future<void> updateTotalSeconds(String sessionId, int seconds) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'totalSeconds': seconds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 이슈 #630 — 특정 프로젝트에 연결된 도안 세션의 누적시간 합계.
  Future<int> totalSecondsForProject(String projectId) async {
    if (_uid.isEmpty || projectId.isEmpty) return 0;
    final snap = await _sessionsRef.where('projectId', isEqualTo: projectId).get();
    int sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      sum += (data['totalSeconds'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  /// 이슈 #630 (B-6) — 모든 도안 세션의 누적시간 합계 (통합 대시보드용).
  Future<int> totalSecondsAll() async {
    if (_uid.isEmpty) return 0;
    final snap = await _sessionsRef.get();
    int sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      sum += (data['totalSeconds'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  /// 이슈 #649 Phase 2 — 모든 PatternSession을 projectId 기준으로 그룹화.
  /// 반환: projectId → ProjectTimeAggregate (총 시간, 마지막 작업일, 세션 개수)
  /// projectId가 비어있는 세션은 제외 (프로젝트 미연결 세션은 집계 대상 아님).
  /// 이슈 #721 — 5초 timeout. timeout/장애 시 ServerUnavailableException throw → 화면에서 "서버 연결에 장애가 있음" 표시.
  Future<Map<String, ProjectTimeAggregate>> aggregateByProject() async {
    if (_uid.isEmpty) return {};
    final QuerySnapshot snap;
    try {
      snap = await _sessionsRef.get().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw const ServerUnavailableException('aggregateByProject timeout');
    } on FirebaseException catch (e) {
      throw ServerUnavailableException('firestore: ${e.code}');
    }
    final result = <String, ProjectTimeAggregate>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final pid = (data['projectId'] as String?)?.trim();
      if (pid == null || pid.isEmpty) continue;
      final seconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      final updatedRaw = data['updatedAt'];
      DateTime? updatedAt;
      if (updatedRaw is Timestamp) {
        updatedAt = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        updatedAt = DateTime.tryParse(updatedRaw);
      }

      final existing = result[pid];
      if (existing == null) {
        result[pid] = ProjectTimeAggregate(
          projectId: pid,
          totalSeconds: seconds,
          lastWorkedAt: updatedAt,
          sessionCount: 1,
        );
      } else {
        result[pid] = ProjectTimeAggregate(
          projectId: pid,
          totalSeconds: existing.totalSeconds + seconds,
          lastWorkedAt: _laterOf(existing.lastWorkedAt, updatedAt),
          sessionCount: existing.sessionCount + 1,
        );
      }
    }
    return result;
  }

  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  // ── LINK PROJECT / SWATCH ──────────────────────────────────
  Future<void> linkProject(String sessionId, String projectId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'projectId': projectId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlinkProject(String sessionId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'projectId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> linkSwatch(String sessionId, String swatchId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'swatchId': swatchId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlinkSwatch(String sessionId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'swatchId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// 이슈 #649 Phase 2 — 프로젝트별 작업 시간 집계 결과.
class ProjectTimeAggregate {
  final String projectId;
  final int totalSeconds;
  final DateTime? lastWorkedAt;
  final int sessionCount;

  const ProjectTimeAggregate({
    required this.projectId,
    required this.totalSeconds,
    this.lastWorkedAt,
    this.sessionCount = 0,
  });
}

// ── Riverpod Providers ───────────────────────────────────────
final patternSessionRepositoryProvider =
    Provider<PatternSessionRepository>((ref) => PatternSessionRepository());

/// 이슈 #649 Phase 2 — 프로젝트별 작업 시간 집계 Provider.
final patternTimeByProjectProvider =
    FutureProvider.autoDispose<Map<String, ProjectTimeAggregate>>((ref) async {
  final repo = ref.watch(patternSessionRepositoryProvider);
  return repo.aggregateByProject();
});

/// 특정 도안(chartId)의 세션을 스트림으로 구독.
final patternSessionProvider =
    StreamProvider.family<PatternSession?, String>((ref, chartId) {
  final repo = ref.watch(patternSessionRepositoryProvider);
  return repo.watch(chartId);
});
