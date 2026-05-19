import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/subscription_constants.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Firebase 인증 상태 스트림입니다.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// users/{uid} 문서를 실시간으로 구독합니다.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).userStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// 익명(게스트) 로그인 여부 — Splash 자동 로그인 / Pro 차단 / 가입 권유 트리거에 사용
final isAnonymousUserProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.isAnonymous ?? false;
});

/// 슈퍼 어드민 이메일 — firestore.rules 의 isAdmin() 함수와 동일.
/// admins/{uid} 컬렉션 등록 여부와 무관하게 항상 어드민 권한 부여.
/// (#840) admins 컬렉션 부트스트랩 누락 / 신규 디바이스 동기화 지연으로 인한
/// "권한 없음" 오판정을 방지하기 위한 fallback.
const String _superAdminEmail = 'koyunsuk@gmail.com';

/// admins/{uid} Firestore 컬렉션 기반으로 isAdmin을 실시간 확인합니다.
/// 회원 관리 모달의 "관리자" 토글은 admins/{uid} 문서를 set/delete하므로
/// Custom Claims 대신 컬렉션 존재 여부로 판정하면 즉시 반영됩니다.
/// (Cloud Function으로 Custom Claims sync는 별도 작업 — 향후 #813 워커에 통합 가능)
///
/// (#840) 슈퍼 어드민(koyunsuk@gmail.com)은 admins 컬렉션 조회 없이 즉시 true.
/// firestore.rules 의 isAdmin() 함수가 이메일을 기준으로 판정하므로 이와 일치시킴.
final isAdminProvider = StreamProvider<bool>((ref) {
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(false);
    // 슈퍼 어드민 이메일은 admins 컬렉션 조회 건너뛰고 즉시 true.
    final email = user.email?.toLowerCase().trim();
    if (email == _superAdminEmail) {
      return Stream.value(true);
    }
    return FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists)
        .handleError((_) => false);
  });
});

// 앱 전체에 관리자가 한 명도 없는지 확인 (최초 관리자 설정용)
final hasAnyAdminProvider = FutureProvider<bool>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('isAdmin', isEqualTo: true)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
});

final currentPlanProvider = Provider<String>((ref) {
  // 익명(게스트) 사용자는 무조건 Free — Pro 결제 차단
  final isAnonymous = ref.watch(isAnonymousUserProvider);
  if (isAnonymous) return SubscriptionConstants.planFree;

  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return SubscriptionConstants.planFree;
  final sub = user.subscription;
  // trial 만료 시 free로 다운그레이드
  if (sub.status == SubscriptionConstants.statusTrial && sub.trialEndAt != null) {
    if (sub.trialEndAt!.isBefore(DateTime.now())) {
      return SubscriptionConstants.planFree;
    }
  }
  return sub.planId;
});

/// 현재 사용자가 Pro 이상인지 확인합니다 (trial 만료 포함).
final isProProvider = Provider<bool>((ref) {
  final planId = ref.watch(currentPlanProvider);
  return planId == SubscriptionConstants.planPro ||
      planId == SubscriptionConstants.planBusiness;
});

/// Pro 플랜(trial 포함) 잔여일을 반환합니다. trial이 아니면 null.
final proRemainingDaysProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final sub = user?.subscription;
  if (sub == null) return null;
  if (sub.status == SubscriptionConstants.statusTrial && sub.trialEndAt != null) {
    final remaining = sub.trialEndAt!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
  return null;
});

// 기능 제한은 화면 진입 전과 저장 직전에 함께 확인합니다.
final featureGatesProvider = Provider<FeatureGates>((ref) {
  final planId = ref.watch(currentPlanProvider);
  return FeatureGates(planId: planId);
});

class FeatureGates {
  final String planId;

  const FeatureGates({required this.planId});

  bool get isFree => planId == SubscriptionConstants.planFree;
  bool get isStarter => planId == SubscriptionConstants.planStarter;
  bool get isPro => planId == SubscriptionConstants.planPro;
  bool get isBusiness => planId == SubscriptionConstants.planBusiness;
  bool get isStarterOrAbove => isStarter || isPro || isBusiness;
  bool get isProOrAbove => isPro || isBusiness;

  bool canAddSwatch(int currentCount) {
    if (isStarterOrAbove) return true;
    return currentCount < SubscriptionConstants.maxFreeSwatches;
  }

  int get swatchLimit => isFree ? SubscriptionConstants.maxFreeSwatches : -1;

  bool canAddProject(int currentCount) {
    if (isStarterOrAbove) return true;
    return currentCount < SubscriptionConstants.maxFreeProjects;
  }

  int get projectLimit => isFree ? SubscriptionConstants.maxFreeProjects : -1;

  bool canAddCounter(int currentCount) {
    if (isStarterOrAbove) return true;
    return currentCount < SubscriptionConstants.maxFreeCounters;
  }

  bool canPost(int postsThisMonth) {
    if (isStarterOrAbove) return true;
    return postsThisMonth < SubscriptionConstants.maxFreePostsPerMonth;
  }

  bool canSaveEditor(int currentCount) {
    if (isProOrAbove) return true;
    if (isStarter) {
      return currentCount < SubscriptionConstants.maxStarterEditorSaves;
    }
    return false;
  }

  bool get canExportPdf => isStarterOrAbove;
  bool get canEnrollTier1 => isStarterOrAbove;
  bool get canEnrollTier2 => isProOrAbove;
  bool get canSell => isProOrAbove;
  bool get canHostKal => isStarterOrAbove;

  String swatchLimitMessage(int current) {
    return 'Free 플랜에서는 스와치를 ${SubscriptionConstants.maxFreeSwatches}개까지 저장할 수 있어요.\n'
        'Starter로 업그레이드하면 더 많이 기록할 수 있습니다.';
  }

  String projectLimitMessage(int current) {
    return 'Free 플랜에서는 프로젝트를 ${SubscriptionConstants.maxFreeProjects}개까지 만들 수 있어요.\n'
        'Starter로 업그레이드하면 제한이 더 넉넉해집니다.';
  }
}
