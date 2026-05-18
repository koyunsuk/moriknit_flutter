import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/features/admin/presentation/admin_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  // idTokenChanges: 로그인/로그아웃 및 Custom Claims 갱신 시 라우터 재평가
  final authRefresh = GoRouterRefreshStream(FirebaseAuth.instance.idTokenChanges());
  ref.listen(isAdminProvider, (_, _) => authRefresh.refresh());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    // 이슈 #815 후속 — 모바일 어드민 진입 흐름:
    // 런처 → AdminSplashScreen (오렌지 프로그레스바) → 로그인 / 어드민 콘솔
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final isAdminState = ref.read(isAdminProvider);
      final location = state.matchedLocation;

      // 스플래시 화면은 자체 _navigate() 사용 — redirect 가로채지 않음
      if (location == '/') return null;

      // 비로그인이면 무조건 /login
      if (!isLoggedIn) return location == '/login' ? null : '/login';

      // Custom Claims 로딩 중 대기
      if (isAdminState.isLoading) return null;

      // 어드민 권한 체크
      final isAdmin = isAdminState.valueOrNull ?? false;
      if (!isAdmin) return '/no-permission';

      // 어드민이면서 /login 진입 시 → /admin
      if (location == '/login') return '/admin';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _AdminSplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen(isAdmin: true)),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/no-permission', builder: (_, _) => const _NoPermissionScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// 모리니트 어드민 스플래시 — 오렌지 프로그레스바 + 어드민 타이틀.
/// 사용자 앱의 SplashScreen과 동일 구조, 컬러만 어드민 톤(오렌지)으로 차별화.
class _AdminSplashScreen extends ConsumerStatefulWidget {
  const _AdminSplashScreen();

  @override
  ConsumerState<_AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends ConsumerState<_AdminSplashScreen>
    with TickerProviderStateMixin {
  static const Color _adminAccent = Color(0xFFFF8A00); // 어드민 오렌지

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
    context.go(isLoggedIn ? '/admin' : '/login');
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
                          valueColor: const AlwaysStoppedAnimation<Color>(_adminAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'MoriKnit Admin',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _adminAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '모리니트 어드민',
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

class _NoPermissionScreen extends StatelessWidget {
  const _NoPermissionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('관리자 권한이 없습니다.', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('다른 계정으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
