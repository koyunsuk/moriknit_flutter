// 이슈 #815 — 어드민 모바일 앱 entry (E안)
//
// 기존 lib/main_admin.dart 는 웹 어드민 전용 entry.
// 본 파일은 동일한 AdminRouter / AdminScreen 코드를 100% 재사용하여
// 모바일(APK/IPA)에서 어드민 콘솔을 띄우기 위한 entry 입니다.
//
// 차이점:
//   - usePathUrlStrategy() 호출 제거 (모바일에서는 web URL 전략 불필요)
//   - GoogleFonts.allowRuntimeFetching 동일 정책 유지
//
// 빌드 방법 (가이드: docs/admin_mobile_setup.md 참조):
//   flutter build apk --debug --target=lib/main_admin_mobile.dart
//
// 주의: pubspec.yaml / android/app/build.gradle.kts 는 본 PR에서 변경하지 않음.
// 별도 applicationId 분리, 앱 아이콘, 패키지명 분기는 사용자 승인 후 메인 세션에서 처리.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/localization/app_language.dart';
import 'core/router/admin_router.dart';
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
      child: MoriKnitAdminMobileApp(),
    ),
  );
}

class MoriKnitAdminMobileApp extends ConsumerWidget {
  const MoriKnitAdminMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    return MaterialApp.router(
      key: ValueKey(themeMode),
      title: 'MoriKnit Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.adminLight,
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
