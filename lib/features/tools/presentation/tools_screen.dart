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
import '../../yarn/presentation/yarn_list_screen.dart';

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
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
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
                    // 1. 작업 요약 통계
                    SectionTitle(title: isKorean ? '작업 요약' : 'Work Summary'),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: Row(
                        children: [
                          Expanded(child: GestureDetector(onTap: () => context.push(Routes.swatchList), child: _StatChip(label: t.swatches, value: '$swatchCount'))),
                          const SizedBox(width: 10),
                          Expanded(child: GestureDetector(onTap: () => context.push(Routes.projectList), child: _StatChip(label: t.projects, value: '$projectCount'))),
                          const SizedBox(width: 10),
                          Expanded(child: GestureDetector(onTap: () => context.push(Routes.counterList), child: _StatChip(label: t.counters, value: '$counterCount'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. 진행중 프로젝트
                    SectionTitle(title: isKorean ? '진행중 프로젝트' : 'Active Projects'),
                    const SizedBox(height: 10),
                    if (activeProjects.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: GlassCard(
                          onTap: () => context.push(Routes.projectInput),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, color: C.mu, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                isKorean ? '프로젝트를 시작해보세요' : 'Start your first project',
                                style: T.bodyBold.copyWith(color: C.tx2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isKorean ? '탭해서 새 프로젝트 만들기' : 'Tap to create a new project',
                                style: T.caption.copyWith(color: C.mu),
                              ),
                            ],
                          ),
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
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

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
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YarnListScreen())),
                    ),
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

                    // 7. 모든 도구
                    SectionTitle(title: isKorean ? '모든 도구' : 'All Tools'),
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.calculate_rounded,
                      color: C.pk,
                      title: t.gaugeCalculator,
                      description: t.gaugeHeaderSubtitle,
                      onTap: () => context.push(Routes.toolsGauge),
                    ),
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.grid_on_rounded,
                      color: C.lvD,
                      title: isKorean ? '도안 에디터' : 'Pattern Editor',
                      description: isKorean ? '새 도안을 바로 그려요' : 'Open editor directly',
                      onTap: () => context.push(Routes.toolsPattern),
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
              height: 120,
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Text(value, style: T.h3.copyWith(color: C.lvD)),
          const SizedBox(height: 4),
          Text(label, style: T.caption.copyWith(color: C.mu)),
        ],
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
  const _ToolCard({required this.icon, required this.color, required this.title, required this.description, required this.onTap});

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
                Text(title, style: T.bodyBold),
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
