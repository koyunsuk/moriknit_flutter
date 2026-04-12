import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/features/admin/presentation/admin_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/splash_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  // idTokenChanges: 로그인/로그아웃 및 Custom Claims 갱신 시 라우터 재평가
  final authRefresh = GoRouterRefreshStream(FirebaseAuth.instance.idTokenChanges());
  ref.listen(isAdminProvider, (_, _) => authRefresh.refresh());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final isAdminState = ref.read(isAdminProvider);
      final location = state.matchedLocation;

      if (location == '/') return '/admin';
      if (!isLoggedIn) return '/login';

      // Custom Claims 아직 로딩 중이면 대기
      if (isAdminState.isLoading) return null;

      final isAdmin = isAdminState.valueOrNull ?? false;
      if (!isAdmin) return '/no-permission';

      if (location == '/login') return '/admin';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen(isAdmin: true)),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/no-permission', builder: (_, _) => const _NoPermissionScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

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
