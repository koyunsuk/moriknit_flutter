// lib/features/calendar/data/outlook_calendar_service.dart
//
// 이슈 #885 — Outlook 캘린더 양방향 동기화
// Microsoft Graph API v1.0 직접 HTTP 호출.
// flutter_appauth 패턴은 dropbox_auth_provider.dart 참조.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/knitting_event.dart';

// ── 상수 ──────────────────────────────────────────────────────────────────────
const _kClientId = 'YOUR_MS_CLIENT_ID'; // Azure AD 앱 등록 후 교체
const _kRedirectUri = 'msauth.com.moriknit.moriknit_flutter://auth';
const _kAuthority = 'https://login.microsoftonline.com/common';
const _kAuthEndpoint = '$_kAuthority/oauth2/v2.0/authorize';
const _kTokenEndpoint = '$_kAuthority/oauth2/v2.0/token';
const _kScopes = ['Calendars.ReadWrite', 'offline_access'];
const _kGraphBase = 'https://graph.microsoft.com/v1.0';

const _kKeyAccessToken = 'outlook_access_token';
const _kKeyRefreshToken = 'outlook_refresh_token';
const _kKeyTokenExpiry = 'outlook_token_expiry';
const _kKeyEmail = 'outlook_email';

// Extended property GUID for moriknit custom fields
const _kExtPropGuid = '66f5a359-4659-4830-9070-00047ec6ac6e';

