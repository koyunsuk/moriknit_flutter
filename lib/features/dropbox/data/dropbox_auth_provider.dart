import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ── 상수 ──────────────────────────────────────────────────────────────────────
const _kClientId = '807t0lx4fvthfep';
const _kRedirectUri = 'com.moriknit.app://oauth-callback/dropbox';
const _kAuthEndpoint = 'https://www.dropbox.com/oauth2/authorize';
const _kTokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';
const _kScopes = ['files.content.read', 'files.metadata.read', 'account_info.read'];

const _kKeyAccessToken = 'dropbox_accessToken';
const _kKeyRefreshToken = 'dropbox_refreshToken';
const _kKeyAccountId = 'dropbox_accountId';
const _kKeyEmail = 'dropbox_email';
const _kKeyTokenExpiry = 'dropbox_tokenExpiry';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class DropboxAuthState {
  final bool isLoggedIn;
  final String? accountId;
  final String? email;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const DropboxAuthState({
    this.isLoggedIn = false,
    this.accountId,
    this.email,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  DropboxAuthState copyWith({
    bool? isLoggedIn,
    String? accountId,
    String? email,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return DropboxAuthState(
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
class DropboxAuthProvider extends StateNotifier<DropboxAuthState> {
  DropboxAuthProvider() : super(const DropboxAuthState()) {
    _restoreSession();
  }

  static const _appAuth = FlutterAppAuth();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 현재 유효한 액세스 토큰 반환 (만료 시 refresh 시도)
  Future<String?> getValidAccessToken() async {
    final token = state.accessToken ?? await _storage.read(key: _kKeyAccessToken);
    if (token == null) return null;

    final expiryStr = await _storage.read(key: _kKeyTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
        return state.accessToken;
      }
    }
    return token;
  }

  Future<void> _restoreSession() async {
    final accessToken = await _storage.read(key: _kKeyAccessToken);
    final accountId = await _storage.read(key: _kKeyAccountId);
    final email = await _storage.read(key: _kKeyEmail);
    final expiryStr = await _storage.read(key: _kKeyTokenExpiry);

    if (accessToken == null || accountId == null) return;

    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
        return;
      }
    }

    state = state.copyWith(
      isLoggedIn: true,
      accountId: accountId,
      email: email,
      accessToken: accessToken,
    );
  }

  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _kClientId,
          _kRedirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _kAuthEndpoint,
            tokenEndpoint: _kTokenEndpoint,
          ),
          scopes: _kScopes,
        ),
      );

      final token = result.accessToken ?? '';
      if (token.isEmpty) {
        state = state.copyWith(isLoading: false, error: '액세스 토큰을 받지 못했어요.');
        return;
      }

      await _storage.write(key: _kKeyAccessToken, value: token);
      if (result.refreshToken != null) {
        await _storage.write(key: _kKeyRefreshToken, value: result.refreshToken);
      }
      if (result.accessTokenExpirationDateTime != null) {
        await _storage.write(
          key: _kKeyTokenExpiry,
          value: result.accessTokenExpirationDateTime!.toIso8601String(),
        );
      }

      // 계정 정보 취득
      final accountInfo = await _fetchCurrentAccount(token);
      final accountId = accountInfo?['account_id'] as String?;
      final email = (accountInfo?['email'] as String?) ??
          ((accountInfo?['name'] as Map?)?['display_name'] as String?);

      if (accountId != null) {
        await _storage.write(key: _kKeyAccountId, value: accountId);
      }
      if (email != null) {
        await _storage.write(key: _kKeyEmail, value: email);
      }

      state = state.copyWith(
        isLoggedIn: true,
        accountId: accountId,
        email: email,
        accessToken: token,
        isLoading: false,
      );
    } catch (e) {
      final msg = '$e';
      final isCancel = msg.contains('cancelled') || msg.contains('cancel');
      state = state.copyWith(
        isLoading: false,
        error: isCancel ? null : '로그인 중 오류가 발생했어요: $e',
      );
    }
  }

  Future<void> _tryRefresh() async {
    final refreshToken = await _storage.read(key: _kKeyRefreshToken);
    final accountId = await _storage.read(key: _kKeyAccountId);
    final email = await _storage.read(key: _kKeyEmail);
    if (refreshToken == null) return;

    try {
      final result = await _appAuth.token(
        TokenRequest(
          _kClientId,
          _kRedirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _kAuthEndpoint,
            tokenEndpoint: _kTokenEndpoint,
          ),
          refreshToken: refreshToken,
          scopes: _kScopes,
        ),
      );

      final token = result.accessToken ?? '';
      if (token.isEmpty) return;

      await _storage.write(key: _kKeyAccessToken, value: token);
      if (result.refreshToken != null) {
        await _storage.write(
          key: _kKeyRefreshToken,
          value: result.refreshToken ?? refreshToken,
        );
      }
      if (result.accessTokenExpirationDateTime != null) {
        await _storage.write(
          key: _kKeyTokenExpiry,
          value: result.accessTokenExpirationDateTime!.toIso8601String(),
        );
      }

      state = state.copyWith(
        isLoggedIn: true,
        accountId: accountId,
        email: email,
        accessToken: token,
      );
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _kKeyAccessToken);
    await _storage.delete(key: _kKeyRefreshToken);
    await _storage.delete(key: _kKeyAccountId);
    await _storage.delete(key: _kKeyEmail);
    await _storage.delete(key: _kKeyTokenExpiry);
    state = const DropboxAuthState();
  }

  /// POST /2/users/get_current_account (빈 body, Bearer 토큰)
  Future<Map<String, dynamic>?> _fetchCurrentAccount(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: 'null',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

final dropboxAuthProvider =
    StateNotifierProvider<DropboxAuthProvider, DropboxAuthState>(
  (ref) => DropboxAuthProvider(),
);
