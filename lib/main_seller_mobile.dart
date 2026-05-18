// 이슈 #816 — 모바일셀러 앱 entry (E안 패턴, Etsy Seller 벤치마크)
//
// 모리니트 5번째 플랫폼: Pro/Business 등급 셀러 전용 모바일 앱.
// 도안 판매 관리, 주문/구매자 응대, 테스터 모집, Fork 통계 등.
//
// 빌드 방법:
//   flutter build apk --debug --flavor seller --target=lib/main_seller_mobile.dart
//
// Phase 1 (현재): entry + 가드 + placeholder 셀러 콘솔
// Phase 2 (후속): 셀러 대시보드 (매출/주문/리뷰), 주문 관리, FCM seller-alerts

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/localization/app_language.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
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

class MoriKnitSellerMobileApp extends ConsumerWidget {
  const MoriKnitSellerMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    return MaterialApp(
      key: ValueKey(themeMode),
      title: 'MoriKnit Seller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
      home: const _SellerEntryGate(),
    );
  }
}

/// 셀러 앱 진입 게이트 — Pro/Business 등급만 통과.
/// 로그인 안 됐으면 로그인 안내, 등급 미달이면 업그레이드 안내.
class _SellerEntryGate extends ConsumerWidget {
  const _SellerEntryGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('인증 오류: $e', style: T.body.copyWith(color: C.og))),
      ),
      data: (user) {
        if (user == null) {
          return const _LoginRequiredPlaceholder();
        }
        // TODO Phase 2: featureGatesProvider.isPro 또는 isBusiness 체크
        // 현재는 placeholder — 모든 로그인 사용자 허용 (개발 단계)
        return const _SellerConsolePlaceholder();
      },
    );
  }
}

class _LoginRequiredPlaceholder extends StatelessWidget {
  const _LoginRequiredPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_rounded, size: 80, color: C.lm),
                const SizedBox(height: 24),
                Text('모리니트 셀러', style: T.h1.copyWith(color: C.tx)),
                const SizedBox(height: 8),
                Text(
                  'Pro 또는 비즈니스 셀러 전용 앱',
                  style: T.body.copyWith(color: C.tx2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  '먼저 모리니트 사용자 앱에서 로그인하고\nPro 등급으로 업그레이드하세요.',
                  style: T.caption.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 1 placeholder — Phase 2에서 셀러 대시보드/주문관리/통계로 확장.
class _SellerConsolePlaceholder extends StatelessWidget {
  const _SellerConsolePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('모리니트 셀러', style: T.h3.copyWith(color: C.tx)),
        backgroundColor: C.bg,
        elevation: 0,
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
                '이슈 #816 — Phase 1 (entry + 가드 + placeholder).\n'
                'Phase 2에서 셀러 대시보드 + 주문 관리 + FCM seller-alerts 구현 예정.',
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
