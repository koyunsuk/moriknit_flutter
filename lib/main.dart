import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'core/constants/subscription_constants.dart';
import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_orchestrator.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/pattern/data/symbol_svg_repository.dart';
import 'firebase_options.dart';
import 'features/ravelry/data/ravelry_auth_provider.dart';
import 'providers/font_provider.dart';
import 'providers/theme_provider.dart';


void main() async {
  if (kIsWeb) usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // 폰트 선택 기능을 위해 런타임 페치 허용 (첫 사용 시 다운로드 → 캐시).
  // 오프라인 첫 진입 시 페치 실패 → fontFamilyFallback(Noto Sans CJK KR 등)으로 자동 폴백.
  GoogleFonts.config.allowRuntimeFetching = true;
  if (!kIsWeb) {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(SubscriptionConstants.boxSwatches),
      Hive.openBox<Map>(SubscriptionConstants.boxProjects),
      Hive.openBox<Map>(SubscriptionConstants.boxCounters),
      Hive.openBox<Map>(SubscriptionConstants.boxNeedles),
      Hive.openBox<Map>(SubscriptionConstants.boxSyncQueue),
      Hive.openBox<Map>(SubscriptionConstants.boxUser),
      Hive.openBox<dynamic>(SubscriptionConstants.boxViewerState),
      // #685 — 영속 캐시 Box
      Hive.openBox<Map>(SubscriptionConstants.boxCacheKnitSymbols),
      Hive.openBox<Map>(SubscriptionConstants.boxCacheEncyclopedia),
      Hive.openBox<Map>(SubscriptionConstants.boxCachePatternCharts),
      // #704 Phase A-B — PatternSession 오프라인 폴백 캐시
      Hive.openBox<Map>(SubscriptionConstants.boxPatternSessionHiveCache),
      // #704 Phase 2 — StepBlueprint + units 오프라인 폴백 캐시
      Hive.openBox<Map>(SubscriptionConstants.boxStepBlueprintsHiveCache),
      Hive.openBox<Map>(SubscriptionConstants.boxStepBlueprintUnitsHiveCache),
      // 심볼 SVG 본문 영속 캐시 — 오프라인에서 도안에디터 동작 보장
      Hive.openBox<Map>(SubscriptionConstants.boxKnitSymbolSvgCache),
      // 홈 즐겨찾기 — 사용자가 별표한 화면 카드 목록
      Hive.openBox<Map>(SubscriptionConstants.boxFavorites),
    ]);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // #685 — Firestore 영속 캐시 (모바일 SQLite / 웹 IndexedDB 자동).
  // v6 SDK: settings로 통합. enablePersistence 별도 호출 불필요.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // #784 — 카카오 SDK init: 모바일은 nativeAppKey, 웹은 javaScriptAppKey 사용.
  kakao.KakaoSdk.init(
    nativeAppKey: 'de107e8c3aa2ecdb5271c1a48a7da0d7',
    javaScriptAppKey: 'b69570c25792e78f96988f7425a256ec',
  );

  runApp(
    const ProviderScope(
      child: MoriKnitApp(),
    ),
  );
}

class MoriKnitApp extends ConsumerWidget {
  const MoriKnitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    final appFont = ref.watch(fontProvider);
    C.apply(themeMode);

    return MaterialApp.router(
      key: ValueKey('$themeMode-${appFont.storageKey}'),
      title: 'MoriKnit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightWithFont(appFont),
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // #768 — flutter_quill 11.x 의 필수 delegate (없으면 UnimplementedError)
        FlutterQuillLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return resolveSupportedLocale(deviceLocale);
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return _OAuthLinkListener(child: child);
      },
    );
  }
}

class _OAuthLinkListener extends ConsumerStatefulWidget {
  const _OAuthLinkListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_OAuthLinkListener> createState() => _OAuthLinkListenerState();
}

class _OAuthLinkListenerState extends ConsumerState<_OAuthLinkListener>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('moriknit/deeplink');
  bool _handledInitialUri = false;

  // #738 — 게스트 휘발 정책.
  // detached(앱 완전 종료) 시 즉시 sign out + paused 5분 이상 백그라운드 시 sign out.
  // 일반 단기 백그라운드(다른 앱 잠깐 보기)에서는 작업 보존을 위해 유지.
  DateTime? _pausedAt;
  static const Duration _guestBackgroundTtl = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 심볼 SVG 본문 백그라운드 prefetch — 오프라인 도안에디터 보장.
    // 사용자 체감 0 (PostFrame, fire-and-forget).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(symbolSvgRepositoryProvider).prefetchAll();
    });
    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleMethodCall);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleInitialUri();
      });
    }
    // 이슈 #704 Phase 2 — 앱 시작 시 첫 sync 시도 (활성화)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncOrchestratorProvider).syncAll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 포그라운드 복귀 시 Ravelry 세션 재검증 — 토큰 만료 조기 감지
      ref.read(ravelryAuthProvider.notifier).refreshSession();
      // 이슈 #704 Phase 2 — 포그라운드 복귀 시 pending op 처리 (활성화)
      ref.read(syncOrchestratorProvider).syncAll();
      // #738 — 게스트 모드: 백그라운드 5분 이상이면 sign out (휘발성)
      _maybeSignOutGuestAfterLongBackground();
      _pausedAt = null;
    } else if (state == AppLifecycleState.paused) {
      // 이슈 #704 Phase 2 — 백그라운드 진입 시 pending flush (활성화)
      ref.read(syncOrchestratorProvider).flushPending();
      // #738 — 게스트 휘발 타이머 시작 (다른 앱 잠깐 보기는 보호)
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.detached) {
      // #738 — 앱 완전 종료 시: 익명 사용자는 즉시 sign out (게스트 휘발 정책)
      _signOutIfGuest();
    }
  }

  /// 백그라운드 5분 이상이면 익명 사용자 sign out.
  void _maybeSignOutGuestAfterLongBackground() {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    final elapsed = DateTime.now().difference(pausedAt);
    if (elapsed >= _guestBackgroundTtl) {
      _signOutIfGuest();
    }
  }

  /// 익명 사용자일 때만 signOut — fire-and-forget.
  void _signOutIfGuest() {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      auth.signOut().catchError((_) {});
    }
  }

  Future<void> _handleInitialUri() async {
    if (_handledInitialUri) return;
    _handledInitialUri = true;
    try {
      final uriString = await _channel.invokeMethod<String>('getInitialLink');
      if (uriString != null && uriString.isNotEmpty) {
        _handleUri(Uri.parse(uriString));
      }
    } catch (error) {
      debugPrint('Ravelry initial link error: $error');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onLink' && call.arguments is String) {
      final uriString = call.arguments as String;
      if (uriString.isNotEmpty) {
        _handleUri(Uri.parse(uriString));
      }
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('Received deep link: $uri');
    if (uri.scheme == 'com.moriknit.app' &&
        uri.host == 'oauth-callback' &&
        uri.path == '/ravelry') {
      ref.read(ravelryAuthProvider.notifier).handleOAuthCallback(uri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
