import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/core/widgets/main_shell.dart';
import 'package:moriknit_flutter/features/auth/presentation/login_screen.dart';
import 'package:moriknit_flutter/features/auth/presentation/splash_screen.dart';
import 'package:moriknit_flutter/features/counter/presentation/counter_list_screen.dart';
import 'package:moriknit_flutter/features/community/presentation/community_screen.dart';
import 'package:moriknit_flutter/features/counter/presentation/counter_screen.dart';
import 'package:moriknit_flutter/features/dm/presentation/dm_list_screen.dart';
import 'package:moriknit_flutter/features/dm/presentation/dm_chat_screen.dart';
import 'package:moriknit_flutter/features/course/presentation/course_screen.dart';
import 'package:moriknit_flutter/features/encyclopedia/presentation/encyclopedia_screen.dart';
import 'package:moriknit_flutter/features/gauge/presentation/gauge_calculator_screen.dart';
import 'package:moriknit_flutter/features/home/presentation/home_screen.dart';
import 'package:moriknit_flutter/features/market/presentation/market_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/delete_account_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/my_page_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/accessory_detail_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/accessory_list_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/needle_detail_screen.dart';
import 'package:moriknit_flutter/features/my/presentation/needle_list_screen.dart';
import 'package:moriknit_flutter/features/pattern/presentation/pattern_editor_screen.dart';
import 'package:moriknit_flutter/features/pattern/presentation/pattern_list_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_input_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_list_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_patterns_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/template_list_screen.dart';
import 'package:moriknit_flutter/features/project/domain/user_template.dart';
import 'package:moriknit_flutter/features/project/presentation/template_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/template_editor_screen.dart';
import 'package:moriknit_flutter/features/ravelry/data/ravelry_auth_provider.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_detail_screen.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_input_screen.dart';
import 'package:moriknit_flutter/features/swatch/presentation/swatch_list_screen.dart';
import 'package:moriknit_flutter/features/tools/presentation/tools_screen.dart';
import 'package:moriknit_flutter/features/tools/presentation/tool_memo_screen.dart';
import 'package:moriknit_flutter/features/ravelry/presentation/ravelry_screen.dart';
import 'package:moriknit_flutter/features/etsy/presentation/etsy_screen.dart';
import 'package:moriknit_flutter/features/tools/presentation/needle_size_converter_screen.dart';
import 'package:moriknit_flutter/features/yarn/domain/yarn_model.dart';
import 'package:moriknit_flutter/features/yarn/presentation/yarn_input_screen.dart';
import 'package:moriknit_flutter/features/yarn/presentation/yarn_detail_screen.dart';
import 'package:moriknit_flutter/features/yarn/presentation/yarn_list_screen.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

export 'routes.dart';
import 'routes.dart';

// ── 페이지 전환 헬퍼 ─────────────────────────────────────────
Page<void> _noTransitionPage(Widget child) => NoTransitionPage(child: child);

