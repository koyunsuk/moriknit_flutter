// lib/features/blueprint/data/blueprint_migration.dart
//
// 이슈 #687 (Phase H) — 일회성 마이그레이션 스크립트.
//
// 목적: 기존 데이터 컬렉션을 신규 청사진(StepBlueprint) + 실행(StepRun) 구조로
//       병렬 복제한다. 기존 컬렉션은 절대 삭제하지 않는다.
//
// 마이그레이션 대상:
//   1. users/{uid}/pattern_charts        → step_blueprints + units
//   2. users/{uid}/projects/{pid}/steps  → users/{uid}/step_runs + progress
//   3. builtin_templates                 → step_blueprints (kind=template, official)
//   4. users/{uid}/templates             → step_blueprints (kind=template, user)
//
// 멱등성:
//   - 신규 청사진/실행 문서에 `migrationVersion` 필드 부착.
//   - 재실행 시 이미 마이그레이션된 문서는 skip.
//
// 안전성:
//   - 기존 컬렉션은 read-only. 어떤 경우에도 delete/update 호출하지 않는다.
//   - Dry Run 모드는 실제 Firestore 쓰기를 일절 하지 않는다.
//   - 본인 소유(uid) 데이터에 한정.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../pattern/domain/ai_pattern_section.dart' as ais;
import '../../pattern/domain/pattern_chart.dart' as pat;
import '../../project/domain/builtin_template.dart' as bt;
import '../../project/domain/project_step.dart' as ps;
import '../../project/domain/user_template.dart' as ut;
import '../domain/step_blueprint.dart';
import '../domain/step_blueprint_unit.dart';
import '../domain/step_run.dart';
import '../domain/step_run_progress.dart';
import '../domain/step_unit_groupmeta.dart';

/// 마이그레이션 메타 식별 버전.
/// 같은 값이 신규 청사진/실행 문서에 박혀 멱등성 키로 사용된다.
const String kBlueprintMigrationVersion = 'v1.0.0';

/// 마이그레이션 단일 단계 결과.
class MigrationResult {
  final int migrated;
  final int skipped;
  final int errors;
  final List<String> errorMessages;
  final Map<String, int> extras;

  const MigrationResult({
    required this.migrated,
    required this.skipped,
    required this.errors,
    required this.errorMessages,
    this.extras = const {},
  });

  String get summary {
    final parts = <String>[
      'migrated=$migrated',
      'skipped=$skipped',
      'errors=$errors',
    ];
    extras.forEach((k, v) => parts.add('$k=$v'));
    return parts.join(', ');
  }
}

/// 컬렉션별 문서 수 진단.
class CollectionCounts {
  final int patternCharts;
  final int aiSectionsAggregate;
  final int projects;
  final int projectStepsAggregate;
  final int userTemplates;
  final int builtinTemplates;

  final int stepBlueprints;
  final int stepBlueprintUnitsAggregate;
  final int stepRuns;
  final int stepRunProgressAggregate;

  const CollectionCounts({
    required this.patternCharts,
    required this.aiSectionsAggregate,
    required this.projects,
    required this.projectStepsAggregate,
    required this.userTemplates,
    required this.builtinTemplates,
    required this.stepBlueprints,
    required this.stepBlueprintUnitsAggregate,
    required this.stepRuns,
    required this.stepRunProgressAggregate,
  });

  String get summary =>
      'patternCharts=$patternCharts (aiSections총합=$aiSectionsAggregate) · '
      'projects=$projects (steps총합=$projectStepsAggregate) · '
      'userTemplates=$userTemplates · '
      'builtinTemplates=$builtinTemplates · '
      'stepBlueprints=$stepBlueprints (units총합=$stepBlueprintUnitsAggregate) · '
      'stepRuns=$stepRuns (progress총합=$stepRunProgressAggregate)';
}

