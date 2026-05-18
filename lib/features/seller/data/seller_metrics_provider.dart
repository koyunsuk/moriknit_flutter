// 이슈 #816 Phase 2 — 셀러 요약 카드용 메트릭 provider
//
// 미응답 테스터 피드백 / 신규 주문 / 진행 중 함께뜨기 카운트 집계.
//
// 주의:
//   - collectionGroup('tester_feedback') 조회는 Firestore 인덱스 + blueprintOwnerUid
//     필드가 저장되어 있어야 작동. 미충족 시 catch 로 0 fallback.
//   - market_purchases 컬렉션 / sellerUid 필드 미존재 시 동일하게 0 fallback.
//   - knit_along 집계는 Phase 2.5에서 schema 확정 후 활성화.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';

/// 셀러 요약 메트릭 — 마이페이지 SellerSummaryCard / 셀러 앱 대시보드 공통 사용.
class SellerMetrics {
  final int pendingFeedbacks;  // 미응답 테스터 피드백
  final int newOrders;          // 신규 주문 (market_purchases.status == 'new')
  final int activeKnitAlongs;   // 진행 중 함께뜨기 그룹

  const SellerMetrics({
    this.pendingFeedbacks = 0,
    this.newOrders = 0,
    this.activeKnitAlongs = 0,
  });

  static const empty = SellerMetrics();

  int get total => pendingFeedbacks + newOrders + activeKnitAlongs;
}

final sellerMetricsProvider = FutureProvider<SellerMetrics>((ref) async {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return SellerMetrics.empty;

  try {
    // 1) 본인 도안 list 조회 — 이후 메트릭 짧은 회로 차단용
    final patternsSnap = await FirebaseFirestore.instance
        .collection('step_blueprints')
        .where('ownerUid', isEqualTo: uid)
        .get();
    final patternIds = patternsSnap.docs.map((d) => d.id).toList();
    if (patternIds.isEmpty) return SellerMetrics.empty;

    // 2) 미응답 테스터 피드백 — collectionGroup 'tester_feedback'
    //    blueprintOwnerUid 필드는 Phase 2 마이그레이션 대상. 미존재 시 0.
    int pendingFeedbacks = 0;
    try {
      final fbSnap = await FirebaseFirestore.instance
          .collectionGroup('tester_feedback')
          .where('blueprintOwnerUid', isEqualTo: uid)
          .where('resolved', isEqualTo: false)
          .count()
          .get();
      pendingFeedbacks = fbSnap.count ?? 0;
    } catch (_) {
      pendingFeedbacks = 0;
    }

    // 3) 신규 주문 — market_purchases where sellerUid == uid && status == 'new'
    int newOrders = 0;
    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('market_purchases')
          .where('sellerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'new')
          .count()
          .get();
      newOrders = orderSnap.count ?? 0;
    } catch (_) {
      newOrders = 0;
    }

    // 4) 진행 중 함께뜨기 — Phase 2.5 (schema 확정 후)
    const int activeKnitAlongs = 0;

    return SellerMetrics(
      pendingFeedbacks: pendingFeedbacks,
      newOrders: newOrders,
      activeKnitAlongs: activeKnitAlongs,
    );
  } catch (_) {
    return SellerMetrics.empty;
  }
});
