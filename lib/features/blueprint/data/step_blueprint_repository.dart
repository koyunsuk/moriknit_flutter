// lib/features/blueprint/data/step_blueprint_repository.dart
//
// 이슈 #687 (Phase G) — StepBlueprint Repository.
//
// 컬렉션 경로:
//   - step_blueprints/{bid}                    (전역, ownerUid 필드)
//   - step_blueprints/{bid}/units/{unitId}     (subcollection)
//
// 책임:
//   1. CRUD (create / get / update / delete / watch)
//   2. units subcollection 관리 (batch 저장)
//   3. 버전 발행 (publishVersion)
//   4. Fork (다른 청사진을 내 청사진으로 복제)
//   5. visibility별 query
//
// 본격 권한 검사는 Firestore Rules에 위임. 본 Repository는 데이터 정합성만 책임.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/step_blueprint.dart';
import '../domain/step_blueprint_unit.dart';
import '../domain/step_unit_groupmeta.dart';

class StepBlueprintRepository {
  StepBlueprintRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _root =>
      _db.collection('step_blueprints');

  DocumentReference<Map<String, dynamic>> _doc(String id) => _root.doc(id);

  CollectionReference<Map<String, dynamic>> _unitsCol(String bid) =>
      _doc(bid).collection('units');

  // ── helpers ────────────────────────────────────────────────────────────────

  StepBlueprint _readBlueprint(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepBlueprint.fromMap({...data, 'id': snap.id});
  }

  StepBlueprintUnit _readUnit(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return StepBlueprintUnit.fromMap({...data, 'id': snap.id});
  }

  // ── CRUD: blueprint 본체 ───────────────────────────────────────────────────