/// 마이그레이션 헬퍼. uid 단위로 사용.
class BlueprintMigration {
  BlueprintMigration({required this.uid, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  // ── 컬렉션 ref ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _userPatternCharts =>
      _db.collection('users').doc(uid).collection('pattern_charts');

  CollectionReference<Map<String, dynamic>> get _userProjects =>
      _db.collection('users').doc(uid).collection('projects');

  CollectionReference<Map<String, dynamic>> get _userTemplates =>
      _db.collection('users').doc(uid).collection('templates');

  CollectionReference<Map<String, dynamic>> get _builtinTemplates =>
      _db.collection('builtin_templates');

  CollectionReference<Map<String, dynamic>> get _stepBlueprints =>
      _db.collection('step_blueprints');

  CollectionReference<Map<String, dynamic>> _stepBlueprintUnits(String bid) =>
      _stepBlueprints.doc(bid).collection('units');

  CollectionReference<Map<String, dynamic>> get _userStepRuns =>
      _db.collection('users').doc(uid).collection('step_runs');

  CollectionReference<Map<String, dynamic>> _runProgress(String rid) =>
      _userStepRuns.doc(rid).collection('progress');

  // ── 통합 실행 ─────────────────────────────────────────────────────────────

  /// 순서: patterns → templates → project_steps (의존성: project_steps는 patterns 청사진 참조 가능).
  Future<Map<String, MigrationResult>> migrateAll({
    bool dryRun = false,
  }) async {
    final patterns = await migratePatterns(dryRun: dryRun);
    final userTemplates = await migrateUserTemplates(dryRun: dryRun);
    final builtinTemplates = await migrateBuiltinTemplates(dryRun: dryRun);
    final projectSteps = await migrateProjectSteps(dryRun: dryRun);
    return {
      'patterns': patterns,
      'userTemplates': userTemplates,
      'builtinTemplates': builtinTemplates,
      'projectSteps': projectSteps,
    };
  }

  // ── 1) 도안 → 청사진 ──────────────────────────────────────────────────────

  /// users/{uid}/pattern_charts → step_blueprints + units.
  /// blueprintId == 원본 PatternChart.id (역참조 단순화 + 멱등 키).
  Future<MigrationResult> migratePatterns({bool dryRun = false}) async {
    final snap = await _userPatternCharts.get();
    int migrated = 0, skipped = 0, errors = 0;
    final errorMessages = <String>[];

    for (final doc in snap.docs) {
      try {
        // 원본 PatternChart 파싱. 실패 시 raw map 으로 fallback.
        pat.PatternChart? chart;
        final raw = <String, dynamic>{...doc.data(), 'id': doc.id};
        try {
          chart = pat.PatternChart.fromJson(raw);
        } catch (_) {
          chart = null;
        }

        final blueprintId = doc.id;

        // 멱등성 검사: 이미 마이그레이션된 청사진은 skip.
        final existing = await _stepBlueprints.doc(blueprintId).get();
        if (existing.exists &&
            existing.data()?['migrationVersion'] == kBlueprintMigrationVersion) {
          skipped++;
          continue;
        }

        final title = chart?.title ?? (raw['title'] as String? ?? 'Untitled');
        final aiSections = chart?.aiSections ?? const <ais.AiSection>[];
        final pdfUrl = chart?.pdfUrl ?? (raw['pdfUrl'] as String? ?? '');
        final imageUrl = chart?.imageUrl ?? (raw['imageUrl'] as String? ?? '');
        final sourceType = chart?.sourceType ?? pat.PatternSourceType.editor;
        final createdAt = chart?.createdAt ?? DateTime.now();

        // groups: aiSections 그대로 그룹으로 사상. 빈 도안은 빈 groups.
        final groups = <StepGroupMeta>[];
        final units = <StepBlueprintUnit>[];
        for (var gi = 0; gi < aiSections.length; gi++) {
          final section = aiSections[gi];
          groups.add(StepGroupMeta(
            id: section.id,
            title: section.title,
            titleKo: section.titleKo,
            order: gi,
            unitIds: section.steps.map((s) => s.id).toList(),
          ));
          for (var i = 0; i < section.steps.length; i++) {
            final step = section.steps[i];
            units.add(StepBlueprintUnit(
              id: step.id,
              blueprintId: blueprintId,
              order: gi * 1000 + i, // 그룹 분리 보존
              title: '',
              instruction: step.instruction,
              instructionKo: step.instructionKo,
              targetRows: 0,
              referenceImages: const [],
              chartRegion: null,
              isPreview: false,
              tags: const [],
              createdAt: createdAt,
            ));
          }
        }

        final blueprint = StepBlueprint(
          id: blueprintId,
          ownerUid: uid,
          title: title,
          kind: BlueprintKind.pattern,
          visibility: BlueprintVisibility.private,
          license: const BlueprintLicense(),
          provider: BlueprintProvider.user,
          sourcePatternChartId: blueprintId,
          chartAssetId: blueprintId,
          attachedPdfUrls: pdfUrl.isEmpty ? null : [pdfUrl],
          attachedImageUrls: imageUrl.isEmpty ? null : [imageUrl],
          version: '1.0.0',
          publishedVersions: const [],
          autoSyncOwnerRuns: true,
          members: const {},
          discoverability: BlueprintDiscoverability.hidden,
          isFeatured: false,
          isCurated: false,
          moriknitVerified: false,
          tags: <String>[
            'migrated:patterns',
            'sourceType:${sourceType.name}',
          ],
          groups: groups,
          createdAt: createdAt,
          updatedAt: DateTime.now(),
        );

        if (!dryRun) {
          await _stepBlueprints.doc(blueprintId).set({
            ...blueprint.toMap(),
            'migrationVersion': kBlueprintMigrationVersion,
            'migratedFromPatternChartId': blueprintId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));

          // units 일괄 저장 (Firestore batch 500 제한 대응).
          final batches = _chunked(units, 400);
          for (final chunk in batches) {
            final batch = _db.batch();
            for (final unit in chunk) {
              batch.set(_stepBlueprintUnits(blueprintId).doc(unit.id), {
                ...unit.toMap(),
                'migrationVersion': kBlueprintMigrationVersion,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: false));
            }
            await batch.commit();
          }
        }
        migrated++;
      } catch (e) {
        errors++;
        errorMessages.add('pattern ${doc.id}: $e');
      }
    }

    return MigrationResult(
      migrated: migrated,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  // ── 2) 프로젝트 단계 → step_runs + progress ───────────────────────────────

  /// users/{uid}/projects/{pid} + /steps
  ///   → users/{uid}/step_runs/{rid}/progress
  ///
  /// blueprintId 결정:
  ///   - project.sourcePatternId 가 있으면 그 청사진(즉 patterns 마이그레이션의 산물)을 참조.
  ///   - 없으면 프로젝트 단계로부터 즉석에서 manual 청사진을 1건 생성 (visibility=private, kind=pattern).
  ///
  /// rid는 project.id 와 동일 (1 프로젝트 = 1 run, 멱등 키).
  Future<MigrationResult> migrateProjectSteps({bool dryRun = false}) async {
    final projectsSnap = await _userProjects.get();
    int migrated = 0, skipped = 0, errors = 0;
    int syntheticBlueprints = 0;
    final errorMessages = <String>[];

    for (final pdoc in projectsSnap.docs) {
      try {
        final projectId = pdoc.id;
        final pdata = pdoc.data();
        final stepsSnap = await _userProjects
            .doc(projectId)
            .collection('steps')
            .orderBy('order')
            .get();

        // 멱등성 검사: 동일 rid 에 migrationVersion 이미 있으면 skip.
        final existingRun = await _userStepRuns.doc(projectId).get();
        if (existingRun.exists &&
            existingRun.data()?['migrationVersion'] ==
                kBlueprintMigrationVersion) {
          skipped++;
          continue;
        }

        String? blueprintId =
            (pdata['sourcePatternId'] as String?)?.trim().isNotEmpty == true
                ? (pdata['sourcePatternId'] as String).trim()
                : null;

        // 단계가 없으면 빈 progress 의 run만 만든다 (텍스트 우선 원칙).
        final stepsRaw = stepsSnap.docs;
        final hasSteps = stepsRaw.isNotEmpty;

        // 청사진 부재 시 — synthetic blueprint 생성.
        if (blueprintId == null) {
          final syntheticId = 'project_$projectId';
          final exists = await _stepBlueprints.doc(syntheticId).get();
          final alreadySeed = exists.exists &&
              exists.data()?['migrationVersion'] ==
                  kBlueprintMigrationVersion;
          if (!alreadySeed) {
            final groups = <StepGroupMeta>[];
            final units = <StepBlueprintUnit>[];

            if (hasSteps) {
              // 단일 그룹(=프로젝트 자체)으로 묶음.
              final unitIds = <String>[];
              for (var i = 0; i < stepsRaw.length; i++) {
                final sdoc = stepsRaw[i];
                final step = ps.ProjectStep.fromMap(sdoc.data(), sdoc.id);
                unitIds.add(step.id);
                units.add(StepBlueprintUnit(
                  id: step.id,
                  blueprintId: syntheticId,
                  order: i,
                  title: step.name,
                  instruction: step.description,
                  targetRows: step.targetRow,
                  referenceImages: const [],
                  chartRegion: null,
                  isPreview: false,
                  tags: const [],
                  createdAt: step.createdAt,
                ));
              }
              groups.add(StepGroupMeta(
                id: 'main',
                title: (pdata['title'] as String?) ?? '프로젝트 단계',
                titleKo: (pdata['title'] as String?) ?? '프로젝트 단계',
                order: 0,
                unitIds: unitIds,
              ));
            }

            final synthetic = StepBlueprint(
              id: syntheticId,
              ownerUid: uid,
              title: (pdata['title'] as String?) ?? '프로젝트 청사진',
              kind: BlueprintKind.pattern,
              visibility: BlueprintVisibility.private,
              license: const BlueprintLicense(),
              provider: BlueprintProvider.user,
              version: '1.0.0',
              publishedVersions: const [],
              autoSyncOwnerRuns: true,
              members: const {},
              discoverability: BlueprintDiscoverability.hidden,
              isFeatured: false,
              isCurated: false,
              moriknitVerified: false,
              tags: const ['migrated:projectSteps', 'synthetic'],
              groups: groups,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            if (!dryRun) {
              await _stepBlueprints.doc(syntheticId).set({
                ...synthetic.toMap(),
                'migrationVersion': kBlueprintMigrationVersion,
                'migratedFromProjectId': projectId,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: false));

              final batches = _chunked(units, 400);
              for (final chunk in batches) {
                final batch = _db.batch();
                for (final unit in chunk) {
                  batch.set(_stepBlueprintUnits(syntheticId).doc(unit.id), {
                    ...unit.toMap(),
                    'migrationVersion': kBlueprintMigrationVersion,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: false));
                }
                await batch.commit();
              }
            }
            syntheticBlueprints++;
          }
          blueprintId = syntheticId;
        }

        // run + progress 생성.
        final completed =
            (pdata['completedStepCount'] as num?)?.toInt() ?? 0;
        final total = (pdata['totalStepCount'] as num?)?.toInt() ??
            stepsRaw.length;
        final pct = total > 0 ? completed / total : 0.0;

        final run = StepRun(
          id: projectId,
          userUid: uid,
          blueprintId: blueprintId,
          sourceBlueprintVersion: '1.0.0',
          projectId: projectId,
          role: StepRunRole.user,
          summary: RunSummary(
            totalUnits: total,
            completedCount: completed,
            percentComplete: pct,
            lastActivityAt: DateTime.now(),
          ),
          yarnIds: (pdata['yarnIds'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
          needleIds: (pdata['needleIds'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
          swatchId: (pdata['swatchId'] as String?)?.trim().isEmpty ?? true
              ? null
              : pdata['swatchId'] as String,
          startedAt: DateTime.tryParse(pdata['createdAt'] as String? ?? '') ??
              DateTime.now(),
          completedAt: pdata['finishDate'] != null
              ? DateTime.tryParse(pdata['finishDate'] as String)
              : null,
          updatedAt: DateTime.now(),
        );

        if (!dryRun) {
          await _userStepRuns.doc(projectId).set({
            ...run.toMap(),
            'migrationVersion': kBlueprintMigrationVersion,
            'migratedFromProjectId': projectId,
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));

          // progress 일괄 저장.
          final chunks = _chunked(stepsRaw, 400);
          for (final chunk in chunks) {
            final batch = _db.batch();
            for (final sdoc in chunk) {
              final step = ps.ProjectStep.fromMap(sdoc.data(), sdoc.id);
              final progress = StepRunProgress(
                unitId: step.id,
                runId: projectId,
                isDone: step.isDone,
                doneAt: step.doneAt,
                currentRow: step.isDone ? step.targetRow : 0,
                targetRow: step.targetRow,
                totalSeconds: 0,
                progressImages: step.photoUrl != null &&
                        step.photoUrl!.isNotEmpty
                    ? [
                        ProgressImage(
                          url: step.photoUrl!,
                          takenAt: step.doneAt ?? step.createdAt,
                          order: 0,
                        )
                      ]
                    : const [],
                note: step.note.isEmpty ? null : step.note,
                counterId: null,
                updatedAt: DateTime.now(),
              );
              batch.set(_runProgress(projectId).doc(step.id), {
                ...progress.toMap(),
                'migrationVersion': kBlueprintMigrationVersion,
                'migratedFromProjectStepId': step.id,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: false));
            }
            await batch.commit();
          }
        }
        migrated++;
      } catch (e) {
        errors++;
        errorMessages.add('project ${pdoc.id}: $e');
      }
    }

    return MigrationResult(
      migrated: migrated,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
      extras: {'syntheticBlueprints': syntheticBlueprints},
    );
  }

  // ── 3) 사용자 템플릿 → step_blueprints (kind=template) ────────────────────

  Future<MigrationResult> migrateUserTemplates({bool dryRun = false}) async {
    final snap = await _userTemplates.get();
    int migrated = 0, skipped = 0, errors = 0;
    final errorMessages = <String>[];

    for (final doc in snap.docs) {
      try {
        final blueprintId = 'tmpl_user_${doc.id}';

        final existing = await _stepBlueprints.doc(blueprintId).get();
        if (existing.exists &&
            existing.data()?['migrationVersion'] ==
                kBlueprintMigrationVersion) {
          skipped++;
          continue;
        }

        final tmpl = ut.UserTemplate.fromMap(doc.data(), doc.id);

        final units = <StepBlueprintUnit>[];
        final unitIds = <String>[];
        for (var i = 0; i < tmpl.stepTitles.length; i++) {
          final unitId = '${blueprintId}_u$i';
          unitIds.add(unitId);
          final desc = i < tmpl.stepDescs.length ? tmpl.stepDescs[i] : '';
          units.add(StepBlueprintUnit(
            id: unitId,
            blueprintId: blueprintId,
            order: i,
            title: tmpl.stepTitles[i],
            instruction: desc,
            targetRows: 0,
            referenceImages: const [],
            chartRegion: null,
            isPreview: false,
            tags: const [],
            createdAt: tmpl.createdAt,
          ));
        }

        final groups = <StepGroupMeta>[
          StepGroupMeta(
            id: 'main',
            title: tmpl.title,
            order: 0,
            unitIds: unitIds,
          ),
        ];

        final blueprint = StepBlueprint(
          id: blueprintId,
          ownerUid: uid,
          title: tmpl.title,
          kind: BlueprintKind.template,
          visibility: BlueprintVisibility.private,
          license: const BlueprintLicense(),
          provider: BlueprintProvider.user,
          attachedImageUrls:
              tmpl.photoUrl.isEmpty ? null : [tmpl.photoUrl],
          version: '1.0.0',
          publishedVersions: const [],
          autoSyncOwnerRuns: false,
          members: const {},
          discoverability: BlueprintDiscoverability.hidden,
          isFeatured: false,
          isCurated: false,
          moriknitVerified: false,
          tags: const ['migrated:userTemplates'],
          groups: groups,
          createdAt: tmpl.createdAt,
          updatedAt: DateTime.now(),
        );

        if (!dryRun) {
          await _stepBlueprints.doc(blueprintId).set({
            ...blueprint.toMap(),
            'migrationVersion': kBlueprintMigrationVersion,
            'migratedFromUserTemplateId': doc.id,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));

          final chunks = _chunked(units, 400);
          for (final chunk in chunks) {
            final batch = _db.batch();
            for (final unit in chunk) {
              batch.set(_stepBlueprintUnits(blueprintId).doc(unit.id), {
                ...unit.toMap(),
                'migrationVersion': kBlueprintMigrationVersion,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: false));
            }
            await batch.commit();
          }
        }
        migrated++;
      } catch (e) {
        errors++;
        errorMessages.add('userTemplate ${doc.id}: $e');
      }
    }

    return MigrationResult(
      migrated: migrated,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  // ── 4) builtin_templates → step_blueprints (kind=template, official) ─────

  Future<MigrationResult> migrateBuiltinTemplates({bool dryRun = false}) async {
    final snap = await _builtinTemplates.get();
    int migrated = 0, skipped = 0, errors = 0;
    final errorMessages = <String>[];

    for (final doc in snap.docs) {
      try {
        final blueprintId = 'tmpl_builtin_${doc.id}';

        final existing = await _stepBlueprints.doc(blueprintId).get();
        if (existing.exists &&
            existing.data()?['migrationVersion'] ==
                kBlueprintMigrationVersion) {
          skipped++;
          continue;
        }

        final tmpl = bt.BuiltinTemplate.fromFirestore(doc);

        final useKo = tmpl.stepsKo.isNotEmpty;
        final titles = useKo ? tmpl.stepsKo : tmpl.stepsEn;
        final notesKo = tmpl.stepNotesKo;
        final notesEn = tmpl.stepNotesEn;
        final targets = tmpl.stepTargetRows;

        final units = <StepBlueprintUnit>[];
        final unitIds = <String>[];
        for (var i = 0; i < titles.length; i++) {
          final unitId = '${blueprintId}_u$i';
          unitIds.add(unitId);
          final ko = i < notesKo.length ? notesKo[i] : '';
          final en = i < notesEn.length ? notesEn[i] : '';
          final target = i < targets.length ? targets[i] : 0;
          units.add(StepBlueprintUnit(
            id: unitId,
            blueprintId: blueprintId,
            order: i,
            title: titles[i],
            titleKo: i < tmpl.stepsKo.length ? tmpl.stepsKo[i] : null,
            titleEn: i < tmpl.stepsEn.length ? tmpl.stepsEn[i] : null,
            instruction: ko.isNotEmpty ? ko : en,
            instructionKo: ko.isEmpty ? null : ko,
            instructionEn: en.isEmpty ? null : en,
            targetRows: target,
            referenceImages: const [],
            chartRegion: null,
            isPreview: false,
            tags: const [],
            createdAt: DateTime.now(),
          ));
        }

        final groups = <StepGroupMeta>[
          StepGroupMeta(
            id: 'main',
            title: tmpl.titleKo.isNotEmpty ? tmpl.titleKo : tmpl.titleEn,
            titleKo: tmpl.titleKo,
            titleEn: tmpl.titleEn,
            order: 0,
            unitIds: unitIds,
          ),
        ];

        final blueprint = StepBlueprint(
          id: blueprintId,
          ownerUid: uid, // 마이그레이션 실행 어드민 (현재 모리니트 공식 계정).
          title: tmpl.titleKo.isNotEmpty ? tmpl.titleKo : tmpl.titleEn,
          titleKo: tmpl.titleKo,
          titleEn: tmpl.titleEn,
          kind: BlueprintKind.template,
          visibility: BlueprintVisibility.public,
          license: const BlueprintLicense(
            type: LicenseType.moriknit_official,
          ),
          provider: BlueprintProvider.official,
          version: '1.0.0',
          publishedVersions: const [],
          autoSyncOwnerRuns: false,
          members: const {},
          discoverability: BlueprintDiscoverability.curated_only,
          isFeatured: false,
          isCurated: true,
          moriknitVerified: true,
          tags: <String>[
            'migrated:builtinTemplates',
            'kind:${tmpl.kind.value}',
          ],
          groups: groups,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (!dryRun) {
          await _stepBlueprints.doc(blueprintId).set({
            ...blueprint.toMap(),
            'migrationVersion': kBlueprintMigrationVersion,
            'migratedFromBuiltinTemplateId': doc.id,
            'builtinKind': tmpl.kind.value,
            if (tmpl.measurementData != null)
              'measurementData': tmpl.measurementData,
            'iconName': tmpl.iconName,
            'colorHex': tmpl.colorHex,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));

          final chunks = _chunked(units, 400);
          for (final chunk in chunks) {
            final batch = _db.batch();
            for (final unit in chunk) {
              batch.set(_stepBlueprintUnits(blueprintId).doc(unit.id), {
                ...unit.toMap(),
                'migrationVersion': kBlueprintMigrationVersion,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: false));
            }
            await batch.commit();
          }
        }
        migrated++;
      } catch (e) {
        errors++;
        errorMessages.add('builtinTemplate ${doc.id}: $e');
      }
    }

    return MigrationResult(
      migrated: migrated,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  // ── 진단 도구 ─────────────────────────────────────────────────────────────

  /// 컬렉션별 문서 수 보고. 마이그레이션 전후 검증용.
  /// 주의: aiSections/steps 총합은 client-side 읽기로 집계되므로 비용 발생.
  Future<CollectionCounts> countByCollection() async {
    final patternSnap = await _userPatternCharts.get();
    var aiSectionsAgg = 0;
    for (final doc in patternSnap.docs) {
      final list = doc.data()['aiSections'] as List?;
      if (list != null) {
        for (final s in list) {
          final steps = (s as Map?)?['steps'] as List?;
          if (steps != null) aiSectionsAgg += steps.length;
        }
      }
    }

    final projectsSnap = await _userProjects.get();
    var projectStepsAgg = 0;
    for (final p in projectsSnap.docs) {
      final stepsSnap =
          await _userProjects.doc(p.id).collection('steps').get();
      projectStepsAgg += stepsSnap.docs.length;
    }

    final userTmplSnap = await _userTemplates.get();
    final builtinSnap = await _builtinTemplates.get();

    // 신규 컬렉션 — owner 단위 + 글로벌 전체 (builtin 포함).
    final blueprintsSnap = await _stepBlueprints
        .where('ownerUid', isEqualTo: uid)
        .get();
    var unitsAgg = 0;
    for (final bp in blueprintsSnap.docs) {
      final unitSnap =
          await _stepBlueprintUnits(bp.id).get();
      unitsAgg += unitSnap.docs.length;
    }

    final runsSnap = await _userStepRuns.get();
    var progressAgg = 0;
    for (final r in runsSnap.docs) {
      final pSnap = await _runProgress(r.id).get();
      progressAgg += pSnap.docs.length;
    }

    return CollectionCounts(
      patternCharts: patternSnap.docs.length,
      aiSectionsAggregate: aiSectionsAgg,
      projects: projectsSnap.docs.length,
      projectStepsAggregate: projectStepsAgg,
      userTemplates: userTmplSnap.docs.length,
      builtinTemplates: builtinSnap.docs.length,
      stepBlueprints: blueprintsSnap.docs.length,
      stepBlueprintUnitsAggregate: unitsAgg,
      stepRuns: runsSnap.docs.length,
      stepRunProgressAggregate: progressAgg,
    );
  }

  // ── 내부 유틸 ─────────────────────────────────────────────────────────────

  Iterable<List<T>> _chunked<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
