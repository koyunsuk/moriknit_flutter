import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/core/widgets/main_shell.dart';
import 'package:moriknit_flutter/features/admin/presentation/admin_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/splash_screen.dart';
import 'package:moriknit_flutter/features/landing/presentation/landing_screen.dart';
import 'package:moriknit_flutter/features/community/presentation/community_screen.dart';
import 'package:moriknit_flutter/features/messenger/presentation/messenger_screen.dart';
import 'package:moriknit_flutter/features/counter/presentation/counter_screen.dart';
import 'package:moriknit_flutter/features/course/presentation/course_screen.dart';
import 'package:moriknit_flutter/features/encyclopedia/presentation/encyclopedia_screen.dart';
import 'package:moriknit_flutter/features/gauge/presentation/gauge_calculator_screen.dart';
import 'package:moriknit_flutter/features/home/presentation/home_screen.dart';
import 'package:moriknit_flutter/features/market/presentation/market_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/my_page_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/needle_list_screen.dart';
import 'package:moriknit_flutter/features/pattern/presentation/pattern_editor_screen.dart';
import 'package:moriknit_flutter/features/pattern/presentation/pattern_list_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_input_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_list_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_patterns_screen.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_detail_screen.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_input_screen.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_list_screen.dart';
import 'package:moriknit_flutter/features/tools/presentation/tools_screen.dart';
import 'package:moriknit_flutter/features/tools/presentation/tool_memo_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

export 'routes.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authRefresh = GoRouterRefreshStream(authRepository.authStateChanges);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentUser != null;
      final location = state.matchedLocation;
      final isSplash = location == Routes.splash;
      final isLogin = location == Routes.login;

      final isLanding = location == Routes.landing;
      final isAdmin = location == Routes.admin;
      final isPublicWebRoute = kIsWeb && (location == Routes.market || location == Routes.community || location == Routes.projectList);

      if (isSplash) {
        return null; // SplashScreen handles its own navigation after animation
      }
      if (isAdmin && !isLoggedIn) {
        return Routes.login;
      }
      if (!isLoggedIn && !isLogin && !isLanding && !isPublicWebRoute) {
        return kIsWeb ? Routes.landing : Routes.login;
      }
      if (isLoggedIn && (isLogin || isLanding)) {
        if (isLogin) {
          final from = state.uri.queryParameters['from'];
          if (from != null && from.isNotEmpty) return from;
        }
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.landing, builder: (_, _) => const LandingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: Routes.projectList,
            builder: (_, _) => const ProjectListScreen(),
            routes: [
              GoRoute(path: 'input', builder: (_, _) => const ProjectInputScreen()),
              GoRoute(path: 'patterns', builder: (_, _) => const ProjectPatternsScreen()),
              GoRoute(path: ':id', builder: (_, state) => ProjectDetailScreen(projectId: state.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: Routes.swatchList,
            builder: (_, _) => const SwatchListScreen(),
            routes: [
              GoRoute(path: 'input', builder: (_, _) => const SwatchInputScreen()),
              GoRoute(path: ':id', builder: (_, state) => SwatchDetailScreen(swatchId: state.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: Routes.tools,
            builder: (_, _) => const ToolsScreen(),
            routes: [
              GoRoute(
                path: 'patterns',
                builder: (_, _) => const PatternListScreen(),
              ),
              GoRoute(
                path: 'pattern',
                builder: (_, _) => const PatternEditorScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => PatternEditorScreen(patternId: state.pathParameters['id']),
                  ),
                ],
              ),
              GoRoute(path: 'gauge', builder: (_, _) => const GaugeCalculatorScreen()),
              GoRoute(path: 'course', builder: (_, _) => const CourseScreen()),
              GoRoute(path: 'encyclopedia', builder: (_, _) => const EncyclopediaScreen()),
              GoRoute(path: 'memo', builder: (_, _) => const ToolMemoScreen()),
            ],
          ),
          GoRoute(path: Routes.community, builder: (_, _) => const CommunityScreen()),
          GoRoute(path: Routes.messenger, builder: (_, _) => const MessengerScreen()),
          GoRoute(path: Routes.market, builder: (_, _) => const MarketScreen()),
          GoRoute(
            path: Routes.my,
            builder: (_, _) => const MyPageScreen(),
            routes: [GoRoute(path: 'needles', builder: (_, _) => const NeedleListScreen())],
          ),
          GoRoute(path: '/counter/:id', builder: (_, state) => CounterScreen(counterId: state.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
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
