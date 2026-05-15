// lib/features/cloud_integrations/data/google_drive_auth_provider.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// Google Drive 인증 stub. 실제 OAuth는 후속 작업.
// 드롭박스 (`dropbox_auth_provider.dart`) 패턴 1:1 모방.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class GoogleDriveAuthState {
  final bool isLoggedIn;
  final String? accountId;
  final String? email;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const GoogleDriveAuthState({
    this.isLoggedIn = false,
    this.accountId,
    this.email,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  GoogleDriveAuthState copyWith({
    bool? isLoggedIn,
    String? accountId,
    String? email,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return GoogleDriveAuthState(
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
class GoogleDriveAuthNotifier extends StateNotifier<GoogleDriveAuthState> {
  GoogleDriveAuthNotifier() : super(const GoogleDriveAuthState());

  /// 실제 Google OAuth 흐름 구현은 후속 작업 (#703 후속).
  /// 지금은 stub — 호출 시 UnimplementedError 발생, 화면에서 친화 메시지로 변환.
  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO(#703 후속): google_sign_in + Drive scopes / OAuth 구현
      throw UnimplementedError('Google Drive 연동은 준비 중이에요');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const GoogleDriveAuthState();
  }
}

final googleDriveAuthProvider =
    StateNotifierProvider<GoogleDriveAuthNotifier, GoogleDriveAuthState>(
  (ref) => GoogleDriveAuthNotifier(),
);
