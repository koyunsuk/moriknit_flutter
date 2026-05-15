import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/admin_config_provider.dart';
import '../../../providers/app_config_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../blueprint/data/migration_guard.dart';
import '../../../providers/editorial_provider.dart';
import '../../../providers/guestbook_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/project_provider.dart';
import '../../project/domain/project_model.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../community/presentation/gallery_detail_page.dart';
import '../../landing/data/landing_board_repository.dart';
import '../../project/data/public_project_service.dart';
import '../../project/presentation/widgets/project_start_sheet.dart';
import '../../tools/presentation/widgets/knit_dashboard_card.dart';
import '../../../providers/template_provider.dart';
import '../domain/editorial_post.dart';

// 공지사항 Provider
final landingNoticesProvider = StreamProvider<List<LandingPost>>((ref) {
  return LandingBoardRepository().getNotices();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _bannerDismissed = false;
  bool _popupShown = false;
  bool _migrationKicked = false;

  @override
  void initState() {
    super.initState();
    // 이슈 #687 — 로그인 완료 후 첫 홈 진입 시 자동 마이그레이션 1회 실행 (백그라운드).
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickOffMigration());
  }

  void _kickOffMigration() {
    if (_migrationKicked) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || uid.isEmpty) return;
    _migrationKicked = true;
    // UI 차단 없이 fire-and-forget. 결과는 디버그 로그로만 노출됨.
    // ignore: discarded_futures
    ref.read(migrationGuardProvider).runIfNeeded(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 팝업 공지는 첫 번째 데이터 수신 시 1회만 표시
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
  }

  void _maybeShowPopup() {
    if (_popupShown) return;
    final appConfig = ref.read(appConfigProvider).valueOrNull;
    if (appConfig == null) return;
    if (appConfig.maintenanceNotice.isNotEmpty && appConfig.noticeType == 'popup') {
      _popupShown = true;
      final isKorean = ref.read(appLanguageProvider).isKorean;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isKorean ? '공지사항' : 'Notice'),
          content: Text(appConfig.maintenanceNotice),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isKorean ? '확인' : 'OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final mobileSubtitle = resolveUiCopy(data: uiCopy, language: language, key: 'home_header_subtitle', fallback: t.homeHeaderSubtitleMobile);
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    final itemsAsync = ref.watch(marketItemsProvider);
    final projectCount = ref.watch(projectCountProvider);
    final publicProjectsAsync = ref.watch(publicProjectsProvider);
    final adminConfig = ref.watch(adminConfigProvider).valueOrNull;
    final appConfig = ref.watch(appConfigProvider).valueOrNull;
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

    // 팝업 공지: 데이터가 처음 로드되면 표시 시도
    if (!_popupShown && appConfig != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
    }

    final showBanner = !_bannerDismissed &&
        (appConfig?.maintenanceNotice.isNotEmpty ?? false) &&
        appConfig?.noticeType == 'banner';

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
            // 긴급공지 배너
            if (showBanner)
              _MaintenanceBanner(
                message: appConfig!.maintenanceNotice,
                onDismiss: () => setState(() => _bannerDismissed = true),
              ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 오늘 요약
                    _EcosystemHero(
                      t: t,
                      isKorean: isKorean,
                      projectCount: projectCount,
                      postsAsync: postsAsync,
                      itemsAsync: itemsAsync,
                      publicProjectsAsync: publicProjectsAsync,
                    ),
                    const SizedBox(height: 20),
                    // 1-b. 뜨개 대시보드 (이슈 #649 Phase 2)
                    KnitDashboardCard(isKorean: isKorean),
                    const SizedBox(height: 20),
                    // 2. 공지사항
                    _HomeNoticesSection(isKorean: isKorean),
                    const SizedBox(height: 20),
                    // 3. 커뮤니티 그룹 카드 (위·아래 핑크 보더 + 내부 스크롤)
                    _SectionGroupCard(
                      label: isKorean ? '커뮤니티' : 'Community',
                      icon: Icons.people_rounded,
                      color: C.pk,
                      onMoreTap: () => context.go(Routes.community),
                      scrollHeight: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SubSectionLabel(title: isKorean ? '방명록' : 'Guestbook', color: C.pkD),
                          const SizedBox(height: 8),
                          _HomeGuestbookFadeTicker(isKorean: isKorean),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, thickness: 0.5),
                          ),
                          _SubSectionLabel(title: isKorean ? '커뮤니티 게시글' : 'Posts', color: C.pk),
                          const SizedBox(height: 8),
                          _CommunityPreview(isKorean: isKorean),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, thickness: 0.5),
                          ),
                          _SubSectionLabel(title: isKorean ? '완성 갤러리' : 'Gallery', color: C.lv),
                          const SizedBox(height: 8),
                          _HomeGalleryVerticalSection(isKorean: isKorean),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 4. 강의실 (위·아래 보라 보더 + 내부 스크롤)
                    _SectionGroupCard(
                      label: isKorean ? '강의실' : 'Course',
                      icon: Icons.play_lesson_rounded,
                      color: C.lv,
                      onMoreTap: () => context.push(Routes.toolsCourse),
                      scrollHeight: 320,
                      child: const _PopularCourseSection(),
                    ),
                    const SizedBox(height: 20),
                    // 5. 오늘의 뜨개 소식 (모리채널 포함) — 위·아래 오렌지 보더 + 내부 스크롤
                    _SectionGroupCard(
                      label: isKorean ? '오늘의 Knitting 소식' : "Today's Knitting News",
                      icon: Icons.newspaper_rounded,
                      color: C.og,
                      scrollHeight: 360,
                      child: _EditorialBoard(isKorean: isKorean, t: t),
                    ),
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

