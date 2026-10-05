import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../domain/knitting_event.dart';

/// Google Calendar API v3 — HTTP 직접 호출 (googleapis 패키지 불필요)
/// #885 외부 캘린더 연동
///
/// google_sign_in ^7.x API 사용:
///   - GoogleSignIn.instance (싱글톤)
///   - initialize() → authenticate() → account.authorizationClient.authorizationHeaders()
class GoogleCalendarService {
  static const _calendarId = 'primary';
  static const _baseUrl = 'https://www.googleapis.com/calendar/v3';
  static const _morinitTag = 'moriknit';
  static const _calendarScopes = [
    'https://www.googleapis.com/auth/calendar',
  ];

  GoogleSignInAccount? _currentAccount;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  bool _initialized = false;

  // ── 초기화 ───────────────────────────────────────────────────────────────────

  /// 캘린더 서비스를 초기화합니다. 앱 시작 시 1회 호출.
  /// GoogleSignIn.instance.initialize()는 전체 앱에서 1회만 허용되므로
  /// 이미 초기화된 경우 건너뜁니다.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    // authenticationEvents 스트림으로 현재 사용자 상태 추적
    _authSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentAccount = event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentAccount = null;
      }
    });
  }

  // ── 인증 ────────────────────────────────────────────────────────────────────

  /// Google 계정으로 로그인하고 캘린더 스코프 권한을 요청합니다.
  /// 반환값: 로그인 성공 여부
  Future<bool> signIn() async {
    await ensureInitialized();
    try {
      // 1단계: 인증 (사용자 선택)
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _calendarScopes,
      );
      _currentAccount = account;
      // 2단계: 캘린더 스코프 명시적 요청 (필요 시 동의 화면)
      await account.authorizationClient.authorizeScopes(_calendarScopes);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _currentAccount = null;
  }

  bool get isSignedIn => _currentAccount != null;
  String? get userEmail => _currentAccount?.email;

  /// 유효한 Bearer 토큰 헤더 반환.
  /// 미로그인 또는 스코프 미승인 시 null.
  Future<Map<String, String>?> _getHeaders() async {
    final account = _currentAccount;
    if (account == null) return null;
    try {
      // authorizationHeaders: 스코프가 승인돼 있으면 토큰 즉시 반환,
      // 만료 시 자동 refresh, 미승인이면 null 반환
      final headers = await account.authorizationClient.authorizationHeaders(
        _calendarScopes,
        promptIfNecessary: false,
      );
      if (headers == null) return null;
      return {
        ...headers,
        'Content-Type': 'application/json',
      };
    } catch (_) {
      return null;
    }
  }

  // ── Push (로컬 → Google Calendar) ──────────────────────────────────────────

  /// 로컬 KnittingEvent를 Google Calendar에 생성 또는 업데이트합니다.
  /// [event.gcalEventId]가 있으면 PATCH(업데이트), 없으면 POST(생성).
  /// 반환값: 생성/업데이트된 구글 이벤트 ID. 실패 시 null.
  Future<String?> pushEvent(KnittingEvent event) async {
    final headers = await _getHeaders();
    if (headers == null) return null;

    final body = jsonEncode(_toGCalEvent(event));

    try {
      if (event.gcalEventId != null && event.gcalEventId!.isNotEmpty) {
        // 기존 이벤트 업데이트 (PATCH)
        final url = Uri.parse(
          '$_baseUrl/calendars/$_calendarId/events/${Uri.encodeComponent(event.gcalEventId!)}',
        );
        final response = await http.patch(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return json['id'] as String?;
        }
        return null;
      } else {
        // 새 이벤트 생성 (POST)
        final url = Uri.parse('$_baseUrl/calendars/$_calendarId/events');
        final response = await http.post(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return json['id'] as String?;
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // ── Delete (Google Calendar 이벤트 삭제) ────────────────────────────────────

  /// Google Calendar에서 이벤트를 삭제합니다.
  Future<void> deleteEvent(String gcalEventId) async {
    final headers = await _getHeaders();
    if (headers == null) return;

    try {
      final url = Uri.parse(
        '$_baseUrl/calendars/$_calendarId/events/${Uri.encodeComponent(gcalEventId)}',
      );
      await http.delete(url, headers: headers);
    } catch (_) {
      // best-effort
    }
  }

  // ── Pull (Google Calendar → 로컬) ──────────────────────────────────────────

  /// Google Calendar에서 `#moriknit` 태그가 포함된 이벤트를 최근 1년 치 가져옵니다.
  /// 반환값: Google Calendar 이벤트 JSON 목록 (raw)
  Future<List<Map<String, dynamic>>> pullEvents() async {
    final headers = await _getHeaders();
    if (headers == null) return [];

    try {
      final timeMin = DateTime.now()
          .subtract(const Duration(days: 365))
          .toUtc()
          .toIso8601String();

      // extendedProperties.private.moriknit_tag=moriknit 필터로 모리니트 이벤트만 조회
      final url = Uri.parse(
        '$_baseUrl/calendars/$_calendarId/events'
        '?timeMin=${Uri.encodeComponent(timeMin)}'
        '&privateExtendedProperty=${Uri.encodeComponent('moriknit_tag=$_morinitTag')}'
        '&maxResults=500'
        '&singleEvents=true'
        '&orderBy=startTime',
      );

      final response = await http.get(url, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return items.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── 변환 헬퍼 ────────────────────────────────────────────────────────────────

  /// KnittingEvent → Google Calendar 이벤트 JSON
  Map<String, dynamic> _toGCalEvent(KnittingEvent e) {
    final dateStr = e.date.toIso8601String().substring(0, 10);
    final endDateStr = e.date
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    return {
      'summary': '${e.type.emoji} [MoriKnit] ${e.title}',
      'description': '${e.note}\n\n#moriknit #${e.type.value}',
      'start': {'date': dateStr},
      'end': {'date': endDateStr},
      'extendedProperties': {
        'private': {
          'moriknit_id': e.id,
          'moriknit_type': e.type.value,
          'moriknit_tag': _morinitTag,
        },
      },
    };
  }

  /// Google Calendar 이벤트 JSON에서 모리니트 private 확장 속성을 추출합니다.
  Map<String, String> extractPrivateProps(Map<String, dynamic> gcalEvent) {
    final extended =
        gcalEvent['extendedProperties'] as Map<String, dynamic>? ?? {};
    final private = extended['private'] as Map<String, dynamic>? ?? {};
    return private.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Google Calendar 이벤트 JSON에서 날짜 문자열('2024-01-15')을 DateTime으로 변환합니다.
  DateTime? extractDate(Map<String, dynamic> gcalEvent) {
    try {
      final start = gcalEvent['start'] as Map<String, dynamic>?;
      if (start == null) return null;
      final dateStr = start['date'] as String? ?? start['dateTime'] as String?;
      if (dateStr == null) return null;
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _authSub?.cancel();
  }
}

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  final service = GoogleCalendarService();
  ref.onDispose(service.dispose);
  return service;
});
