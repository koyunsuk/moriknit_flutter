// lib/features/cloud_integrations/data/onedrive_auth_provider.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// Microsoft OneDrive 인증 stub. 실제 MSAL/OAuth 연동은 후속 작업.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class OneDriveAuthState {
  final bool isLoggedIn;
  final String? accountId;
  final String? email;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const OneDriveAuthState({
    this.isLoggedIn = false,
    this.accountId,
    this.email,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  OneDriveAuthState copyWith({
    bool? isLoggedIn,
    String? accountId,
    String? email,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return OneDriveAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class OneDriveAuthNotifier extends StateNotifier<OneDriveAuthState> {
  OneDriveAuthNotifier() : super(const OneDriveAuthState());

  /// 실제 Microsoft Graph / MSAL 연동은 후속 작업 (#703 후속).
  /// 지금은 stub.
  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO(#703 후속): MSAL / Microsoft Graph OAuth 구현
      throw UnimplementedError('OneDrive 연동은 준비 중이에요');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const OneDriveAuthState();
  }
}

final oneDriveAuthProvider =
    StateNotifierProvider<OneDriveAuthNotifier, OneDriveAuthState>(
  (ref) => OneDriveAuthNotifier(),
);
