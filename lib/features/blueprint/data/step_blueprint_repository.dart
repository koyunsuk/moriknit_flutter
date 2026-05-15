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

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart' as pat;
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

  /// 청사진 + units subcollection 일괄 삭제 (#687 본문 교체).
  /// units가 많을 경우에도 batch로 안전하게 처리.
  Future<void> delete(String id) async {
    // units subcollection 먼저 삭제 (batch).
    final unitsSnap = await _unitsCol(id).get();
    final batch = _db.batch();
    for (final doc in unitsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_doc(id));
    await batch.commit();
  }

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

  /// 협업자(members 맵의 key)로 참여 중인 청사진 스트림.
  ///
  /// Firestore는 map 의 key 존재 여부 단독 query 가 어렵기 때문에
  /// `members.{uid}` 필드 존재 여부로 매칭한다. Firestore rules 의 hasBlueprintMemberRole
  /// 와 동일한 정책: members 맵에 uid 가 키로 들어가 있으면 협업자.
  ///
  /// 자기 자신이 ownerUid 인 청사진은 제외 (watchByOwner 와 중복 방지).
  Stream<List<StepBlueprint>> watchByMember(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _root
        .where('members.$uid', whereIn: const [
          'admin',
          'editor',
          'tester',
          'commenter',
          'viewer',
        ])
        .snapshots()
        .map((s) => s.docs
            .map(_readBlueprint)
            .where((bp) => bp.ownerUid != uid)
            .toList());
  }

  // ── 협업자(members) 관리 ──────────────────────────────────────────────────

  /// 협업자 추가/역할 변경. owner 만 호출해야 한다(Rules 에서 차단됨).
  Future<void> upsertMember({
    required String blueprintId,
    required String memberUid,
    required BlueprintMemberRole role,
  }) async {
    await _doc(blueprintId).set({
      'members': {memberUid: role.name},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 협업자 제거.
  Future<void> removeMember({
    required String blueprintId,
    required String memberUid,
  }) async {
    await _doc(blueprintId).update({
      'members.$memberUid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 사용자 검색 (displayName prefix). 협업자 초대 시트에서 사용.
  Future<List<Map<String, String>>> searchUsersByDisplayName(
    String query, {
    String? excludeUid,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$qꯦ')
        .limit(20)
        .get();
    return snap.docs
        .map((doc) => {
              'uid': doc.id,
              'displayName': (doc.data()['displayName'] as String?) ?? '',
              'email': (doc.data()['email'] as String?) ?? '',
              'photoURL': (doc.data()['photoURL'] as String?) ?? '',
            })
        .where((u) =>
            u['uid'] != excludeUid && (u['displayName']!.isNotEmpty))
        .toList();
  }

  /// 단일 사용자 조회 (uid 로). 협업자 표시에 닉네임 가져올 때 사용.
  Future<Map<String, String>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return {
      'uid': uid,
      'displayName': (data['displayName'] as String?) ?? '',
      'email': (data['email'] as String?) ?? '',
      'photoURL': (data['photoURL'] as String?) ?? '',
    };
  }

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

  // ── Phase I-A : 신규 컬렉션 우선 + 기존 pattern_charts 어댑터 fallback ────
  //
  // 마이그레이션 실행 여부와 무관하게 화면이 정상 동작하도록 보강.
  // 본 메서드는 **읽기 전용 어댑터** — pattern_charts 데이터는 변형하지 않음.
  // 어댑터로 생성된 StepBlueprint는 신규 컬렉션에 저장되지 않고 메모리에서만 사용.
  //
  // Phase J(옛 코드 삭제) 진입 시 본 fallback 메서드들도 함께 제거 예정.

  /// 단일 청사진 조회 — 신규 컬렉션 우선, 없으면 기존 pattern_charts에서 어댑터 변환.
  ///
  /// 사용 예: 청사진 상세화면이 [id]를 받아 표시할 때, 마이그레이션 안 한 사용자는
  /// pattern_charts 데이터를 어댑터로 즉시 보여줌(저장 안 함).
  Future<StepBlueprint?> getOrAdaptLegacy(
    String id, {
    required PatternRepository patternRepo,
  }) async {
    final blueprint = await get(id);
    if (blueprint != null) return blueprint;
    final chart = await patternRepo.get(id);
    if (chart == null) return null;
    return adaptFromPatternChart(chart, ownerUid: _uid);
  }

  /// 내 청사진 목록 — step_blueprints 우선 + pattern_charts 어댑터 보충 (중복 제거).
  ///
  /// 두 stream을 동시 구독하고 매 emission마다 최신 결합 리스트를 emit.
  /// - 같은 id가 양쪽에 있으면 step_blueprints 우선 (마이그레이션 완료 데이터).
  /// - pattern_charts 단독은 어댑터로 변환(임시) 후 합산.
  Stream<List<StepBlueprint>> watchMyBlueprintsWithLegacy({
    required String ownerUid,
    required PatternRepository patternRepo,
  }) {
    final controller = StreamController<List<StepBlueprint>>.broadcast();
    var latestBlueprints = <StepBlueprint>[];
    var latestMemberBlueprints = <StepBlueprint>[];
    var latestCharts = <pat.PatternChart>[];
    var hasBlueprints = false;
    var hasCharts = false;

    void emit() {
      // step_blueprints는 우선권 (이미 마이그레이션된 데이터).
      // ownerUid 가 자신인 청사진 + 협업자로 참여중인 청사진 결합.
      final ownerIds = latestBlueprints.map((b) => b.id).toSet();
      final memberOnly = latestMemberBlueprints
          .where((b) => !ownerIds.contains(b.id))
          .toList();
      final combinedBlueprints = <StepBlueprint>[
        ...latestBlueprints,
        ...memberOnly,
      ];
      final blueprintIds = combinedBlueprints.map((b) => b.id).toSet();
      // sourcePatternChartId / chartAssetId 매칭으로도 중복 차단 (id 형식이 다를 수 있음).
      final referencedChartIds = <String>{
        for (final b in combinedBlueprints) ...[
          if (b.sourcePatternChartId != null) b.sourcePatternChartId!,
          if (b.chartAssetId != null) b.chartAssetId!,
        ],
      };

      final adapted = <StepBlueprint>[];
      for (final chart in latestCharts) {
        if (blueprintIds.contains(chart.id)) continue;
        if (referencedChartIds.contains(chart.id)) continue;
        adapted.add(adaptFromPatternChart(chart, ownerUid: ownerUid));
      }

      final merged = <StepBlueprint>[...combinedBlueprints, ...adapted];
      merged.sort((a, b) {
        final au = a.updatedAt ?? a.createdAt;
        final bu = b.updatedAt ?? b.createdAt;
        return bu.compareTo(au);
      });
      controller.add(merged);
    }

    final subBlueprints = watchByOwner(ownerUid).listen(
      (list) {
        latestBlueprints = list;
        hasBlueprints = true;
        // 한쪽만 와도 빠르게 노출. emit()는 두 리스트의 현 상태로 결합.
        if (hasCharts || hasBlueprints) {
          emit();
        }
      },
      onError: controller.addError,
    );
    // 협업자로 참여 중인 청사진도 함께 라이브러리에 노출 (#687).
    final subMemberBlueprints = watchByMember(ownerUid).listen(
      (list) {
        latestMemberBlueprints = list;
        emit();
      },
      // members map 쿼리 미지원 환경/색인 부재 시 조용히 빈 리스트 유지.
      onError: (_) {
        latestMemberBlueprints = const [];
        emit();
      },
    );
    final subCharts = patternRepo.watchAll().listen(
      (list) {
        latestCharts = list;
        hasCharts = true;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subBlueprints.cancel();
      await subMemberBlueprints.cancel();
      await subCharts.cancel();
    };
    return controller.stream;
  }

  /// PatternChart → StepBlueprint 어댑터 (메모리 변환, 저장 X).
  ///
  /// 신규 컬렉션이 비어 있을 때 화면에 표시하기 위한 임시 표현. 사용자가 청사진을
  /// 명시적으로 발행/저장할 때 비로소 step_blueprints 컬렉션에 기록된다.
  static StepBlueprint adaptFromPatternChart(
    pat.PatternChart chart, {
    required String ownerUid,
  }) {
    final aiSections = chart.aiSections ?? const [];
    final groups = <StepGroupMeta>[];
    for (var gi = 0; gi < aiSections.length; gi++) {
      final section = aiSections[gi];
      groups.add(StepGroupMeta(
        id: section.id,
        title: section.title,
        titleKo: section.titleKo,
        order: gi,
        unitIds: section.steps.map((s) => s.id).toList(),
      ));
    }

    final attachedImageUrls =
        chart.imageUrl.isNotEmpty ? <String>[chart.imageUrl] : null;
    final attachedPdfUrls =
        chart.pdfUrl.isNotEmpty ? <String>[chart.pdfUrl] : null;

    return StepBlueprint(
      id: chart.id,
      ownerUid: ownerUid,
      title: chart.title,
      kind: BlueprintKind.pattern,
      visibility: BlueprintVisibility.private,
      license: const BlueprintLicense(),
      provider: BlueprintProvider.user,
      sourcePatternChartId: chart.id,
      chartAssetId: chart.id,
      attachedImageUrls: attachedImageUrls,
      attachedPdfUrls: attachedPdfUrls,
      version: '1.0.0',
      publishedVersions: const [],
      autoSyncOwnerRuns: true,
      members: const {},
      discoverability: BlueprintDiscoverability.hidden,
      isFeatured: false,
      isCurated: false,
      moriknitVerified: false,
      tags: const ['adapter:legacy_pattern_chart'],
      groups: groups,
      // ── #687 Phase A — 1:1 이식 보강 필드 ──
      ravelryPatternId: chart.ravelryPatternId,
      forkCount: chart.forkCount,
      assetType: chart.type.name,
      gaugeJson: chart.gauge?.toJson(),
      repeatRegionsJson:
          chart.repeatRegions.map((r) => r.toJson()).toList(),
      createdAt: chart.createdAt ?? DateTime.now(),
      updatedAt: chart.createdAt,
    );
  }
}
