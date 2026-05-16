import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/errors/network_errors.dart';
import '../../blueprint/data/chart_to_units_converter.dart';
import '../../blueprint/data/step_blueprint_repository.dart';
import '../../blueprint/domain/step_blueprint_unit.dart';
import '../../pattern_converter/data/pdf_thumbnail_extractor.dart';
import '../domain/ai_pattern_section.dart';
import '../domain/pattern_chart.dart';
import '../domain/round_chart.dart';
import 'round_chart_thumbnail.dart';

class PatternRepository {
  /// #687 — StepBlueprintRepository를 선택적 주입 받아 모든 저장 시
  /// step_blueprints + units에도 동일 id로 청사진을 기록한다.
  /// 영역 분리: pattern_charts는 시각/메타, step_blueprints는 단계.
  PatternRepository({
    StepBlueprintRepository? blueprintRepo,
    LocalCache<PatternChart>? cache,
  })  : _blueprintRepo = blueprintRepo ?? StepBlueprintRepository(),
        _cache = cache ??
            LocalCache<PatternChart>(
              // #704 Phase A-A — 오프라인 폴백용 Hive 캐시.
              // #685 에서 이미 main.dart 에서 box 가 열려 있음 (boxCachePatternCharts).
              boxName: SubscriptionConstants.boxCachePatternCharts,
              fromJson: PatternChart.fromJson,
              toJson: (c) => c.toJson(),
              idOf: (c) => c.id,
            );

  final StepBlueprintRepository _blueprintRepo;
  final LocalCache<PatternChart> _cache;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _ref =>
      _db.collection('users').doc(_uid).collection('pattern_charts');

  Future<PatternChart> save(PatternChart chart) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final docRef = chart.id.isEmpty ? _ref.doc() : _ref.doc(chart.id);

    // 이슈 #665 Phase 5 — 원형 도안이면 썸네일 자동 생성·업로드.
    // imageUrl이 비어있을 때만 자동 생성 (사용자 명시 커버 보존).
    String resolvedImageUrl = chart.imageUrl;
    if (chart.chartType != ChartShape.rect &&
        chart.roundData != null &&
        resolvedImageUrl.isEmpty) {
      final url = await generateAndUploadRoundThumbnail(
        patternId: docRef.id,
        chart: chart.roundData!,
      );
      if (url != null && url.isNotEmpty) resolvedImageUrl = url;
    }

    final saved = chart.copyWith(
      id: docRef.id,
      imageUrl: resolvedImageUrl,
    );
    final isNew = chart.id.isEmpty;

    // 1) pattern_charts 저장 (시각/메타 — 기존 그대로).
    //    #687 Phase E1 — 단계 데이터(aiSections)는 더 이상 pattern_charts에
    //    저장하지 않는다. toJson에서 이미 제외되지만, merge:true 모드에서
    //    기존 문서에 남아 있던 aiSections 잔재를 비우기 위해 빈 배열로 명시.
    //    #720 — 무한로딩 방지: 15초 timeout. 실패 시 친화 메시지로 fallthrow.
    await docRef.set({
      ...saved.toJson(),
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('저장이 지연되고 있어요. 잠시 후 다시 시도해 주세요.'),
    );

    // 2) step_blueprints + units 동시 저장 (#687 — 단계 영역 분리).
    //    동일 id로 짝 — 호출자는 PatternChart.id로 양쪽 모두 조회 가능.
    //    #720 — 청사진 미러링 실패가 도안 저장 자체를 막지 않도록 try/catch.
    //    pattern_charts 는 이미 저장 완료 — 청사진은 다음 진입 시 어댑터로 폴백.
    try {
      await _mirrorToBlueprint(saved).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.save] mirror to blueprint failed: $e');
    }

    // 3) #704 Phase A-A — write-through 캐시 (오프라인 폴백용).
    //    저장 성공 시점에만 캐시 갱신, 실패는 무음 (UX 영향 X).
    await _cache.writeOne(saved);

