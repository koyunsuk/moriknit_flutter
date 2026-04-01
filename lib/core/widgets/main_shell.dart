import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/avatar_provider.dart';
import '../localization/app_language.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _fabOpen = false;

  int _locationToIndex(String location) {
    if (location.startsWith(Routes.tools)) return 1;
    if (location.startsWith(Routes.projectList)) return 1;
    if (location.startsWith(Routes.swatchList)) return 1;
    if (location.startsWith(Routes.counterList)) return 1;
    if (location.startsWith(Routes.community)) return 2;
    if (location.startsWith(Routes.messenger)) return 3;
    if (location.startsWith(Routes.market)) return 4;
    if (location.startsWith(Routes.my)) return 5;
    return 0;
  }

  void _closeFab() => setState(() => _fabOpen = false);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = kIsWeb || screenWidth >= 900;

    if (isWide) {
      return _WebShell(locationIndex: _locationToIndex(GoRouterState.of(context).matchedLocation), child: widget.child);
    }

    final t = ref.watch(appStringsProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);
    final profile = ref.watch(currentUserProvider).valueOrNull;
    final avatarPreset = ref.watch(avatarPresetProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : ((authUser?.displayName?.isNotEmpty ?? false) ? authUser!.displayName! : (authUser?.email ?? 'M'));
    final avatarInitial = displayName.trim().isEmpty ? 'M' : displayName.trim().characters.first.toUpperCase();
    final avatarUrl = (profile?.photoURL.isNotEmpty == true) ? profile!.photoURL : (authUser?.photoURL ?? '');

    final tabs = [
      MoriTabDestination(Icons.home_rounded, t.home, C.pk),
      MoriTabDestination(Icons.folder_special_rounded, t.projectsTabLabel, C.lv),
      MoriTabDestination(Icons.people_alt_rounded, t.community, C.pkD),
      MoriTabDestination(Icons.chat_bubble_outline_rounded, t.messengerTabLabel, C.lmD),
      MoriTabDestination(Icons.storefront_rounded, t.market, C.lvD),
      MoriTabDestination(Icons.person_rounded, t.my, C.tx, avatarUrl: avatarUrl, avatarInitial: authUser == null ? null : avatarInitial, avatarPreset: avatarPreset),
    ];

    final speedItems = [
      _SpeedItem(icon: Icons.folder_open_rounded, label: '새 프로젝트', color: C.lv, onTap: () { _closeFab(); context.push(Routes.projectInput); }),
      _SpeedItem(icon: Icons.grid_view_rounded, label: t.swatches, color: C.lmD, onTap: () { _closeFab(); context.push(Routes.swatchInput); }),
      _SpeedItem(icon: Icons.edit_note_rounded, label: '새 메모', color: C.pk, onTap: () { _closeFab(); context.push(Routes.toolsMemo); }),
      _SpeedItem(icon: Icons.exposure_plus_1_rounded, label: t.newCounter, color: C.pkD, onTap: () { _closeFab(); context.push(Routes.counterList); }),
    ];

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          widget.child,
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _SpeedDial(
          open: _fabOpen,
          onToggle: () => setState(() => _fabOpen = !_fabOpen),
          items: speedItems,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: MoriTabBar(currentIndex: currentIndex, tabs: tabs, onTap: (i) => _onTap(context, i)),
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(Routes.home); return;
      case 1: context.go(Routes.tools); return;
      case 2: context.go(Routes.community); return;
      case 3: context.go(Routes.messenger); return;
      case 4: context.go(Routes.market); return;
      case 5: context.go(Routes.my); return;
    }
  }

}

class _SpeedItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpeedItem({required this.icon, required this.label, required this.color, required this.onTap});
}

class _SpeedDial extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final List<_SpeedItem> items;
  const _SpeedDial({required this.open, required this.onToggle, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...items.asMap().entries.map((e) {
          final item = e.value;
          return IgnorePointer(
            ignoring: !open,
            child: AnimatedSlide(
              offset: open ? Offset.zero : const Offset(0, 0.3),
              duration: Duration(milliseconds: 150 + e.key * 30),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: Duration(milliseconds: 150 + e.key * 30),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8)],
                          ),
                          child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton.small(
                        heroTag: 'fab_${item.label}',
                        onPressed: item.onTap,
                        backgroundColor: item.color,
                        foregroundColor: Colors.white,
                        child: Icon(item.icon, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'main_speed_fab',
          onPressed: onToggle,
          backgroundColor: C.lm,
          foregroundColor: const Color(0xFF1a3000),
          elevation: open ? 6 : 4,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, size: 26),
          ),
        ),
      ],
    );
  }
}

class _WebShell extends ConsumerWidget {
  final Widget child;
  final int locationIndex;
  const _WebShell({required this.child, required this.locationIndex});

  static const double _sidebarBreakpoint = 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth >= _sidebarBreakpoint;

