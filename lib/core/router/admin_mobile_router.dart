// 이슈 #815 Phase 2 — 어드민 모바일 전용 라우터.
//
// admin_router.dart (웹 어드민용)와 분리. 모바일에서는 PC용 다크 사이드바
// 대신 BottomNavigationBar 기반 AdminMobileShell을 사용한다.
//
// 진입 흐름: 스플래시 → 로그인 / 어드민 모바일 셸 / 권한 없음.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_mobile_shell.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../providers/auth_provider.dart';

final adminMobileRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authRefresh = _AdminMobileRefreshStream(
    FirebaseAuth.instance.idTokenChanges(),
  );
  ref.listen(isAdminProvider, (_, _) => authRefresh.refresh());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final isAdminState = ref.read(isAdminProvider);
      final location = state.matchedLocation;

      // 스플래시는 자체 _navigate() 사용 — redirect 가로채지 않음
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
      GoRoute(path: '/', builder: (_, _) => const _AdminMobileSplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(isAdmin: true),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminMobileShell()),
      // 기존 PC 어드민 콘솔로 진입할 수 있는 호환 경로 (Phase 2 placeholder
      // 카드에서 "기존 어드민 콘솔로 이동" 액션이 사용한다).
      GoRoute(
        path: '/legacy-admin',
        builder: (_, _) => const AdminScreen(),
      ),
      GoRoute(
        path: '/no-permission',
        builder: (_, _) => const _AdminMobileNoPermissionScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// 모리니트 어드민 모바일 스플래시 — admin_router._AdminSplashScreen과 동일 톤.
/// (분리 라우터에서 import 충돌 없이 사용하려고 본 파일에 사본 유지)
class _AdminMobileSplashScreen extends ConsumerStatefulWidget {
  const _AdminMobileSplashScreen();

  @override
  ConsumerState<_AdminMobileSplashScreen> createState() =>
      _AdminMobileSplashScreenState();
}

class _AdminMobileSplashScreenState
    extends ConsumerState<_AdminMobileSplashScreen>
    with TickerProviderStateMixin {
  static const Color _adminAccent = Color(0xFFFF8A00);

  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
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
    final isLoggedIn =
        ref.read(authRepositoryProvider).currentUser != null;
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
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_adminAccent),
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

class _AdminMobileNoPermissionScreen extends StatelessWidget {
  const _AdminMobileNoPermissionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '관리자 권한이 없습니다.',
              style: TextStyle(fontSize: 18),
            ),
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

class _AdminMobileRefreshStream extends ChangeNotifier {
  _AdminMobileRefreshStream(Stream<dynamic> stream) {
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
