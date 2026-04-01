import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/admin_config_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/editorial_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../domain/editorial_post.dart';
import 'editorial_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final mobileSubtitle = resolveUiCopy(data: uiCopy, language: language, key: 'home_header_subtitle', fallback: t.homeHeaderSubtitleMobile);
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    final itemsAsync = ref.watch(marketItemsProvider);
    final projectCount = ref.watch(projectCountProvider);
    final adminConfig = ref.watch(adminConfigProvider).valueOrNull;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.email.isNotEmpty == true ? currentUser!.email.split('@').first : '');

    final rawGreeting = isKorean
        ? (adminConfig?.homeGreetingKo.isNotEmpty == true ? adminConfig!.homeGreetingKo : mobileSubtitle)
        : (adminConfig?.homeGreetingEn.isNotEmpty == true ? adminConfig!.homeGreetingEn : mobileSubtitle);
    final personalizedSubtitle = rawGreeting
        .replaceAll('[사용자 이름]', userName)
        .replaceAll('[userName]', userName);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.home,
                subtitle: personalizedSubtitle,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EcosystemHero(
                      t: t,
                      isKorean: isKorean,
                      projectCount: projectCount,
                      postsAsync: postsAsync,
                      itemsAsync: itemsAsync,
                    ),
                    const SizedBox(height: 18),
                    SectionTitle(
                      title: isKorean ? '인기도안 TOP5' : 'Top 5 Patterns',
                      trailing: GestureDetector(
                        onTap: () => context.push(Routes.market),
                        child: Text(isKorean ? '더보기' : 'More', style: T.caption.copyWith(color: C.lmD)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MarketPreview(isKorean: isKorean),
                    const SizedBox(height: 18),
                    SectionTitle(
                      title: isKorean ? '최신 등록된 도안' : 'Latest Patterns',
                      trailing: GestureDetector(
                        onTap: () => context.push(Routes.market),
                        child: Text(isKorean ? '더보기' : 'More', style: T.caption.copyWith(color: C.lmD)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LatestPatternsPreview(isKorean: isKorean),
                    const SizedBox(height: 18),
                    SectionTitle(
                      title: t.homeCommunityHighlights,
                      trailing: GestureDetector(
                        onTap: () => context.go(Routes.community),
                        child: Text(t.homeMore, style: T.caption.copyWith(color: C.pkD)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CommunityPreview(isKorean: isKorean),
                    const SizedBox(height: 18),
                    SectionTitle(
                      title: isKorean ? '다른사람들이 많이 본 영상' : 'Popular Videos',
                      trailing: GestureDetector(
                        onTap: () => context.push(Routes.toolsCourse),
                        child: Text(isKorean ? '더보기' : 'More', style: T.caption.copyWith(color: C.lvD)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _PopularCourseSection(),
                    const SizedBox(height: 18),
                    SectionTitle(title: isKorean ? '오늘의 Knitting 소식' : "Today's Knitting News"),
                    const SizedBox(height: 10),
                    _EditorialBoard(isKorean: isKorean, t: t),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EcosystemHero extends StatelessWidget {
  final bool isKorean;
  final AppStrings t;
  final int projectCount;
  final AsyncValue postsAsync;
  final AsyncValue itemsAsync;

  const _EcosystemHero({
    required this.t,
    required this.isKorean,
    required this.projectCount,
    required this.postsAsync,
    required this.itemsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final postCount = postsAsync.valueOrNull is List ? (postsAsync.valueOrNull as List).length : 0;
    final itemCount = itemsAsync.valueOrNull is List ? (itemsAsync.valueOrNull as List).length : 0;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MoriChip(label: t.ecosystemHub, type: ChipType.white),
              MoriChip(label: t.editorialPicks, type: ChipType.lavender),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isKorean ? '오늘의 모리니트' : "Today's MoriKnit",
            style: T.h2,
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? '커뮤니티 게시글, 마켓 상품, 진행 중인 프로젝트 현황을 한눈에 볼 수 있어요.'
                : 'See the current status of community posts, market listings, and active projects at a glance.',
            style: T.body.copyWith(color: C.tx2, height: 1.6),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: t.communityPosts,
                  value: '$postCount',
                  accent: C.pk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: t.marketListings,
                  value: '$itemCount',
                  accent: C.lmD,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: isKorean ? '전체 프로젝트' : 'Total projects',
                  value: '$projectCount',
                  accent: C.lvD,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, style: T.h2.copyWith(color: accent)),
          const SizedBox(height: 4),
          Text(label, style: T.captionBold.copyWith(color: accent)),
        ],
      ),
    );
  }
}

class _EditorialBoard extends ConsumerWidget {
  final bool isKorean;
  final AppStrings t;

  const _EditorialBoard({required this.isKorean, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letterAsync = ref.watch(editorialLatestProvider('letter'));
    final tipsAsync = ref.watch(editorialLatestProvider('tips'));
    final trendingAsync = ref.watch(editorialLatestProvider('trending'));
    final youtubeAsync = ref.watch(editorialLatestProvider('youtube'));

    final letterPost = letterAsync.valueOrNull?.isNotEmpty == true ? letterAsync.valueOrNull!.first : null;
    final tipsPost = tipsAsync.valueOrNull?.isNotEmpty == true ? tipsAsync.valueOrNull!.first : null;
    final trendingPost = trendingAsync.valueOrNull?.isNotEmpty == true ? trendingAsync.valueOrNull!.first : null;
    final youtubePost = youtubeAsync.valueOrNull?.isNotEmpty == true ? youtubeAsync.valueOrNull!.first : null;

    return Column(
      children: [
        _EditorialCard(
          icon: Icons.menu_book_rounded,
          color: C.pk,
          title: letterPost?.title ?? (isKorean ? '뜨개 레터' : 'Knitting Letter'),
          caption: letterPost?.content ?? '',
          isEmpty: letterPost == null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorialScreen(type: 'letter', title: isKorean ? '뜨개 레터' : 'Knitting Letter', isKorean: isKorean))),
        ),
        const SizedBox(height: 10),
        _EditorialCard(
          icon: Icons.tips_and_updates_rounded,
          color: C.lvD,
          title: tipsPost?.title ?? t.recommendedInfo,
          caption: tipsPost?.content ?? '',
          isEmpty: tipsPost == null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorialScreen(type: 'tips', title: t.recommendedInfo, isKorean: isKorean))),
        ),
        const SizedBox(height: 10),
        _EditorialCard(
          icon: Icons.trending_up_rounded,
          color: C.lmD,
          title: trendingPost?.title ?? (isKorean ? '인기 토픽' : 'Trending Topics'),
          caption: trendingPost?.content ?? '',
          isEmpty: trendingPost == null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorialScreen(type: 'trending', title: isKorean ? '인기 토픽' : 'Trending Topics', isKorean: isKorean))),
        ),
        const SizedBox(height: 10),
        _YoutubePreviewCard(post: youtubePost, isKorean: isKorean),
      ],
    );
  }
}

class _EditorialCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String caption;
  final bool isEmpty;
  final VoidCallback onTap;

  const _EditorialCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.caption,
    this.isEmpty = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: T.bodyBold)),
                    Icon(Icons.chevron_right_rounded, color: C.mu, size: 16),
                  ]),
                  if (!isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: T.caption.copyWith(color: C.mu, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Container(height: 10, width: 120, decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 5),
                    Container(height: 10, width: 80, decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(4))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YoutubePreviewCard extends StatelessWidget {
  final EditorialPost? post;
  final bool isKorean;

  const _YoutubePreviewCard({required this.post, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final videoId = post?.youtubeVideoId ?? '';
    final hasVideo = videoId.isNotEmpty;
    final thumbUrl = hasVideo ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : '';

    return GestureDetector(
      onTap: hasVideo
          ? () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=$videoId'), mode: LaunchMode.externalApplication)
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorialScreen(type: 'youtube', title: 'YouTube', isKorean: isKorean))),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasVideo
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          thumbUrl,
                          width: 80,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 56,
                            color: Colors.red.withValues(alpha: 0.12),
                            child: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 28),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(99)),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    )
                  : Container(
                      width: 80,
                      height: 56,
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.play_circle_outline_rounded, color: Colors.red, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        post?.title ?? (isKorean ? 'YouTube' : 'YouTube'),
                        style: T.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: C.mu, size: 16),
                  ]),
                  if ((post?.content ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post!.content,
                      style: T.caption.copyWith(color: C.mu, height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPreview extends ConsumerStatefulWidget {
  final bool isKorean;
  const _CommunityPreview({required this.isKorean});

  @override
  ConsumerState<_CommunityPreview> createState() => _CommunityPreviewState();
}

class _CommunityPreviewState extends ConsumerState<_CommunityPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final ScrollController _scrollCtrl;

  static const double _itemHeight = 44.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    if (!_scrollCtrl.hasClients) return;
    final maxExtent = _scrollCtrl.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final next = _ticker.value * (maxExtent + _itemHeight);
    if (next >= maxExtent) {
      _scrollCtrl.jumpTo(0);
    } else {
      _scrollCtrl.jumpTo(next);
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    return postsAsync.when(
      data: (posts) {
        final displayPosts = posts
            .take(3)
            .map((p) => _PostDisplay(category: p.category, title: p.title, timeAgo: p.timeAgo, imageUrls: p.imageUrls))
            .toList();

        if (displayPosts.isEmpty) {
          return GestureDetector(
            onTap: () => context.push(Routes.community),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SizedBox(
                height: _itemHeight * 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 48, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(7))),
                        const SizedBox(width: 8),
                        Expanded(child: Container(height: 14, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(7)))),
                      ],
                    ),
                  )),
                ),
              ),
            ),
          );
        }

        final loopPosts = displayPosts.isNotEmpty
            ? [...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts]
            : <_PostDisplay>[];
        final visibleCount = 5;

        return GestureDetector(
          onTap: () => context.push(Routes.community),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SizedBox(
              height: _itemHeight * visibleCount,
              child: ClipRect(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: loopPosts.length,
                  itemExtent: _itemHeight,
                  itemBuilder: (_, i) => _PostTickerRow(post: loopPosts[i], isKorean: widget.isKorean),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PostDisplay {
  final String category;
  final String title;
  final String timeAgo;
  final List<String> imageUrls;
  const _PostDisplay({required this.category, required this.title, required this.timeAgo, this.imageUrls = const []});
}

class _PostTickerRow extends StatelessWidget {
  final _PostDisplay post;
  final bool isKorean;
  const _PostTickerRow({required this.post, required this.isKorean});

  Color _catColor(String cat) {
    switch (cat) {
      case 'showcase':
        return C.pkD;
      case 'questions':
        return C.lvD;
      case 'pattern_share':
        return C.lmD;
      default:
        return C.mu;
    }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'showcase':
        return isKorean ? '작품' : 'Showcase';
      case 'questions':
        return isKorean ? '질문' : 'Questions';
      case 'pattern_share':
        return isKorean ? '도안공유' : 'Pattern Share';
      default:
        return isKorean ? '전체' : 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(post.category);
    final hasImage = post.imageUrls.isNotEmpty;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
          child: Text(_catLabel(post.category), style: T.caption.copyWith(color: catColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(post.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              post.imageUrls.first,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 40),
            ),
          ),
          const SizedBox(width: 6),
        ] else ...[
          Text(post.timeAgo, style: T.caption.copyWith(color: C.mu)),
        ],
      ],
    );
  }
}

