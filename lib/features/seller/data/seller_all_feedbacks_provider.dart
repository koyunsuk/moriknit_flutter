// 이슈 #816 Phase 2 — 셀러 탭에서 사용할 통합 피드백 provider
//
// 본인이 작성한 도안 전반에 달린 테스터 피드백을 한 곳에 모아 보기 위한 stream.
//
// 의존:
//   - Firestore에 blueprintOwnerUid 필드가 tester_feedback 문서에 저장되어 있어야 함.
//     (없으면 빈 list 반환 — Phase 2 마이그레이션 작업이 별도 진행됨.)
//   - collectionGroup 'tester_feedback' 인덱스 + 보안 규칙 필요.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../tester_feedback/domain/tester_feedback.dart';

/// 본인 도안에 달린 모든 테스터 피드백 (최신 50건).
/// blueprintOwnerUid 필드 미존재 / 인덱스 미생성 시 빈 list 로 폴백.
final sellerAllFeedbacksProvider =
    StreamProvider<List<TesterFeedback>>((ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream<List<TesterFeedback>>.value(const []);

  try {
    return FirebaseFirestore.instance
        .collectionGroup('tester_feedback')
        .where('blueprintOwnerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TesterFeedback.fromMap({...d.data(), 'id': d.id}))
            .toList())
        .handleError((_) => <TesterFeedback>[]);
  } catch (_) {
    return Stream<List<TesterFeedback>>.value(const []);
  }
});
