import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/counter/domain/counter_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/counter_provider.dart';
import '../localization/app_language.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith(Routes.projectList)) return 1;
    if (location.startsWith(Routes.swatchList)) return 2;
    if (location.startsWith(Routes.community)) return 4;
    if (location.startsWith(Routes.market)) return 5;
    if (location.startsWith(Routes.my)) return 6;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);
    final profile = ref.watch(currentUserProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : ((authUser?.displayName?.isNotEmpty ?? false) ? authUser!.displayName! : (authUser?.email ?? 'M'));
    final avatarInitial = displayName.trim().isEmpty ? 'M' : displayName.trim().characters.first.toUpperCase();
    final avatarUrl = (profile?.photoURL.isNotEmpty == true) ? profile!.photoURL : (authUser?.photoURL ?? '');

    final tabs = [
      MoriTabDestination(Icons.home_rounded, t.home, C.pk),
      MoriTabDestination(Icons.folder_rounded, t.projects, C.lv),
      MoriTabDestination(Icons.grid_view_rounded, t.swatches, C.lmD),
      MoriTabDestination(Icons.handyman_rounded, t.tools, C.og),
      MoriTabDestination(Icons.people_alt_rounded, t.community, C.pkD),
      MoriTabDestination(Icons.storefront_rounded, t.market, C.lvD),
      MoriTabDestination(Icons.person_rounded, t.my, C.tx, avatarUrl: avatarUrl, avatarInitial: authUser == null ? null : avatarInitial),
    ];

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [const BgOrbs(), child]),
      floatingActionButton: SizedBox(
        height: 56,
        child: FloatingActionButton.extended(
          heroTag: 'main_create_fab',
          onPressed: () => _showQuickCreate(context, ref),
          backgroundColor: C.lm,
          foregroundColor: const Color(0xFF1a3000),
          shape: const StadiumBorder(),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
          icon: const Icon(Icons.add, size: 22),
          label: Text(t.create, style: T.bodyBold.copyWith(color: const Color(0xFF1a3000))),
        ),
      ),
      bottomNavigationBar: MoriTabBar(currentIndex: currentIndex, tabs: tabs, onTap: (i) => _onTap(context, ref, i)),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        context.go(Routes.home);
        return;
      case 1:
        context.go(Routes.projectList);
        return;
      case 2:
        context.go(Routes.swatchList);
        return;
      case 3:
        _showToolsHub(context, ref);
        return;
      case 4:
        context.go(Routes.community);
        return;
      case 5:
        context.go(Routes.market);
        return;
      case 6:
        context.go(Routes.my);
        return;
    }
  }

  void _showToolsHub(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.toolHub, style: T.h3),
              const SizedBox(height: 6),
              Text(t.toolHubDescription, style: T.caption.copyWith(color: C.mu)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CreateChip(icon: Icons.grid_on_rounded, label: t.patternEditor, color: C.lv, onTap: () { Navigator.pop(ctx); context.push(Routes.toolsPattern); }),
                  _CreateChip(icon: Icons.calculate_rounded, label: t.gaugeCalculator, color: C.pk, onTap: () { Navigator.pop(ctx); context.push(Routes.toolsGauge); }),
                  _CreateChip(icon: Icons.exposure_plus_1_rounded, label: t.newCounter, color: C.lmD, onTap: () { Navigator.pop(ctx); _createCounter(context, ref); }),
                  _CreateChip(icon: Icons.apps_rounded, label: t.openToolsPage, color: C.og, onTap: () { Navigator.pop(ctx); context.go(Routes.tools); }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickCreate(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.createActivity, style: T.h3),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CreateChip(icon: Icons.grid_view_rounded, label: t.swatches, color: C.lmD, onTap: () { Navigator.pop(ctx); context.push(Routes.swatchInput); }),
                  _CreateChip(icon: Icons.folder_rounded, label: t.projects, color: C.lv, onTap: () { Navigator.pop(ctx); context.push(Routes.projectInput); }),
                  _CreateChip(icon: Icons.grid_on_rounded, label: t.patternEditor, color: C.pk, onTap: () { Navigator.pop(ctx); context.push(Routes.toolsPattern); }),
                  _CreateChip(icon: Icons.exposure_plus_1_rounded, label: t.newCounter, color: C.pkD, onTap: () { Navigator.pop(ctx); _createCounter(context, ref); }),
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

  void _createCounter(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go(Routes.login);
      return;
    }
    final ctrl = TextEditingController(text: t.newCounter);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.newCounter, style: T.h3),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: t.newCounter), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close)),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final counter = CounterModel.empty(uid: user.uid, name: name);
              final saved = await ref.read(counterRepositoryProvider).createCounter(counter);
              if (context.mounted) context.push('/counter/${saved.id}');
            },
            child: Text(t.create),
          ),
        ],
      ),
    );
  }
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
