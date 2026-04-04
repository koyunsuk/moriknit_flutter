import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── 상수 ──────────────────────────────────────────────────────────────────────
const _kClientId = 'sy3q9x9d1bp2g0136w3jd1ve';
const _kRedirectUri = 'com.moriknit.app://oauth-callback/etsy';
const _kAuthEndpoint = 'https://www.etsy.com/oauth/connect';
const _kTokenEndpoint = 'https://api.etsy.com/v3/public/oauth/token';
// listings_r: 리스팅 읽기, shops_r: 샵 정보 읽기
const _kScopes = ['listings_r', 'shops_r'];

const _kKeyAccessToken = 'etsy_access_token';
const _kKeyRefreshToken = 'etsy_refresh_token';
const _kKeyUserId = 'etsy_user_id';
const _kKeyShopName = 'etsy_shop_name';
const _kKeyTokenExpiry = 'etsy_token_expiry';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class EtsyAuthState {
  final bool isLoggedIn;
  final String? userId;
  final String? shopName;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const EtsyAuthState({
    this.isLoggedIn = false,
    this.userId,
    this.shopName,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  EtsyAuthState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? shopName,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return EtsyAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      shopName: shopName ?? this.shopName,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class EtsyAuthNotifier extends StateNotifier<EtsyAuthState> {
  EtsyAuthNotifier() : super(const EtsyAuthState()) {
    _restoreSession();
  }

  static const _appAuth = FlutterAppAuth();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _restoreSession() async {
    final accessToken = await _storage.read(key: _kKeyAccessToken);
    final userId = await _storage.read(key: _kKeyUserId);
    final shopName = await _storage.read(key: _kKeyShopName);
    final expiryStr = await _storage.read(key: _kKeyTokenExpiry);

    if (accessToken == null || userId == null) return;

    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
        return;
      }
    }

    state = state.copyWith(
      isLoggedIn: true,
      userId: userId,
      shopName: shopName,
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
      final userId = _extractUserId(token);

      await _storage.write(key: _kKeyAccessToken, value: token);
      if (result.refreshToken != null) {
        await _storage.write(key: _kKeyRefreshToken, value: result.refreshToken);
      }
      if (result.accessTokenExpirationDateTime != null) {
        await _storage.write(
            key: _kKeyTokenExpiry,
            value: result.accessTokenExpirationDateTime!.toIso8601String());
      }
      if (userId != null) {
        await _storage.write(key: _kKeyUserId, value: userId);
      }

      state = state.copyWith(
        isLoggedIn: true,
        userId: userId,
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
    final userId = await _storage.read(key: _kKeyUserId);
    final shopName = await _storage.read(key: _kKeyShopName);
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
        await _storage.write(key: _kKeyRefreshToken, value: result.refreshToken ?? refreshToken);
      }
      if (result.accessTokenExpirationDateTime != null) {
        await _storage.write(
            key: _kKeyTokenExpiry,
            value: result.accessTokenExpirationDateTime!.toIso8601String());
      }

      state = state.copyWith(
        isLoggedIn: true,
        userId: userId,
        shopName: shopName,
        accessToken: token,
      );
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _kKeyAccessToken);
    await _storage.delete(key: _kKeyRefreshToken);
    await _storage.delete(key: _kKeyUserId);
    await _storage.delete(key: _kKeyShopName);
    await _storage.delete(key: _kKeyTokenExpiry);
    state = const EtsyAuthState();
  }

  /// 토큰에서 user_id 추출 (JWT인 경우)
  String? _extractUserId(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return (map['user_id'] ?? map['sub'])?.toString();
    } catch (_) {
      return null;
    }
  }
}

final etsyAuthProvider =
    StateNotifierProvider<EtsyAuthNotifier, EtsyAuthState>(
  (ref) => EtsyAuthNotifier(),
);
