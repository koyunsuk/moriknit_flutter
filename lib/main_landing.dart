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
import 'features/landing/presentation/landing_screen.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MoriKnitLandingApp()));
}

final _landingRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    const known = ['/', '/login', '/landing'];
    if (!known.contains(state.uri.path)) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
    GoRoute(path: '/landing', redirect: (_, _) => '/'),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
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
