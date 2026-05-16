// 이슈 #723 — 헤더+바디+독 셸 구조.
//
// 모든 화면이 이 위젯으로 감싸지면, 헤더/배경/SafeArea/뒤로가기 등을 한 곳에서 제어.
// 헤더 토큰(HeaderTheme)과 결합되어 한 곳 수정 = 모든 화면 일괄 반영.
//
// 사용:
// ```dart
// return AppShellScaffold(
//   subtitle: '내 스와치',
//   trailing: [IconButton(...)],
//   showBackButton: true,
//   body: 본문위젯,
// );
// ```

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'common_widgets.dart';
import 'network_badge.dart';

class AppShellScaffold extends StatelessWidget {
  /// 메인 본문.
  final Widget body;

  /// 헤더 서브타이틀 (null 또는 빈 문자열 시 헤더 자체 표시 X).
  final String? subtitle;

  /// 헤더 타이틀 (MoriWideHeader.title 호환, 표시 안 됨 — 잔존 필드).
  final String? title;

  /// 헤더 우측 trailing 위젯 (아이콘 버튼 등).
  final List<Widget>? trailing;

  /// 헤더 아래·본문 위 (TabBar/카테고리칩 등) 영역.
  final Widget? aboveBody;

  /// 헤더 표시 여부.
  final bool showHeader;

  /// 배경 BgOrbs 표시 여부.
  final bool showBgOrbs;

  /// 컴팩트 헤더 사용 (모바일 좁은 화면).
  final bool compact;

  /// 뒤로가기 버튼 표시 여부 (headerLeading 자동 배치).
  final bool showBackButton;

  /// 이슈 #727 — 뒤로가기 버튼 커스텀 콜백.
  /// null이면 기본 동작 (context.pop / Navigator.maybePop).
  /// dirty 가드, 사용자 확인 등을 위해 화면별 오버라이드 가능.
  /// 반환 false: pop 차단. true 또는 void: 기본 pop 실행.
  final Future<bool> Function()? onBackPressed;

  /// SafeArea 사용 여부.
  final bool useSafeArea;

  /// 하단 네비게이션 / 액션 영역 (Scaffold.bottomNavigationBar).
  final Widget? bottom;

  /// FloatingActionButton.
  final Widget? floatingActionButton;

  const AppShellScaffold({
    super.key,
    required this.body,
    this.subtitle,
    this.title,
    this.trailing,
    this.aboveBody,
    this.showHeader = true,
    this.showBgOrbs = true,
    this.compact = false,
    this.showBackButton = false,
    this.onBackPressed,
    this.useSafeArea = true,
    this.bottom,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // 이슈 #704 — 헤더 trailing 앞에 NetworkBadge 자동 prepend.
    // 온라인 상태에서는 SizedBox.shrink() 반환하므로 공간 차지 X.
    // 오프라인 상태일 때만 작은 칩으로 표시.
    final List<Widget> effectiveTrailing = <Widget>[
      const NetworkBadge(),
      if (trailing != null) ...trailing!,
    ];

    final content = Column(
      children: [
        if (showHeader)
          Stack(
            children: [
              MoriPageHeaderShell(
                child: MoriWideHeader(
                  title: title ?? '',
                  subtitle: subtitle ?? '',
                  trailing: effectiveTrailing,
                  compact: compact,
                ),
              ),
              if (showBackButton)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    color: C.tx,
                    onPressed: () async {
                      // 이슈 #727 — 화면별 onBackPressed 콜백 우선.
                      // false 반환 시 pop 차단 (dirty 가드 등에서 활용).
                      if (onBackPressed != null) {
                        final allow = await onBackPressed!();
                        if (!allow) return;
                      }
                      if (!context.mounted) return;
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ),
            ],
          ),
        if (aboveBody != null) aboveBody!,
        Expanded(child: body),
      ],
    );

    return Scaffold(
      backgroundColor: showBgOrbs ? Colors.transparent : C.bg,
      bottomNavigationBar: bottom,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          if (showBgOrbs) const BgOrbs(),
          useSafeArea ? SafeArea(child: content) : content,
        ],
      ),
    );
  }
}
