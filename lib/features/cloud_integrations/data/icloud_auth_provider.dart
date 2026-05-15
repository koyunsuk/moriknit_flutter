// lib/features/cloud_integrations/data/icloud_auth_provider.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// iCloud Drive 인증 stub. 실제 CloudKit/iCloud Drive 연동은 후속 작업.
// iOS 전용 — Android/웹에서는 화면에서 비활성 안내.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class ICloudAuthState {
  final bool isLoggedIn;
  final String? accountId;
  final String? email;
  final bool isLoading;
  final String? error;

  const ICloudAuthState({
    this.isLoggedIn = false,
    this.accountId,
    this.email,
    this.isLoading = false,
    this.error,
  });

  ICloudAuthState copyWith({
    bool? isLoggedIn,
    String? accountId,
    String? email,
    bool? isLoading,
    String? error,
  }) {
    return ICloudAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class ICloudAuthNotifier extends StateNotifier<ICloudAuthState> {
  ICloudAuthNotifier() : super(const ICloudAuthState());

  /// 실제 iCloud Drive(CloudKit) 연동은 후속 작업 (#703 후속).
  /// 지금은 stub.
  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO(#703 후속): icloud_storage / CloudKit 연동 구현
      throw UnimplementedError('iCloud Drive 연동은 준비 중이에요');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const ICloudAuthState();
  }
}

final iCloudAuthProvider =
    StateNotifierProvider<ICloudAuthNotifier, ICloudAuthState>(
  (ref) => ICloudAuthNotifier(),
);
