// 이슈 #727 — 메인 5탭 물리 뒤로가기 처리 wrapper.
// 홈 탭: "한 번 더 누르면 종료" 더블탭 패턴.
// 비-홈 메인 탭: 홈으로 이동 (탭 히스토리 단순화).
//
// 사용: app_router.dart의 메인 5탭 GoRoute pageBuilder에서 child를 이 위젯으로 wrap.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_language.dart';
import '../router/routes.dart';

class MainTabBackHandler extends ConsumerStatefulWidget {
  final Widget child;
  final bool isHome;
  const MainTabBackHandler({
    super.key,
    required this.child,
    this.isHome = false,
  });

  @override
  ConsumerState<MainTabBackHandler> createState() =>
      _MainTabBackHandlerState();
}

class _MainTabBackHandlerState extends ConsumerState<MainTabBackHandler> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // 홈 탭이 아니면 → 홈으로 이동
        if (!widget.isHome) {
          if (context.mounted) context.go(Routes.home);
          return;
        }
        // 홈 탭 최상위 → 더블탭 종료 패턴
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!).inSeconds < 2) {
          await SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        if (!context.mounted) return;
        final isKorean = ref.read(appLanguageProvider).isKorean;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? '한 번 더 누르면 종료돼요'
                  : 'Press back again to exit',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: widget.child,
    );
  }
}