/// 운영지원 긴급공지 배너 (maintenanceNotice + noticeType == 'banner')
class _MaintenanceBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _MaintenanceBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: C.og.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, size: 18, color: C.og),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: T.sm.copyWith(color: C.og, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 18, color: C.og),
          ),
        ],
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
  final AsyncValue publicProjectsAsync;

  const _EcosystemHero({
    required this.t,
    required this.isKorean,
    required this.projectCount,
    required this.postsAsync,
    required this.itemsAsync,
    required this.publicProjectsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final postCount = postsAsync.valueOrNull is List ? (postsAsync.valueOrNull as List).length : 0;
    final itemCount = itemsAsync.valueOrNull is List ? (itemsAsync.valueOrNull as List).length : 0;
    final galleryCount = publicProjectsAsync.valueOrNull is List ? (publicProjectsAsync.valueOrNull as List).length : 0;

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
                  label: isKorean ? '진행중 프로젝트' : 'Active projects',
                  value: '$projectCount',
                  accent: C.lvD,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: isKorean ? '완성 갤러리' : 'Finished Gallery',
                  value: '$galleryCount',
                  accent: C.lv,
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
          onTap: () => context.push('/editorial/letter', extra: {'title': isKorean ? '뜨개 레터' : 'Knitting Letter', 'isKorean': isKorean}),
        ),
        const SizedBox(height: 10),
        _EditorialCard(
          icon: Icons.tips_and_updates_rounded,
          color: C.lvD,
          title: tipsPost?.title ?? t.recommendedInfo,
          caption: tipsPost?.content ?? '',
          isEmpty: tipsPost == null,
          onTap: () => context.push('/editorial/tips', extra: {'title': t.recommendedInfo, 'isKorean': isKorean}),
        ),
        const SizedBox(height: 10),
        _EditorialCard(
          icon: Icons.trending_up_rounded,
          color: C.lmD,
          title: trendingPost?.title ?? (isKorean ? '인기 토픽' : 'Trending Topics'),
          caption: trendingPost?.content ?? '',
          isEmpty: trendingPost == null,
          onTap: () => context.push('/editorial/trending', extra: {'title': isKorean ? '인기 토픽' : 'Trending Topics', 'isKorean': isKorean}),
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
          : () => context.push('/editorial/youtube', extra: {'title': 'YouTube', 'isKorean': isKorean}),
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
  int _tab = 0;

  static const double _itemHeight = 52.0;
  static const int _visibleCount = 5;
  static const double _projectCardHeight = 80.0;
  static const int _projectCount = 3;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    if (_tab != 0) return;
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

  Widget _buildTabRow() {
    final isKo = widget.isKorean;
    return Row(
      children: [
        _TabChip(label: isKo ? '게시글' : 'Posts', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
        const SizedBox(width: 6),
        _TabChip(label: isKo ? '진행중 프로젝트' : 'In Progress', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
      ],
    );
  }

  void _showProjectStartSheet() => showProjectStartSheet(context, ref);

  Widget _buildProjectsTab(List<ProjectModel> projects) {
    final totalHeight = _projectCardHeight * _projectCount + 8.0 * (_projectCount - 1);
    return SizedBox(
      height: totalHeight,
      child: Column(
        children: List.generate(_projectCount, (i) {
          final isLast = i == _projectCount - 1;
          if (i >= projects.length) {
            // 첫 번째 빈 슬롯: 추가하기 카드
            if (i == 0) {
              return GestureDetector(
                onTap: _showProjectStartSheet,
                child: Container(
                  height: _projectCardHeight,
                  margin: isLast ? null : const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.lv.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: _projectCardHeight,
                        height: _projectCardHeight,
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.10),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                        ),
                        child: Icon(Icons.add_rounded, color: C.lv, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.isKorean ? '새 프로젝트 추가하기' : 'Add new project',
                        style: T.bodyBold.copyWith(color: C.lv),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Container(
              height: _projectCardHeight,
              margin: isLast ? null : const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
            );
          }
            final proj = projects[i];
            final imageUrl = proj.coverPhotoUrl.isNotEmpty
                ? proj.coverPhotoUrl
                : (proj.photoUrls.isNotEmpty ? proj.photoUrls.last : '');
            return GestureDetector(
              onTap: () => context.push(Routes.projectList),
              child: Container(
              height: _projectCardHeight,
              margin: isLast ? null : const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: _projectCardHeight,
                            height: _projectCardHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _projectImgPlaceholder(),
                          )
                        : _projectImgPlaceholder(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(proj.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (proj.yarnName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(proj.yarnName, style: T.caption.copyWith(color: C.tx2), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: proj.progressPercent / 100,
                            minHeight: 4,
                            backgroundColor: C.lv.withValues(alpha: 0.14),
                            valueColor: AlwaysStoppedAnimation(C.lv),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          );
          }),
      ),
    );
  }

  Widget _projectImgPlaceholder() => Container(
    width: _projectCardHeight,
    height: _projectCardHeight,
    color: C.lvL,
    child: Icon(Icons.auto_stories_rounded, color: C.lv.withValues(alpha: 0.5)),
  );

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    final allProjects = ref.watch(projectListProvider).valueOrNull ?? [];
    final inProgressProjects = allProjects.where((p) => p.status == 'in_progress').take(_projectCount).toList();
    // 템플릿 프로바이더 사전 로드 (추가 시트에서 즉시 표시되도록)
    ref.watch(builtinTemplateListProvider);
    ref.watch(userTemplateListProvider);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabRow(),
          const SizedBox(height: 8),
          if (_tab == 0)
            postsAsync.when(
              data: (posts) {
                final displayPosts = posts
                    .take(_visibleCount)
                    .map((p) => _PostDisplay(category: p.category, title: p.title, timeAgo: p.timeAgo, imageUrls: p.imageUrls))
                    .toList();

                if (displayPosts.isEmpty) {
                  return GestureDetector(
                    onTap: () => context.push(Routes.community),
                    child: SizedBox(
                      height: _itemHeight * _visibleCount,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_visibleCount, (i) => Padding(
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
                  );
                }

                final loopPosts = [...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts];

                return GestureDetector(
                  onTap: () => context.push(Routes.community),
                  child: SizedBox(
                    height: _itemHeight * _visibleCount,
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
                );
              },
              loading: () => SizedBox(height: _itemHeight * _visibleCount, child: Center(child: CircularProgressIndicator(color: C.lv))),
              error: (_, _) => SizedBox(height: _itemHeight * _visibleCount),
            )
          else
            _buildProjectsTab(inProgressProjects),
        ],
      ),
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

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? Colors.white : C.lvD,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final Color accent;
  final String? imageType;
  const _PlaceholderIcon({required this.accent, this.imageType});

  IconData get _resolvedIcon {
    switch (imageType ?? '') {
      case 'yarn': return Icons.blur_circular_rounded;
      case 'tool': return Icons.handyman_rounded;
      default: return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.12),
      child: Center(child: Icon(_resolvedIcon, color: accent, size: 28)),
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
                                errorBuilder: (_, _, _) => _PlaceholderIcon(accent: accent, imageType: item.imageType),
                              )
                            : _PlaceholderIcon(accent: accent, imageType: item.imageType),
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

// ignore: unused_element
class _HomeGuestbookSection extends ConsumerWidget {
  final bool isKorean;
  const _HomeGuestbookSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(guestbookListProvider);
    return entriesAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: C.lv, strokeWidth: 2)),
      error: (_, _) => Text(isKorean ? '불러오지 못했어요.' : 'Unable to load.', style: T.caption.copyWith(color: C.mu)),
      data: (entries) {
        if (entries.isEmpty) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isKorean ? '아직 방명록이 없어요. 첫 인사를 남겨보세요!' : 'No guestbook entries yet.',
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
          );
        }
        final visible = entries.take(10).toList();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 12, thickness: 0.5),
            itemBuilder: (_, i) {
              final e = visible[i];
              return GestureDetector(
                onTap: () => context.go(Routes.community),
                behavior: HitTestBehavior.opaque,
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: C.lvL,
                    backgroundImage: e.avatarUrl.isNotEmpty ? NetworkImage(e.avatarUrl) : null,
                    child: e.avatarUrl.isEmpty
                        ? Text(
                            e.displayName.isNotEmpty ? e.displayName.characters.first.toUpperCase() : '?',
                            style: TextStyle(fontSize: 11, color: C.lvD, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${e.displayName.isNotEmpty ? e.displayName : (isKorean ? '익명' : 'Anon')}: ',
                            style: T.captionBold.copyWith(color: C.tx),
                          ),
                          TextSpan(
                            text: e.message,
                            style: T.body.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.timeAgoLocalized(isKorean: isKorean),
                    style: T.caption.copyWith(color: C.mu, fontSize: 11),
                  ),
                ],
              ),
              );
            },
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _HomeGallerySection extends ConsumerWidget {
  final bool isKorean;
  const _HomeGallerySection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(publicProjectsProvider);
    return projectsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) {
          return GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isKorean ? '아직 공개된 작품이 없어요.' : 'No public projects yet.',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ),
            ),
          );
        }
        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final entry = entries[i];
              return GestureDetector(
                onTap: () => _showGalleryDetail(context, ref, entry),
                child: Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: C.gx,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.bd),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: () {
                            final thumbUrl = entry.coverPhotoUrl.isNotEmpty
                                ? entry.coverPhotoUrl
                                : entry.photoUrls.firstWhere((u) => u.isNotEmpty, orElse: () => '');
                            return thumbUrl.isNotEmpty
                                ? Image.network(thumbUrl, width: 110, height: 80, fit: BoxFit.cover, cacheWidth: 220, cacheHeight: 160,
                                    errorBuilder: (_, _, _) => Container(width: 110, height: 80, color: C.lvL, child: Icon(Icons.grid_view_rounded, color: C.lv)))
                                : Container(width: 110, height: 80, color: C.lvL, child: Icon(Icons.grid_view_rounded, color: C.lv));
                          }(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(entry.title, style: T.caption.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Row(children: [
                                Icon(Icons.favorite_rounded, size: 10, color: C.pk),
                                const SizedBox(width: 2),
                                Text('${entry.likeCount}', style: T.caption.copyWith(fontSize: 9, color: C.mu)),
                              ]),
                            ],
                          ),
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
    );
  }
}

void _showGalleryDetail(BuildContext context, WidgetRef ref, PublicProjectEntry entry) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GalleryDetailPage(
        entry: entry,
        currentUid: ref.read(authStateProvider).valueOrNull?.uid ?? '',
      ),
    ),
  );
}