    return saved;
  }

  /// #687 — PatternChart를 step_blueprints + units에 미러링.
  /// blueprint.id == chart.id 보장. units 생성 분기:
  ///   1) aiSections 있음 → aiSections.steps → units (기존 흐름)
  ///   2) ChartMode.narrative 또는 grid 비었지만 narrativeText 있음 → 행별 분해 (auto:narrative)
  ///   3) grid 있는 차트 모드 (symbol/colorChart/color) → toNarrative RLE → 행별 unit (auto:chart)
  ///   4) 그 외 (image/pdf 도안, 빈 차트) → units 없음 (단계 미생성 상태)
  Future<void> _mirrorToBlueprint(PatternChart chart) async {
    final blueprint = StepBlueprintRepository.adaptFromPatternChart(
      chart,
      ownerUid: _uid,
    );
    await _blueprintRepo.save(blueprint);

    final aiSections = chart.aiSections ?? const <AiSection>[];

    // 1) aiSections 있으면 기존 흐름 유지 (AI 변환 도안)
    if (aiSections.isNotEmpty) {
      final units = <StepBlueprintUnit>[];
      int order = 0;
      final now = DateTime.now();
      for (final section in aiSections) {
        for (final step in section.steps) {
          units.add(StepBlueprintUnit(
            id: step.id,
            blueprintId: blueprint.id,
            order: order++,
            title: '',
            instruction: step.instruction,
            instructionKo: step.instructionKo,
            createdAt: now,
          ));
        }
      }
      if (units.isNotEmpty) {
        await _blueprintRepo.saveUnits(blueprint.id, units);
      }
      return;
    }

    // 2) 서술형 도안 (narrativeText 행별 분해)
    //    ChartMode.narrative이거나, grid가 비어 있어도 narrativeText 있을 때.
    final hasNarrativeText = chart.narrativeText.trim().isNotEmpty;
    final isNarrativeMode = chart.mode == ChartMode.narrative;
    if (hasNarrativeText && (isNarrativeMode || chart.grid.isEmpty)) {
      final units = ChartToUnitsConverter.convertFromNarrativeText(
        narrativeText: chart.narrativeText,
        blueprintId: blueprint.id,
        korean: true,
      );
      if (units.isNotEmpty) {
        await _blueprintRepo.saveUnits(blueprint.id, units);
      }
      return;
    }

    // 3) 차트(symbol/colorChart/color) 자동 텍스트화 — toNarrative RLE → 행별 unit
    //    image/pdf 타입(grid 비었음)은 자동 제외됨.
    if (chart.grid.isNotEmpty && chart.rows > 0 && chart.cols > 0) {
      final units = ChartToUnitsConverter.convert(
        chart: chart,
        blueprintId: blueprint.id,
        korean: true,
      );
      if (units.isNotEmpty) {
        await _blueprintRepo.saveUnits(blueprint.id, units);
      }
      return;
    }

    // 4) 그 외 — units 없이 blueprint만 미러링 (단계 미생성 상태)
  }

  Future<void> delete(String id) async {
    // pattern_charts 삭제
    await _ref.doc(id).delete().withServerTimeout(op: 'delete_pattern');
    // step_blueprints + units subcollection 일괄 삭제 (#687)
    await _blueprintRepo.delete(id);
    // #704 Phase A-A — Hive 캐시에서도 제거 (성공 시점에만).
    await _cacheRemoveOne(id);
  }

  /// #704 Phase A-A — Hive 캐시 단건 삭제 헬퍼.
  /// LocalCache 가 단건 삭제 API 를 노출하지 않으므로 box 에 직접 접근.
  /// 실패는 무음 (UX 영향 X).
  Future<void> _cacheRemoveOne(String id) async {
    try {
      // 캐시 박스가 닫혀 있거나 웹이면 readOne 도 null 이므로 skip.
      if (_cache.readOne(id) == null) return;
      // 전체 재기록 — N 이 작아 비용 미미. delete 자체가 흔치 않은 액션.
      final remaining = _cache.readAll().where((c) => c.id != id).toList();
      await _cache.writeAll(remaining);
    } catch (_) {
      // 무음
    }
  }

  Future<void> linkToProject(String chartId, String? projectId) async {
    await _ref.doc(chartId).update({'linkedProjectId': projectId}).withServerTimeout(op: 'link_pattern_to_project');
  }

  Future<PatternChart> duplicate(PatternChart original) async {
    final copy = PatternChart(
      id: '',
      title: '${original.title} (복사)',
      rows: original.rows,
      cols: original.cols,
      mode: original.mode,
      grid: original.grid,
      narrativeText: original.narrativeText,
    );
    return save(copy);
  }

  /// 다른 사용자의 chart 타입 도안을 Fork하여 내 컬렉션에 복사합니다.
  /// 원본의 forkCount를 +1 업데이트하고 새 패턴 ID를 반환합니다.
  ///
  /// 이슈 #629 — complete 도안만 Fork 가능(호출부 가드 권장).
  /// 이슈 #687 — pattern_charts와 step_blueprints(+units)를 같은 ID로 동시 복제.
  /// 새 PatternChart는 `forkOfId`, `sourcePatternId`, `sourceOwnerName`을 모두 보유.
  Future<PatternChart> forkPattern({
    required String sourceOwnerId,
    required String sourceOwnerName,
    required PatternChart sourcePattern,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    if (sourcePattern.type != PatternType.chart) {
      throw Exception('차트 타입 도안만 Fork할 수 있어요.');
    }

    // 1. 내 컬렉션에 복사본 저장
    final docRef = _ref.doc();
    final forked = PatternChart(
      id: docRef.id,
      title: '${sourcePattern.title} (Fork)',
      rows: sourcePattern.rows,
      cols: sourcePattern.cols,
      mode: sourcePattern.mode,
      grid: sourcePattern.grid,
      narrativeText: sourcePattern.narrativeText,
      type: PatternType.chart,
      sourcePatternId: sourcePattern.id,
      sourceOwnerName: sourceOwnerName,
      // 이슈 #629 — Fork 관계 식별자(sourcePatternId와 동일 값, 명시적 표현).
      forkOfId: sourcePattern.id,
      // Fork 결과물은 무료 사본. 마켓 도입 후 가격 정책은 별도.
      priceWon: 0,
      narrativeBlocks: sourcePattern.narrativeBlocks,
      repeatRegions: sourcePattern.repeatRegions,
      gauge: sourcePattern.gauge,
      knittingDirection: sourcePattern.knittingDirection,
      mirrorMode: sourcePattern.mirrorMode,
      category: sourcePattern.category,
      chartType: sourcePattern.chartType,
      roundData: sourcePattern.roundData,
      guidePathData: sourcePattern.guidePathData,
    );
    await docRef.set({
      ...forked.toJson(),
      // #687 Phase E1 — 단계 데이터는 step_blueprints/units에만.
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'fork_pattern');

    // 2. step_blueprints + units 복제 (#687 — 단계 영역 동기 복제).
    //    blueprint.id == new chart.id 보장. 실패해도 본 도안 저장은 유효.
    try {
      await _copyBlueprintForFork(
        sourceOwnerName: sourceOwnerName,
        sourcePatternId: sourcePattern.id,
        newPatternId: docRef.id,
        forked: forked,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.forkPattern] blueprint copy failed: $e');
      // 본 도안에 청사진이 없거나 권한 부족 시에도 도안 자체 Fork는 성공 유지.
    }

    // 3. 원본 패턴의 forkCount를 +1 증가
    final sourceRef = _db
        .collection('users')
        .doc(sourceOwnerId)
        .collection('pattern_charts')
        .doc(sourcePattern.id);
    await sourceRef.update({'forkCount': FieldValue.increment(1)}).withServerTimeout(op: 'increment_fork');

    // #704 Phase A-A — Fork 본인 컬렉션 사본은 캐시에 기록.
    await _cache.writeOne(forked);

    return forked;
  }

  /// #629/#687 — Fork 시 원본 청사진(step_blueprints + units)을 새 chart.id로 복제.
  /// `StepBlueprintRepository.fork()`는 새 ID를 생성하므로 직접 batch 작업으로
  /// blueprint.id == newPatternId 일치를 보장한다.
  Future<void> _copyBlueprintForFork({
    required String sourceOwnerName,
    required String sourcePatternId,
    required String newPatternId,
    required PatternChart forked,
  }) async {
    // 원본 blueprint 조회. 권한이 없으면 Exception → 호출부 try/catch에서 무음 처리.
    final srcBlueprintRef =
        _db.collection('step_blueprints').doc(sourcePatternId);
    final srcDoc = await srcBlueprintRef.get();

    final newBlueprintRef =
        _db.collection('step_blueprints').doc(newPatternId);

    if (srcDoc.exists) {
      // 원본 blueprint 존재 — 그대로 복제 + units 일괄 복사.
      final srcUnitsSnap = await srcBlueprintRef.collection('units').get();
      final srcData = Map<String, dynamic>.from(srcDoc.data()!);
      final batch = _db.batch();
      batch.set(newBlueprintRef, {
        ...srcData,
        'id': newPatternId,
        'ownerUid': _uid,
        // Fork 결과물은 비공개 초안. 마켓 게이트는 호출부에서 별도 처리.
        'visibility': 'draft',
        'provider': 'user',
        'fromBlueprintId': sourcePatternId,
        'fromAttribution': 'forked from @$sourceOwnerName',
        'publishedVersions': const <dynamic>[],
        'version': '1.0.0',
        'isFeatured': false,
        'isCurated': false,
        'moriknitVerified': false,
        'members': const <String, dynamic>{},
        'autoSyncOwnerRuns': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // units 복제 — 새 unit.id, blueprintId=newPatternId
      for (final unitDoc in srcUnitsSnap.docs) {
        final unitData = Map<String, dynamic>.from(unitDoc.data());
        final newUnitRef = newBlueprintRef.collection('units').doc();
        unitData['id'] = newUnitRef.id;
        unitData['blueprintId'] = newPatternId;
        unitData['createdAt'] = FieldValue.serverTimestamp();
        unitData['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(newUnitRef, unitData);
      }
      await batch.commit().withServerTimeout(op: 'fork_blueprint_batch');
    } else {
      // 원본 blueprint 부재(레거시 도안) — chart 본문 기반 미러만 수행.
      await _mirrorToBlueprint(forked);
    }
  }

  /// 원본 도안의 forkCount를 +1 증가시킵니다.
  Future<void> incrementForkCount({
    required String sourceOwnerId,
    required String patternId,
  }) async {
    await _db
        .collection('users')
        .doc(sourceOwnerId)
        .collection('pattern_charts')
        .doc(patternId)
        .update({'forkCount': FieldValue.increment(1)}).withServerTimeout(op: 'increment_fork_count');
  }

  Stream<List<PatternChart>> watchAll() async* {
    // 이슈 #700 — 비로그인/지연 시에도 빈 리스트 첫 emit 보장 (무한로딩 차단).
    if (_uid.isEmpty) {
      yield const <PatternChart>[];
      return;
    }

    // #704 Phase A-A — Hive 캐시 즉시 emit (오프라인 폴백).
    //   비행기/기차 등 인터넷 없는 상황에서 이미 본 도안을 즉시 표시.
    final cached = _cache.readAll();
    if (cached.isNotEmpty) {
      // updatedAt 정렬은 Firestore 쿼리 책임 — 캐시는 단순 list 그대로 emit.
      yield cached;
    }

    // 이슈 #701 재발 fix — 기존 `.timeout(5s)` 는 Stream inactivity 기반이라
    //   첫 emit 후 5초간 변경 없으면 빈 리스트로 강제 reset → 도안이 사라지는 회귀 원인.
    //   Firestore snapshots 는 정상 상태에서 첫 도착 후 침묵하므로 timeout 부적합.
    //   인덱스 빌드/네트워크 지연은 error 콜백(AsyncDelayedFriendly)로 별도 처리.
    yield* _ref
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        // id 필드가 없는 구버전 문서는 doc.id로 보완
        if ((data['id'] as String?)?.isEmpty != false) data['id'] = d.id;
        return PatternChart.fromJson(data);
      }).toList();
      // #704 Phase A-A — 서버 응답 도착 시 캐시 전체 갱신 (fire-and-forget).
      //   다음 콜드 스타트/오프라인 진입 시 즉시 표시 가능하도록 항상 캐시한다.
      _cache.writeAll(list);
      return list;
    });
  }

  /// id 필드가 없는 구버전 도안에 id 필드를 자동 등록합니다.
  Future<void> migrateIds() async {
    if (_uid.isEmpty) return;
    final snap = await _ref.get().withServerTimeout(op: 'migrate_ids_get');
    final batch = _db.batch();
    bool hasUpdates = false;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['id'] as String?)?.isEmpty != false) {
        batch.update(doc.reference, {'id': doc.id});
        hasUpdates = true;
      }
    }
    if (hasUpdates) await batch.commit().withServerTimeout(op: 'migrate_ids_commit');
  }

  Future<PatternChart?> get(String id) async {
    try {
      final doc = await _ref.doc(id).get().withServerTimeout(op: 'get_pattern');
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      if ((data['id'] as String?)?.isEmpty != false) data['id'] = doc.id;
      final chart = PatternChart.fromJson(data);
      // #704 Phase A-A — 성공 시 캐시 write-through.
      await _cache.writeOne(chart);
      return chart;
    } on ServerUnavailableException {
      // #704 Phase A-A — 오프라인/타임아웃 시 Hive 캐시 폴백.
      final cached = _cache.readOne(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// 타인의 도안을 UID + patternId로 조회합니다 (Fork 출처 보기 등).
  /// 타인 소유 도안은 본인 캐시에 저장하지 않음 (소유자별 분리 원칙).
  Future<PatternChart?> getFromUser(String ownerUid, String patternId) async {
    final doc = await _db
        .collection('users')
        .doc(ownerUid)
        .collection('pattern_charts')
        .doc(patternId)
        .get()
        .withServerTimeout(op: 'get_pattern_from_user');
    if (!doc.exists) return null;
    return PatternChart.fromJson(doc.data() as Map<String, dynamic>);
  }

  Future<String> _uploadFile(File file, String folder) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final ext = file.path.split('.').last;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users/$_uid/patterns/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await storageRef.putFile(file);
    return storageRef.getDownloadURL();
  }

  /// 이슈 #683 — 웹 호환 bytes 업로드 헬퍼.
  /// kIsWeb 환경에서 File 객체 대신 Uint8List bytes를 직접 업로드.
  Future<String> _uploadBytes(
    Uint8List bytes,
    String folder,
    String fileName,
  ) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    String? contentType;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'webp':
        contentType = 'image/webp';
        break;
      case 'pdf':
        contentType = 'application/pdf';
        break;
    }
    final storageRef = FirebaseStorage.instance.ref().child(
          'users/$_uid/patterns/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
    await storageRef.putData(
      bytes,
      contentType != null ? SettableMetadata(contentType: contentType) : null,
    );
    return storageRef.getDownloadURL();
  }

  /// 이슈 #648 — PDF 첫 페이지를 추출해 Storage에 업로드하고 다운로드 URL 반환.
  /// 실패 시 null 반환 (호출자가 fallback 가능).
  Future<String?> _uploadPdfCover(File pdfFile) async {
    if (_uid.isEmpty) return null;
    try {
      final bytes = await pdfFile.readAsBytes();
      final thumb = await PdfThumbnailExtractor.extractFirstPageThumbnail(bytes);
      if (thumb == null || thumb.isEmpty) return null;
      final ref = FirebaseStorage.instance.ref().child(
            'users/$_uid/patterns/covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg',
          );
      await ref.putData(thumb, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<PatternChart> saveImagePattern({
    required String title,
    required File imageFile,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final imageUrl = await _uploadFile(imageFile, 'images');
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.image,
      imageUrl: imageUrl,
    );
    // 1) pattern_charts 저장 (시각/메타)
    //    #720 — 무한로딩 방지: 15초 timeout.
    await docRef.set({
      ...chart.toJson(),
      // #687 Phase E1 — 단계 데이터는 step_blueprints/units에만.
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('저장이 지연되고 있어요. 잠시 후 다시 시도해 주세요.'),
    );
    // 2) step_blueprints 미러 (#687) — units 없음 (단계 미생성 상태)
    //    #720 — 미러 실패 무음 처리 (도안 본체는 이미 저장 완료).
    try {
      await _mirrorToBlueprint(chart).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.saveImagePattern] mirror failed: $e');
    }
    // #704 Phase A-A — write-through 캐시.
    await _cache.writeOne(chart);
    return chart;
  }

  Future<PatternChart> savePdfPattern({
    required String title,
    required File pdfFile,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    // #652 — 커버 추출은 백그라운드로 분리. 사용자 흐름 차단 방지.
    // PDF만 빠르게 업로드 후 즉시 반환 → PatternDetailScreen 진입.
    final pdfUrl = await _uploadFile(pdfFile, 'pdfs');
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.pdf,
      pdfUrl: pdfUrl,
      imageUrl: '', // 커버는 백그라운드 추출 후 updateCover로 채워짐
    );
    // 1) pattern_charts 저장
    //    #720 — 무한로딩 방지: 15초 timeout.
    await docRef.set({
      ...chart.toJson(),
      // #687 Phase E1 — 단계 데이터는 step_blueprints/units에만.
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('저장이 지연되고 있어요. 잠시 후 다시 시도해 주세요.'),
    );
    // 2) step_blueprints 미러 (#687) — units 없음
    //    #720 — 미러 실패 무음 처리.
    try {
      await _mirrorToBlueprint(chart).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.savePdfPattern] mirror failed: $e');
    }
    // #704 Phase A-A — write-through 캐시.
    await _cache.writeOne(chart);
    // 백그라운드 fire-and-forget — 사용자 흐름 차단 X
    _extractAndSetPdfCover(chart.id, pdfFile);
    return chart;
  }

  /// #652 — PDF 커버 백그라운드 추출 + Firestore 자동 업데이트.
  /// PatternDetailScreen이 chart stream watch하므로 완료 시 자동 갱신.
  /// #687 — step_blueprints.attachedImageUrls도 동기 업데이트.
  Future<void> _extractAndSetPdfCover(String patternId, File pdfFile) async {
    try {
      final coverUrl = await _uploadPdfCover(pdfFile);
      if (coverUrl == null || coverUrl.isEmpty) return;
      await _ref.doc(patternId).update({
        'imageUrl': coverUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }).withServerTimeout(op: 'set_pdf_cover');
      await _syncBlueprintCover(patternId, coverUrl);
    } catch (e) {
      // 백그라운드 실패는 무음 (사용자 흐름 영향 없음)
    }
  }

  /// #687 — step_blueprints.attachedImageUrls 동기. 커버 prepend.
  Future<void> _syncBlueprintCover(String patternId, String coverUrl) async {
    try {
      final current = await _blueprintRepo.get(patternId);
      if (current == null) return;
      final existing = current.attachedImageUrls ?? const <String>[];
      // 이미 같은 URL이 있으면 skip (멱등성).
      if (existing.contains(coverUrl)) return;
      final next = <String>[coverUrl, ...existing];
      await _blueprintRepo.update(patternId, {'attachedImageUrls': next});
    } catch (_) {
      // 백그라운드 무음
    }
  }

  /// 이슈 #683 — 웹 호환 이미지 도안 저장 (bytes 입력).
  /// 기존 saveImagePattern(File)과 동일한 로직, putFile 대신 putData 사용.
  Future<PatternChart> saveImagePatternFromBytes({
    required String title,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final imageUrl = await _uploadBytes(bytes, 'images', fileName);
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.image,
      imageUrl: imageUrl,
    );
    // 1) pattern_charts 저장
    //    #720 — 무한로딩 방지: 15초 timeout.
    await docRef.set({
      ...chart.toJson(),
      // #687 Phase E1 — 단계 데이터는 step_blueprints/units에만.
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('저장이 지연되고 있어요. 잠시 후 다시 시도해 주세요.'),
    );
    // 2) step_blueprints 미러 (#687)
    //    #720 — 미러 실패 무음 처리.
    try {
      await _mirrorToBlueprint(chart).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.saveImagePatternFromBytes] mirror failed: $e');
    }
    // #704 Phase A-A — write-through 캐시.
    await _cache.writeOne(chart);
    return chart;
  }

  /// 이슈 #683 — 웹 호환 PDF 도안 저장 (bytes 입력).
  /// 기존 savePdfPattern(File)과 동일한 흐름. 커버는 백그라운드 추출.
  Future<PatternChart> savePdfPatternFromBytes({
    required String title,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final pdfUrl = await _uploadBytes(bytes, 'pdfs', fileName);
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.pdf,
      pdfUrl: pdfUrl,
      imageUrl: '', // 커버는 백그라운드 추출 후 채워짐
    );
    // 1) pattern_charts 저장
    //    #720 — 무한로딩 방지: 15초 timeout.
    await docRef.set({
      ...chart.toJson(),
      // #687 Phase E1 — 단계 데이터는 step_blueprints/units에만.
      'aiSections': const <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('저장이 지연되고 있어요. 잠시 후 다시 시도해 주세요.'),
    );
    // 2) step_blueprints 미러 (#687)
    //    #720 — 미러 실패 무음 처리.
    try {
      await _mirrorToBlueprint(chart).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[PatternRepository.savePdfPatternFromBytes] mirror failed: $e');
    }
    // #704 Phase A-A — write-through 캐시.
    await _cache.writeOne(chart);
    // 백그라운드 fire-and-forget — 사용자 흐름 차단 X
    _extractAndSetPdfCoverFromBytes(chart.id, bytes);
    return chart;
  }

  /// 이슈 #683 — PDF 커버 백그라운드 추출 (bytes 버전).
  /// 기존 _extractAndSetPdfCover(File)와 동일 흐름, readAsBytes 단계 생략.
  /// #687 — step_blueprints.attachedImageUrls도 동기 업데이트.
  Future<void> _extractAndSetPdfCoverFromBytes(
    String patternId,
    Uint8List pdfBytes,
  ) async {
    try {
      if (_uid.isEmpty) return;
      final thumb = await PdfThumbnailExtractor.extractFirstPageThumbnail(pdfBytes);
      if (thumb == null || thumb.isEmpty) return;
      final ref = FirebaseStorage.instance.ref().child(
            'users/$_uid/patterns/covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg',
          );
      await ref.putData(thumb, SettableMetadata(contentType: 'image/jpeg'));
      final coverUrl = await ref.getDownloadURL();
      if (coverUrl.isEmpty) return;
      await _ref.doc(patternId).update({
        'imageUrl': coverUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }).withServerTimeout(op: 'set_pdf_cover_bytes');
      await _syncBlueprintCover(patternId, coverUrl);
    } catch (_) {
      // 백그라운드 실패 무음
    }
  }

  /// 이슈 #651 — 기존 PDF 도안 중 커버가 비어있는 것을 lazy 추출.
  /// PatternDetailScreen 진입 시 fire-and-forget으로 호출.
  /// - 이미 imageUrl이 있으면 skip (멱등성)
  /// - PDF URL에서 bytes 다운로드 → PdfThumbnailExtractor → Storage 업로드 → imageUrl 갱신
  /// - 실패 시 무음 (return)
  Future<void> ensureCoverFromPdf(String patternId, String pdfUrl) async {
    debugPrint('[ensureCoverFromPdf] start id=$patternId pdfUrl=$pdfUrl');
    if (_uid.isEmpty) {
      debugPrint('[ensureCoverFromPdf] uid empty — abort');
      return;
    }
    if (patternId.isEmpty || pdfUrl.isEmpty) {
      debugPrint('[ensureCoverFromPdf] id/url empty — abort');
      return;
    }
    try {
      // 멱등성: 최신 imageUrl 재확인 (race condition 방지)
      final snap = await _ref.doc(patternId).get().withServerTimeout(op: 'ensure_cover_check');
      if (!snap.exists) {
        debugPrint('[ensureCoverFromPdf] doc not exists — abort');
        return;
      }
      final data = snap.data() as Map<String, dynamic>?;
      final currentImageUrl = (data?['imageUrl'] as String?) ?? '';
      if (currentImageUrl.isNotEmpty) {
        debugPrint('[ensureCoverFromPdf] imageUrl already set — skip');
        return;
      }

      // pdfUrl이 Storage 상대경로면 다운로드 URL로 해석
      String resolvedUrl = pdfUrl;
      if (!pdfUrl.startsWith('http')) {
        debugPrint('[ensureCoverFromPdf] resolving Storage path: $pdfUrl');
        resolvedUrl = await FirebaseStorage.instance.ref(pdfUrl).getDownloadURL();
        debugPrint('[ensureCoverFromPdf] resolved to: $resolvedUrl');
      }

      // PDF 다운로드
      debugPrint('[ensureCoverFromPdf] downloading PDF...');
      final res = await http.get(Uri.parse(resolvedUrl));
      if (res.statusCode != 200) {
        debugPrint('[ensureCoverFromPdf] HTTP ${res.statusCode} — abort');
        return;
      }
      final pdfBytes = res.bodyBytes;
      if (pdfBytes.isEmpty) {
        debugPrint('[ensureCoverFromPdf] empty bytes — abort');
        return;
      }
      debugPrint('[ensureCoverFromPdf] PDF bytes=${pdfBytes.length}');

      debugPrint('[ensureCoverFromPdf] extracting thumbnail...');

      // 첫 페이지 썸네일 추출
      final thumb =
          await PdfThumbnailExtractor.extractFirstPageThumbnail(pdfBytes);
      if (thumb == null || thumb.isEmpty) {
        debugPrint('[ensureCoverFromPdf] thumb null/empty — abort');
        return;
      }
      debugPrint('[ensureCoverFromPdf] thumb extracted ${thumb.length} bytes');

      // Storage 업로드
      debugPrint('[ensureCoverFromPdf] uploading to Storage...');
      final ref = FirebaseStorage.instance.ref().child(
            'pattern/$_uid/${patternId}_cover_lazy.jpg',
          );
      await ref.putData(thumb, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      debugPrint('[ensureCoverFromPdf] uploaded url=$url');

      // Firestore 갱신 (15초 timeout — 네트워크 hang 회피)
      debugPrint('[ensureCoverFromPdf] updating Firestore...');
      await _ref.doc(patternId).update({
        'imageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      debugPrint('[ensureCoverFromPdf] Firestore updated — DONE');
    } catch (e, st) {
      debugPrint('[ensureCoverFromPdf] EXCEPTION: $e\n$st');
      return;
    }
  }

  /// 이슈 #651 옵션 A — 어드민 일괄 마이그레이션.
  /// 모든 사용자의 모든 도안 중 type=pdf, imageUrl 비어있는 것만 추출 + 처리.
  /// - collectionGroup('pattern_charts') 사용 (어드민 권한 필요)
  /// - 각 PDF 도안에 대해 PdfThumbnailExtractor + Storage 업로드 + Firestore 갱신
  /// - 실패한 도안은 skip (계속 진행)
  /// - 이미 imageUrl 있으면 skip (멱등성)
  /// - [onProgress]: (current, total) 콜백 (진행률 표시용)
  /// - 처리 성공한 개수 반환
  Future<int> migrateMissingCoversForAllUsers({
    void Function(int current, int total)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요해요.');
    if (user.email != 'koyunsuk@gmail.com') {
      throw Exception('어드민만 사용할 수 있어요.');
    }

    // 모든 pattern_charts 중 PDF 타입 + imageUrl 비어있는 것 추출
    final snap = await _db.collectionGroup('pattern_charts').get().withServerTimeout(op: 'migrate_admin_get');
    final candidates = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = (data['type'] as String?) ?? '';
      final pdfUrl = (data['pdfUrl'] as String?) ?? '';
      final imageUrl = (data['imageUrl'] as String?) ?? '';
      // PDF 타입이고, pdfUrl 있고, imageUrl 비어있는 것만
      if (type == 'pdf' && pdfUrl.isNotEmpty && imageUrl.isEmpty) {
        candidates.add(doc);
      }
    }

    final total = candidates.length;
    int processed = 0;
    int success = 0;
    onProgress?.call(0, total);

    for (final doc in candidates) {
      processed++;
      try {
        final data = doc.data();
        final pdfUrl = (data['pdfUrl'] as String?) ?? '';
        if (pdfUrl.isEmpty) {
          onProgress?.call(processed, total);
          continue;
        }

        // doc 경로에서 ownerUid 추출: users/{uid}/pattern_charts/{id}
        final pathParts = doc.reference.path.split('/');
        if (pathParts.length < 4) {
          onProgress?.call(processed, total);
          continue;
        }
        final ownerUid = pathParts[1];
        final patternId = doc.id;

        // PDF 다운로드
        final res = await http.get(Uri.parse(pdfUrl));
        if (res.statusCode != 200) {
          onProgress?.call(processed, total);
          continue;
        }
        final pdfBytes = res.bodyBytes;
        if (pdfBytes.isEmpty) {
          onProgress?.call(processed, total);
          continue;
        }

        // 첫 페이지 썸네일 추출
        final thumb =
            await PdfThumbnailExtractor.extractFirstPageThumbnail(pdfBytes);
        if (thumb == null || thumb.isEmpty) {
          onProgress?.call(processed, total);
          continue;
        }

        // Storage 업로드 (소유자 경로)
        final ref = FirebaseStorage.instance.ref().child(
              'pattern/$ownerUid/${patternId}_cover_admin_migrate.jpg',
            );
        await ref.putData(thumb, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();

        // Firestore 갱신 (어드민 권한)
        await doc.reference.update({
          'imageUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }).withServerTimeout(op: 'migrate_admin_update');
        success++;
      } catch (_) {
        // 개별 도안 실패는 skip
      }
      onProgress?.call(processed, total);
    }

    return success;
  }

  /// 이슈 #648 — 도안 커버 이미지만 업데이트 (사용자가 상세에서 직접 변경).
  /// 새 커버 파일을 Storage에 업로드 후 imageUrl 필드를 갱신합니다.
  /// type 무관 (chart/image/pdf 모두 동일하게 imageUrl을 커버 슬롯으로 사용).
  Future<String> updateCover({
    required String patternId,
    required File coverFile,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    if (patternId.isEmpty) throw Exception('도안 ID가 없어요.');
    final ext = coverFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final ref = FirebaseStorage.instance.ref().child(
          'pattern/$_uid/${patternId}_cover_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
    final bytes = await coverFile.readAsBytes();
    await ref.putData(Uint8List.fromList(bytes),
        SettableMetadata(contentType: mime));
    final url = await ref.getDownloadURL();
    await _ref.doc(patternId).update({
      'imageUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'update_cover');
    // #687 — step_blueprints attachedImageUrls 동기.
    await _syncBlueprintCover(patternId, url);
    return url;
  }
}

final patternRepositoryProvider = Provider<PatternRepository>((ref) {
  // #687 — StepBlueprintRepository 주입으로 양쪽 컬렉션 동시 저장 보장.
  return PatternRepository(
    blueprintRepo: StepBlueprintRepository(),
  );
});

final patternListProvider = StreamProvider<List<PatternChart>>((ref) {
  ref.keepAlive();
  final repo = ref.watch(patternRepositoryProvider);
  Future.microtask(() => repo.migrateIds());
  return repo.watchAll();
});
