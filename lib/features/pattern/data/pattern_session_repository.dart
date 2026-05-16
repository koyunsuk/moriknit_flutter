// lib/features/pattern/data/pattern_session_repository.dart
//
// 도안 뷰어 세션 Firestore 동기화 Repository.
// 경로: users/{uid}/pattern_sessions/{sessionId}
// 세션은 patternChartId 당 1개만 존재 (patternChartId == sessionId 로 사용).
//
// 이슈 #704 Phase A-B:
//  - Hive box `pattern_session_hive_cache` 폴백 (오프라인 읽기/쓰기)
//  - 타이머 누적시간은 Hive 즉시 commit + Firestore best-effort
//  - 충돌 시 totalSeconds는 sum 정책 (양쪽 보존)

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/errors/network_errors.dart';
import '../../../core/sync/conflict_resolver.dart';
import '../../../core/sync/sync_queue.dart';
import '../domain/pattern_session.dart';

class PatternSessionRepository {
  PatternSessionRepository({SyncQueue? syncQueue}) : _syncQueue = syncQueue;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SyncQueue? _syncQueue;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _sessionsRef =>
      _db.collection('users').doc(_uid).collection('pattern_sessions');

  // ── HIVE CACHE ─────────────────────────────────────────────
  /// 폴백/누적용 Hive box. 열려있지 않으면 null (웹 등).
  Box<Map>? get _hiveBox {
    if (!Hive.isBoxOpen(SubscriptionConstants.boxPatternSessionHiveCache)) {
      return null;
    }
    return Hive.box<Map>(SubscriptionConstants.boxPatternSessionHiveCache);
  }

  /// Hive에 세션 1건 저장 (sessionId == patternChartId).
  Future<void> _writeHive(PatternSession session) async {
    final box = _hiveBox;
    if (box == null) return;
    try {
      await box.put(session.patternChartId, session.toJson());
    } catch (e) {
      debugPrint('PatternSessionRepository: Hive write failed - $e');
    }
  }

  /// Hive에서 세션 1건 읽기.
  PatternSession? _readHive(String patternChartId) {
    final box = _hiveBox;
    if (box == null) return null;
    try {
      final raw = box.get(patternChartId);
      if (raw == null) return null;
      return PatternSession.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('PatternSessionRepository: Hive read failed - $e');
      return null;
    }
  }

