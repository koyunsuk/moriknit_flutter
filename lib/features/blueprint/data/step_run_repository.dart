// lib/features/blueprint/data/step_run_repository.dart
//
// 이슈 #687 (Phase G) — StepRun Repository.
//
// 컬렉션 경로:
//   - users/{uid}/step_runs/{rid}
//   - users/{uid}/step_runs/{rid}/progress/{unitId}
//
// 책임:
//   1. StepRun CRUD + watch
//   2. progress 문서 CRUD + watch
//   3. progress 변경 시 RunSummary 자동 갱신 (transaction)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/step_run.dart';
import '../domain/step_run_progress.dart';

class StepRunRepository {
  StepRunRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _runsCol([String? uid]) =>
      _db.collection('users').doc(uid ?? _uid).collection('step_runs');

  DocumentReference<Map<String, dynamic>> _runDoc(String rid, [String? uid]) =>
      _runsCol(uid).doc(rid);

  CollectionReference<Map<String, dynamic>> _progressCol(
    String rid, [
    String? uid,
  ]) =>
      _runDoc(rid, uid).collection('progress');

  // ── helpers ────────────────────────────────────────────────────────────────

  StepRun _readRun(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepRun.fromMap({...data, 'id': snap.id});
  }

  StepRunProgress _readProgress(
    DocumentSnapshot<Map<String, dynamic>> snap,
    String runId,
  ) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepRunProgress.fromMap({
      ...data,
      'unitId': snap.id,
      'runId': runId,
    });
  }

  // ── run CRUD ───────────────────────────────────────────────────────────────

  Future<StepRun> create(StepRun run) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final ref = run.id.isEmpty ? _runsCol().doc() : _runDoc(run.id);
    final prepared = run.copyWith(
      id: ref.id,
      userUid: run.userUid.isEmpty ? _uid : run.userUid,
      updatedAt: DateTime.now(),
    );
    await ref.set({
      ...prepared.toMap(),
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
    return prepared;
  }

  Future<void> update(String rid, Map<String, dynamic> patch) async {
    await _runDoc(rid).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<StepRun?> get(String rid) async {
    final snap = await _runDoc(rid).get();
    if (!snap.exists) return null;
    return _readRun(snap);
  }

  Stream<StepRun?> watch(String rid) => _runDoc(rid)
      .snapshots()
      .map((s) => s.exists ? _readRun(s) : null);

  /// 내 모든 실행. updatedAt desc.
  Stream<List<StepRun>> watchMine() => _runsCol()
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readRun).toList());

  Stream<List<StepRun>> watchByBlueprint(String blueprintId) => _runsCol()
      .where('blueprintId', isEqualTo: blueprintId)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readRun).toList());

  /// 프로젝트별 실행 (1 프로젝트 = N 실행 가능).
  Stream<List<StepRun>> watchByProject(String projectId) => _runsCol()
      .where('projectId', isEqualTo: projectId)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readRun).toList());

  Future<void> delete(String rid) async => _runDoc(rid).delete();

  Future<void> markCompleted(String rid) async => update(rid, {
        'completedAt': FieldValue.serverTimestamp(),
      });

  // ── progress CRUD ──────────────────────────────────────────────────────────

  Stream<List<StepRunProgress>> watchProgress(String rid) =>
      _progressCol(rid).snapshots().map(
            (s) => s.docs.map((d) => _readProgress(d, rid)).toList(),
          );

  Stream<StepRunProgress?> watchProgressUnit(String rid, String unitId) =>
      _progressCol(rid).doc(unitId).snapshots().map(
            (s) => s.exists ? _readProgress(s, rid) : null,
          );

  /// 단계 progress 저장 + RunSummary 동기 갱신.
  /// totalUnits 인자가 필요 — 호출부에서 blueprint.unit 개수를 넘긴다.
  Future<StepRunProgress> saveProgress({
    required String rid,
    required StepRunProgress progress,
    required int totalUnits,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    if (progress.unitId.isEmpty) {
      throw Exception('progress.unitId 가 필요합니다.');
    }
    final progRef = _progressCol(rid).doc(progress.unitId);
    final runRef = _runDoc(rid);

    return _db.runTransaction<StepRunProgress>((tx) async {
      // 1) 기존 progress 콜렉션 전체 통계 — 비효율적이지만 작은 N(보통 <50) 가정.
      final all = await _progressCol(rid).get();
      final others = all.docs.where((d) => d.id != progress.unitId);
      var completed = others
          .where((d) => (d.data()['isDone'] as bool? ?? false))
          .length;
      if (progress.isDone) completed += 1;

      // 2) progress 본문 set
      tx.set(progRef, {
        ...progress.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) run 본문에 summary 갱신
      final pct = totalUnits > 0 ? completed / totalUnits : 0.0;
      tx.set(runRef, {
        'summary': {
          'totalUnits': totalUnits,
          'completedCount': completed,
          'currentUnitId': progress.unitId,
          'percentComplete': pct,
          'lastActivityAt': DateTime.now().toIso8601String(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return progress.copyWith(updatedAt: DateTime.now());
    });
  }

  Future<void> deleteProgress(String rid, String unitId) async =>
      _progressCol(rid).doc(unitId).delete();
}
