// 이슈 #816 Phase 2 — 셀러 모바일 앱 라우터.
//
// admin_router.dart 패턴을 그대로 따르되, 어드민 권한 체크 단계 없이
// 로그인만 통과하면 /seller 콘솔로 진입한다.
//
// 색상 액센트: 라임 (#7CB342 dark / #C0DC3C light) — 셀러 톤.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/features/seller/presentation/seller_dashboard_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

final sellerRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  // idTokenChanges: 로그인/로그아웃 시 라우터 재평가
  final authRefresh = _SellerRouterRefreshStream(FirebaseAuth.instance.idTokenChanges());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final location = state.matchedLocation;

      // 스플래시 화면은 자체 _navigate() 사용 — redirect 가로채지 않음
      if (location == '/') return null;

      // 비로그인 → 무조건 /login
      if (!isLoggedIn) return location == '/login' ? null : '/login';

      // 로그인 + /login 진입 시 → /seller
      if (location == '/login') return '/seller';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SellerSplashScreen()),
      // 셀러 앱은 일반 사용자 로그인 화면 재사용 + 게스트 진입 차단 (Pro/Business 전용).
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen(isAdmin: false, showGuestLogin: false)),
      GoRoute(path: '/seller', builder: (_, _) => const SellerDashboardScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// 모리니트 셀러 스플래시 — 라임 프로그레스바 + 셀러 타이틀.
/// admin_router의 _AdminSplashScreen 패턴 그대로 (오렌지 → 라임).
class _SellerSplashScreen extends ConsumerStatefulWidget {
  const _SellerSplashScreen();

  @override
  ConsumerState<_SellerSplashScreen> createState() => _SellerSplashScreenState();
}

class _SellerSplashScreenState extends ConsumerState<_SellerSplashScreen>
    with TickerProviderStateMixin {
  static const Color _sellerAccent = Color(0xFF7CB342); // 셀러 라임 (다크)

  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _progressController.forward();
    });
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _navigate();
    });
  }

  void _navigate() {
    final isLoggedIn = ref.read(authRepositoryProvider).currentUser != null;
    if (!mounted) return;
    context.go(isLoggedIn ? '/seller' : '/login');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _slideUp,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Image.asset(
                      'assets/splash_cat.png',
                      width: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(_sellerAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'MoriKnit Seller',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _sellerAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '모리니트 셀러',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFB8B8B8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
