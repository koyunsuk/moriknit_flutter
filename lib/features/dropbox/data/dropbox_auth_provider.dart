import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // 이슈 #870 — Firestore 동기화 헬퍼.
  //   users/{uid}/private/dropbox 문서에 토큰을 함께 보관해
  //   Cloud Function(인입 이메일 첨부 처리)이 본인 Dropbox `/모리니트/` 폴더로
  //   추가 백업할 수 있게 한다. Firestore rules 에서 본인 uid 만 read/write 허용.
  DocumentReference<Map<String, dynamic>>? _dropboxPrivateDocRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('dropbox');
  }

  Future<void> _syncTokenToFirestore({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return;
    try {
      final data = <String, dynamic>{
        'accessToken': accessToken,
        if (refreshToken != null && refreshToken.isNotEmpty)
          'refreshToken': refreshToken,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await ref.set(data, SetOptions(merge: true));
    } catch (_) {
      // best-effort. 실패해도 secure_storage 토큰은 남으므로 앱 내 동작은 정상.
    }
  }

  Future<void> _clearTokenInFirestore() async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return;
    try {
      await ref.delete();
    } catch (_) {
      // best-effort.
    }
  }

  // 이슈 #870 — 사용자가 마이페이지에서 지정한 Dropbox 백업 폴더 경로.
  //   Cloud Function(inboundEmailHandler) 이 본인 Dropbox 의 해당 폴더로 백업.
  //   미지정(null/빈문자열) 시 Cloud Function 은 Dropbox 업로드를 건너뜀.
  Future<String?> readUploadFolder() async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      if (!snap.exists) return null;
      final raw = (snap.data() ?? const {})['uploadFolder'];
      if (raw is String) return raw;
      return null;
    } catch (_) {
      return null;
    }
  }

  // 이슈 #871 — 사용자가 본인 Dropbox uploadFolder 에 직접 추가한 파일을
  //   앱 진입 시 자동 등록할지 여부. 기본값 false (다이얼로그 확인).
  Future<bool> readAutoImportEnabled() async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return false;
    try {
      final snap = await ref.get();
      if (!snap.exists) return false;
      final raw = (snap.data() ?? const {})['autoImportEnabled'];
      if (raw is bool) return raw;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> writeAutoImportEnabled(bool enabled) async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return;
    try {
      await ref.set(
        {
          'autoImportEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort.
    }
  }

  // 이슈 #873 — SendGrid 인입 메일 PDF 의 자동 AI 분석 토글.
  //   기본값 false. Pro 사용자만 활성 (UI 가드).
  //   Cloud Function(inboundEmailHandler)이 이 값을 검사해 pending_ai_jobs 큐 생성.
  Future<bool> readAutoAiAnalysisEnabled() async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return false;
    try {
      final snap = await ref.get();
      if (!snap.exists) return false;
      final raw = (snap.data() ?? const {})['autoAiAnalysisEnabled'];
      if (raw is bool) return raw;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> writeAutoAiAnalysisEnabled(bool enabled) async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return;
    try {
      await ref.set(
        {
          'autoAiAnalysisEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort.
    }
  }

  /// 마이페이지 폴더 입력 저장.
  ///   - 빈 문자열을 넘기면 필드 삭제 (Dropbox 업로드 건너뜀).
  ///   - 토큰 도큐먼트 자체가 없으면(Dropbox 미연결) merge 로 폴더만 보관해
  ///     이후 연결 시점에 함께 사용.
  Future<void> writeUploadFolder(String folder) async {
    final ref = _dropboxPrivateDocRef();
    if (ref == null) return;
    final trimmed = folder.trim();
    if (trimmed.isEmpty) {
      try {
        await ref.set(
          {
            'uploadFolder': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        // best-effort.
      }
      return;
    }
    // 끝 슬래시 보정은 Cloud Function 에서도 한 번 더 처리.
    final normalized = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    try {
      await ref.set(
        {
          'uploadFolder': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort.
    }
  }

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

    // 이슈 #870 — 세션 복원 시에도 Firestore 동기화 (구버전 사용자 마이그레이션).
    final refreshTokenForSync = await _storage.read(key: _kKeyRefreshToken);
    DateTime? expiryForSync;
    if (expiryStr != null) {
      expiryForSync = DateTime.tryParse(expiryStr);
    }
    await _syncTokenToFirestore(
      accessToken: accessToken,
      refreshToken: refreshTokenForSync,
      expiresAt: expiryForSync,
    );
  }

  Future<void> login() async {
    if (kIsWeb) return; // 웹 신규 로그인은 flutter_appauth 미지원 — 세션 복원은 _restoreSession에서 처리
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

      // 이슈 #870 — Firestore 동기화 (Cloud Function 백업 업로드 용).
      await _syncTokenToFirestore(
        accessToken: token,
        refreshToken: result.refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
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

      // 이슈 #870 — refresh 후에도 Firestore 동기화 (Cloud Function 이 최신 토큰 사용).
      await _syncTokenToFirestore(
        accessToken: token,
        refreshToken: result.refreshToken ?? refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
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
    // 이슈 #870 — 연결 해제 시 Firestore 토큰 도큐먼트 정리.
    //   (uploadFolder 등 사용자 입력값도 함께 삭제되므로 재연결 후 다시 입력해야 함)
    await _clearTokenInFirestore();
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