class _MarketPreview extends ConsumerWidget {
  final bool isKorean;
  const _MarketPreview({required this.isKorean});

  static final _palette = [C.pk, C.lv, C.lm, C.lvD, C.pkD, C.lmD, C.og];

  Color _accentColor(dynamic item) {
    final idx = item.id.hashCode.abs() % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(popularPatternItemsProvider);
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(isKorean ? '등록된 상품이 아직 없어요' : 'No items yet', style: T.caption.copyWith(color: C.mu)),
              ),
            ),
          );
        }
        final top5 = items.take(5).toList();
        return Column(
          children: List.generate(top5.length, (index) {
            final item = top5[index];
            final accent = _accentColor(item);
            final isEven = index % 2 == 0;
            return GestureDetector(
              onTap: () => context.push(Routes.market),
              child: Container(
                height: 80,
                margin: EdgeInsets.only(bottom: index < top5.length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.bd),
                  boxShadow: [
                    BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: isEven
                      ? [
                          _ItemImage(item: item, accent: accent),
                          const SizedBox(width: 12),
                          Expanded(child: _ItemText(item: item, accent: accent, isKorean: isKorean)),
                          const SizedBox(width: 10),
                        ]
                      : [
                          const SizedBox(width: 10),
                          Expanded(child: _ItemText(item: item, accent: accent, isKorean: isKorean)),
                          const SizedBox(width: 12),
                          _ItemImage(item: item, accent: accent),
                        ],
                ),
              ),
            );
          }),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: C.lmD)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ItemImage extends StatelessWidget {
  final dynamic item;
  final Color accent;
  const _ItemImage({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: item.imageUrl.isNotEmpty
          ? Image.network(
              item.imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Placeholder(accent: accent, imageType: item.imageType),
            )
          : _Placeholder(accent: accent, imageType: item.imageType),
    );
  }
}