// ── 방명록 페이드 티커 (한 항목씩 3초마다 교체) ──────────────
class _HomeGuestbookFadeTicker extends ConsumerStatefulWidget {
  final bool isKorean;
  const _HomeGuestbookFadeTicker({required this.isKorean});

  @override
  ConsumerState<_HomeGuestbookFadeTicker> createState() => _HomeGuestbookFadeTickerState();
}

class _HomeGuestbookFadeTickerState extends ConsumerState<_HomeGuestbookFadeTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  int _index = 0;
  Timer? _timer;
  List<dynamic> _entries = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_entries.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _ctrl.reverse();
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _entries.length);
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(guestbookListProvider);
    return entriesAsync.when(
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.isKorean ? '아직 방명록이 없어요.' : 'No guestbook entries yet.',
              style: T.caption.copyWith(color: C.mu),
            ),
          );
        }
        if (_entries.length != entries.length) {
          _entries = entries;
          _index = _index.clamp(0, entries.length - 1);
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }
        final e = entries[_index.clamp(0, entries.length - 1)];
        return GestureDetector(
          onTap: () => context.go(Routes.community),
          behavior: HitTestBehavior.opaque,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: C.pk.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.pk.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: C.pkL,
                    backgroundImage: e.avatarUrl.isNotEmpty ? NetworkImage(e.avatarUrl) : null,
                    child: e.avatarUrl.isEmpty
                        ? Text(
                            e.displayName.isNotEmpty ? e.displayName.characters.first.toUpperCase() : '?',
                            style: TextStyle(fontSize: 11, color: C.pkD, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${e.displayName.isNotEmpty ? e.displayName : (widget.isKorean ? '익명' : 'Anon')}: ',
                            style: T.captionBold.copyWith(color: C.tx),
                          ),
                          TextSpan(text: e.message, style: T.body.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 16, color: C.mu),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 완성 갤러리 세로 목록 ─────────────────────────────────────
class _HomeGalleryVerticalSection extends ConsumerWidget {
  final bool isKorean;
  const _HomeGalleryVerticalSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(publicProjectsProvider);
    return projectsAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        const galleryItemH = 68.0;
        const galleryCount = 4;
        const galleryTotalH = galleryItemH * galleryCount + 10.0 * (galleryCount - 1);
        if (entries.isEmpty) {
          return SizedBox(
            height: galleryTotalH,
            child: Center(
              child: Text(
                isKorean ? '아직 공개된 작품이 없어요.' : 'No public projects yet.',
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
          );
        }
        final visible = entries.take(galleryCount).toList();
        return SizedBox(
          height: galleryTotalH,
          child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 10, thickness: 0.5),
          itemBuilder: (_, i) {
            final entry = visible[i];
            return GestureDetector(
              onTap: () => _showGalleryDetail(context, ref, entry),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: () {
                      final url = entry.coverPhotoUrl.isNotEmpty
                          ? entry.coverPhotoUrl
                          : entry.photoUrls.firstWhere((u) => u.isNotEmpty, orElse: () => '');
                      return url.isNotEmpty
                          ? Image.network(url, width: 64, height: 64, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: C.lvL, child: Icon(Icons.grid_view_rounded, color: C.lv, size: 20)))
                          : Container(width: 64, height: 64, color: C.lvL, child: Icon(Icons.grid_view_rounded, color: C.lv, size: 20));
                    }(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title, style: T.captionBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.person_outline_rounded, size: 11, color: C.mu),
                          const SizedBox(width: 2),
                          Text(entry.ownerName, style: T.caption.copyWith(fontSize: 11, color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(width: 8),
                          Icon(Icons.favorite_rounded, size: 11, color: C.pk),
                          const SizedBox(width: 2),
                          Text('${entry.likeCount}', style: T.caption.copyWith(fontSize: 11, color: C.mu)),
                        ]),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: C.mu),
                ],
              ),
            );
          },
        ),
        );
      },
    );
  }
}