// ── 인증 상태 ─────────────────────────────────────────────────────────────────
class OutlookAuthState {
  final bool isLoggedIn;
  final String? email;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const OutlookAuthState({
    this.isLoggedIn = false,
    this.email,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  OutlookAuthState copyWith({
    bool? isLoggedIn,
    String? email,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return OutlookAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── 서비스 ────────────────────────────────────────────────────────────────────
class OutlookCalendarService extends StateNotifier<OutlookAuthState> {
  OutlookCalendarService() : super(const OutlookAuthState()) {
    _restoreSession();
  }

  static const _appAuth = FlutterAppAuth();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── 인증 ─────────────────────────────────────────────────────────────────

  /// 세션 복원 (앱 시작 시 자동 호출)
  Future<void> _restoreSession() async {
    final accessToken = await _storage.read(key: _kKeyAccessToken);
    if (accessToken == null) return;

    final expiryStr = await _storage.read(key: _kKeyTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
        return;
      }
    }

    final email = await _storage.read(key: _kKeyEmail);
    state = state.copyWith(
      isLoggedIn: true,
      email: email,
      accessToken: accessToken,
    );
  }

  /// Microsoft 계정으로 로그인 (OAuth2 PKCE)
  Future<bool> signIn() async {
    if (kIsWeb) return false; // flutter_appauth 웹 미지원 — 개발자 확인 필요
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
        state = state.copyWith(
          isLoading: false,
          error: '액세스 토큰을 받지 못했어요.',
        );
        return false;
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

      // Graph /me 에서 이메일 취득
      final email = await _fetchEmail(token);
      if (email != null) {
        await _storage.write(key: _kKeyEmail, value: email);
      }

      state = state.copyWith(
        isLoggedIn: true,
        email: email,
        accessToken: token,
        isLoading: false,
      );
      return true;
    } catch (e) {
      final msg = '$e';
      final isCancel = msg.contains('cancelled') || msg.contains('cancel');
      state = state.copyWith(
        isLoading: false,
        error: isCancel ? null : 'Outlook 로그인 중 오류가 발생했어요: $e',
      );
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _storage.delete(key: _kKeyAccessToken);
    await _storage.delete(key: _kKeyRefreshToken);
    await _storage.delete(key: _kKeyTokenExpiry);
    await _storage.delete(key: _kKeyEmail);
    state = const OutlookAuthState();
  }

  /// 현재 로그인 여부
  bool get isSignedIn => state.isLoggedIn;

  // ── 토큰 관리 ─────────────────────────────────────────────────────────────

  /// 유효한 액세스 토큰 반환 (만료 시 자동 갱신)
  Future<String?> _getAccessToken() async {
    final expiryStr = await _storage.read(key: _kKeyTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _tryRefresh();
      }
    }
    return state.accessToken ?? await _storage.read(key: _kKeyAccessToken);
  }

  Future<void> _tryRefresh() async {
    final refreshToken = await _storage.read(key: _kKeyRefreshToken);
    if (refreshToken == null) return;
    final email = await _storage.read(key: _kKeyEmail);

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
        await _storage.write(key: _kKeyRefreshToken, value: result.refreshToken);
      }
      if (result.accessTokenExpirationDateTime != null) {
        await _storage.write(
          key: _kKeyTokenExpiry,
          value: result.accessTokenExpirationDateTime!.toIso8601String(),
        );
      }

      state = state.copyWith(
        isLoggedIn: true,
        email: email,
        accessToken: token,
      );
    } catch (_) {
      await signOut();
    }
  }

  // ── Graph API 헬퍼 ────────────────────────────────────────────────────────

  Future<String?> _fetchEmail(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_kGraphBase/me?\$select=mail,userPrincipalName'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['mail'] as String?) ?? (data['userPrincipalName'] as String?);
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // ── 이벤트 CRUD ───────────────────────────────────────────────────────────

  /// 로컬 KnittingEvent → Outlook 생성 또는 업데이트.
  /// 성공 시 Outlook event ID 반환, 실패 시 null.
  Future<String?> pushEvent(KnittingEvent event) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    final body = jsonEncode(_toGraphEvent(event));
    final outlookId = event.outlookEventId;

    http.Response res;
    try {
      if (outlookId != null && outlookId.isNotEmpty) {
        // 업데이트 (PATCH)
        res = await http.patch(
          Uri.parse('$_kGraphBase/me/events/$outlookId'),
          headers: _headers(token),
          body: body,
        );
      } else {
        // 신규 생성 (POST)
        res = await http.post(
          Uri.parse('$_kGraphBase/me/events'),
          headers: _headers(token),
          body: body,
        );
      }
    } catch (e) {
      return null;
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id'] as String?;
    }
    return null;
  }

  /// Outlook 이벤트 삭제
  Future<void> deleteEvent(String outlookEventId) async {
    final token = await _getAccessToken();
    if (token == null) return;
    try {
      await http.delete(
        Uri.parse('$_kGraphBase/me/events/$outlookEventId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  /// Outlook에서 MoriKnit 카테고리 이벤트 가져오기 (pull 동기화)
  /// 반환: Graph 이벤트 JSON 목록 (id, subject, body, start, end, singleValueExtendedProperties 포함)
  Future<List<Map<String, dynamic>>> pullEvents() async {
    final token = await _getAccessToken();
    if (token == null) return [];

    // singleValueExtendedProperties expand로 moriknit_id 포함
    final extFilter =
        "String {$_kExtPropGuid} Name moriknit_id";
    final uri = Uri.parse('$_kGraphBase/me/events').replace(queryParameters: {
      r'$filter': "categories/any(c: c eq 'MoriKnit')",
      r'$select': 'id,subject,body,start,end,categories,singleValueExtendedProperties',
      r'$expand': 'singleValueExtendedProperties(\$filter=id eq \'$extFilter\')',
      r'$top': '250',
      r'$orderby': 'start/dateTime asc',
    });

    try {
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['value'] as List<dynamic>? ?? [];
        return items.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ── 변환 ─────────────────────────────────────────────────────────────────

  /// KnittingEvent → Microsoft Graph 이벤트 JSON
  Map<String, dynamic> _toGraphEvent(KnittingEvent e) {
    final dateStr = e.date.toIso8601String().substring(0, 10);
    return {
      'subject': '${e.type.emoji} [MoriKnit] ${e.title}',
      'body': {
        'contentType': 'text',
        'content': '${e.note}\n\n#moriknit #${e.type.value}\nmoriknit_id:${e.id}',
      },
      'start': {
        'dateTime': '${dateStr}T09:00:00',
        'timeZone': 'Asia/Seoul',
      },
      'end': {
        'dateTime': '${dateStr}T10:00:00',
        'timeZone': 'Asia/Seoul',
      },
      'categories': ['MoriKnit'],
      'singleValueExtendedProperties': [
        {
          'id': 'String {$_kExtPropGuid} Name moriknit_id',
          'value': e.id,
        },
        {
          'id': 'String {$_kExtPropGuid} Name moriknit_type',
          'value': e.type.value,
        },
      ],
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final outlookCalendarServiceProvider =
    StateNotifierProvider<OutlookCalendarService, OutlookAuthState>(
  (ref) => OutlookCalendarService(),
);
