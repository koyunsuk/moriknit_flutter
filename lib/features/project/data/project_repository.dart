// lib/features/project/data/project_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import '../domain/project_model.dart';
import '../../../core/constants/subscription_constants.dart';

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
      });

      final saved = prepared.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved);
      return saved;
    } catch (e) {
      final dirty = prepared.copyWith(isDirty: true);
      await _saveToHive(dirty);
      return dirty;
    }
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
  Stream<List<ProjectModel>> watchProjects() {
    if (_uid.isEmpty) return Stream.value([]);
    return _projectsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProjectModel.fromFirestore(doc))
            .toList());
  }

  // ── READ (단건) ──────────────────────────────────────────
  Stream<ProjectModel?> watchProject(String id) {
    if (_uid.isEmpty) return Stream.value(null);
    return _projectsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProjectModel.fromFirestore(doc);
    });
  }

  Future<ProjectModel?> getProject(String id) async {
    final doc = await _projectsRef.doc(id).get();
    if (!doc.exists) return null;
    return ProjectModel.fromFirestore(doc);
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
      });
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
    });
  }

  Future<void> updateStatus(String id, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == ProjectStatus.finished.value) {
      updates['finishDate'] = FieldValue.serverTimestamp();
    }
    await _projectsRef.doc(id).update(updates);
  }

  // ── LINK COUNTER ─────────────────────────────────────────
  Future<void> addCounter(String projectId, String counterId) async {
    await _projectsRef.doc(projectId).update({
      'counterIds': FieldValue.arrayUnion([counterId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeCounter(String projectId, String counterId) async {
    await _projectsRef.doc(projectId).update({
      'counterIds': FieldValue.arrayRemove([counterId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    });
  }

  // ── Hive ─────────────────────────────────────────────────
  Future<void> _saveToHive(ProjectModel project) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
    final key = project.id.isEmpty
        ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
        : project.id;
    await box.put(key, project.toJson());
  }

  Future<void> _removeFromHive(String id) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxProjects);
    await box.delete(id);
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
