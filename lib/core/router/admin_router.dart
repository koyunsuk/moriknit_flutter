import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/features/admin/presentation/admin_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/splash_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authRefresh = GoRouterRefreshStream(authRepository.authStateChanges);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final location = state.matchedLocation;

      if (location == '/') return '/admin';
      if (!isLoggedIn) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