  /// 신규 청사진 저장. id 비어 있으면 새 문서 발급.
  Future<StepBlueprint> create(StepBlueprint blueprint) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final ref = blueprint.id.isEmpty ? _root.doc() : _doc(blueprint.id);
    final now = DateTime.now();
    final prepared = blueprint.copyWith(
      id: ref.id,
      ownerUid: blueprint.ownerUid.isEmpty ? _uid : blueprint.ownerUid,
      createdAt: blueprint.createdAt,
      updatedAt: now,
    );
    await ref.set({
      ...prepared.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
    return prepared;
  }

  /// 부분 업데이트(merge). updatedAt 자동.
  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _doc(id).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 전체 덮어쓰기 저장.
  Future<StepBlueprint> save(StepBlueprint blueprint) async {
    if (blueprint.id.isEmpty) return create(blueprint);
    final now = DateTime.now();
    final next = blueprint.copyWith(updatedAt: now);
    await _doc(blueprint.id).set({
      ...next.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return next;
  }

  Future<StepBlueprint?> get(String id) async {
    final snap = await _doc(id).get();
    if (!snap.exists) return null;
    return _readBlueprint(snap);
  }

  Stream<StepBlueprint?> watch(String id) =>
      _doc(id).snapshots().map((s) => s.exists ? _readBlueprint(s) : null);

  /// 단순 삭제 (units subcollection은 Cloud Functions / 별도 sweep에 위임).
  Future<void> delete(String id) async => _doc(id).delete();

  // ── units subcollection ────────────────────────────────────────────────────

  Future<StepBlueprintUnit> saveUnit(StepBlueprintUnit unit) async {
    final ref = unit.id.isEmpty
        ? _unitsCol(unit.blueprintId).doc()
        : _unitsCol(unit.blueprintId).doc(unit.id);
    final now = DateTime.now();
    final next = unit.copyWith(id: ref.id, updatedAt: now);
    await ref.set({
      ...next.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (unit.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return next;
  }

  /// units 일괄 저장 (그룹 unitIds 와 일치하도록 일괄 갱신).
  Future<List<StepBlueprintUnit>> saveUnits(
    String blueprintId,
    List<StepBlueprintUnit> units,
  ) async {
    final batch = _db.batch();
    final result = <StepBlueprintUnit>[];
    for (final u in units) {
      final ref = u.id.isEmpty
          ? _unitsCol(blueprintId).doc()
          : _unitsCol(blueprintId).doc(u.id);
      final next = u.copyWith(id: ref.id, blueprintId: blueprintId);
      batch.set(ref, {
        ...next.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      result.add(next);
    }
    await batch.commit();
    return result;
  }

  Future<void> deleteUnit(String blueprintId, String unitId) async =>
      _unitsCol(blueprintId).doc(unitId).delete();

  Future<List<StepBlueprintUnit>> listUnits(String blueprintId) async {
    final snap = await _unitsCol(blueprintId).orderBy('order').get();
    return snap.docs.map(_readUnit).toList();
  }

  Stream<List<StepBlueprintUnit>> watchUnits(String blueprintId) =>
      _unitsCol(blueprintId)
          .orderBy('order')
          .snapshots()
          .map((s) => s.docs.map(_readUnit).toList());

  // ── group meta 갱신 (그룹 reorder/추가/삭제) ──────────────────────────────

  Future<void> updateGroups(
    String blueprintId,
    List<StepGroupMeta> groups,
  ) async =>
      update(blueprintId, {
        'groups': groups.map((g) => g.toMap()).toList(),
      });

  // ── 버전 발행 ─────────────────────────────────────────────────────────────

  /// 버전 발행 — version 필드 갱신 + publishedVersions 누적.
  /// visibility가 draft면 자동으로 private로 승격(작가가 직접 마켓/공개 전환은 별도 액션).
  Future<StepBlueprint> publishVersion({
    required String blueprintId,
    required String version,
    String? changelog,
  }) async {
    return _db.runTransaction<StepBlueprint>((tx) async {
      final ref = _doc(blueprintId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('청사진이 존재하지 않아요.');
      final current = _readBlueprint(snap);

      final entry = BlueprintPublishedVersion(
        version: version,
        publishedAt: DateTime.now(),
        changelog: changelog,
      );

      final nextVisibility = current.visibility == BlueprintVisibility.draft
          ? BlueprintVisibility.private
          : current.visibility;

      final next = current.copyWith(
        version: version,
        publishedVersions: [...current.publishedVersions, entry],
        visibility: nextVisibility,
        updatedAt: DateTime.now(),
      );
      tx.set(ref, {
        'version': version,
        'visibility': nextVisibility.name,
        'publishedVersions': next.publishedVersions
            .map((v) => v.toMap())
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });
  }

  // ── Fork ──────────────────────────────────────────────────────────────────

  /// 다른 청사진을 내 청사진으로 복제. units까지 함께 복제.
  /// 라이선스가 modify/redistribute 둘 다 막혀 있으면 호출부에서 사전 차단 권장.
  Future<StepBlueprint> fork({
    required StepBlueprint source,
    required String fromOwnerName,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final newRef = _root.doc();
    final now = DateTime.now();
    final forked = source.copyWith(
      id: newRef.id,
      ownerUid: _uid,
      visibility: BlueprintVisibility.draft,
      provider: BlueprintProvider.user,
      fromBlueprintId: source.id,
      fromAttribution: 'forked from @$fromOwnerName',
      publishedVersions: const [],
      version: '1.0.0',
      isFeatured: false,
      isCurated: false,
      moriknitVerified: false,
      members: const {},
      autoSyncOwnerRuns: false,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(newRef, {
      ...forked.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // units 복제
    final srcUnits = await _unitsCol(source.id).get();
    for (final doc in srcUnits.docs) {
      final unit = _readUnit(doc);
      final newUnitRef = _unitsCol(newRef.id).doc();
      batch.set(newUnitRef, {
        ...unit.toMap(),
        'id': newUnitRef.id,
        'blueprintId': newRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return forked;
  }

  // ── Query — visibility / kind / owner ─────────────────────────────────────

  Stream<List<StepBlueprint>> watchByOwner(String ownerUid) => _root
      .where('ownerUid', isEqualTo: ownerUid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  Stream<List<StepBlueprint>> watchByVisibility(BlueprintVisibility v) => _root
      .where('visibility', isEqualTo: v.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  Stream<List<StepBlueprint>> watchByKind(BlueprintKind kind) => _root
      .where('kind', isEqualTo: kind.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());

  /// 마켓플레이스 노출 청사진.
  Stream<List<StepBlueprint>> watchMarketplace() => _root
      .where('visibility', whereIn: [
        BlueprintVisibility.marketplace.name,
        BlueprintVisibility.public.name,
      ])
      .where('discoverability',
          isEqualTo: BlueprintDiscoverability.searchable.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_readBlueprint).toList());
}