// ── 섹션 그룹 카드 (헤더 + 내용 + 더보기) ─────────────────────
/// 홈 화면 그룹카드 — 공통 MoriBlockShell 으로 위임.
/// 둥근 모서리 + 양끝 끝까지 닿는 위·아래 옅은 보더 + 옅은 헤더 톤(블록 일관성 표준).
class _SectionGroupCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onMoreTap;
  final Widget child;
  final double? scrollHeight;

  const _SectionGroupCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.child,
    this.onMoreTap,
    this.scrollHeight,
  });

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: label,
      icon: icon,
      accent: color,
      onMoreTap: onMoreTap,
      scrollHeight: scrollHeight,
      child: child,
    );
  }
}

// ── 서브섹션 레이블 (왼쪽 컬러 바 + 텍스트) ──────────────────
class _SubSectionLabel extends StatelessWidget {
  final String title;
  final Color color;

  const _SubSectionLabel({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 7),
        Text(title, style: T.captionBold.copyWith(color: color)),
      ],
    );
  }
}

// ── 공지사항 섹션 ──────────────────────────────────────────────
class _HomeNoticesSection extends ConsumerStatefulWidget {
  final bool isKorean;
  const _HomeNoticesSection({required this.isKorean});

  @override
  ConsumerState<_HomeNoticesSection> createState() => _HomeNoticesSectionState();
}

