// 이슈 #816 — 모바일셀러 앱 entry (E안 패턴, Etsy Seller 벤치마크)
//
// 모리니트 5번째 플랫폼: Pro/Business 등급 셀러 전용 모바일 앱.
//
// 빌드: bash deploy_mobile.sh seller
//
// Phase 1 (현재): entry + GoRouter + LoginScreen 통합 + placeholder 셀러 콘솔
// Phase 2 (후속): 셀러 대시보드 (매출/주문/리뷰), FCM seller-alerts, Pro 가드

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/localization/app_language.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
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

/// 셀러 앱 GoRouter — 비로그인 → /login, 로그인 → /seller
final _sellerRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authRefresh = _SellerRouterRefreshStream(FirebaseAuth.instance.idTokenChanges());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final location = state.matchedLocation;
      if (location == '/') return isLoggedIn ? '/seller' : '/login';
      if (!isLoggedIn && location != '/login') return '/login';
      if (isLoggedIn && location == '/login') return '/seller';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      // 셀러 앱은 일반 사용자 로그인 화면 재사용 (isAdmin: false).
      // 카카오 SDK는 셀러 앱에 미등록 — Google/이메일만 작동 예정.
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen(isAdmin: false)),
      GoRoute(path: '/seller', builder: (_, _) => const _SellerConsole()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('페이지를 찾을 수 없습니다: ${state.error}')),
    ),
  );
});

class _SellerRouterRefreshStream extends ChangeNotifier {
  _SellerRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class MoriKnitSellerMobileApp extends ConsumerWidget {
  const MoriKnitSellerMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_sellerRouterProvider);
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

/// Phase 1 placeholder — Phase 2에서 셀러 대시보드/주문관리/통계로 확장.
class _SellerConsole extends ConsumerWidget {
  const _SellerConsole();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('모리니트 셀러', style: T.h3.copyWith(color: C.tx)),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: C.mu),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PlaceholderCard(
              icon: Icons.payments_rounded,
              title: '판매 현황',
              subtitle: '오늘/이번 주/이번 달 매출 (Phase 2 구현 예정)',
              accent: C.lm,
            ),
            const SizedBox(height: 12),
            _PlaceholderCard(
              icon: Icons.shopping_bag_rounded,
              title: '주문 / 구매자',
              subtitle: '신규 주문 · 환불 요청 · 구매자 메시지 (Phase 2)',
              accent: C.lv,
            ),
            const SizedBox(height: 12),
            _PlaceholderCard(
              icon: Icons.upload_file_rounded,
              title: '도안 빠른 등록',
              subtitle: '신규 도안 업로드 · 가격 변경 · draft/complete 토글 (Phase 2)',
              accent: C.pk,
            ),
            const SizedBox(height: 12),
            _PlaceholderCard(
              icon: Icons.group_rounded,
              title: '테스터 모집 / 함께뜨기',
              subtitle: '테스터 그룹 · Fork 통계 · 피드백 (Phase 2)',
              accent: C.og,
            ),
            const SizedBox(height: 12),
            _PlaceholderCard(
              icon: Icons.campaign_rounded,
              title: '마케팅',
              subtitle: '큐레이션 신청 · 에디토리얼 노출 (Phase 2)',
              accent: C.lvD,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '이슈 #816 — Phase 1 (entry + GoRouter + LoginScreen + placeholder).\n'
                'Phase 2: Pro 가드 활성화 + 본 기능 구현 + FCM seller-alerts.',
                style: T.caption.copyWith(color: C.mu),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold.copyWith(color: C.tx)),
                const SizedBox(height: 4),
                Text(subtitle, style: T.caption.copyWith(color: C.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