    final t = ref.watch(appStringsProvider);
    final profile = ref.watch(currentUserProvider).valueOrNull;
    final avatarPreset = ref.watch(avatarPresetProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : ((authUser?.displayName?.isNotEmpty ?? false) ? authUser!.displayName! : (authUser?.email ?? 'Maker'));
    final avatarUrl = (profile?.photoURL.isNotEmpty == true) ? profile!.photoURL : (authUser?.photoURL ?? '');
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;

    final navItems = [
      _WebNavItem(Icons.home_rounded, t.home, C.pk, Routes.home),
      _WebNavItem(Icons.folder_special_rounded, t.projectsTabLabel, C.lv, Routes.tools),
      _WebNavItem(Icons.people_alt_rounded, t.community, C.pkD, Routes.community),
      _WebNavItem(Icons.chat_bubble_outline_rounded, t.messengerTabLabel, C.lmD, Routes.messenger),
      _WebNavItem(Icons.storefront_rounded, t.market, C.lvD, Routes.market),
      _WebNavItem(Icons.person_rounded, t.my, C.tx2, Routes.my),
      if (isAdmin) _WebNavItem(Icons.admin_panel_settings_rounded, t.adminLabel, const Color(0xFF1A1A2E), Routes.admin),
    ];

    final sidebarContent = _buildSidebarContent(context, ref, t, navItems, displayName, avatarUrl, avatarPreset, authUser);

    if (!showSidebar) {
      // Narrow web window: use drawer
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 52,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_rounded, color: C.tx),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const MoriKnitTitle(fontSize: 18),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: C.bd2),
          ),
        ),
        drawer: Drawer(
          backgroundColor: C.gx,
          child: SafeArea(child: sidebarContent),
        ),
        body: Stack(
          children: [
            const BgOrbs(),
            child,
          ],
        ),
      );
    }

    // Wide window: fixed sidebar layout
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: C.bg,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16)],
            ),
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 220,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: C.gx,
                    border: Border(right: BorderSide(color: C.bd2, width: 1)),
                  ),
                  child: sidebarContent,
                ),
                // Main content
                Expanded(
                  child: _WebContentArea(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    WidgetRef ref,
    dynamic t,
    List<_WebNavItem> navItems,
    String displayName,
    String avatarUrl,
    dynamic avatarPreset,
    dynamic authUser,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: const MoriKnitTitle(fontSize: 22),
        ),
        Divider(height: 1, color: C.bd2),
        const SizedBox(height: 8),
        ...List.generate(navItems.length, (i) {
          final item = navItems[i];
          final selected = i == locationIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.of(context).maybePop(); // close drawer if open
                if (kIsWeb && item.route == Routes.admin) {
                  launchUrl(Uri.base.resolve(Routes.admin), webOnlyWindowName: '_blank');
                } else {
                  context.go(item.route);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? C.lvL : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: selected ? C.lvD : C.mu),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: T.body.copyWith(
                        color: selected ? C.lvD : C.tx2,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Divider(height: 1, color: C.bd2),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ElevatedButton.icon(
            onPressed: () => _showWebCreate(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(t.createLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              elevation: 0,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const Spacer(),
        Divider(height: 1, color: C.bd2),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: C.lvL,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? MoriDefaultAvatar(size: 26, borderRadius: 999, preset: avatarPreset)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName, style: T.sm.copyWith(fontWeight: FontWeight.w700, color: C.tx), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (authUser?.email != null)
                      Text(authUser!.email!, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showWebCreate(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: C.bg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.createActivity, style: T.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CreateChip(icon: Icons.grid_view_rounded, label: t.swatches, color: C.lmD, onTap: () { Navigator.pop(ctx); context.push(Routes.swatchInput); }),
                  _CreateChip(icon: Icons.folder_rounded, label: t.projects, color: C.lv, onTap: () { Navigator.pop(ctx); context.push(Routes.projectInput); }),
                  _CreateChip(icon: Icons.grid_on_rounded, label: t.patternEditor, color: C.pk, onTap: () { Navigator.pop(ctx); context.push(Routes.toolsPattern); }),
                  _CreateChip(icon: Icons.people_alt_rounded, label: t.community, color: C.og, onTap: () { Navigator.pop(ctx); context.go(Routes.community); }),
                  _CreateChip(icon: Icons.storefront_rounded, label: t.market, color: C.lvD, onTap: () { Navigator.pop(ctx); context.go(Routes.market); }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebContentArea extends ConsumerStatefulWidget {
  final Widget child;
  const _WebContentArea({required this.child});

  @override
  ConsumerState<_WebContentArea> createState() => _WebContentAreaState();
}

class _WebContentAreaState extends ConsumerState<_WebContentArea> {
  bool _fabOpen = false;

  void _closeFab() => setState(() => _fabOpen = false);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final speedItems = [
      _SpeedItem(icon: Icons.folder_open_rounded, label: '새 프로젝트', color: C.lv, onTap: () { _closeFab(); context.push(Routes.projectInput); }),
      _SpeedItem(icon: Icons.grid_view_rounded, label: t.swatches, color: C.lmD, onTap: () { _closeFab(); context.push(Routes.swatchInput); }),
      _SpeedItem(icon: Icons.edit_note_rounded, label: '새 메모', color: C.pk, onTap: () { _closeFab(); context.push(Routes.toolsMemo); }),
      _SpeedItem(icon: Icons.exposure_plus_1_rounded, label: t.newCounter, color: C.pkD, onTap: () { _closeFab(); context.push(Routes.counterList); }),
    ];

    return Stack(
      children: [
        const BgOrbs(),
        widget.child,
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeFab,
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _SpeedDial(
            open: _fabOpen,
            onToggle: () => setState(() => _fabOpen = !_fabOpen),
            items: speedItems,
          ),
        ),
      ],
    );
  }
}

class _WebNavItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _WebNavItem(this.icon, this.label, this.color, this.route);
}


class _CreateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CreateChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(label, style: T.bodyBold.copyWith(color: color))]),
      ),
    );
  }
}
