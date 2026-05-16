// lib/features/project/data/project_repository.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../domain/project_model.dart';
import '../../../core/constants/subscription_constants.dart';
import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../core/utils/firestore_json.dart';

class ProjectRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _projectsRef =>
      _db.collection('users').doc(_uid).collection('projects');

  DocumentReference get _userRef =>
      _db.collection('users').doc(_uid);

  // ── CREATE ───────────────────────────────────────────────
  Future<ProjectModel> createProject(ProjectModel project) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final prepared = project.copyWith(updatedAt: DateTime.now());
    await _saveToHive(prepared);

    try {
      final docRef = project.id.isEmpty
          ? _projectsRef.doc()
          : _projectsRef.doc(project.id);

      await _db.runTransaction((tx) async {
        tx.set(docRef, {
          ...prepared.toJson(),
          'id': docRef.id,
          'uid': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isDirty': false,
        });
        tx.update(_userRef, {
          'usage.projectCount': FieldValue.increment(1),
        });
      }).withServerTimeout(op: 'create_project_tx');

      final saved = prepared.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved);
      return saved;
    } catch (e) {
      final dirty = prepared.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── FORK (타인의 공개 프로젝트 복사) ─────────────────────
  Future<ProjectModel> forkProject({
    required String originProjectId,
    required String originUserId,
    required String originOwnerName,
    required String title,
    required String yarnName,
    required String yarnBrandName,
    required String yarnWeight,
    required double needleSize,
    String sourcePatternId = '',
  }) async {
    final now = DateTime.now();
    final forked = ProjectModel(
      id: '',
      uid: _uid,
      title: title,
      yarnName: yarnName,
      yarnBrandName: yarnBrandName,
      yarnWeight: yarnWeight,
      needleSize: needleSize,
      originProjectId: originProjectId,
      originUserId: originUserId,
      originOwnerName: originOwnerName,
      sourcePatternId: sourcePatternId,
      createdAt: now,
      updatedAt: now,
    );
    return createProject(forked);
  }

  // ── DUPLICATE ────────────────────────────────────────────
  Future<ProjectModel> duplicateProject(ProjectModel original) async {
    final now = DateTime.now();
    final copy = original.copyWith(
      id: '',
      title: '${original.title} (복사)',
      createdAt: now,
      updatedAt: now,
      isDirty: false,
      counterIds: [],
    );
    return createProject(copy);
  }

  // ── READ (목록) ──────────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  // Hive 캐시를 즉시 emit → Firestore stream을 받아 정상 데이터로 갱신.
  // Firestore stream 에러(오프라인/타임아웃) 시 Hive 캐시 유지.
  Stream<List<ProjectModel>> watchProjects() {
    if (_uid.isEmpty) return Stream.value([]);

    final controller = StreamController<List<ProjectModel>>();

    // 1) Hive 캐시 즉시 emit
    final cached = _readListFromHive();
    if (cached.isNotEmpty) {
      controller.add(cached);
    }

    // 2) Firestore stream 구독 → 성공 시 Hive write-through
    final sub = _projectsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        final list = snap.docs.map((doc) => ProjectModel.fromFirestore(doc)).toList();
        controller.add(list);
        // write-through: Firestore 응답을 Hive에 미러
        unawaited(_writeListToHive(list));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchProjects] firestore error → hive fallback: $e');
        // 폴백: 캐시 재emit (이미 emit했으면 동일 값이라도 보장)
        final fallback = _readListFromHive();
        controller.add(fallback);
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ── READ (단건) ──────────────────────────────────────────
  // 이슈 #704 Phase A — Hive 폴백.
  Stream<ProjectModel?> watchProject(String id) {
    if (_uid.isEmpty) return Stream.value(null);

    final controller = StreamController<ProjectModel?>();

    // 1) Hive 캐시 즉시 emit
    final cached = _readFromHive(id);
    if (cached != null) {
      controller.add(cached);
    }

    // 2) Firestore stream
    final sub = _projectsRef.doc(id).snapshots().listen(
      (doc) {
        if (!doc.exists) {
          controller.add(null);
          return;
        }
        final model = ProjectModel.fromFirestore(doc);
        controller.add(model);
        unawaited(_saveToHive(model));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[watchProject] firestore error → hive fallback: $e');
        final fallback = _readFromHive(id);
        controller.add(fallback);
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<ProjectModel?> getProject(String id) async {
    try {
      final doc = await _projectsRef.doc(id).get().withServerTimeout(op: 'get_project');
      if (!doc.exists) return null;
      final model = ProjectModel.fromFirestore(doc);
      unawaited(_saveToHive(model));
      return model;
    } catch (e) {
      // 이슈 #704 Phase A — Firestore 실패 시 Hive 폴백
      debugPrint('[getProject] firestore error → hive fallback: $e');
      return _readFromHive(id);
    }
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<ProjectModel> updateProject(ProjectModel project) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = project.copyWith(updatedAt: DateTime.now());
    await _saveToHive(updated);

    try {
      await _projectsRef.doc(project.id).update({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
      }).withServerTimeout(op: 'update_project');
      return updated.copyWith(isDirty: false);
    } catch (e) {
      final dirty = updated.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
  }

  // ── UPDATE STATUS / PROGRESS ──────────────────────────────
  Future<void> updateProgress(String id, double percent) async {
    await _projectsRef.doc(id).update({
      'progressPercent': percent,
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'update_progress');
  }

  Future<void> updateStatus(String id, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == ProjectStatus.finished.value) {
      updates['finishDate'] = FieldValue.serverTimestamp();
    }
    await _projectsRef.doc(id).update(updates).withServerTimeout(op: 'update_status');
  }

  // ── #627 LINK PATTERN ────────────────────────────────────
  // 프로젝트에 도안 연결. sourcePatternId만 업데이트(저수준).
  // 단계 자동 미러링은 호출부에서 ProjectStepRepository.addPatternSectionStepsWithCounters
  // 를 별도 호출하거나, 본 메서드 대신 화면 측에서 한 번에 처리한다.
  Future<void> linkPattern({
    required String projectId,
    required String patternId,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _projectsRef.doc(projectId).update({
      'sourcePatternId': patternId,
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'link_pattern');
  }

  // 도안 연결 해제. sourcePatternId 만 비움 (단계는 유지 — 사용자 보호).
  Future<void> unlinkPattern(String projectId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _projectsRef.doc(projectId).update({
      'sourcePatternId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'unlink_pattern');
  }

  // ── LINK COUNTER ─────────────────────────────────────────
  Future<void> addCounter(String projectId, String counterId) async {
    await _projectsRef.doc(projectId).update({
      'counterIds': FieldValue.arrayUnion([counterId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'add_counter');
  }

  Future<void> removeCounter(String projectId, String counterId) async {
    await _projectsRef.doc(projectId).update({
      'counterIds': FieldValue.arrayRemove([counterId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'remove_counter');
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteProject(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    await _removeFromHive(id);
    await _db.runTransaction((tx) async {
      tx.delete(_projectsRef.doc(id));
      tx.update(_userRef, {
        'usage.projectCount': FieldValue.increment(-1),
      });
    }).withServerTimeout(op: 'delete_project_tx');
  }

  // ── Hive ─────────────────────────────────────────────────
  Future<void> _saveToHive(ProjectModel project) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
      final key = project.id.isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : project.id;
      await box.put(key, project.toJson());
    } catch (_) {
      // Hive 캐시 실패는 무시 — Firestore가 primary
    }
  }

  Future<void> _removeFromHive(String id) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
      await box.delete(id);
    } catch (_) {}
  }

  // 이슈 #704 Phase A — Hive 읽기 헬퍼.
  // 현재 uid의 프로젝트만 필터하여 createdAt 내림차순 정렬.
  List<ProjectModel> _readListFromHive() {
    if (kIsWeb) return const [];
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
      final uid = _uid;
      final items = <ProjectModel>[];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data == null) continue;
        try {
          final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
          final model = ProjectModel.fromJson(json);
          if (uid.isEmpty || model.uid.isEmpty || model.uid == uid) {
            items.add(model);
          }
        } catch (_) {}
      }
      items.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return items;
    } catch (_) {
      return const [];
    }
  }

  ProjectModel? _readFromHive(String id) {
    if (kIsWeb || id.isEmpty) return null;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
      final data = box.get(id);
      if (data == null) return null;
      final json = normalizeFirestoreMap(Map<String, dynamic>.from(data));
      return ProjectModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeListToHive(List<ProjectModel> projects) async {
    if (kIsWeb) return;
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
      for (final p in projects) {
        if (p.id.isEmpty) continue;
        await box.put(p.id, p.toJson());
      }
    } catch (_) {}
  }

  Future<void> syncDirtyProjects() async {
    if (kIsWeb || _uid.isEmpty) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data['isDirty'] == true) {
        try {
          final project = ProjectModel.fromJson(Map<String, dynamic>.from(data));
          await updateProject(project);
        } catch (_) {}
      }
    }
  }
}
