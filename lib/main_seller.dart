// 이슈 #816 Phase 2 — 셀러 웹 entry
//
// 모리니트 셀러 전용 웹 사이트 (seller.moriknit.com).
// 모바일셀러 앱(lib/main_seller_mobile.dart)과 코드 공유.
// 큰 화면(PC)에서 도안 업로드/통계/관리에 편리.
//
// 빌드/배포: bash deploy_web.sh seller

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/localization/app_language.dart';
import 'core/router/seller_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MoriKnitSellerWebApp(),
    ),
  );
}

class MoriKnitSellerWebApp extends ConsumerWidget {
  const MoriKnitSellerWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(sellerRouterProvider);
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    return MaterialApp.router(
      key: ValueKey(themeMode),
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
