import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/app_language.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/landing/presentation/landing_board_screen.dart';
import 'features/landing/presentation/landing_notice_screen.dart';
import 'features/landing/presentation/landing_pricing_screen.dart';
import 'features/landing/presentation/landing_screen.dart';
import 'features/landing/presentation/landing_class_screen.dart';
import 'features/landing/presentation/landing_encyclopedia_screen.dart';
import 'features/landing/presentation/landing_service_screen.dart';
import 'features/landing/presentation/landing_feature_page.dart';
import 'features/landing/presentation/landing_signup_screen.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

late final _AuthRefresh _authRefresh;

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _authRefresh = _AuthRefresh(FirebaseAuth.instance.authStateChanges());
  runApp(const ProviderScope(child: MoriKnitLandingApp()));
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}

final _landingRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefresh,
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;
    if (isLoggedIn && loc == '/login') return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
    GoRoute(path: '/landing', redirect: (_, _) => '/'),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, s) => LandingSignupScreen(source: s.uri.queryParameters['source'])),
    GoRoute(path: '/pricing', builder: (_, _) => const LandingPricingScreen()),
    GoRoute(
      path: '/features/:feature',
      builder: (_, s) {
        final id = s.pathParameters['feature']!;
        if (id == 'encyclopedia') return const LandingEncyclopediaScreen();
        return LandingGenericFeaturePage(featureId: id);
      },
    ),
    GoRoute(path: '/encyclopedia', builder: (_, _) => const LandingEncyclopediaScreen()),
    GoRoute(path: '/service', builder: (_, _) => const LandingServiceScreen()),
    GoRoute(path: '/classes', builder: (_, _) => const LandingClassListScreen()),
    GoRoute(path: '/notices', builder: (_, _) => const LandingNoticeListScreen()),
    GoRoute(path: '/notices/:id', builder: (_, s) => LandingNoticeDetailScreen(noticeId: s.pathParameters['id']!)),
    GoRoute(path: '/reviews', builder: (_, _) => const LandingBoardListScreen(boardType: 'review')),
    GoRoute(path: '/releases', builder: (_, _) => const LandingBoardListScreen(boardType: 'release')),
    GoRoute(path: '/qa', builder: (_, _) => const LandingBoardListScreen(boardType: 'qa')),
    GoRoute(
      path: '/board/:type',
      builder: (_, s) => LandingBoardListScreen(boardType: s.pathParameters['type']!),
      routes: [
        GoRoute(path: 'write', builder: (_, s) => LandingBoardWriteScreen(boardType: s.pathParameters['type']!)),
        GoRoute(path: ':id', builder: (_, s) => LandingBoardDetailScreen(boardType: s.pathParameters['type']!, postId: s.pathParameters['id']!)),
      ],
    ),
  ],
);

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
