// lib/features/pattern/data/pattern_session_repository.dart
//
// 도안 뷰어 세션 Firestore 동기화 Repository.
// 경로: users/{uid}/pattern_sessions/{sessionId}
// 세션은 patternChartId 당 1개만 존재 (patternChartId == sessionId 로 사용).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // ── UPDATE: STROKES ────────────────────────────────────────
  Future<void> updateStrokes(String sessionId, List<StrokeData> strokes) async {
    if (_uid.isEmpty) return;
    await _sessionsRef.doc(sessionId).set({
      'strokes': strokes.map((e) => e.toJson()).toList(),
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

// ── Riverpod Providers ───────────────────────────────────────
final patternSessionRepositoryProvider =
    Provider<PatternSessionRepository>((ref) => PatternSessionRepository());

/// 특정 도안(chartId)의 세션을 스트림으로 구독.
final patternSessionProvider =
    StreamProvider.family<PatternSession?, String>((ref, chartId) {
  final repo = ref.watch(patternSessionRepositoryProvider);
  return repo.watch(chartId);
});