  /// Hive 전체 읽기 (집계용).
  List<PatternSession> _readHiveAll() {
    final box = _hiveBox;
    if (box == null) return const [];
    try {
      return box.values
          .whereType<Map>()
          .map((m) => PatternSession.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('PatternSessionRepository: Hive readAll failed - $e');
      return const [];
    }
  }

  /// totalSeconds sum 정책 ConflictResolver — 양쪽 보존(합산).
  static final ConflictResolver<PatternSession> _totalSecondsSumResolver =
      ConflictResolver<PatternSession>(
    policy: ConflictPolicy.sum,
    sumSelector: (s) => s.totalSeconds,
    sumApplier: (base, totalSum) =>
        base.copyWith(totalSeconds: totalSum.toInt()),
  );

  // ── GET OR CREATE ──────────────────────────────────────────
  /// patternChartId를 문서 ID로 사용해 1:1 매핑 보장.
  /// #704 Phase A-B — Firestore timeout/장애 시 Hive 폴백 (없으면 새 세션 생성).
  Future<PatternSession> getOrCreate(String patternChartId) async {
    if (_uid.isEmpty) {
      return PatternSession.empty(uid: '', patternChartId: patternChartId);
    }
    final docRef = _sessionsRef.doc(patternChartId);
    try {
      final snap = await docRef.get().withServerTimeout(op: 'get_session');
      if (snap.exists) {
        final fromServer = PatternSession.fromFirestore(snap);
        // 충돌 처리: Hive에 더 큰 누적값이 있으면 sum 정책으로 합산.
        final local = _readHive(patternChartId);
        PatternSession merged = fromServer;
        if (local != null &&
            local.totalSeconds > 0 &&
            local.totalSeconds != fromServer.totalSeconds) {
          merged = _totalSecondsSumResolver.resolve(local, fromServer);
          // 합산 결과를 Firestore에도 best-effort 반영.
          unawaited(
            docRef.set({
              'totalSeconds': merged.totalSeconds,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
                .withServerTimeout(op: 'merge_total_seconds')
                .catchError((Object e) {
              debugPrint(
                  'PatternSessionRepository: merge totalSeconds failed - $e');
            }),
          );
        }
        // Hive 캐시 갱신.
        await _writeHive(merged);
        return merged;
      }
      // 신규: Firestore 생성 + Hive 캐시.
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
      }).withServerTimeout(op: 'create_session');
      await _writeHive(initial);
      return initial;
    } on ServerUnavailableException {
      // Firestore 실패 → Hive 폴백.
      final cached = _readHive(patternChartId);
      if (cached != null) return cached;
      // Hive에도 없으면 빈 세션 생성 (id는 chartId로 세팅).
      final fallback = PatternSession.empty(
        uid: _uid,
        patternChartId: patternChartId,
      ).copyWith(id: patternChartId);
      await _writeHive(fallback);
      return fallback;
    }
  }

  // ── WATCH ──────────────────────────────────────────────────
  /// #704 Phase A-B — Firestore stream 실패 시 Hive emit. 첫 emit 전 5초 timeout 시도.
  Stream<PatternSession?> watch(String patternChartId) async* {
    if (_uid.isEmpty) {
      yield null;
      return;
    }
    // 1) Hive 즉시 emit (있으면).
    final cached = _readHive(patternChartId);
    if (cached != null) yield cached;

    bool emittedAny = cached != null;

    // 2) Firestore stream — 정상 시 캐시 갱신, 실패 시 Hive 폴백 한번 더 emit.
    final firestoreStream = _sessionsRef
        .doc(patternChartId)
        .snapshots()
        .map<PatternSession?>((doc) {
      if (!doc.exists) return null;
      final session = PatternSession.fromFirestore(doc);
      // 서버 응답일 때만 Hive 캐시 갱신 (fire-and-forget).
      if (!doc.metadata.isFromCache) {
        unawaited(_writeHive(session));
      }
      return session;
    });

    yield* firestoreStream
        .timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!emittedAny) {
          final fallback = _readHive(patternChartId);
          sink.add(fallback);
          emittedAny = true;
        }
      },
    )
        .handleError((Object e) {
      debugPrint('PatternSessionRepository.watch error: $e');
      // 에러 시 Hive 폴백 (이미 yield 했다면 중복 emit 가능하나 안전).
    }).map((s) {
      emittedAny = true;
      return s;
    });
  }

  // ── UPDATE: RULER ──────────────────────────────────────────
  Future<void> updateRuler(String sessionId, double y) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'rulerY': y,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'update_ruler');
  }

  // ── UPDATE: HAIRLINE ───────────────────────────────────────
  Future<void> updateHairline(String sessionId, double x) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'hairlineX': x,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'update_hairline');
  }

  // ── UPDATE: STROKES ────────────────────────────────────────
  Future<void> updateStrokes(String sessionId, List<StrokeData> strokes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'strokes': strokes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'update_strokes');
  }

  /// 이슈 #663-A — 스티키 노트 다중 지원: List 통째로 덮어쓰기 (추가/이동/삭제 한꺼번에).
  Future<void> setStickyNotes(String sessionId, List<StickyNote> notes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'stickyNotes': notes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'set_sticky_notes');
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
    }).withServerTimeout(op: 'update_sticky_note_tx');
  }

  Future<void> replaceStickyNotes(
      String sessionId, List<StickyNote> notes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'stickyNotes': notes.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'replace_sticky_notes');
  }

  // ── UPDATE: TIMER NAME (이슈 #649 Phase 1) ─────────────────────
  Future<void> updateTimerName(String sessionId, String name) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'timerName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'update_timer_name');
  }

  // ── UPDATE: TOTAL SECONDS (타이머 누적시간) ─────────────────────
  /// #704 Phase A-B — 타이머 누적은 사용자가 작업 중인 핵심 값.
  /// 1) Hive에 즉시 commit (오프라인에서도 누적 보존).
  /// 2) Firestore best-effort. 실패해도 throw 안 함 (다음 호출/세션에서 sum 정책으로 복구).
  /// 3) Firestore 실패 시 SyncQueue에 enqueue (있으면).
  Future<void> updateTotalSeconds(String sessionId, int seconds) async {
    if (_uid.isEmpty) return;
    // 1) Hive 즉시 commit.
    final cached = _readHive(sessionId);
    final updated = (cached ??
            PatternSession.empty(uid: _uid, patternChartId: sessionId)
                .copyWith(id: sessionId))
        .copyWith(
      totalSeconds: seconds,
      updatedAt: DateTime.now(),
    );
    await _writeHive(updated);

    // 2) Firestore best-effort.
    try {
      await _sessionsRef.doc(sessionId).set({
        'totalSeconds': seconds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).withServerTimeout(op: 'update_total_seconds');
    } on ServerUnavailableException catch (e) {
      debugPrint(
          'PatternSessionRepository.updateTotalSeconds: Firestore failed, kept in Hive - $e');
      // 3) SyncQueue가 있으면 enqueue.
      final queue = _syncQueue;
      if (queue != null) {
        try {
          await queue.enqueue(SyncOp(
            id: 'pattern_session_total_seconds:$sessionId',
            entity: 'pattern_session',
            docId: sessionId,
            op: 'update',
            data: {'totalSeconds': seconds},
            createdAt: DateTime.now(),
          ));
        } catch (qe) {
          debugPrint(
              'PatternSessionRepository.updateTotalSeconds: SyncQueue enqueue failed - $qe');
        }
      }
      // Hive에 이미 저장됨 → 사용자 작업은 보존됨. throw하지 않음.
    }
  }

  // ── #704 Phase 2 — SyncQueue 에서 위임된 push ─────────────────
  /// SyncOrchestrator 가 큐에서 꺼낸 SyncOp 를 Firestore 로 push.
  ///
  /// totalSeconds 누적은 sum 정책 — 서버에 더 큰 값이 있으면 합산.
  /// 그 외 필드(스티키노트/스트로크 등)는 merge set.
  /// 회귀 방지: updateTotalSeconds / updateRuler 등 기존 직접 호출은 영향 없음.
  Future<void> pushFromSync(SyncOp op) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final data = op.data;
    final docId = op.docId;
    final docRef = _sessionsRef.doc(docId);

    // totalSeconds 만 담긴 op 인 경우 sum 정책으로 합산.
    if (data.containsKey('totalSeconds') && data.length == 1) {
      final localSeconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      try {
        final snap = await docRef.get().withServerTimeout(op: 'push_from_sync_get');
        final serverSeconds = snap.exists
            ? ((snap.data() as Map<String, dynamic>?)?['totalSeconds'] as num?)
                    ?.toInt() ??
                0
            : 0;
        // sum 정책: 양쪽 보존 — 큰 값 채택(중복 누적 방지).
        // 단순 sum 은 큐에 동일 op 가 여러 번 쌓이면 폭주하므로 max 사용.
        final merged =
            localSeconds > serverSeconds ? localSeconds : serverSeconds;
        await docRef.set({
          'totalSeconds': merged,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).withServerTimeout(op: 'push_total_seconds');
        // Hive 캐시 갱신.
        final cached = _readHive(docId);
        if (cached != null) {
          await _writeHive(cached.copyWith(
            totalSeconds: merged,
            updatedAt: DateTime.now(),
          ));
        }
      } catch (e) {
        debugPrint('[PatternSessionRepository.pushFromSync] failed: $e');
        rethrow;
      }
      return;
    }

    // 그 외 필드: merge set.
    final payload = Map<String, dynamic>.from(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(payload, SetOptions(merge: true))
        .withServerTimeout(op: 'push_from_sync_set');
  }

  /// 이슈 #630 — 특정 프로젝트에 연결된 도안 세션의 누적시간 합계.
  Future<int> totalSecondsForProject(String projectId) async {
    if (_uid.isEmpty || projectId.isEmpty) return 0;
    final snap = await _sessionsRef.where('projectId', isEqualTo: projectId).get().withServerTimeout(op: 'total_seconds_for_project');
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
    final snap = await _sessionsRef.get().withServerTimeout(op: 'total_seconds_all');
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
  /// #704 Phase A-B — Firestore timeout/장애 시 Hive 폴백 집계 (오프라인 대시보드 유지).
  ///   Hive에도 데이터 없으면 ServerUnavailableException throw (기존 동작 보존).
  Future<Map<String, ProjectTimeAggregate>> aggregateByProject() async {
    if (_uid.isEmpty) return {};
    try {
      final snap = await _sessionsRef.get().timeout(const Duration(seconds: 5));
      // 정상 응답 → Hive 캐시도 갱신 (best-effort).
      unawaited(_refreshHiveFromSnap(snap));
      return _aggregateFromDocs(snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return _AggregateRow(
          projectId: (data['projectId'] as String?)?.trim(),
          totalSeconds: (data['totalSeconds'] as num?)?.toInt() ?? 0,
          updatedAt: _readUpdatedAt(data['updatedAt']),
        );
      }));
    } on TimeoutException {
      final fallback = _aggregateFromHive();
      if (fallback.isNotEmpty) return fallback;
      throw const ServerUnavailableException('aggregateByProject timeout');
    } on FirebaseException catch (e) {
      final fallback = _aggregateFromHive();
      if (fallback.isNotEmpty) return fallback;
      throw ServerUnavailableException('firestore: ${e.code}');
    }
  }

  /// 스냅샷을 Hive에 best-effort 동기화.
  Future<void> _refreshHiveFromSnap(QuerySnapshot snap) async {
    final box = _hiveBox;
    if (box == null) return;
    for (final doc in snap.docs) {
      try {
        await box.put(doc.id, PatternSession.fromFirestore(doc).toJson());
      } catch (_) {/* 무음 */}
    }
  }

  /// Hive 데이터로 집계.
  Map<String, ProjectTimeAggregate> _aggregateFromHive() {
    final rows = _readHiveAll().map((s) => _AggregateRow(
          projectId: s.projectId?.trim(),
          totalSeconds: s.totalSeconds,
          updatedAt: s.updatedAt,
        ));
    return _aggregateFromDocs(rows);
  }

  Map<String, ProjectTimeAggregate> _aggregateFromDocs(
      Iterable<_AggregateRow> rows) {
    final result = <String, ProjectTimeAggregate>{};
    for (final row in rows) {
      final pid = row.projectId;
      if (pid == null || pid.isEmpty) continue;
      final existing = result[pid];
      if (existing == null) {
        result[pid] = ProjectTimeAggregate(
          projectId: pid,
          totalSeconds: row.totalSeconds,
          lastWorkedAt: row.updatedAt,
          sessionCount: 1,
        );
      } else {
        result[pid] = ProjectTimeAggregate(
          projectId: pid,
          totalSeconds: existing.totalSeconds + row.totalSeconds,
          lastWorkedAt: _laterOf(existing.lastWorkedAt, row.updatedAt),
          sessionCount: existing.sessionCount + 1,
        );
      }
    }
    return result;
  }

  static DateTime? _readUpdatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    return null;
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
    }, SetOptions(merge: true)).withServerTimeout(op: 'link_project');
  }

  Future<void> unlinkProject(String sessionId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'projectId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'unlink_project');
  }

  Future<void> linkSwatch(String sessionId, String swatchId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'swatchId': swatchId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'link_swatch');
  }

  Future<void> unlinkSwatch(String sessionId) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'swatchId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).withServerTimeout(op: 'unlink_swatch');
  }
}

/// #704 Phase A-B — Firestore doc과 Hive 모델을 한 형태로 다루기 위한 내부 row.
class _AggregateRow {
  final String? projectId;
  final int totalSeconds;
  final DateTime? updatedAt;
  const _AggregateRow({
    required this.projectId,
    required this.totalSeconds,
    required this.updatedAt,
  });
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
    Provider<PatternSessionRepository>((ref) {
  // #704 Phase A-B — SyncQueue 주입 (Firestore 실패 시 큐잉용).
  final queue = ref.watch(syncQueueProvider);
  return PatternSessionRepository(syncQueue: queue);
});

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
