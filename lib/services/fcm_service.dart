// ── lib/services/fcm_service.dart ────────────────────────────────────────────
// 이슈 #817 — FCM Phase 1: 모바일 사용자 토큰 등록 + 수신 핸들러.
//
// 책임:
//  1) 권한 요청 (iOS / Android 13+ POST_NOTIFICATIONS)
//  2) 토큰 발급 + Firestore 저장 (`users/{uid}/fcm_tokens/{token}`)
//  3) 토큰 갱신(onTokenRefresh) 자동 재저장
//  4) 포그라운드 메시지 → SnackBar
//  5) 백그라운드/종료 상태에서 알림 탭 → 딥링크 라우팅
//
// 사용:
//   final fcm = FcmService.instance;
//   await fcm.initializeAfterLogin(uid);  // 로그인 후 호출
//
// 호출 위치:
//   lib/main.dart의 _OAuthLinkListener에서 authStateChanges() 구독 후 호출.
//
// 웹 안전성:
//   현재는 모바일 위주. kIsWeb일 때 초기화 자체를 건너뛴다 (웹 FCM은 별도 설정 필요).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/foreground_notification_overlay.dart';

/// 백그라운드 isolate 메시지 핸들러 — top-level 함수여야 한다.
/// (FCM 패키지 요구사항 — 클래스 메서드/람다 사용 불가)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 isolate에서는 Flutter UI에 접근할 수 없다.
  // 필요 시 Firebase.initializeApp() 후 분석/로그 등만 수행.
  debugPrint('[FCM] background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _lastSavedUid;
  String? _lastSavedToken;

  /// 글로벌 NavigatorKey — 백그라운드 클릭 → 딥링크 이동 시 사용.
  /// MaterialApp.router 환경에서는 GoRouter의 context를 통해 라우팅하므로
  /// router 참조를 주입 받는 setter를 제공.
  GoRouter? _router;
  ScaffoldMessengerState? _messenger;
  // 이슈 #834 — 포그라운드 알림 overlay 표시용 context (root navigator).
  BuildContext? _overlayContext;

  void attachRouter(GoRouter router) {
    _router = router;
  }

  void attachMessenger(ScaffoldMessengerState messenger) {
    _messenger = messenger;
  }

  /// 이슈 #834 — 포그라운드 알림 overlay 를 띄울 때 사용할 root context 등록.
  /// MaterialApp.router builder 에서 호출.
  void attachOverlayContext(BuildContext context) {
    _overlayContext = context;
  }

  /// 로그인 후(또는 익명 가입 직후) 호출.
  /// - 중복 호출 안전 (token이 동일하면 Firestore write 스킵)
  /// - 웹/데스크탑은 no-op
  Future<void> initializeAfterLogin(String uid) async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        await _setupHandlers();
        _initialized = true;
      }

      // 권한 요청 — iOS는 첫 호출에서 시스템 다이얼로그, Android 13+는 POST_NOTIFICATIONS
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] permission denied');
        return;
      }

      // iOS는 APNs 토큰 확보 후에야 FCM 토큰 발급 가능 — 첫 진입 시 null일 수 있음
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken returned null (APNs not ready?)');
        return;
      }

      await _saveToken(uid: uid, token: token);

      // 토큰 갱신 구독 (idempotent — 여러 번 listen해도 다중 호출 안전)
      _messaging.onTokenRefresh.listen((refreshed) async {
        await _saveToken(uid: uid, token: refreshed);
      });
    } catch (e, st) {
      debugPrint('[FCM] initialize failed: $e\n$st');
    }
  }

  /// 로그아웃 시 토큰 정리 — 다른 사용자가 같은 디바이스 사용 시 알림 누출 방지.
  Future<void> clearTokenOnLogout({String? uid}) async {
    if (kIsWeb) return;
    try {
      final target = uid ?? _lastSavedUid;
      final token = _lastSavedToken ?? await _messaging.getToken();
      if (target == null || token == null) return;
      await _db
          .collection('users')
          .doc(target)
          .collection('fcm_tokens')
          .doc(token)
          .delete();
      await _messaging.deleteToken();
      _lastSavedUid = null;
      _lastSavedToken = null;
    } catch (e) {
      debugPrint('[FCM] clearTokenOnLogout failed: $e');
    }
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    // 동일 uid + token이면 lastSeenAt만 업데이트 (write 비용 절감)
    final isSame = _lastSavedUid == uid && _lastSavedToken == token;
    final doc = _db
        .collection('users')
        .doc(uid)
        .collection('fcm_tokens')
        .doc(token);

    final payload = <String, dynamic>{
      'token': token,
      'platform': defaultTargetPlatform.name, // 'android' | 'iOS' | ...
      'lastSeenAt': FieldValue.serverTimestamp(),
    };
    if (!isSame) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(payload, SetOptions(merge: true));
    _lastSavedUid = uid;
    _lastSavedToken = token;
    debugPrint('[FCM] token saved for $uid (...${token.substring(token.length - 8)})');
  }

  Future<void> _setupHandlers() async {
    // 1) 포그라운드: 모리톡 채팅 풍선 스타일 floating overlay (#834).
    //    overlay context 가 없으면 SnackBar 폴백.
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      final title = notif?.title ?? msg.data['title']?.toString() ?? '';
      final body = notif?.body ?? msg.data['body']?.toString() ?? '';
      if (title.isEmpty && body.isEmpty) return;

      final ctx = _overlayContext;
      final hasDeepLink = _extractDeepLink(msg) != null;
      if (ctx != null && ctx.mounted) {
        ForegroundNotificationOverlay.show(
          ctx,
          title: title,
          body: body,
          onTap: hasDeepLink ? () => _navigateDeepLink(msg) : null,
        );
        return;
      }

      // 폴백: SnackBar
      final m = _messenger;
      if (m == null) return;
      final text = [title, body].where((s) => s.isNotEmpty).join(' · ');
      m.showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: hasDeepLink
              ? SnackBarAction(
                  label: '열기',
                  onPressed: () => _navigateDeepLink(msg),
                )
              : null,
        ),
      );
    });

    // 2) 백그라운드 → 알림 탭 → 앱 포그라운드 진입
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateDeepLink);

    // 3) 종료 상태에서 알림으로 앱 실행
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateDeepLink(initial);
      });
    }
  }

  String? _extractDeepLink(RemoteMessage msg) {
    final raw = msg.data['deepLink']?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  void _navigateDeepLink(RemoteMessage msg) {
    final link = _extractDeepLink(msg);
    if (link == null) return;
    final router = _router;
    if (router == null) {
      debugPrint('[FCM] router not attached, deep link ignored: $link');
      return;
    }
    try {
      // 외부 URL(https) 은 무시(필요 시 url_launcher 사용 — 정책 결정 필요).
      // 앱 내부 경로(/swatch, /community/... 등)만 push.
      if (link.startsWith('http://') || link.startsWith('https://')) {
        debugPrint('[FCM] external link ignored: $link');
        return;
      }
      router.push(link);
    } catch (e) {
      debugPrint('[FCM] deep link navigation failed: $e');
    }
  }
}
