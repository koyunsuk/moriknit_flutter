import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/ravelry_auth_provider.dart';
import '../data/ravelry_repository.dart';
import '../domain/ravelry_models.dart';

class RavelryScreen extends ConsumerStatefulWidget {
  const RavelryScreen({super.key});

  @override
  ConsumerState<RavelryScreen> createState() => _RavelryScreenState();
}

class _RavelryScreenState extends ConsumerState<RavelryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(ravelryAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: 'Ravelry',
                subtitle: isKorean ? '라벨리 계정을 연결해 실과 도안을 관리하세요' : 'Connect your Ravelry account',
                trailing: auth.isLoggedIn
                    ? [
                        TextButton(
                          onPressed: () => ref.read(ravelryAuthProvider.notifier).logout(),
                          child: Text(isKorean ? '연결 해제' : 'Disconnect',
                              style: T.caption.copyWith(color: C.og)),
                        ),
                      ]
                    : null,
              ),
            ),
            Expanded(
              child: auth.isLoggedIn
                  ? _LoggedInBody(tabController: _tabController, isKorean: isKorean)
                  : _LoginPrompt(isKorean: isKorean),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 로그인 전 ──────────────────────────────────────────────────────────────────
class _LoginPrompt extends ConsumerWidget {
  const _LoginPrompt({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(ravelryAuthProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.texture, color: C.lv, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              isKorean ? 'Ravelry 계정 연결' : 'Connect Ravelry',
              style: T.h3,
            ),
            const SizedBox(height: 8),
            Text(
              isKorean
                  ? '라벨리 계정을 연결하면\n실 보관함, 도안 라이브러리, 프로젝트를\n모리니트에서 함께 관리할 수 있어요.'
                  : 'Connect your Ravelry account to manage your stash, pattern library, and projects.',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (auth.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: C.og.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  auth.error!.contains('User cancelled') || auth.error!.contains('cancelled')
                      ? (isKorean ? '로그인이 취소됐어요.' : 'Login was cancelled.')
                      : auth.error!,
                  style: T.caption.copyWith(color: C.og),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () => ref.read(ravelryAuthProvider.notifier).login(),
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(isKorean ? 'Ravelry로 로그인' : 'Login with Ravelry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 로그인 후 ──────────────────────────────────────────────────────────────────
class _LoggedInBody extends ConsumerWidget {
  const _LoggedInBody({required this.tabController, required this.isKorean});
  final TabController tabController;
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(ravelryAuthProvider);

    return Column(
      children: [
        // 사용자 이름
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: C.lv, size: 16),
              const SizedBox(width: 6),
              Text(
                isKorean ? '${auth.username ?? ''}님의 라벨리 계정 연결됨' : 'Connected as ${auth.username ?? ''}',
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 탭바
        TabBar(
          controller: tabController,
          tabs: [
            Tab(text: isKorean ? '실 보관함' : 'Stash'),
            Tab(text: isKorean ? '도안 라이브러리' : 'Patterns'),
            Tab(text: isKorean ? '프로젝트' : 'Projects'),
          ],
          labelColor: C.lv,
          unselectedLabelColor: C.mu,
          indicatorColor: C.lv,
          labelStyle: T.caption.copyWith(fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _StashTab(isKorean: isKorean),
              _LibraryTab(isKorean: isKorean),
              _ProjectsTab(isKorean: isKorean),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 스태시 탭 ─────────────────────────────────────────────────────────────────
class _StashTab extends ConsumerWidget {
  const _StashTab({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashAsync = ref.watch(ravelryStashProvider);
    return stashAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: '$e', isKorean: isKorean),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(
            icon: Icons.texture,
            message: isKorean ? '실 보관함이 비어 있어요' : 'Your stash is empty',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _StashCard(item: items[i], isKorean: isKorean),
        );
      },
    );
  }
}

class _StashCard extends StatelessWidget {
  const _StashCard({required this.item, required this.isKorean});
  final RavelryStashEntry item;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.thumbnailUrl != null
                  ? CachedNetworkImage(imageUrl: item.thumbnailUrl!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: C.lvL, child: Icon(Icons.texture, color: C.lv)))
                  : Container(color: C.lvL, child: Icon(Icons.texture, color: C.lv)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.yarnName != null)
                  Text(item.yarnName!, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.weightName != null) _InfoChip(label: item.weightName!),
                    if (item.gramsTotal != null) ...[
                      const SizedBox(width: 4),
                      _InfoChip(label: '${item.gramsTotal!.toStringAsFixed(0)}g'),
                    ],
                    if (item.yardsTotal != null) ...[
                      const SizedBox(width: 4),
                      _InfoChip(label: '${item.yardsTotal!.toStringAsFixed(0)}yd'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 도안 라이브러리 탭 ─────────────────────────────────────────────────────────
class _LibraryTab extends ConsumerWidget {
  const _LibraryTab({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(ravelryLibraryProvider);
    return libraryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: '$e', isKorean: isKorean),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(
            icon: Icons.menu_book_rounded,
            message: isKorean ? '도안 라이브러리가 비어 있어요' : 'Your pattern library is empty',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PatternCard(item: items[i], isKorean: isKorean),
        );
      },
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.item, required this.isKorean});
  final RavelryLibraryPattern item;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.thumbnailUrl != null
                  ? CachedNetworkImage(imageUrl: item.thumbnailUrl!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: C.pkL, child: Icon(Icons.menu_book_rounded, color: C.pk)))
                  : Container(color: C.pkL, child: Icon(Icons.menu_book_rounded, color: C.pk)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.authorName != null)
                  Text(item.authorName!, style: T.caption.copyWith(color: C.mu)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.isFree)
                      _InfoChip(label: isKorean ? '무료' : 'Free', color: C.lv)
                    else if (item.price != null)
                      _InfoChip(label: '\$${item.price!.toStringAsFixed(2)}'),
                    if (item.craft != null) ...[
                      const SizedBox(width: 4),
                      _InfoChip(label: item.craft!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (item.ravelryUrl != null)
            Icon(Icons.open_in_new_rounded, color: C.mu, size: 16),
        ],
      ),
    );
  }
}

// ── 프로젝트 탭 ───────────────────────────────────────────────────────────────
class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(ravelryProjectsProvider);
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: '$e', isKorean: isKorean),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(
            icon: Icons.folder_special_rounded,
            message: isKorean ? '라벨리 프로젝트가 없어요' : 'No Ravelry projects found',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RavelryProjectCard(item: items[i], isKorean: isKorean),
        );
      },
    );
  }
}

class _RavelryProjectCard extends StatelessWidget {
  const _RavelryProjectCard({required this.item, required this.isKorean});
  final RavelryProject item;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.thumbnailUrl != null
                  ? CachedNetworkImage(imageUrl: item.thumbnailUrl!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: C.lvL, child: Icon(Icons.folder_special_rounded, color: C.lv)))
                  : Container(color: C.lvL, child: Icon(Icons.folder_special_rounded, color: C.lv)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.patternName != null)
                  Text(item.patternName!, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _InfoChip(label: isKorean ? item.statusKo : (item.status ?? '')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.mu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: T.caption.copyWith(color: c, fontSize: 10)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: C.mu, size: 48),
          const SizedBox(height: 12),
          Text(message, style: T.body.copyWith(color: C.mu)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.isKorean});
  final String message;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: C.og, size: 48),
            const SizedBox(height: 12),
            Text(
              isKorean ? '데이터를 불러오지 못했어요' : 'Failed to load data',
              style: T.bodyBold,
            ),
            const SizedBox(height: 8),
            Text(message, style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