class _HomeNoticesSectionState extends ConsumerState<_HomeNoticesSection> {
  bool get isKorean => widget.isKorean;

  String _formatDateDt(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  void _showNoticeDetailPost(BuildContext context, LandingPost notice) {
    final title = notice.title;
    final content = notice.content;
    final allImages = <String>[
      if (notice.imageUrl.isNotEmpty) notice.imageUrl,
      ...notice.imageUrls.where((u) => u != notice.imageUrl && u.isNotEmpty),
    ];
    // 단건 fileUrl + 복수 fileUrls 통합
    final fileUrls = <String>[
      if (notice.fileUrl.isNotEmpty) notice.fileUrl,
      ...notice.fileUrls.where((u) => u != notice.fileUrl && u.isNotEmpty),
    ];
    final fileNames = notice.fileNames.isNotEmpty
        ? notice.fileNames
        : (notice.fileName.isNotEmpty ? [notice.fileName] : <String>[]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: C.bd,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  title,
                  style: T.h3.copyWith(color: C.tx),
                ),
              ),
              const SizedBox(height: 4),
              Divider(color: C.bd, thickness: 0.5, indent: 20, endIndent: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    if (allImages.isNotEmpty) ...[
                      ...allImages.map((url) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              width: double.infinity,
                              height: 180,
                              color: C.bd.withValues(alpha: 0.3),
                              child: Center(child: CircularProgressIndicator(color: C.lv, strokeWidth: 2)),
                            ),
                            errorWidget: (_, _, _) => Container(
                              width: double.infinity,
                              height: 100,
                              decoration: BoxDecoration(
                                color: C.bd.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: C.mu, size: 28),
                                  const SizedBox(height: 4),
                                  Text('이미지를 불러올 수 없어요', style: T.caption.copyWith(color: C.mu)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      content,
                      style: T.body.copyWith(color: C.tx2, height: 1.7),
                    ),
                    if (fileUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: C.bd, thickness: 0.5),
                      const SizedBox(height: 8),
                      ...List.generate(fileUrls.length, (i) {
                        final name = i < fileNames.length && fileNames[i].isNotEmpty
                            ? fileNames[i]
                            : '첨부파일 ${i + 1}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => launchUrl(
                              Uri.parse(fileUrls[i]),
                              mode: LaunchMode.externalApplication,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: C.lv.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: C.lv.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file_rounded, size: 16, color: C.lv),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.download_rounded, size: 14, color: C.lv),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(landingNoticesProvider);

    return MoriBlockShell(
      label: isKorean ? '공지사항' : 'Notices',
      icon: Icons.campaign_rounded,
      accent: C.lv,
      child: _buildBody(context, noticesAsync),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue noticesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        noticesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (rawNotices) {
            final notices = rawNotices.where((n) => n.title.isNotEmpty).toList();
            if (notices.isEmpty) {
              return Column(
                children: [
                  for (int i = 0; i < 2; i++)
                    Container(
                      height: 52,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: C.bd.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.bd.withValues(alpha: 0.4)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    isKorean ? '등록된 공지사항이 없어요' : 'No notices yet',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ...notices.map((notice) {
                  final hasFile = notice.fileUrl.isNotEmpty || notice.fileUrls.isNotEmpty;
                  final fileName = notice.fileName.isNotEmpty
                      ? notice.fileName
                      : (notice.fileNames.isNotEmpty ? notice.fileNames.first : '첨부파일');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showNoticeDetailPost(context, notice),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (notice.isPinned) ...[
                                  Icon(Icons.push_pin_rounded, size: 14, color: C.lv),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    notice.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDateDt(notice.createdAt),
                                  style: TextStyle(fontSize: 12, color: C.mu),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, size: 16, color: C.mu),
                              ],
                            ),
                            if (hasFile) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.attach_file_rounded, size: 12, color: C.lv),
                                  const SizedBox(width: 4),
                                  Text(
                                    '첨부파일: $fileName',
                                    style: T.caption.copyWith(color: C.lv, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}


