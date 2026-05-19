// 이슈 #816 — 모바일셀러 앱 entry (E안 패턴, Etsy Seller 벤치마크)
//
// 모리니트 5번째 플랫폼: Pro/Business 등급 셀러 전용 모바일 앱.
//
// 빌드: bash deploy_mobile.sh seller
//
// Phase 2 (현재): sellerRouterProvider 사용 (lib/core/router/seller_router.dart)
//   - GoRouter + LoginScreen 통합 + SellerDashboardScreen
//   - placeholder 콘솔/카드 제거 (라우터 패턴으로 완전 교체)
// Phase 3 (후속): FCM seller-alerts, 가드 강화

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/localization/app_language.dart';
import 'core/router/seller_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MoriKnitSellerMobileApp(),
    ),
  );
}

class MoriKnitSellerMobileApp extends ConsumerWidget {
  const MoriKnitSellerMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(sellerRouterProvider);
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    // #818/#822 — ValueKey 제거 (GlobalKey 'root' 충돌 + ANR 원인)
    return MaterialApp.router(
      title: 'MoriKnit Seller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
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
