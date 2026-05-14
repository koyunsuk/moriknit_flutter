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
//   4. (Phase I-C) 신규 컬렉션 없을 때 기존 ProjectStep 어댑터 fallback

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../project/domain/project_step.dart';
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

  // ── Phase I-C: legacy fallback ─────────────────────────────────────────────
  //
  // 기존 프로젝트 단계 모델(ProjectStep) 데이터를 StepRun/Progress 모델로
  // 합성하는 어댑터. 마이그레이션 전이라도 신규 모델 화면이 동작하도록 함.
  //
  // 안전 원칙:
  // - **읽기 전용**. Firestore에 어떤 쓰기도 하지 않음.
  // - 기존 컬렉션(users/{uid}/projects/{pid}/steps)에서 직접 읽음.
  // - 합성 ID 형식: 'legacy_<projectId>' — 절대 신규 컬렉션 ID와 충돌하지 않음.

  /// 프로젝트의 기존 ProjectStep 컬렉션을 1회 fetch.
  Future<List<ProjectStep>> _fetchLegacyProjectSteps(String projectId) async {
    if (_uid.isEmpty || projectId.isEmpty) return const [];
    final snap = await _db
        .collection('users')
        .doc(_uid)
        .collection('projects')
        .doc(projectId)
        .collection('steps')
        .orderBy('order')
        .get();
    return snap.docs
        .map((d) => ProjectStep.fromMap(d.data(), d.id))
        .toList();
  }

  /// 신규 컬렉션 우선, 없으면 기존 projects/{pid}/steps 에서 어댑터 변환.
  ///
  /// 반환:
  /// - 신규 step_runs에 projectId 매칭 문서가 있으면 첫 번째(가장 최근) 사용.
  /// - 없으면 기존 ProjectStep 리스트를 합성 StepRun으로 변환.
  /// - 둘 다 없으면 null.
  Future<StepRun?> getOrAdaptLegacyByProjectId(String projectId) async {
    if (_uid.isEmpty || projectId.isEmpty) return null;

    // 1차: 신규 컬렉션
    final newSnap = await _runsCol()
        .where('projectId', isEqualTo: projectId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();
    if (newSnap.docs.isNotEmpty) {
      return _readRun(newSnap.docs.first);
    }

    // 2차: 기존 ProjectStep 어댑터 변환
    final steps = await _fetchLegacyProjectSteps(projectId);
    if (steps.isEmpty) return null;
    return _adaptFromProjectSteps(projectId, steps);
  }

  /// 신규 컬렉션 우선 progress 스트림, 없으면 기존 ProjectStep 어댑터 변환.
  ///
  /// 동작:
  /// - 신규 step_runs 문서가 있으면 watchProgress(runId) 직접 반환.
  /// - 없으면 기존 ProjectStep snapshot 스트림을 progress 리스트로 변환.
  Stream<List<StepRunProgress>> watchProgressWithLegacy({
    required String projectId,
    String? runId,
  }) {
    if (_uid.isEmpty) return Stream.value(const []);
    if (runId != null && !runId.startsWith('legacy_')) {
      return watchProgress(runId);
    }
    // legacy 모드: 기존 ProjectStep 컬렉션 스트림을 progress로 변환
    return _db
        .collection('users')
        .doc(_uid)
        .collection('projects')
        .doc(projectId)
        .collection('steps')
        .orderBy('order')
        .snapshots()
        .map((snap) {
      final steps = snap.docs
          .map((d) => ProjectStep.fromMap(d.data(), d.id))
          .toList();
      return _adaptProgressFromSteps(projectId, steps);
    });
  }

  StepRun _adaptFromProjectSteps(String projectId, List<ProjectStep> steps) {
    final completed = steps.where((s) => s.isDone).length;
    final total = steps.length;
    return StepRun(
      id: 'legacy_$projectId',
      userUid: _uid,
      blueprintId: 'legacy_$projectId',
      sourceBlueprintVersion: '1.0.0',
      projectId: projectId,
      role: StepRunRole.user,
      members: const {},
      summary: RunSummary(
        totalUnits: total,
        completedCount: completed,
        percentComplete: total == 0 ? 0 : completed / total,
      ),
      yarnIds: const [],
      needleIds: const [],
      startedAt: steps.isNotEmpty ? steps.first.createdAt : DateTime.now(),
    );
  }

  List<StepRunProgress> _adaptProgressFromSteps(
    String projectId,
    List<ProjectStep> steps,
  ) {
    final runId = 'legacy_$projectId';
    return steps.map((s) {
      return StepRunProgress(
        unitId: s.id,
        runId: runId,
        isDone: s.isDone,
        doneAt: s.doneAt,
        currentRow: 0,
        targetRow: s.targetRow,
        totalSeconds: 0,
        progressImages: (s.photoUrl == null || s.photoUrl!.isEmpty)
            ? const []
            : [
                ProgressImage(
                  url: s.photoUrl!,
                  takenAt: s.doneAt ?? DateTime.now(),
                  order: 0,
                ),
              ],
        note: s.note.isEmpty ? null : s.note,
        counterId: null,
      );
    }).toList();
  }
}
