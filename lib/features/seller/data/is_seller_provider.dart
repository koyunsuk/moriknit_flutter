// 이슈 #816 Phase 2 — 셀러 판정 provider
//
// 정책 (Phase 2):
//   - Pro / Business 등급이면 셀러로 간주 (도안 발행 카운트는 비싸므로 Phase 3)
//   - 비로그인/익명 사용자는 항상 false
//
// 본인이 발행한 도안(complete) 개수는 별도 provider로 분리하여 필요한 화면에서만 조회.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';

/// 현재 사용자가 셀러인지 여부.
/// Phase 2: Pro/Business 등급만으로 판정 (도안 발행 체크는 Phase 3에서 강화).
final isSellerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  final gates = ref.watch(featureGatesProvider);
  return gates.isPro || gates.isBusiness;
});

/// 본인이 발행한 도안(complete 상태) 개수.
/// 조건: ownerUid == currentUid && status == 'complete'
/// — Phase 3에서 isSellerProvider 강화 시 활용.
final myPublishedPatternsCountProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return 0;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('step_blueprints')
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'complete')
        .count()
        .get();
    return snap.count ?? 0;
  } catch (_) {
    return 0;
  }
});
