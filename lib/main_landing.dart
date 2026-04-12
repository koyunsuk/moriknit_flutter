import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:web/web.dart' as web;

import 'core/localization/app_language.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/landing/presentation/feature_detail_screen.dart';
import 'features/landing/presentation/landing_board_screen.dart';
import 'features/landing/presentation/landing_notice_screen.dart';
import 'features/landing/presentation/landing_pricing_screen.dart';
import 'features/landing/presentation/landing_screen.dart';
import 'features/landing/presentation/landing_signup_screen.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

const _mainAppUrl = 'https://moriknit-ceea9.web.app'; // 앱 전용 URL (랜딩은 moriknit.com)

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  kakao.KakaoSdk.init(javaScriptAppKey: 'b69570c25792e78f96988f7425a256ec');

  runApp(const ProviderScope(child: MoriKnitLandingApp()));
}

final _landingRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final path = state.uri.path;
    final allowedPrefixes = [
      '/',
      '/login',
      '/landing',
      '/features/',
      '/pricing',
      '/notices',
      '/reviews',
      '/releases',
      '/qa',
      '/board/',
    ];
    if (path == '/' || path == '/login' || path == '/landing' || path == '/signup') return null;
    if (allowedPrefixes.any((p) => p.length > 1 && path.startsWith(p))) return null;
    return '/';
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
    GoRoute(path: '/landing', redirect: (_, _) => '/'),
    GoRoute(path: '/login', builder: (_, _) => const _LandingLoginScreen()),
    GoRoute(
      path: '/signup',
      builder: (_, state) => LandingSignupScreen(
        source: state.uri.queryParameters['source'],
      ),
    ),
    GoRoute(
      path: '/features/:id',
      builder: (_, state) => FeatureDetailScreen(featureId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/pricing', builder: (_, _) => const LandingPricingScreen()),
    GoRoute(
      path: '/notices',
      builder: (_, _) => const LandingNoticeListScreen(),
    ),
    GoRoute(
      path: '/notices/:id',
      builder: (_, state) => LandingNoticeDetailScreen(noticeId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/reviews',
      builder: (_, _) => const LandingBoardListScreen(boardType: 'review'),
    ),
    GoRoute(
      path: '/releases',
      builder: (_, _) => const LandingBoardListScreen(boardType: 'release'),
    ),
    GoRoute(
      path: '/qa',
      builder: (_, _) => const LandingBoardListScreen(boardType: 'qa'),
    ),
    GoRoute(
      path: '/board/:type/:id',
      builder: (_, state) => LandingBoardDetailScreen(
        boardType: state.pathParameters['type'] ?? '',
        postId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/board/:type/write',
      builder: (_, state) => LandingBoardWriteScreen(
        boardType: state.pathParameters['type'] ?? '',
      ),
    ),
  ],
);

/// 랜딩 전용 LoginScreen 래퍼 — 로그인 성공 시 메인 앱으로 리다이렉트
class _LandingLoginScreen extends StatefulWidget {
  const _LandingLoginScreen();

  @override
  State<_LandingLoginScreen> createState() => _LandingLoginScreenState();
}

class _LandingLoginScreenState extends State<_LandingLoginScreen> {
  late final StreamSubscription<User?> _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        web.window.location.href = _mainAppUrl;
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const LoginScreen();
}

class MoriKnitLandingApp extends ConsumerWidget {
  const MoriKnitLandingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    return MaterialApp.router(
      title: 'MoriKnit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _landingRouter,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return resolveSupportedLocale(deviceLocale);
      },
    );
  }
}
