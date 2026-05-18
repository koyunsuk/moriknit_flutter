import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../course/domain/course_item.dart';
import '../../project/domain/project_model.dart';
import '../../ravelry/data/ravelry_auth_provider.dart';
import '../../ravelry/data/ravelry_repository.dart';
import '../../ravelry/presentation/ravelry_screen.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../project/presentation/widgets/project_start_sheet.dart';
import '../../etsy/data/etsy_auth_provider.dart';
import '../../dropbox/data/dropbox_auth_provider.dart';
// 이슈 #703 — 외부 클라우드 확장 (Google Drive·iCloud·OneDrive)
import '../../cloud_integrations/data/google_drive_auth_provider.dart';
import '../../cloud_integrations/data/icloud_auth_provider.dart';
import '../../cloud_integrations/data/onedrive_auth_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../../providers/needle_provider.dart';
import '../../../providers/accessory_provider.dart';
import '../../../providers/book_provider.dart';
import '../../my/data/recent_works_provider.dart';

String _youtubeThumbnail(String videoUrl) {
  final uri = Uri.tryParse(videoUrl);
  if (uri == null) return '';
  String? id;
  if (uri.host.contains('youtu.be')) {
    id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  } else {
    id = uri.queryParameters['v'];
  }
  return id != null ? 'https://img.youtube.com/vi/$id/mqdefault.jpg' : '';
}

