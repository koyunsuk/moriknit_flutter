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
import '../../../providers/yarn_provider.dart';
import '../../../providers/needle_provider.dart';
import '../../../providers/accessory_provider.dart';
import '../../../providers/book_provider.dart';

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

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final headerSubtitle = resolveUiCopy(data: uiCopy, language: language, key: 'tools_header_subtitle', fallback: t.toolsHeaderSubtitle);
    final activeProjects = ref.watch(activeProjectsProvider);
    final coursesAsync = ref.watch(courseProvider);
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
            // 스크롤 바디
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MoriKnit + Ravelry 2단 캡슐 카드 (최상단)
                    _MoriRavelryCapsuleCard(isKorean: isKorean),
                    const SizedBox(height: 16),
                    // 나의 Asset 요약 카드 (2x2 그리드)
                    _AssetSummaryCard(isKorean: isKorean),
                    const SizedBox(height: 16),
                    // 진행중 프로젝트
                    SectionTitle(title: isKorean ? '진행중 프로젝트' : 'Active Projects'),
                    const SizedBox(height: 10),
                    if (activeProjects.isEmpty)
                      GlassCard(
                        child: Row(
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
                        ),
                      )
                    else ...[
                      ...activeProjects.take(3).map((p) => _ProjectCard(
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
                    const SizedBox(height: 8),
                    Divider(color: C.bd, thickness: 1, height: 20),

                    // 3. 최근 강의실
                    SectionTitle(title: isKorean ? '최근 강의실' : 'Recent Course'),
                    const SizedBox(height: 10),
                    coursesAsync.maybeWhen(
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
                    const SizedBox(height: 20),

                    // ── 구분선 ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(color: C.bd, thickness: 1),
                    ),
                    const SizedBox(height: 4),

                    // 4. 나의 작업관리
                    SectionTitle(title: isKorean ? '나의 작업관리' : 'My Work Management'),
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.grid_view_rounded,
                      color: C.lmD,
                      title: isKorean ? '스와치 라이브러리' : 'Swatch Library',
                      description: isKorean ? '게이지와 실 정보를 기록해요' : 'Record gauge and yarn info',
                      onTap: () => context.push(Routes.swatchList),
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
                      icon: Icons.grid_on_rounded,
                      color: C.lvD,
                      title: isKorean ? '나의 도안 라이브러리' : 'My Pattern Library',
                      description: isKorean ? '컬러/기호 모드로 나만의 도안을 그려요' : 'Draw your own charts',
                      onTap: () => context.push(Routes.toolsPatterns),
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
                    const SizedBox(height: 8),
                    Divider(color: C.bd, thickness: 1, height: 20),

                    // 5. 나의 Asset 관리
                    SectionTitle(title: isKorean ? '나의 Asset 관리' : 'My Asset Management'),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
                    Divider(color: C.bd, thickness: 1, height: 20),

                    // 6. 나의 학습관리
                    SectionTitle(title: isKorean ? '나의 학습관리' : 'My Learning'),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
                    Divider(color: C.bd, thickness: 1, height: 20),

                    // 7. 모든 도구
                    SectionTitle(title: isKorean ? '모든 도구' : 'All Tools'),
                    const SizedBox(height: 10),
                    // 사용자 요청 — 작업관리에서 모든 도구로 이동
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
                    _ToolCard(
                      icon: Icons.calculate_rounded,
                      color: C.pk,
                      title: isKorean ? 'AI 게이지 계산기' : 'AI Gauge Calculator',
                      description: t.gaugeHeaderSubtitle,
                      onTap: () => context.push(Routes.toolsGauge),
                    ),
                    const SizedBox(height: 10),
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
                    // 이슈 #660 Phase 2 — 파일 탐색기 (외부 PDF/이미지 다중 임포트)
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
                    // 이슈 #664 — 패턴 생성기 (래글런 + 단계별 도식 + 출판용 PDF)
                    _ToolCard(
                      icon: Icons.auto_stories_rounded,
                      color: C.lvD,
                      title: isKorean ? '패턴 생성기' : 'Pattern Generator',
                      description: isKorean
                          ? '치수+게이지로 도안 자동 생성, 단계별 도식, 출판용 PDF'
                          : 'Auto-build patterns with diagrams + print-ready PDF',
                      onTap: () => context.push(Routes.toolsPatternGenerator),
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
                    // 이슈 #665/#668 — 도안 에디터 (Gate 화면 진입 → 도안 목록 + 사각/원형/자유 path 모달)
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
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.add_task_rounded,
                      color: C.pkD,
                      title: isKorean ? '카운터 전체보기' : 'All Counters',
                      description: t.counterTools,
                      onTap: () => context.push(Routes.counterList),
                    ),
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.grid_view_rounded,
                      color: C.lmD,
                      title: isKorean ? '스와치' : 'Swatch',
                      description: isKorean ? '게이지와 실 정보를 기록해요' : 'Record gauge and yarn info',
                      onTap: () => context.push(Routes.swatchList),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: C.bd, thickness: 1, height: 20),

                    // 8. 외부 연결
                    SectionTitle(title: isKorean ? '외부 연결' : 'External Links'),
                    const SizedBox(height: 10),
                    _RavelryCard(isKorean: isKorean),
                    const SizedBox(height: 10),
                    _EtsyCard(isKorean: isKorean),
                    const SizedBox(height: 10),
                    _DropboxCard(isKorean: isKorean),
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
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(project.coverPhotoUrl, fit: BoxFit.cover))
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
                  ? Image.network(thumbUrl, fit: BoxFit.cover, errorBuilder: (_, e, s) => Container(color: C.lvL, child: Icon(Icons.school_rounded, color: C.lvD, size: 36)))
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

class _DropboxCard extends ConsumerWidget {
  const _DropboxCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(dropboxAuthProvider);
    return GlassCard(
      onTap: () => context.push(Routes.dropbox),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0061FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.cloud_rounded, color: Color(0xFF0061FF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dropbox', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                      : (isKorean ? '드롭박스 도안 파일을 앱에서 탐색해요' : 'Browse your Dropbox pattern files'),
                  style: T.caption.copyWith(
                      color: auth.isLoggedIn ? const Color(0xFF0061FF) : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF0061FF), size: 18)
          else
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

class _AssetSummaryCard extends ConsumerWidget {
  final bool isKorean;
  const _AssetSummaryCard({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectCount = ref.watch(projectCountProvider);
    final swatchCount = ref.watch(swatchCountProvider);
    final yarnCount = ref.watch(yarnCountProvider);
    final needleAsync = ref.watch(needleListProvider);
    final needleCount = needleAsync.maybeWhen(data: (n) => n.length, orElse: () => 0);
    final accessoryAsync = ref.watch(accessoryListProvider);
    final accessoryCount = accessoryAsync.maybeWhen(data: (a) => a.length, orElse: () => 0);
    final bookAsync = ref.watch(bookListProvider);
    final bookCount = bookAsync.maybeWhen(data: (b) => b.length, orElse: () => 0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
        color: C.bg,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '나의 Asset' : 'My Assets',
              style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _AssetCell(
                icon: Icons.folder_special_rounded,
                color: C.lv,
                label: isKorean ? '프로젝트' : 'Projects',
                value: '$projectCount',
                onTap: () => context.push(Routes.projectList),
              )),
              const SizedBox(width: 10),
              Expanded(child: _AssetCell(
                icon: Icons.grid_view_rounded,
                color: C.lmD,
                label: isKorean ? '스와치' : 'Swatches',
                value: '$swatchCount',
                onTap: () => context.push(Routes.swatchList),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AssetCell(
                icon: Icons.texture,
                color: C.pk,
                label: isKorean ? '실' : 'Yarn',
                value: '$yarnCount',
                onTap: () => context.push('/yarn-list'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _AssetCell(
                icon: Icons.circle_outlined,
                color: C.lvD,
                label: isKorean ? '바늘' : 'Needles',
                value: '$needleCount',
                onTap: () => context.push(Routes.needles),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AssetCell(
                icon: Icons.build_rounded,
                color: C.pkD,
                label: isKorean ? '악세사리' : 'Accessories',
                value: '$accessoryCount',
                onTap: () => context.push(Routes.accessories),
              )),
              const SizedBox(width: 10),
              Expanded(child: _AssetCell(
                icon: Icons.menu_book_rounded,
                color: C.lmD,
                label: isKorean ? '도서' : 'Books',
                value: '$bookCount',
                onTap: () => context.push(Routes.books),
              )),
            ],
          ),
        ],
      ),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          // MoriKnit 상단
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0x14FF6BA8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
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
