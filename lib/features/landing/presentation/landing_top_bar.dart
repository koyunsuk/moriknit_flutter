import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/web_utils_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) '../../../core/utils/web_utils.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';

const String _mainAppUrl = 'https://app.moriknit.com';

const _kNavTextColor = Color(0xFF1A1A2E);
const _kDesktopBreakpoint = 900.0;

// ?? 硫붾돱 ?곗씠?????????????????????????????????????????????????????????????????

const _featureItems = [
  ('project', '프로젝트 기록'),
  ('swatch', '스와치 보관함'),
  ('market', '도안 마켓'),
  ('community', '커뮤니티'),
  ('encyclopedia', '뜨개 백과사전'),
  ('gauge', '게이지 계산기'),
  ('ravelry', 'Ravelry 연동'),
  ('etsy', 'Etsy 연동'),
  ('ai-gauge', 'AI 게이지 판독'),
];

const _boardItems = [
  ('/notices', '공지사항', Icons.campaign_rounded),
  ('/reviews', '리뷰 게시판', Icons.star_rounded),
  ('/releases', '릴리즈 노트', Icons.new_releases_rounded),
  ('/qa', '문의하기 Q&A', Icons.help_outline_rounded),
];

// ?? 踰꾪듉 ?ㅽ??????????????????????????????????????????????????????????????????

ButtonStyle _topBarButtonStyle() => ElevatedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      textStyle: T.bodyBold.copyWith(fontSize: 15, height: 1.1),
    );

// ?? ?ㅽ뙆???뚰떚????????????????????????????????????????????????????????????????
class SparkleParticle {
  final AnimationController controller;
  final double x;
  final String emoji;
  final double drift;
  final double size;

  SparkleParticle({
    required this.controller,
    required this.x,
    required this.emoji,
    required this.drift,
    required this.size,
  });
}

// ?? ?쒕∼?ㅼ슫 ?ㅻ쾭?덉씠 ??????????????????????????????????????????????????????????

class _DropdownOverlay extends StatefulWidget {
  const _DropdownOverlay({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  State<_DropdownOverlay> createState() => _DropdownOverlayState();
}

class _DropdownOverlayState extends State<_DropdownOverlay> {
  OverlayEntry? _entry;
  final _layerLink = LayerLink();
  bool _open = false;

  void _show() {
    if (_open) {
      _hide();
      return;
    }
    _open = true;
    _entry = OverlayEntry(
      builder: (_) => _DropdownPanel(
        link: _layerLink,
        onClose: _hide,
        children: widget.children,
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _open || _hovered;
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _show,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? C.lv.withValues(alpha: 0.09) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? C.lv : _kNavTextColor,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: active ? C.lv : _kNavTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownPanel extends StatelessWidget {
  const _DropdownPanel({
    required this.link,
    required this.children,
    required this.onClose,
  });

  final LayerLink link;
  final List<Widget> children;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownItem extends StatefulWidget {
  const _DropdownItem({
    required this.label,
    this.icon,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered ? C.lv.withValues(alpha: 0.07) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: C.lv),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: _kNavTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ?? ?ㅻ퉬寃뚯씠???띿뒪??踰꾪듉 ?????????????????????????????????????????????????????

class _NavTextButton extends StatefulWidget {
  const _NavTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_NavTextButton> createState() => _NavTextButtonState();
}

class _NavTextButtonState extends State<_NavTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? C.lv.withValues(alpha: 0.09) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: _hovered ? C.lv : _kNavTextColor,
            ),
          ),
        ),
      ),
    );
  }
}


// 무료 배지 포함 네비게이션 버튼
class _FreeNavButton extends StatefulWidget {
  const _FreeNavButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_FreeNavButton> createState() => _FreeNavButtonState();
}

class _FreeNavButtonState extends State<_FreeNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? C.lv.withValues(alpha: 0.09) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: _hovered ? C.lv : _kNavTextColor,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: C.lv.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '무료',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.lv),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ?? 紐⑤컮???ㅻ쾭?덉씠 ?쒕줈???????????????????????????????????????????????????????

class _MobileDrawerOverlay extends StatefulWidget {
  const _MobileDrawerOverlay({
    required this.isLoggedIn,
    required this.onClose,
    required this.onNavigate,
  });

