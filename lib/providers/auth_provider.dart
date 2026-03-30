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

// Firestore users/{uid}.isAdmin 필드를 실시간으로 구독합니다.
final isAdminProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['isAdmin'] == true);
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
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.subscription.planId ?? SubscriptionConstants.planFree;
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
