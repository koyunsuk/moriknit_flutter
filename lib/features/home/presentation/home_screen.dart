import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/subscription_constants.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
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
import '../../../providers/blueprint_provider.dart';
import '../../../providers/step_run_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../../landing/data/landing_board_repository.dart';
import '../../project/data/public_project_service.dart';
import '../../project/presentation/widgets/project_start_sheet.dart';
import '../../tools/presentation/widgets/knit_dashboard_card.dart';
import '../../../providers/template_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../favorites/data/favorites_repository.dart';
import '../domain/editorial_post.dart';

// 공지사항 Provider
final landingNoticesProvider = StreamProvider<List<LandingPost>>((ref) {
  return LandingBoardRepository().getNotices();
});

/// #783 후속 — 홈 화면 Q&A 미리보기 Provider (최근 5개).
final homeQnaPostsProvider = StreamProvider<List<LandingPost>>((ref) {
  return LandingBoardRepository().getPosts('qa');
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _bannerDismissed = false;
  bool _popupShown = false;
  bool _migrationKicked = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 이슈 #687 — 로그인 완료 후 첫 홈 진입 시 자동 마이그레이션 1회 실행 (백그라운드).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kickOffMigration();
      // #781 — 퀵사이드바 별표에서 진입 시 즐겨찾기 탭으로 점프 후 리셋.
      final initialTab = ref.read(homeInitialTabProvider);
      if (initialTab != 0) {
        _tabController.animateTo(initialTab);
        ref.read(homeInitialTabProvider.notifier).state = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _maybeShowPopup() async {
    if (_popupShown) return;
    final appConfig = ref.read(appConfigProvider).valueOrNull;
    if (appConfig == null) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;

    // [신 경로] 어드민이 입력한 팝업 (popupEnabled + title/message).
    if (appConfig.hasAdminPopup) {
      // 동일 popupId 다시보지않기 처리는 Hive user box.
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      const seenKey = 'seen_admin_popup_id';
      final lastSeen = (box.get('settings') ?? {})[seenKey]?.toString() ?? '';
      if (appConfig.popupId.isNotEmpty && lastSeen == appConfig.popupId) {
        _popupShown = true;
        return;
      }
      if (!mounted) return;
      _popupShown = true;
      final title = appConfig.popupTitle.isNotEmpty
          ? appConfig.popupTitle
          : (isKorean ? '공지사항' : 'Notice');
      final message = appConfig.popupMessage;
      final linkUrl = appConfig.popupLinkUrl;
      if (!mounted) return;
      final dontShowAgain = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _MoriAnnouncementDialog(
          title: title,
          message: message,
          linkUrl: linkUrl,
          isKorean: isKorean,
        ),
      );
      // 체크박스 체크된 경우만 popupId 영구 기록 (미체크 시 다음 세션 재노출).
      if (dontShowAgain == true && appConfig.popupId.isNotEmpty) {
        final settings = Map<String, dynamic>.from(box.get('settings') ?? {});
        settings[seenKey] = appConfig.popupId;
        await box.put('settings', settings);
      }
      return;
    }

    // [구 경로] maintenanceNotice + noticeType == 'popup' (호환 보존).
    if (appConfig.maintenanceNotice.isNotEmpty && appConfig.noticeType == 'popup') {
      _popupShown = true;
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _MoriAnnouncementDialog(
          title: isKorean ? '공지사항' : 'Notice',
          message: appConfig.maintenanceNotice,
          linkUrl: '',
          isKorean: isKorean,
          showDontShowAgain: false,
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
    // 이슈 #775 — postsAsync/itemsAsync/projectCount/publicProjectsAsync는 _EcosystemHero가 자체 watch.
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
            // 홈/즐겨찾기 2탭 (이슈 #723 Phase B — 즐겨찾기 시스템)
            _HomeTabBar(
              controller: _tabController,
              isKorean: isKorean,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // [홈] 탭 — 기존 콘텐츠 그대로 보존
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 오늘 요약
                        _EcosystemHero(
                          t: t,
                          isKorean: isKorean,
                        ),
                        const SizedBox(height: 20),
                        // 1-b. 뜨개 대시보드 (이슈 #649 Phase 2)
                        KnitDashboardCard(isKorean: isKorean),
                        const SizedBox(height: 20),
                        // 1-c. 모리니트 함께뜨기 (이슈 #798) — 전체 사용자 활동 중인 함께뜨기 그룹.
                        //      ('내 함께뜨기' 블록은 마이페이지에 별도 보존 — 이슈 #798)
                        _CommunityKnitAlongSection(isKorean: isKorean),
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
                        const SizedBox(height: 20),
                        // 6. Q&A 문의 게시판 (#783 후속) — 최근 QnA 미리보기 + 문의하기 진입
                        _HomeQnaBoardSection(isKorean: isKorean),
                      ],
                    ),
                  ),
                  // [즐겨찾기 ⭐] 탭 — 별표한 화면 카드 그리드
                  _FavoritesTab(isKorean: isKorean),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈/즐겨찾기 탭바.
class _HomeTabBar extends StatelessWidget {
  final TabController controller;
  final bool isKorean;

  const _HomeTabBar({required this.controller, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: C.bd.withValues(alpha: 0.4), width: 0.5),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: C.lvD,
        unselectedLabelColor: C.tx2,
        indicatorColor: C.lvD,
        indicatorWeight: 2.5,
        labelStyle: T.bodyBold,
        unselectedLabelStyle: T.body,
        tabs: [
          Tab(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_rounded, size: 18),
                const SizedBox(width: 6),
                Text(isKorean ? '홈' : 'Home'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, size: 18),
                const SizedBox(width: 6),
                Text(isKorean ? '즐겨찾기' : 'Favorites'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 즐겨찾기 탭 본문 — 별표한 화면 그리드.
class _FavoritesTab extends ConsumerWidget {
  final bool isKorean;

  const _FavoritesTab({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteScreensProvider);

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isKorean ? '즐겨찾기를 불러오지 못했어요.' : 'Could not load favorites.',
            style: T.body.copyWith(color: C.tx2),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _FavoritesEmptyState(isKorean: isKorean);
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _FavoriteCard(item: item, isKorean: isKorean);
          },
        );
      },
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  final bool isKorean;
  const _FavoritesEmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    // 플레이스홀더 — 빈 카드 4개 + 안내 문구
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: List.generate(4, (_) => const _FavoritePlaceholderCard()),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: C.lvL.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.lv.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: C.og, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isKorean
                      ? '자주 가는 화면 우상단의 ⭐ 별 아이콘을 눌러\n즐겨찾기에 추가해 보세요.'
                      : 'Tap the ⭐ icon on any screen header to\nadd it to your favorites.',
                  style: T.caption.copyWith(color: C.tx2, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoritePlaceholderCard extends StatelessWidget {
  const _FavoritePlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.bd.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Icon(
          Icons.star_outline_rounded,
          size: 32,
          color: C.bd,
        ),
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  final FavoriteScreen item;
  final bool isKorean;

  const _FavoriteCard({required this.item, required this.isKorean});

  Future<void> _removeFavorite(BuildContext context, WidgetRef ref) async {
    await ref.read(favoritesRepositoryProvider).remove(item.screenId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            isKorean ? '즐겨찾기에서 해제됐어요.' : 'Removed from favorites.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(item.path),
            onLongPress: () => _removeFavorite(context, ref),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.accent, size: 22),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: T.bodyBold.copyWith(color: C.tx),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isKorean ? '바로가기' : 'Open',
                        style: T.caption.copyWith(
                          color: item.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // 이슈 #729 — 우상단 ✕ 즉시 해제 (항상 표시).
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _removeFavorite(context, ref),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: C.bd, width: 0.8),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: C.mu),
              ),
            ),
          ),
        ),
      ],
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

class _EcosystemHero extends ConsumerWidget {
  final bool isKorean;
  final AppStrings t;

  const _EcosystemHero({
    required this.t,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이슈 #775 — 자체 watch로 분리. top-level rebuild 감소.
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    final itemsAsync = ref.watch(marketItemsProvider);
    final projectCount = ref.watch(projectCountProvider);
    final publicProjectsAsync = ref.watch(publicProjectsProvider);
    final postCount = postsAsync.valueOrNull is List ? (postsAsync.valueOrNull as List).length : 0;
    final itemCount = itemsAsync.valueOrNull is List ? (itemsAsync.valueOrNull as List).length : 0;
    final galleryCount = publicProjectsAsync.valueOrNull is List ? (publicProjectsAsync.valueOrNull as List).length : 0;

    // 이슈 #723 — Hero 블록도 MoriBlockShell 표준으로 통일.
    return MoriBlockShell(
      label: isKorean ? '오늘의 모리니트' : "Today's MoriKnit",
      icon: Icons.today_rounded,
      accent: C.lv,
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
                  // #765 — 마켓 버블 톤 통일 (라벤더/핑크 계열로 다른 버블과 일치).
                  accent: C.pkD,
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
                        CachedNetworkImage(
                          imageUrl: thumbUrl,
                          width: 80,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
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
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: _projectCardHeight,
                            height: _projectCardHeight,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _projectImgPlaceholder(),
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
            // 이슈 #722 — AsyncDataView로 통일. 장애 시 "서버 연결에 장애" 표시.
            AsyncDataView<List<dynamic>>(
              async: postsAsync,
              placeholderRows: _visibleCount,
              rowHeight: _itemHeight,
              onRetry: () => ref.invalidate(postsProvider(communityAllCategory)),
              isEmpty: (posts) => posts.isEmpty,
              emptyBuilder: () => GestureDetector(
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
              ),
              builder: (posts) {
                final displayPosts = posts
                    .take(_visibleCount)
                    .map((p) => _PostDisplay(category: p.category as String, title: p.title as String, timeAgo: p.timeAgo as String, imageUrls: (p.imageUrls as List).cast<String>()))
                    .toList();
                // #784 — 실제 글이 visibleCount 이상일 때만 무한 스크롤 효과(반복). 부족하면 1회만.
                final loopPosts = displayPosts.length >= _visibleCount
                    ? [...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts, ...displayPosts]
                    : displayPosts;
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
            child: CachedNetworkImage(
              imageUrl: post.imageUrls.first,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox(width: 40, height: 40),
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
    // 이슈 #722 — AsyncDataView 통일. 무한로딩 차단 + 서버 장애 표시.
    return SizedBox(
      height: 180,
      child: AsyncDataView<List<dynamic>>(
        async: itemsAsync,
        placeholderRows: 1,
        rowHeight: 170,
        onRetry: () => ref.invalidate(latestPatternItemsProvider),
        isEmpty: (items) => items.isEmpty,
        emptyBuilder: () => EmptyBlockPlaceholder(
          message: widget.isKorean ? '등록된 도안이 아직 없어요' : 'No patterns yet',
          rows: 1,
          rowHeight: 170,
        ),
        builder: (items) => ListView.builder(
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
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              width: 130,
                              height: 90,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _PlaceholderIcon(accent: accent, imageType: item.imageType),
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
      ),
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

    // 이슈 #722 — AsyncDataView 통일. 빈 상태도 플레이스홀더로 표시.
    return AsyncDataView<List<dynamic>>(
      async: coursesAsync,
      placeholderRows: 2,
      rowHeight: 80,
      onRetry: () => ref.invalidate(randomCoursePicksProvider),
      isEmpty: (courses) => courses.isEmpty,
      emptyBuilder: () => EmptyBlockPlaceholder(
        message: isKorean ? '추천 강의가 아직 없어요' : 'No course picks yet',
        rows: 2,
        rowHeight: 80,
      ),
      builder: (courses) => Column(
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
                            CachedNetworkImage(
                              imageUrl: thumbUrl,
                              width: 100,
                              height: 70,
                              fit: BoxFit.cover,
                              errorWidget: (context, e, stack) => Container(
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
      ),
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
    // 이슈 #722 — AsyncDataView 통일.
    return AsyncDataView<List<dynamic>>(
      async: entriesAsync,
      placeholderRows: 3,
      rowHeight: 44,
      onRetry: () => ref.invalidate(guestbookListProvider),
      isEmpty: (entries) => entries.isEmpty,
      emptyBuilder: () => EmptyBlockPlaceholder(
        message: isKorean ? '아직 방명록이 없어요. 첫 인사를 남겨보세요!' : 'No guestbook entries yet.',
        rows: 3,
        rowHeight: 44,
      ),
      builder: (entries) {
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
    // 이슈 #722 — unused 클래스. 단순 SizedBox로 대체 (구조 깨짐 복구).
    return const SizedBox.shrink();
  }
}

void _showGalleryDetail(BuildContext context, WidgetRef ref, PublicProjectEntry entry) {
  context.push(
    Routes.galleryDetail,
    extra: {
      'entry': entry,
      'currentUid': ref.read(authStateProvider).valueOrNull?.uid ?? '',
    },
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
    // 이슈 #722 — AsyncDataView 통일.
    return AsyncDataView<List<dynamic>>(
      async: entriesAsync,
      placeholderRows: 1,
      rowHeight: 44,
      onRetry: () => ref.invalidate(guestbookListProvider),
      isEmpty: (entries) => entries.isEmpty,
      emptyBuilder: () => EmptyBlockPlaceholder(
        message: widget.isKorean ? '아직 방명록이 없어요.' : 'No guestbook entries yet.',
        rows: 1,
        rowHeight: 44,
      ),
      builder: (entries) {
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
    const galleryItemH = 68.0;
    const galleryCount = 4;
    // 픽셀 오버플로우 fix — SizedBox(height) 제거하여 EmptyBlockPlaceholder가 자체 크기로 표시되도록.
    // 데이터 있을 때 ListView.separated가 shrinkWrap으로 자체 크기 결정.
    return AsyncDataView<List<dynamic>>(
      async: projectsAsync,
      placeholderRows: 4,
      rowHeight: galleryItemH,
      onRetry: () => ref.invalidate(publicProjectsProvider),
      isEmpty: (entries) => entries.isEmpty,
      emptyBuilder: () => EmptyBlockPlaceholder(
        message: isKorean ? '아직 공개된 작품이 없어요.' : 'No public projects yet.',
        rows: 4,
        rowHeight: galleryItemH,
      ),
      builder: (entries) {
          final visible = entries.take(galleryCount).toList();
          return ListView.separated(
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
                          ? CachedNetworkImage(imageUrl: url, width: 64, height: 64, fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(width: 64, height: 64, color: C.lvL, child: Icon(Icons.grid_view_rounded, color: C.lv, size: 20)))
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

  Widget _buildBody(BuildContext context, AsyncValue<List<LandingPost>> noticesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이슈 #722 — AsyncDataView 통일. 무한로딩 차단 + 서버 장애 표시.
        AsyncDataView<List<LandingPost>>(
          async: noticesAsync,
          placeholderRows: 2,
          rowHeight: 52,
          onRetry: () => ref.invalidate(landingNoticesProvider),
          isEmpty: (raw) => raw.where((n) => n.title.isNotEmpty).isEmpty,
          emptyBuilder: () => EmptyBlockPlaceholder(
            message: isKorean ? '등록된 공지사항이 없어요' : 'No notices yet',
            rows: 2,
            rowHeight: 52,
          ),
          builder: (rawNotices) {
            final notices = rawNotices.where((n) => n.title.isNotEmpty).toList();
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

// ── #783 후속 — 홈 Q&A 게시판 미리보기 섹션 ────────────────────────────────

class _HomeQnaBoardSection extends ConsumerWidget {
  final bool isKorean;
  const _HomeQnaBoardSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qnaAsync = ref.watch(homeQnaPostsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return MoriBlockShell(
      label: isKorean ? 'Q&A 문의' : 'Q&A',
      icon: Icons.support_agent_rounded,
      accent: C.lmD,
      moreLabel: isKorean ? '전체 보기' : 'View all',
      onMoreTap: () => context.push('/board/qa'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 문의하기 진입 버튼
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                if (user == null) {
                  context.push('/login');
                  return;
                }
                context.push('/board/qa/write');
              },
              icon: Icon(Icons.edit_rounded, size: 16, color: C.lmD),
              label: Text(
                isKorean ? '+ 문의하기' : '+ Ask',
                style: T.caption
                    .copyWith(color: C.lmD, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 4),
          qnaAsync.when(
            loading: () => Column(
              children: List.generate(
                3,
                (_) => Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: C.bd.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('$e', style: T.caption.copyWith(color: C.og)),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        height: 40,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: C.bd.withValues(alpha: 0.5)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isKorean
                            ? '아직 문의글이 없어요. 첫 문의를 남겨보세요.'
                            : 'No questions yet. Be the first to ask.',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                    ),
                  ],
                );
              }
              final preview = posts.take(5).toList();
              return Column(
                children: [
                  for (final p in preview)
                    InkWell(
                      onTap: () => context.push('/board/qa/${p.id}'),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline_rounded,
                                size: 16, color: C.lmD),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title.isEmpty
                                        ? (isKorean
                                            ? '(제목 없음)'
                                            : '(No title)')
                                        : p.title,
                                    style: T.bodyBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        p.authorName,
                                        style: T.caption.copyWith(
                                            color: C.mu,
                                            fontWeight:
                                                FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${p.createdAt.year}.${p.createdAt.month}.${p.createdAt.day}',
                                        style: T.caption
                                            .copyWith(color: C.mu),
                                      ),
                                      if (p.commentCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.chat_bubble_outline,
                                            size: 12, color: C.mu),
                                        const SizedBox(width: 3),
                                        Text('${p.commentCount}',
                                            style: T.caption
                                                .copyWith(color: C.mu)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: C.mu),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// #798 — 홈 "모리니트 함께뜨기" 블록 (커뮤니티 성격).
/// 전체 사용자의 fork 활동을 받는 원본 도안 중 상위 N개 노출. forkCount desc.
/// 탭 → KnitAlongGroupScreen 진입 (해당 도안의 함께뜨기 그룹).
/// (기존 #791 '내 함께뜨기' 블록은 마이페이지에 보존됨 → MyKnitAlongMyPageBlock)
class _CommunityKnitAlongSection extends ConsumerWidget {
  final bool isKorean;
  const _CommunityKnitAlongSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(knitAlongGroupsProvider);

    return MoriBlockShell(
      label: isKorean ? '함께 뜨고 있어요' : 'Knitting Together',
      icon: Icons.call_split_rounded,
      accent: C.lvD,
      moreLabel: isKorean ? '커뮤니티' : 'Community',
      onMoreTap: () => context.go(Routes.community),
      child: AsyncDataView<List<StepBlueprint>>(
        async: groupsAsync,
        placeholderRows: 2,
        rowHeight: 56,
        isEmpty: (list) => list.isEmpty,
        emptyBuilder: () => _CommunityKnitAlongEmptyState(isKorean: isKorean),
        builder: (list) {
          final top = list.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < top.length; i++) ...[
                _CommunityKnitAlongRow(blueprint: top[i], isKorean: isKorean),
                if (i < top.length - 1)
                  const Divider(height: 12, thickness: 0.5),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// #798 — 모리니트 함께뜨기 Row (원본 도안 + 참여자 수).
class _CommunityKnitAlongRow extends StatelessWidget {
  final StepBlueprint blueprint;
  final bool isKorean;

  const _CommunityKnitAlongRow({
    required this.blueprint,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final forkCount = blueprint.forkCount;
    return InkWell(
      onTap: () => context.push('/knit-along/${blueprint.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_rounded, color: C.lvD, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blueprint.localizedTitle(isKorean),
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 13,
                        color: C.lvD,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isKorean
                            ? '$forkCount명 함께뜨는 중'
                            : '$forkCount knitting together',
                        style: T.caption.copyWith(
                          color: C.lvD,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}

/// #798 — 모리니트 함께뜨기 빈 상태(플레이스홀더).
class _CommunityKnitAlongEmptyState extends StatelessWidget {
  final bool isKorean;
  const _CommunityKnitAlongEmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: C.bd.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 110,
                        decoration: BoxDecoration(
                          color: C.bd,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 5,
                        width: 80,
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          isKorean
              ? '아직 함께뜨고 있는 도안이 없어요.\n커뮤니티에서 마음에 드는 도안에 함께해 보세요.'
              : 'No active knit-alongs yet.\nJoin from the community.',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
      ],
    );
  }
}

/// #791 — "내 함께뜨기" 블록 (이슈 #798에서 마이페이지로 이전).
/// 내가 fork 한 도안(=함께 뜨기 참여 중)을 최근 활동순 최대 3개 노출.
/// 진행률 + 원본 도안 이름 표시. 탭 → KnitAlongGroupScreen 진입.
///
/// **외부에서 (예: my_page_screen) import 해 사용** — `_` private 이지만
/// 같은 패키지 내라면 사용 가능. 단, 동일 파일 내에서만 사용된다면 private 유지.
/// 이슈 #798: 마이페이지에서 사용하므로 public 으로 노출.
class MyKnitAlongMyPageBlock extends ConsumerWidget {
  final bool isKorean;
  const MyKnitAlongMyPageBlock({super.key, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myKnitAlongsAsync = ref.watch(myKnitAlongsProvider);

    return AsyncDataView<List<StepBlueprint>>(
      async: myKnitAlongsAsync,
      placeholderRows: 2,
      rowHeight: 56,
      isEmpty: (list) => list.isEmpty,
      emptyBuilder: () => _MyKnitAlongEmptyState(isKorean: isKorean),
      builder: (list) {
        final top = list.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < top.length; i++) ...[
              _MyKnitAlongRow(blueprint: top[i], isKorean: isKorean),
              if (i < top.length - 1)
                const Divider(height: 12, thickness: 0.5),
            ],
          ],
        );
      },
    );
  }
}

class _MyKnitAlongRow extends ConsumerWidget {
  final StepBlueprint blueprint;
  final bool isKorean;

  const _MyKnitAlongRow({required this.blueprint, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originId = blueprint.fromBlueprintId ?? '';
    final runsAsync = ref.watch(stepRunsByBlueprintProvider(blueprint.id));
    final runs = runsAsync.valueOrNull ?? const [];
    final pct = runs.isEmpty ? 0.0 : runs.first.summary.percentComplete;

    return InkWell(
      onTap: originId.isEmpty
          ? null
          : () => context.push('/knit-along/$originId'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_rounded, color: C.lvD, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blueprint.localizedTitle(isKorean),
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: C.bd,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(C.lvD),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: T.caption.copyWith(
                          color: C.lvD,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MyKnitAlongEmptyState extends StatelessWidget {
  final bool isKorean;
  const _MyKnitAlongEmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: C.bd.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 110,
                        decoration: BoxDecoration(
                          color: C.bd,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          isKorean
              ? '커뮤니티에서 마음에 드는 도안으로\n함께 뜨기를 시작해 보세요.'
              : 'Start a knit-along from any pattern\nin the community.',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
      ],
    );
  }
}

/// 모리니트 공지 다이얼로그 — 테마 그라데이션 헤더 + 다시보지않기 체크박스.
/// #812 후속 UI 개선 — 풍부한 디자인 + 표준 팝업 형식 (다시보지않기 + 확인).
class _MoriAnnouncementDialog extends StatefulWidget {
  final String title;
  final String message;
  final String linkUrl;
  final bool isKorean;
  final bool showDontShowAgain;

  const _MoriAnnouncementDialog({
    required this.title,
    required this.message,
    required this.linkUrl,
    required this.isKorean,
    this.showDontShowAgain = true,
  });

  @override
  State<_MoriAnnouncementDialog> createState() => _MoriAnnouncementDialogState();
}

class _MoriAnnouncementDialogState extends State<_MoriAnnouncementDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 그라데이션 헤더 ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [C.lv, C.pk],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isKorean ? '모리니트 공지' : 'MoriKnit Notice',
                      style: T.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 본문 ────────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: T.h3.copyWith(color: C.tx, height: 1.3),
                    ),
                    if (widget.message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.message,
                        style: T.body.copyWith(color: C.tx2, height: 1.55),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── 다시 보지 않기 체크박스 ──────────────────────────────────────────
            if (widget.showDontShowAgain)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _dontShowAgain,
                            onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                            activeColor: C.lv,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.isKorean ? '다시 보지 않기' : "Don't show again",
                          style: T.caption.copyWith(color: C.tx2, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // ── 액션 버튼 ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.linkUrl.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(widget.linkUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        if (context.mounted) Navigator.pop(context, _dontShowAgain);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: C.lvD,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: Text(widget.isKorean ? '바로 가기' : 'Go to'),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _dontShowAgain),
                    style: FilledButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.isKorean ? '확인' : 'OK',
                      style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