class _ItemText extends StatelessWidget {
  final dynamic item;
  final Color accent;
  final bool isKorean;
  const _ItemText({required this.item, required this.accent, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: T.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.price == 0
              ? (isKorean ? '무료 도안' : 'Free')
              : '${item.price}${isKorean ? '원' : ' KRW'}',
          style: T.caption.copyWith(color: accent, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LatestPatternsPreview extends ConsumerStatefulWidget {
  final bool isKorean;
  const _LatestPatternsPreview({required this.isKorean});

  @override
  ConsumerState<_LatestPatternsPreview> createState() => _LatestPatternsPreviewState();
}

class _LatestPatternsPreviewState extends ConsumerState<_LatestPatternsPreview> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollCtrl;
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    final next = _ticker.value * (max + 140.0);
    if (next >= max) {
      _scrollCtrl.jumpTo(0);
    } else {
      _scrollCtrl.jumpTo(next);
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(latestPatternItemsProvider);
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(widget.isKorean ? '등록된 도안이 아직 없어요' : 'No patterns yet', style: T.caption.copyWith(color: C.mu)),
              ),
            ),
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final accent = _parseColor(item.accentHex);
              return GestureDetector(
                onTap: () => context.push(Routes.market),
                child: Container(
                  width: 130,
                  margin: EdgeInsets.only(right: index < items.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.bd),
                    boxShadow: [
                      BoxShadow(color: const Color(0x2A6D4AFF), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                width: 130,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _Placeholder(accent: accent, imageType: item.imageType),
                              )
                            : _Placeholder(accent: accent, imageType: item.imageType),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                        child: Text(
                          item.title,
                          style: T.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          item.price == 0
                              ? (widget.isKorean ? '무료 도안' : 'Free')
                              : '${item.price}${widget.isKorean ? '원' : ' KRW'}',
                          style: T.caption.copyWith(color: accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: C.lmD)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ── 인기 강의 섹션 ──────────────────────────────────────────
class _PopularCourseSection extends ConsumerWidget {
  const _PopularCourseSection();

  String? _videoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return uri.queryParameters['v'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final coursesAsync = ref.watch(randomCoursePicksProvider);

    return coursesAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (courses) {
        if (courses.isEmpty) return const SizedBox.shrink();
        return Column(
          children: courses.map((item) {
            final videoId = _videoId(item.videoUrl);
            final thumbUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : '';
            return GestureDetector(
              onTap: () {
                if (videoId != null) {
                  launchUrl(Uri.parse('https://www.youtube.com/watch?v=$videoId'), mode: LaunchMode.externalApplication);
                } else if (item.videoUrl.isNotEmpty) {
                  launchUrl(Uri.parse(item.videoUrl), mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: C.gx,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.bd),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (thumbUrl.isNotEmpty)
                            Image.network(
                              thumbUrl,
                              width: 100,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, e, stack) => Container(
                                width: 100, height: 70,
                                color: C.lvL,
                                child: Icon(Icons.play_circle_outline_rounded, color: C.lvD, size: 28),
                              ),
                            )
                          else
                            Container(
                              width: 100, height: 70,
                              color: C.lvL,
                              child: Icon(Icons.play_circle_outline_rounded, color: C.lvD, size: 28),
                            ),
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: C.lvL,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(item.category, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isKorean ? item.title : (item.titleEn.isNotEmpty ? item.titleEn : item.title),
                              style: T.bodyBold,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Color accent;
  final String imageType;
  const _Placeholder({required this.accent, required this.imageType});

  IconData get _icon {
    switch (imageType) {
      case 'yarn':
        return Icons.blur_circular_rounded;
      case 'tool':
        return Icons.handyman_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 90,
      color: accent.withValues(alpha: 0.12),
      child: Icon(_icon, color: accent, size: 32),
    );
  }
}