  final bool isLoggedIn;
  final VoidCallback onClose;
  final void Function(String path) onNavigate;

  @override
  State<_MobileDrawerOverlay> createState() => _MobileDrawerOverlayState();
}

class _MobileDrawerOverlayState extends State<_MobileDrawerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _featuresExpanded = false;
  bool _boardExpanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onNavigate('/'),
                      child: const Row(
                        children: [
                          MoriLogo(size: 28),
                          SizedBox(width: 8),
                          MoriKnitTitle(fontSize: 17),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _close,
                      color: _kNavTextColor,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _mobileTile('서비스 소개', onTap: () => widget.onNavigate('/service')),
                    _mobileExpansion(
                      label: '기능',
                      expanded: _featuresExpanded,
                      onToggle: () =>
                          setState(() => _featuresExpanded = !_featuresExpanded),
                      children: _featureItems
                          .map(
                            (e) => _mobileTile(
                              e.$2,
                              indent: true,
                              onTap: () => widget.onNavigate('/features/${e.$1}'),
                            ),
                          )
                          .toList(),
                    ),
                    _mobileFreeInfoTile('뜨개백과', Icons.menu_book_rounded, () => widget.onNavigate('/encyclopedia')),
                    _mobileFreeInfoTile('클라스', Icons.school_rounded, () => widget.onNavigate('/classes')),
                    _mobileExpansion(
                      label: '게시판',
                      expanded: _boardExpanded,
                      onToggle: () =>
                          setState(() => _boardExpanded = !_boardExpanded),
                      children: _boardItems
                          .map(
                            (e) => _mobileTile(
                              e.$2,
                              indent: true,
                              icon: e.$3,
                              onTap: () => widget.onNavigate(e.$1),
                            ),
                          )
                          .toList(),
                    ),
                    _mobileTile('요금제', onTap: () => widget.onNavigate('/pricing')),
                    const Divider(height: 24),
                    if (widget.isLoggedIn) ...[
                      _mobileTile('앱으로 이동',
                          onTap: () => widget.onNavigate('__app__')),
                      _mobileTile('로그아웃',
                          onTap: () => widget.onNavigate('__logout__')),
                    ] else ...[
                      _mobileTile('로그인', onTap: () => widget.onNavigate('/login')),
                      _mobileTile('무료로 시작하기',
                          onTap: () => widget.onNavigate('/signup?source=topbar'),
                          highlight: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileTile(
    String label, {
    required VoidCallback onTap,
    bool indent = false,
    bool highlight = false,
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon, size: 20, color: C.lv) : null,
      contentPadding: EdgeInsets.symmetric(horizontal: indent ? 36 : 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          color: highlight ? C.lv : _kNavTextColor,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _mobileFreeInfoTile(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: C.lv),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _kNavTextColor)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('무료', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.lv)),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _mobileExpansion({
    required String label,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _kNavTextColor,
            ),
          ),
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: _kNavTextColor),
          ),
          onTap: onToggle,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

// ?? ?쒕뵫 怨듭슜 ?묐컮 ????????????????????????????????????????????????????????????
class LandingTopBar extends ConsumerStatefulWidget {
  const LandingTopBar({super.key});

  @override
  ConsumerState<LandingTopBar> createState() => _LandingTopBarState();
}

class _LandingTopBarState extends ConsumerState<LandingTopBar> with TickerProviderStateMixin {
  static const _emojis = ['✨', '🧶', '💜', '🍵', '🌿', '📌', '🤍'];
  final _rng = Random();
  final _particles = <SparkleParticle>[];
  Timer? _sparkleTimer;

  OverlayEntry? _mobileOverlay;

  @override
  void initState() {
    super.initState();
    _sparkleTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _spawnParticle());
  }

  void _spawnParticle() {
    if (!mounted) return;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    final p = SparkleParticle(
      controller: ctrl,
      x: _rng.nextDouble(),
      emoji: _emojis[_rng.nextInt(_emojis.length)],
      drift: (_rng.nextDouble() - 0.5) * 20,
      size: 14 + _rng.nextDouble() * 10,
    );
    setState(() => _particles.add(p));
    ctrl.forward().then((_) {
      if (mounted) setState(() => _particles.remove(p));
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    _sparkleTimer?.cancel();
    for (final p in _particles) {
      p.controller.dispose();
    }
    _mobileOverlay?.remove();
    super.dispose();
  }

  void _openMobileMenu(bool isLoggedIn) {
    if (_mobileOverlay != null) return;
    _mobileOverlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _MobileDrawerOverlay(
          isLoggedIn: isLoggedIn,
          onClose: _closeMobileMenu,
          onNavigate: (path) {
            _closeMobileMenu();
            if (path == '__app__') {
              goToWebUrl('$_mainAppUrl/home');
            } else if (path == '__logout__') {
              FirebaseAuth.instance.signOut();
            } else if (path.contains('?')) {
              final uri = Uri.parse(path);
              context.go(uri.path, extra: uri.queryParameters);
            } else {
              context.go(path);
            }
          },
        ),
      ),
    );
    Overlay.of(context).insert(_mobileOverlay!);
  }

  void _closeMobileMenu() {
    _mobileOverlay?.remove();
    _mobileOverlay = null;
  }

  Widget _featureDropdown(BuildContext context) {
    return _DropdownOverlay(
      label: '기능',
      children: _featureItems
          .map((e) => _DropdownItem(
                label: e.$2,
                onTap: () => context.go('/features/${e.$1}'),
              ))
          .toList(),
    );
  }

  Widget _boardDropdown(BuildContext context) {
    return _DropdownOverlay(
      label: '게시판',
      children: _boardItems
          .map((e) => _DropdownItem(
                label: e.$2,
                icon: e.$3,
                onTap: () => context.go(e.$1),
              ))
          .toList(),
    );
  }

  // ?? build ?????????????????????????????????????????????????????????????????

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isLoggedIn = user != null;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _kDesktopBreakpoint;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: C.bd.withValues(alpha: 0.6))),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    // ?? 濡쒓퀬 ????????????????????????????????????????????????
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: const Row(
                          children: [
                            MoriLogo(size: 32),
                            SizedBox(width: 10),
                            MoriKnitTitle(fontSize: 19),
                          ],
                        ),
                      ),
                    ),

                    if (isDesktop) ...[
                      const SizedBox(width: 32),
                      // ?? ?곗뒪?ы깙 ?ㅻ퉬寃뚯씠?????????????????????????????????
                      _NavTextButton(label: '서비스 소개', onTap: () => context.go('/service')),
                      _featureDropdown(context),
                      _FreeNavButton(label: '뜨개백과', onTap: () => context.go('/encyclopedia')),
                      _FreeNavButton(label: '클라스', onTap: () => context.go('/classes')),
                      _boardDropdown(context),
                      _NavTextButton(label: '요금제', onTap: () => context.go('/pricing')),

                      const Spacer(),


                      // ?? ?곗뒪?ы깙 ?곗륫 踰꾪듉 ??????????????????????????????
                      if (isLoggedIn) ...[
                        TextButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: Text('로그아웃', style: TextStyle(color: Colors.grey[600])),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: () => goToWebUrl('$_mainAppUrl/home'),
                          style: _topBarButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(C.lv),
                            foregroundColor: const WidgetStatePropertyAll(Colors.white),
                          ),
                          child: const Text('앱으로 이동',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ] else ...[
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('로그인'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => context.go('/signup?source=topbar'),
                          style: _topBarButtonStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(C.lv),
                            foregroundColor: const WidgetStatePropertyAll(Colors.white),
                          ),
                          child: const Text('무료로 시작하기',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ] else ...[
                      // ?? 紐⑤컮??????????????????????????????????????????????
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, size: 26),
                        color: _kNavTextColor,
                        onPressed: () => _openMobileMenu(isLoggedIn),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ?? ?ㅽ뙆???뚰떚??????????????????????????????????????????????????
          ..._particles.map((p) => AnimatedBuilder(
                animation: p.controller,
                builder: (context, _) {
                  final t = p.controller.value;
                  final opacity = t < 0.15 ? t / 0.15 : t > 0.65 ? (1 - t) / 0.35 : 1.0;
                  final barWidth = MediaQuery.of(context).size.width;
                  return Positioned(
                    left: p.x * barWidth + p.drift * t * 2,
                    bottom: 4 + 48 * t,
                    child: Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.7 + 0.5 * (1 - t),
                        child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
                      ),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}