Page<void> _fadePage(Widget child) => CustomTransitionPage(
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut), child: child),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  bool authInitialized = false;
  // .map() 변환 안에서 동기적으로 플래그 세팅 → notifyListeners() 이전에 확정됨
  final authRefresh = GoRouterRefreshStream(
    authRepository.authStateChanges.map((user) {
      authInitialized = true;
      return user;
    }),
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authRefresh,

    redirect: (context, state) {
      // auth 상태가 아직 초기화되지 않은 경우 redirect 보류 (로그인 화면 깜빡임 방지)
      if (!authInitialized) return null;

      final isLoggedIn = authRepository.currentUser != null;
      final location = state.matchedLocation;
      final isSplash = location == Routes.splash;
      final isLogin = location == Routes.login;
      final isPublicWebRoute = kIsWeb && (location == Routes.market || location == Routes.community || location == Routes.projectList);

      if (isSplash) {
        return null; // SplashScreen handles its own navigation after animation
      }
      if (!isLoggedIn && !isLogin && !isPublicWebRoute) {
        return Routes.login;
      }
      if (isLoggedIn && isLogin) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) return from;
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, pageBuilder: (_, _) => _fadePage(const LoginScreen())),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, pageBuilder: (_, _) => _noTransitionPage(const HomeScreen())),
          GoRoute(
            path: Routes.projectList,
            pageBuilder: (_, _) => _noTransitionPage(const ProjectListScreen()),
            routes: [
              GoRoute(path: 'input', pageBuilder: (_, _) => _fadePage(const ProjectInputScreen())),
              GoRoute(path: 'patterns', pageBuilder: (_, _) => _fadePage(const ProjectPatternsScreen())),
              GoRoute(path: ':id', pageBuilder: (_, state) => _fadePage(ProjectDetailScreen(projectId: state.pathParameters['id']!))),
            ],
          ),
          GoRoute(
            path: Routes.swatchList,
            pageBuilder: (_, _) => _noTransitionPage(const SwatchListScreen()),
            routes: [
              GoRoute(path: 'input', pageBuilder: (_, _) => _fadePage(const SwatchInputScreen())),
              GoRoute(path: ':id', pageBuilder: (_, state) => _fadePage(SwatchDetailScreen(swatchId: state.pathParameters['id']!))),
            ],
          ),
          GoRoute(
            path: Routes.tools,
            pageBuilder: (_, _) => _noTransitionPage(const ToolsScreen()),
            routes: [
              GoRoute(path: 'patterns', pageBuilder: (_, _) => _fadePage(const PatternListScreen())),
              GoRoute(
                path: 'pattern',
                pageBuilder: (_, _) => _fadePage(const PatternEditorScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, state) => _fadePage(PatternEditorScreen(patternId: state.pathParameters['id'])),
                  ),
                ],
              ),
              GoRoute(path: 'gauge', pageBuilder: (_, _) => _fadePage(const GaugeCalculatorScreen())),
              GoRoute(path: 'course', pageBuilder: (_, _) => _fadePage(const CourseScreen())),
              GoRoute(path: 'encyclopedia', pageBuilder: (_, _) => _fadePage(const EncyclopediaScreen())),
              GoRoute(path: 'memo', pageBuilder: (_, _) => _fadePage(const ToolMemoScreen())),
              GoRoute(path: 'ravelry', pageBuilder: (_, _) => _fadePage(const RavelryScreen())),
              GoRoute(path: 'etsy', pageBuilder: (_, _) => _fadePage(const EtsyScreen())),
              GoRoute(path: 'needle-size', pageBuilder: (_, _) => _fadePage(const NeedleSizeConverterScreen())),
            ],
          ),
          GoRoute(path: Routes.community, pageBuilder: (_, _) => _noTransitionPage(const CommunityScreen())),
          GoRoute(path: Routes.messenger, pageBuilder: (_, _) => _noTransitionPage(const DmListScreen())),
          GoRoute(
            path: Routes.dm,
            pageBuilder: (_, _) => _noTransitionPage(const DmListScreen()),
            routes: [
              GoRoute(path: ':roomId', pageBuilder: (_, state) => _fadePage(DmChatScreen(roomId: state.pathParameters['roomId']!))),
            ],
          ),
          GoRoute(path: Routes.market, pageBuilder: (_, _) => _noTransitionPage(const MarketScreen())),
          GoRoute(
            path: Routes.my,
            pageBuilder: (_, _) => _noTransitionPage(const MyPageScreen()),
            routes: [
              GoRoute(path: 'needles', pageBuilder: (_, _) => _fadePage(const NeedleListScreen())),
              GoRoute(path: 'accessories', pageBuilder: (_, _) => _fadePage(const AccessoryListScreen())),
              GoRoute(path: 'delete-account', pageBuilder: (_, _) => _fadePage(const DeleteAccountScreen())),
            ],
          ),
          GoRoute(path: Routes.counterList, pageBuilder: (_, _) => _noTransitionPage(const CounterListScreen())),
          GoRoute(
            path: Routes.templateList,
            pageBuilder: (_, _) => _noTransitionPage(const TemplateListScreen()),
            routes: [
              GoRoute(
                path: 'editor',
                pageBuilder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _fadePage(TemplateEditorScreen(
                    templateId: extra?['templateId'] as String?,
                    initialTitle: extra?['title'] as String?,
                    initialSteps: (extra?['steps'] as List?)?.map((e) => e.toString()).toList(),
                    initialStepDescs: (extra?['stepDescs'] as List?)?.map((e) => e.toString()).toList(),
                  ));
                },
              ),
              GoRoute(
                path: 'detail',
                pageBuilder: (_, state) {
                  final tmpl = state.extra as UserTemplate;
                  return _fadePage(TemplateDetailScreen(template: tmpl));
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/counter/:id', pageBuilder: (_, state) => _fadePage(CounterScreen(counterId: state.pathParameters['id']!))),
      GoRoute(path: '/yarn-list', pageBuilder: (_, _) => _fadePage(const YarnListScreen())),
      GoRoute(path: '/yarn-detail/:id', pageBuilder: (_, state) => _fadePage(YarnDetailScreen(yarnId: state.pathParameters['id']!))),
      GoRoute(path: '/needle-detail/:id', pageBuilder: (_, state) => _fadePage(NeedleDetailScreen(needleId: state.pathParameters['id']!))),
      GoRoute(path: '/accessory-detail/:id', pageBuilder: (_, state) => _fadePage(AccessoryDetailScreen(itemId: state.pathParameters['id']!))),
      GoRoute(
        path: '/yarn-input',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _fadePage(YarnInputScreen(
            yarnId: extra?['yarnId'] as String?,
            initialYarn: extra?['initialYarn'] as YarnModel?,
          ));
        },
      ),
    ],
    errorBuilder: (_, state) {
      if (state.uri.toString().contains('oauth-callback/ravelry')) {
        return _RavelryOAuthCallbackScreen(uri: state.uri);
      }
      return Scaffold(body: Center(child: Text('Page not found: ${state.error}')));
    },
  );
});

class _RavelryOAuthCallbackScreen extends ConsumerStatefulWidget {
  const _RavelryOAuthCallbackScreen({required this.uri});

  final Uri uri;

  @override
  ConsumerState<_RavelryOAuthCallbackScreen> createState() =>
      _RavelryOAuthCallbackScreenState();
}

class _RavelryOAuthCallbackScreenState
    extends ConsumerState<_RavelryOAuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(ravelryAuthProvider.notifier)
          .handleOAuthCallback(widget.uri);
      if (!mounted) return;
      context.go(Routes.ravelry);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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
