// lib/features/tester_feedback/data/tester_feedback_repository.dart
//
// 이슈 #794 — 도안별 테스터 피드백 저장/구독.
//
// 컬렉션 경로:
//   step_blueprints/{bid}/tester_feedback/{feedbackId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tester_feedback.dart';

class TesterFeedbackRepository {
  TesterFeedbackRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _col(String blueprintId) =>
      _db.collection('step_blueprints').doc(blueprintId).collection('tester_feedback');

  /// 피드백 작성 (테스터 또는 본인 도안에 셀프 메모).
  Future<String> create({
    required String blueprintId,
    required String authorName,
    required TesterFeedbackCategory category,
    required String content,
    String? unitId,
    int? unitOrder,
  }) async {
    final now = DateTime.now();
    final ref = _col(blueprintId).doc();
    final fb = TesterFeedback(
      id: ref.id,
      blueprintId: blueprintId,
      authorUid: _uid,
      authorName: authorName,
      category: category,
      content: content,
      unitId: unitId,
      unitOrder: unitOrder,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(fb.toMap());
    return ref.id;
  }

  /// 해결 상태 토글.
  Future<void> setResolved(String blueprintId, String id, bool resolved) async {
    await _col(blueprintId).doc(id).update({
      'resolved': resolved,
      'updatedAt': Timestamp.now(),
    });
  }

  /// 작성자 응답 추가.
  Future<void> addReply({
    required String blueprintId,
    required String feedbackId,
    required String authorName,
    required String content,
  }) async {
    final reply = TesterFeedbackReply(
      authorUid: _uid,
      authorName: authorName,
      content: content,
      createdAt: DateTime.now(),
    );
    await _col(blueprintId).doc(feedbackId).update({
      'replies': FieldValue.arrayUnion([reply.toMap()]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// 피드백 삭제 (작성자만).
  Future<void> delete(String blueprintId, String id) async {
    await _col(blueprintId).doc(id).delete();
  }

  /// 한 도안의 피드백 스트림 (최신순).
  Stream<List<TesterFeedback>> watchByBlueprint(String blueprintId) {
    return _col(blueprintId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TesterFeedback.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// 미해결 피드백 카운트 (배지용).
  Stream<int> watchUnresolvedCount(String blueprintId) {
    return _col(blueprintId)
        .where('resolved', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }
}

final testerFeedbackRepositoryProvider = Provider<TesterFeedbackRepository>(
  (_) => TesterFeedbackRepository(),
);

final testerFeedbackByBlueprintProvider =
    StreamProvider.family<List<TesterFeedback>, String>((ref, blueprintId) {
  return ref.watch(testerFeedbackRepositoryProvider).watchByBlueprint(blueprintId);
});

final testerFeedbackUnresolvedCountProvider =
    StreamProvider.family<int, String>((ref, blueprintId) {
  return ref.watch(testerFeedbackRepositoryProvider).watchUnresolvedCount(blueprintId);
});