// 내 작업실 5탭 분리: 작업관리 / AI / Asset / 도구 / 학습
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final headerSubtitle = resolveUiCopy(data: uiCopy, language: language, key: 'tools_header_subtitle', fallback: t.toolsHeaderSubtitle);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final userName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (authUser?.displayName?.isNotEmpty == true
            ? authUser!.displayName!
            : (authUser?.email?.isNotEmpty == true ? authUser!.email!.split('@').first : ''));
    final userLabel = userName.isNotEmpty ? '$userName님의' : (isKorean ? '나의' : 'My');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더 (스크롤 안 됨)
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '$userLabel 작업실' : '$userLabel Studio',
                subtitle: headerSubtitle,
              ),
            ),
            // NestedScrollView — 요약카드는 위로 스크롤되어 사라짐, 탭바는 sticky.
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        children: [
                          _MoriRavelryCapsuleCard(isKorean: isKorean),
                          const SizedBox(height: 12),
                          // #769 후속 — Asset 자리에 '최근 작업' 블록 (프로젝트/스와치/도안 랜덤).
                          _RecentWorksBlock(isKorean: isKorean),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ToolsTabBarDelegate(
                      child: Container(
                        color: C.bg,
                        child: _ToolsTabBar(controller: _tab, isKorean: isKorean),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tab,
                  children: [
                    _WorkTab(isKorean: isKorean),
                    _AiTab(isKorean: isKorean, t: t),
                    _AssetTab(isKorean: isKorean, t: t),
                    _ToolboxTab(isKorean: isKorean, t: t),
                    _LearningTab(isKorean: isKorean, t: t),
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

class _ToolsTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _ToolsTabBarDelegate({required this.child});
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_ToolsTabBarDelegate oldDelegate) => oldDelegate.child != child;
}

// ── 탭바 ───────────────────────────────────────────────────────
class _ToolsTabBar extends StatelessWidget {
  final TabController controller;
  final bool isKorean;
  const _ToolsTabBar({required this.controller, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: C.lv.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: C.lvD,
        unselectedLabelColor: C.mu,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: [
          _miniTab(Icons.folder_special_rounded, isKorean ? '작업관리' : 'Work'),
          _miniTab(Icons.auto_awesome_rounded, isKorean ? 'AI' : 'AI'),
          _miniTab(Icons.inventory_2_rounded, isKorean ? 'Asset' : 'Asset'),
          _miniTab(Icons.build_rounded, isKorean ? '도구' : 'Tools'),
          _miniTab(Icons.school_rounded, isKorean ? '학습' : 'Learn'),
        ],
      ),
    );
  }

  Widget _miniTab(IconData icon, String label) {
    return Tab(
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}

// ── 탭 1: 작업관리 ───────────────────────────────────────────
class _WorkTab extends ConsumerWidget {
  final bool isKorean;
  const _WorkTab({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjects = ref.watch(activeProjectsProvider);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행중 프로젝트
          MoriBlockShell(
            label: isKorean ? '진행중 프로젝트' : 'Active Projects',
            icon: Icons.folder_open_rounded,
            accent: C.lmD,
            child: activeProjects.isEmpty
                ? Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.folder_open_rounded, color: C.lmD, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isKorean ? '진행 중인 프로젝트가 없어요' : 'No active projects', style: T.bodyBold),
                            const SizedBox(height: 2),
                            Text(isKorean ? '새 프로젝트를 시작해보세요' : 'Start a new project', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => showProjectStartSheet(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(isKorean ? '추가' : 'Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    // #767 — 진행중 프로젝트 블록 높이 축소 (300 → 180), 버티칼 스크롤 유지.
                    height: 180,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView(
                        children: [
                          ...activeProjects.map((p) => _ProjectCard(
                                project: p,
                                isKorean: isKorean,
                                onTap: () => context.push('/project/${p.id}'),
                              )),
                          if (activeProjects.length > 3)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push(Routes.projectList),
                                child: Text(isKorean ? '전체 보기' : 'View all'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // 나의 작업 관리
          MoriBlockShell(
            label: isKorean ? '나의 작업 관리' : 'My Work Management',
            icon: Icons.work_outline_rounded,
            accent: C.lv,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToolCard(
                  icon: Icons.grid_view_rounded,
                  color: C.lmD,
                  title: isKorean ? '스와치 라이브러리' : 'Swatch Library',
                  description: isKorean ? '게이지와 실 정보를 기록해요' : 'Record gauge and yarn info',
                  onTap: () => context.push(Routes.swatchList),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.grid_on_rounded,
                  color: C.lvD,
                  title: isKorean ? '나의 도안 라이브러리' : 'My Pattern Library',
                  description: isKorean ? '컬러/기호 모드로 나만의 도안을 그려요' : 'Draw your own charts',
                  onTap: () => context.push(Routes.toolsPatterns),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.folder_special_rounded,
                  color: C.lv,
                  title: isKorean ? '프로젝트 라이브러리' : 'Project Library',
                  description: isKorean ? '진행 중인 작업을 한눈에 관리해요' : 'Manage all your ongoing projects',
                  onTap: () => context.push(Routes.projectList),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.folder_copy_rounded,
                  color: C.lv,
                  title: isKorean ? '나의 템플릿 관리' : 'My Templates',
                  description: isKorean ? '프로젝트 시작 단계를 템플릿으로 관리해요' : 'Manage project steps as templates',
                  onTap: () => context.push(Routes.templateList),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.photo_library_rounded,
                  color: C.pk,
                  title: isKorean ? '나의 작업 앨범' : 'My Work Album',
                  description: isKorean ? '프로젝트·스와치 사진을 날짜별로 모아봐요' : 'Browse project & swatch photos by date',
                  onTap: () => context.push(Routes.photoAlbum),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 탭 2: AI ─────────────────────────────────────────────────
class _AiTab extends ConsumerWidget {
  final bool isKorean;
  final dynamic t;
  const _AiTab({required this.isKorean, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoriBlockShell(
            label: isKorean ? 'AI 작업 도구' : 'AI Tools',
            icon: Icons.auto_awesome_rounded,
            accent: C.lvD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToolCard(
                  icon: Icons.auto_awesome_rounded,
                  color: C.lv,
                  title: isKorean ? 'AI 도안 변환기' : 'AI Pattern Converter',
                  description: isKorean
                      ? 'PDF·이미지 도안을 나의 도안 라이브러리로 변환'
                      : 'Convert PDF/image patterns to your library',
                  onTap: () => context.push(Routes.toolsPatternConverter),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.calculate_rounded,
                  color: C.pk,
                  title: isKorean ? 'AI 게이지 계산기' : 'AI Gauge Calculator',
                  description: t.gaugeHeaderSubtitle,
                  onTap: () => context.push(Routes.toolsGauge),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.translate_rounded,
                  color: C.lv,
                  title: isKorean ? 'AI 영문도안 번역기' : 'Pattern Translator',
                  description: isKorean
                      ? 'Ravelry/Etsy 등 영문 도안을 한국어로 변환합니다'
                      : 'Translate English patterns to Korean',
                  onTap: () => context.push(Routes.toolsPatternTranslator),
                ),
                const SizedBox(height: 10),
                // 이슈 #664 — AI 패턴 생성기 (래글런 + 단계별 도식 + 출판용 PDF)
                _ToolCard(
                  icon: Icons.auto_stories_rounded,
                  color: C.lvD,
                  title: isKorean ? 'AI 패턴 생성기' : 'AI Pattern Generator',
                  description: isKorean
                      ? '치수+게이지로 도안 자동 생성, 단계별 도식, 출판용 PDF'
                      : 'Auto-build patterns with diagrams + print-ready PDF',
                  onTap: () => context.push(Routes.toolsPatternGenerator),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 탭 3: Asset ──────────────────────────────────────────────
class _AssetTab extends ConsumerWidget {
  final bool isKorean;
  final dynamic t;
  const _AssetTab({required this.isKorean, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #769 (재복구) — 나의 Asset 라이브러리 4종(실/바늘/악세사리/도서) 복구.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoriBlockShell(
            label: isKorean ? '나의 Asset 관리' : 'My Asset Management',
            icon: Icons.inventory_2_rounded,
            accent: C.pk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToolCard(
                  icon: Icons.circle_outlined,
                  color: C.lv,
                  title: isKorean ? '나의 바늘 라이브러리' : 'My Needle Library',
                  description: t.needleToolDescription,
                  onTap: () => context.push(Routes.needles),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.texture,
                  color: C.pk,
                  title: isKorean ? '나의 실 라이브러리' : 'My Yarn Library',
                  description: isKorean ? '실 보유 현황과 실 정보를 관리해요' : 'Manage your yarn stash and info',
                  onTap: () => context.push('/yarn-list'),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.build_rounded,
                  color: C.pkD,
                  title: isKorean ? '나의 악세사리 라이브러리' : 'My Accessory Library',
                  description: isKorean ? '니팅 도구 및 악세사리를 관리해요' : 'Manage your knitting tools & accessories',
                  onTap: () => context.push(Routes.accessories),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.menu_book_rounded,
                  color: C.lmD,
                  title: isKorean ? '나의 도서 라이브러리' : 'My Book Library',
                  description: isKorean ? '참고 도서 목록을 관리해요' : 'Manage your reference books',
                  onTap: () => context.push(Routes.books),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 탭 4: 도구 ───────────────────────────────────────────────
class _ToolboxTab extends ConsumerWidget {
  final bool isKorean;
  final dynamic t;
  const _ToolboxTab({required this.isKorean, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // #767 — 도구 블록 테마 라벤더로 통일.
          MoriBlockShell(
            label: isKorean ? '기타 도구·자산' : 'Other Tools',
            icon: Icons.handyman_rounded,
            accent: C.lvD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToolCard(
                  icon: Icons.add_task_rounded,
                  color: C.pkD,
                  title: isKorean ? '카운터 라이브러리' : 'Counter Library',
                  description: t.counterTools,
                  onTap: () => context.push(Routes.counterList),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.edit_note_rounded,
                  color: C.pk,
                  title: t.memoPad,
                  description: t.toolsMemoDescription,
                  onTap: () => context.push(Routes.toolsMemo),
                  showLock: true,
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.timer_rounded,
                  color: C.lv,
                  title: isKorean ? '뜨개 타이머' : 'Knitting Timer',
                  description: isKorean ? '전체 뜨개 시간 누적 기록' : 'Accumulate total knitting time',
                  onTap: () => context.push(Routes.toolsFreeTimer),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.dashboard_rounded,
                  color: C.lvD,
                  title: isKorean ? '뜨개시간 대시보드' : 'Time Dashboard',
                  description: isKorean ? '자유·도안·스와치 누적시간 통합' : 'Free + pattern + swatch totals',
                  onTap: () => context.push(Routes.toolsTimeDashboard),
                ),
                const SizedBox(height: 10),
                // 이슈 #660 Phase 2 — 파일 탐색기
                _ToolCard(
                  icon: Icons.folder_open_rounded,
                  color: C.pkD,
                  title: isKorean ? '파일 탐색기' : 'File Explorer',
                  description: isKorean
                      ? '폰의 PDF·이미지 파일을 한번에 도안 라이브러리로'
                      : 'Bulk import PDFs/images from your phone',
                  onTap: () => context.push(Routes.toolsFileExplorer),
                ),
                const SizedBox(height: 10),
                // 이슈 #665/#668 — 도안 에디터
                _ToolCard(
                  icon: Icons.edit_note_rounded,
                  color: C.pk,
                  title: isKorean ? '도안 에디터' : 'Pattern Editor',
                  description: isKorean
                      ? '내 도안 목록 + 사각/원형/자유 path 새 도안'
                      : 'My charts + new (rect/round/path)',
                  onTap: () => context.push(Routes.toolsPatternGate),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.straighten_rounded,
                  color: C.lvD,
                  title: isKorean ? '바늘 크기 변환기' : 'Needle Size Converter',
                  description: isKorean ? '대바늘/코바늘 Metric ↔ US ↔ JP 변환' : 'Knitting & Crochet: Metric ↔ US ↔ JP',
                  onTap: () => context.push(Routes.toolsNeedleSize),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.square_foot_rounded,
                  color: C.lv,
                  title: isKorean ? '측정 도구' : 'Measure Tool',
                  description: isKorean ? '격자·각도·원·실바늘 두께를 화면으로 측정' : 'Measure grid, angle, circle & yarn/needle',
                  onTap: () => context.push(Routes.toolsMeasure),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // #767 — 외부 연결 블록도 라벤더로 통일.
          MoriBlockShell(
            label: isKorean ? '외부 연결' : 'External Links',
            icon: Icons.link_rounded,
            accent: C.lv,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RavelryCard(isKorean: isKorean),
                const SizedBox(height: 10),
                _EtsyCard(isKorean: isKorean),
                const SizedBox(height: 10),
                _CloudHubCard(isKorean: isKorean),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 탭 5: 학습 ───────────────────────────────────────────────
class _LearningTab extends ConsumerWidget {
  final bool isKorean;
  final dynamic t;
  const _LearningTab({required this.isKorean, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseProvider);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 최근 강의실
          MoriBlockShell(
            label: isKorean ? '최근 강의실' : 'Recent Course',
            icon: Icons.play_lesson_rounded,
            accent: C.lvD,
            onMoreTap: () => context.push(Routes.toolsCourse),
            child: coursesAsync.maybeWhen(
              data: (courses) {
                if (courses.isEmpty) {
                  return GlassCard(
                    onTap: () => context.push(Routes.toolsCourse),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.school_rounded, color: C.lvD, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isKorean ? '등록된 강의가 없어요' : 'No courses yet', style: T.bodyBold.copyWith(color: C.tx2)),
                              const SizedBox(height: 2),
                              Text(isKorean ? '강의실 탭해서 추가하기' : 'Tap to add a course', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  );
                }
                return _CourseCard(course: courses.first, isKorean: isKorean, onTap: () => context.push(Routes.toolsCourse));
              },
              orElse: () => GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.school_rounded, color: C.lvD, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(isKorean ? '강의를 불러오는 중...' : 'Loading courses...', style: T.body.copyWith(color: C.mu))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 나의 학습관리 (뜨개사전 + 클라스)
          MoriBlockShell(
            label: isKorean ? '나의 학습관리' : 'My Learning',
            icon: Icons.school_rounded,
            accent: C.pkD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToolCard(
                  icon: Icons.menu_book_rounded,
                  color: C.pkD,
                  title: t.myEncyclopedia,
                  description: t.encyclopediaToolDescription,
                  onTap: () => context.push(Routes.toolsEncyclopedia),
                ),
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.school_rounded,
                  color: C.lvD,
                  title: isKorean ? '클라스' : 'Class',
                  description: t.coursesToolDescription,
                  onTap: () => context.push(Routes.toolsCourse),
                ),
                // 사용자 분류표 — 학습탭에 나의 도서 중복 노출
                const SizedBox(height: 10),
                _ToolCard(
                  icon: Icons.menu_book_rounded,
                  color: C.lmD,
                  title: isKorean ? '나의 도서 라이브러리' : 'My Book Library',
                  description: isKorean ? '참고 도서 목록을 관리해요' : 'Manage your reference books',
                  onTap: () => context.push(Routes.books),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final bool isKorean;
  final VoidCallback onTap;
  const _ProjectCard({required this.project, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = isKorean
        ? (ProjectStatus.values.firstWhere((s) => s.value == project.status, orElse: () => ProjectStatus.planning).koreanLabel)
        : (ProjectStatus.values.firstWhere((s) => s.value == project.status, orElse: () => ProjectStatus.planning).label);
    final counters = ref.watch(countersByProjectProvider(project.id)).valueOrNull ?? [];
    final rowTargetCounters = counters.where((c) => c.targetRowCount > 0).toList();
    final totalRows = rowTargetCounters.fold<int>(0, (acc, c) => acc + c.rowCount);
    final totalTargetRows = rowTargetCounters.fold<int>(0, (acc, c) => acc + c.targetRowCount);
    final rowRatio = totalTargetRows > 0 ? (totalRows / totalTargetRows).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
                child: project.coverPhotoUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: project.coverPhotoUrl, fit: BoxFit.cover))
                    : Icon(Icons.folder_special_rounded, color: C.lv, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.title.isNotEmpty ? project.title : (isKorean ? '제목 없음' : 'Untitled'), style: T.bodyBold),
                    if (project.yarnName.isNotEmpty)
                      Text(project.yarnName, style: T.caption.copyWith(color: C.mu)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
            ],
          ),
          if (project.totalStepCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: C.lv, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (project.completedStepCount / project.totalStepCount).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: C.lv.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(C.lv),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${project.completedStepCount}/${project.totalStepCount}${isKorean ? '단계' : ' steps'}',
                  style: T.caption.copyWith(color: C.lv),
                ),
              ],
            ),
          ],
          if (totalTargetRows > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.straighten_rounded, color: C.pk, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: rowRatio,
                      minHeight: 5,
                      backgroundColor: C.pk.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(C.pk),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalRows/$totalTargetRows${isKorean ? '단' : ' rows'}',
                  style: T.caption.copyWith(color: C.pk),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseItem course;
  final bool isKorean;
  final VoidCallback onTap;
  const _CourseCard({required this.course, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = isKorean ? course.title : (course.titleEn.isNotEmpty ? course.titleEn : course.title);
    final thumbUrl = course.thumbnailUrl.isNotEmpty
        ? course.thumbnailUrl
        : _youtubeThumbnail(course.videoUrl);
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: thumbUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover, errorWidget: (_, e, s) => Container(color: C.lvL, child: Icon(Icons.school_rounded, color: C.lvD, size: 36)))
                  : Container(color: C.lvL, child: Icon(Icons.school_rounded, color: C.lvD, size: 36)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(course.category, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _EtsyCard extends ConsumerWidget {
  const _EtsyCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(etsyAuthProvider);
    return GlassCard(
      onTap: () => context.push(Routes.etsy),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF16521).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFFF16521)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Etsy', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.shopName ?? ''} 샵 연결됨' : 'Shop connected')
                      : (isKorean ? '내 Etsy 샵 리스팅을 앱에서 확인해요' : 'View your Etsy shop listings'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? const Color(0xFFF16521) : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: Color(0xFFF16521), size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

// 외부 연결 UI 단계 정리 — Dropbox/GDrive/iCloud/OneDrive 4개를 1개 "클라우드" 카드로 통합
class _CloudHubCard extends ConsumerWidget {
  const _CloudHubCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dropbox = ref.watch(dropboxAuthProvider);
    final gdrive = ref.watch(googleDriveAuthProvider);
    final icloud = ref.watch(iCloudAuthProvider);
    final onedrive = ref.watch(oneDriveAuthProvider);
    final connectedCount = [dropbox.isLoggedIn, gdrive.isLoggedIn, icloud.isLoggedIn, onedrive.isLoggedIn]
        .where((c) => c)
        .length;
    return GlassCard(
      onTap: () => context.push(Routes.cloudHub),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud_rounded, color: C.lv),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '클라우드' : 'Cloud', style: T.bodyBold),
                const SizedBox(height: 4),
                Text(
                  isKorean
                      ? 'Dropbox · Google Drive · iCloud · OneDrive'
                      : 'Dropbox · Google Drive · iCloud · OneDrive',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
          ),
          if (connectedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isKorean ? '$connectedCount개 연결됨' : '$connectedCount connected',
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _RavelryCard extends ConsumerWidget {
  const _RavelryCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(ravelryAuthProvider);
    return GlassCard(
      onTap: () => context.push(Routes.ravelry),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.texture, color: C.lv),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ravelry', style: T.bodyBold),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.username}님 계정 연결됨' : 'Connected as ${auth.username}')
                      : (isKorean ? '실·도안·프로젝트를 라벨리와 연동해요' : 'Sync stash, patterns & projects'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? C.lv : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            Icon(Icons.check_circle_rounded, color: C.lv, size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

/// #769 후속 — 내 작업실 상단 "최근 작업" 블록.
class _RecentWorksBlock extends ConsumerWidget {
  final bool isKorean;
  const _RecentWorksBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recentWorksProvider);
    return MoriBlockShell(
      label: isKorean ? '최근 작업' : 'Recent Works',
      icon: Icons.history_rounded,
      accent: C.pk,
      moreLabel: isKorean ? '새로고침' : 'Shuffle',
      onMoreTap: () => ref.invalidate(recentWorksProvider),
      child: SizedBox(
        height: 120,
        child: items.isEmpty
            ? Center(
                child: Text(
                  isKorean
                      ? '아직 저장된 이미지가 없어요. 프로젝트나 스와치를 추가해 보세요.'
                      : 'No images yet. Add a project or swatch first.',
                  style: T.caption.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return GestureDetector(
                    onTap: () => context.push(item.routePath),
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(color: C.bd.withValues(alpha: 0.15)),
                                    errorWidget: (_, _, _) => Container(
                                      color: C.bd.withValues(alpha: 0.15),
                                      child: Icon(Icons.broken_image_rounded, color: C.mu, size: 20),
                                    ),
                                  ),
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.typeLabel(isKorean),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.caption.copyWith(color: C.tx2, fontWeight: FontWeight.w600),
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

// ignore: unused_element
class _AssetSummaryCard extends StatelessWidget {
  final bool isKorean;
  const _AssetSummaryCard({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    // 이슈 #776 — 카운트별 ConsumerWidget으로 분리. 셀별로 자기 provider만 watch.
    // 이슈 #723 — 블록 외형 표준 MoriBlockShell 사용.
    return MoriBlockShell(
      label: isKorean ? '나의 Asset' : 'My Assets',
      icon: Icons.inventory_2_rounded,
      accent: C.pk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _ProjectCountCell(isKorean: isKorean)),
              const SizedBox(width: 10),
              Expanded(child: _SwatchCountCell(isKorean: isKorean)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _YarnCountCell(isKorean: isKorean)),
              const SizedBox(width: 10),
              Expanded(child: _NeedleCountCell(isKorean: isKorean)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AccessoryCountCell(isKorean: isKorean)),
              const SizedBox(width: 10),
              Expanded(child: _BookCountCell(isKorean: isKorean)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectCountCell extends ConsumerWidget {
  final bool isKorean;
  const _ProjectCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectCount = ref.watch(projectCountProvider);
    return _AssetCell(
      icon: Icons.folder_special_rounded,
      color: C.lv,
      label: isKorean ? '프로젝트' : 'Projects',
      value: '$projectCount',
      onTap: () => context.push(Routes.projectList),
    );
  }
}

class _SwatchCountCell extends ConsumerWidget {
  final bool isKorean;
  const _SwatchCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swatchCount = ref.watch(swatchCountProvider);
    return _AssetCell(
      icon: Icons.grid_view_rounded,
      color: C.lmD,
      label: isKorean ? '스와치' : 'Swatches',
      value: '$swatchCount',
      onTap: () => context.push(Routes.swatchList),
    );
  }
}

class _YarnCountCell extends ConsumerWidget {
  final bool isKorean;
  const _YarnCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yarnCount = ref.watch(yarnCountProvider);
    return _AssetCell(
      icon: Icons.texture,
      color: C.pk,
      label: isKorean ? '실' : 'Yarn',
      value: '$yarnCount',
      onTap: () => context.push('/yarn-list'),
    );
  }
}

class _NeedleCountCell extends ConsumerWidget {
  final bool isKorean;
  const _NeedleCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needleAsync = ref.watch(needleListProvider);
    final needleCount = needleAsync.maybeWhen(data: (n) => n.length, orElse: () => 0);
    return _AssetCell(
      icon: Icons.circle_outlined,
      color: C.lvD,
      label: isKorean ? '바늘' : 'Needles',
      value: '$needleCount',
      onTap: () => context.push(Routes.needles),
    );
  }
}

class _AccessoryCountCell extends ConsumerWidget {
  final bool isKorean;
  const _AccessoryCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessoryAsync = ref.watch(accessoryListProvider);
    final accessoryCount = accessoryAsync.maybeWhen(data: (a) => a.length, orElse: () => 0);
    return _AssetCell(
      icon: Icons.build_rounded,
      color: C.pkD,
      label: isKorean ? '악세사리' : 'Accessories',
      value: '$accessoryCount',
      onTap: () => context.push(Routes.accessories),
    );
  }
}

class _BookCountCell extends ConsumerWidget {
  final bool isKorean;
  const _BookCountCell({required this.isKorean});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookListProvider);
    final bookCount = bookAsync.maybeWhen(data: (b) => b.length, orElse: () => 0);
    return _AssetCell(
      icon: Icons.menu_book_rounded,
      color: C.lmD,
      label: isKorean ? '도서' : 'Books',
      value: '$bookCount',
      onTap: () => context.push(Routes.books),
    );
  }
}

class _AssetCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _AssetCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.tx, height: 1.1)),
                  Text(label, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 16),
          ],
        ),
      ),
    );
  }
}


class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool showLock;
  const _ToolCard({required this.icon, required this.color, required this.title, required this.description, required this.onTap, this.showLock = false});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: T.bodyBold),
                    if (showLock) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.lock_rounded, size: 13, color: C.mu),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

// ── MoriKnit + Ravelry 2단 캡슐 카드 ──────────────────────
class _MoriRavelryCapsuleCard extends ConsumerStatefulWidget {
  final bool isKorean;
  const _MoriRavelryCapsuleCard({required this.isKorean});

  @override
  ConsumerState<_MoriRavelryCapsuleCard> createState() => _MoriRavelryCapsuleCardState();
}

class _MoriRavelryCapsuleCardState extends ConsumerState<_MoriRavelryCapsuleCard> {
  bool get isKorean => widget.isKorean;

  @override
  Widget build(BuildContext context) {
    final yarnCount = ref.watch(yarnCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final patternAsync = ref.watch(patternListProvider);
    final patternCount = patternAsync.maybeWhen(data: (p) => p.length, orElse: () => 0);
    final auth = ref.watch(ravelryAuthProvider);
    final stashAsync = auth.isLoggedIn ? ref.watch(ravelryStashProvider) : null;
    final libraryAsync = auth.isLoggedIn ? ref.watch(ravelryLibraryProvider) : null;
    final ravelryProjectsAsync = auth.isLoggedIn ? ref.watch(ravelryProjectsProvider) : null;

    final stashCount = stashAsync?.maybeWhen(data: (s) => s.length, orElse: () => null);
    final libraryCount = libraryAsync?.maybeWhen(data: (p) => p.length, orElse: () => null);
    final ravelryProjectCount = ravelryProjectsAsync?.maybeWhen(data: (p) => p.length, orElse: () => null);
    final isRavelryLoading = auth.isLoggedIn && (
      stashAsync?.isLoading == true ||
      libraryAsync?.isLoading == true ||
      ravelryProjectsAsync?.isLoading == true
    );

    // 이슈 #723 — 블록 외형 표준 (도안 라이브러리 MoriBlockShell 기준):
    // GlassCard radius 18 + 옅은 헤더 톤 보더. 듀얼 캡슐 콘텐츠는 그대로.
    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: C.pk.withValues(alpha: 0.25),
      child: Column(
        children: [
          // MoriKnit 상단
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0x14FF6BA8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.pk.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('MoriKnit',
                        style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                ),
                Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/yarn-list'),
                  child: _CapsuleStat(label: isKorean ? '실' : 'Yarn', value: '$yarnCount'),
                )),
                Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Expanded(child: GestureDetector(
                  onTap: () => context.push(Routes.projectList),
                  child: _CapsuleStat(label: isKorean ? '프로젝트' : 'Project', value: '$projectCount'),
                )),
                Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Expanded(child: GestureDetector(
                  onTap: () => context.push(Routes.toolsPatterns),
                  child: _CapsuleStat(label: isKorean ? '도안' : 'Pattern', value: '$patternCount'),
                )),
              ],
            ),
          ),
          // 구분선
          Container(height: 1, color: C.bd),
          // Ravelry 하단
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Ravelry',
                        style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                ),
                Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                if (!auth.isLoggedIn)
                  Expanded(child: GestureDetector(
                    onTap: () => context.push(Routes.ravelry),
                    child: Text(isKorean ? '연결 안 됨' : 'Not connected',
                        style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
                  ))
                else if (isRavelryLoading)
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 3, child: LinearProgressIndicator(
                        backgroundColor: C.bd2,
                        valueColor: AlwaysStoppedAnimation(C.lv),
                        borderRadius: BorderRadius.circular(2),
                      )),
                      const SizedBox(height: 4),
                      Text(isKorean ? '가져오는 중...' : 'Loading...',
                          style: T.caption.copyWith(color: C.mu, fontSize: 9)),
                    ],
                  ))
                else ...[
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RavelryScreen(initialTab: 0))),
                    child: _CapsuleStat(label: isKorean ? '스태시' : 'Stash', value: '${stashCount ?? 0}'),
                  )),
                  Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RavelryScreen(initialTab: 2))),
                    child: _CapsuleStat(label: isKorean ? '프로젝트' : 'Project', value: '${ravelryProjectCount ?? 0}'),
                  )),
                  Container(width: 1, height: 28, color: C.bd, margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RavelryScreen(initialTab: 1))),
                    child: _CapsuleStat(label: isKorean ? '라이브러리' : 'Library', value: '${libraryCount ?? 0}'),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleStat extends StatelessWidget {
  final String label;
  final String value;
  const _CapsuleStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: T.bodyBold),
        Text(label, style: T.caption.copyWith(color: C.mu, fontSize: 10)),
      ],
    );
  }
}
