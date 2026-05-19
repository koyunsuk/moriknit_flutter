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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/favorites/data/favorites_provider.dart';
import '../../features/favorites/data/favorites_repository.dart';
import 'common_widgets.dart';
import 'network_badge.dart';

class AppShellScaffold extends ConsumerStatefulWidget {
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

  /// 즐겨찾기 ⭐ 토글 자동 prepend 옵션.
  /// `favoriteScreenId` 가 주어지면 trailing 첫 자리에 FavoriteToggleButton 자동 추가.
  final String? favoriteScreenId;
  final String? favoriteTitle;
  final IconData? favoriteIcon;
  final Color? favoriteAccent;

  /// 즐겨찾기 카드를 탭했을 때 이동할 경로.
  /// 미지정 시 현재 GoRouter 경로를 사용.
  final String? favoritePath;

  /// 토스트 메시지를 위한 언어 정보 (즐겨찾기 토글 시).
  final bool? favoriteIsKorean;

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
    this.favoriteScreenId,
    this.favoriteTitle,
    this.favoriteIcon,
    this.favoriteAccent,
    this.favoritePath,
    this.favoriteIsKorean,
  });

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishFavoriteCandidate());
  }

  @override
  void didUpdateWidget(covariant AppShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishFavoriteCandidate());
  }

  void _publishFavoriteCandidate() {
    if (!mounted) return;
    final id = widget.favoriteScreenId;
    final title = widget.favoriteTitle;
    final icon = widget.favoriteIcon;
    final accent = widget.favoriteAccent;
    if (id != null && title != null && icon != null && accent != null) {
      final path = widget.favoritePath ?? GoRouterState.of(context).uri.toString();
      ref.read(currentScreenFavoriteProvider.notifier).state = FavoriteScreen(
        screenId: id,
        title: title,
        icon: icon,
        path: path,
        accent: accent,
        addedAt: DateTime.now(),
      );
    } else {
      ref.read(currentScreenFavoriteProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ConsumerState 호환: widget.* 로 props 접근.
    final subtitle = widget.subtitle;
    final title = widget.title;
    final trailing = widget.trailing;
    final aboveBody = widget.aboveBody;
    final showHeader = widget.showHeader;
    final showBgOrbs = widget.showBgOrbs;
    final compact = widget.compact;
    final showBackButton = widget.showBackButton;
    final onBackPressed = widget.onBackPressed;
    final useSafeArea = widget.useSafeArea;
    final bottom = widget.bottom;
    final floatingActionButton = widget.floatingActionButton;
    final body = widget.body;
    // 이슈 #704 — 헤더 trailing 앞에 NetworkBadge 자동 prepend.
    // #766 — 즐겨찾기 ⭐는 헤더에서 제거하고 퀵버튼(메인 셸)으로 이동.
    final List<Widget> effectiveTrailing = <Widget>[
      const NetworkBadge(),
      if (trailing != null) ...trailing,
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
                        final allow = await onBackPressed();
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
        ?aboveBody,
        Expanded(child: body),
      ],
    );

    return Scaffold(
      // 이슈 #833 — MaterialPageRoute로 push된 화면에서 Scaffold가 transparent면
      // 라우트 아래 검은 캔버스가 비쳐서 까만 배경 발생.
      // BgOrbs는 투명 painter라 backgroundColor를 항상 C.bg로 두어도 시각 변화 없음.
      backgroundColor: C.bg,
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
