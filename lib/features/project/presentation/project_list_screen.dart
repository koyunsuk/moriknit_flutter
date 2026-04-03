import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/core/localization/app_language.dart';
import 'package:moriknit_flutter/core/router/app_router.dart';
import 'package:moriknit_flutter/core/router/routes.dart';
import 'package:moriknit_flutter/core/theme/app_colors.dart';
import 'package:moriknit_flutter/core/theme/app_theme.dart';
import 'package:moriknit_flutter/core/widgets/common_widgets.dart';
import 'package:moriknit_flutter/features/project/presentation/project_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_input_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/widgets/project_list_sections.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';
import 'package:moriknit_flutter/providers/project_provider.dart';
import 'package:moriknit_flutter/providers/ui_copy_provider.dart';
import 'package:moriknit_flutter/providers/template_provider.dart';


class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final headerSubtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'project_header_subtitle',
      fallback: t.projectHeaderSubtitle,
    );
    final projectsAsync = ref.watch(projectListProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final gates = ref.watch(featureGatesProvider);
    final count = ref.watch(projectCountProvider);
    final limitReached = ref.watch(projectLimitReachedProvider);
    final isWide = screenWidth >= 1100;
    final isExtraWideWeb = kIsWeb && screenWidth >= 1440;
    final contentMaxWidth = isWide ? 1280.0 : 900.0;
    final isPublicWeb = kIsWeb && user == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              maxWidth: contentMaxWidth,
              child: isPublicWeb
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        MoriWideHeader(
                          title: t.projects,
                          subtitle: headerSubtitle,
                        ),
                        if (gates.isFree)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                            child: LimitBar(
                              label: isKorean ? '프로젝트' : 'Projects',
                              current: count,
                              max: 3,
                              isReached: limitReached,
                              onUpgrade: () {},
                            ),
                          ),
                      ],
                    ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: isPublicWeb
                      ? _ProjectShowcase(
                          isKorean: isKorean,
                          isWide: isWide,
                          onTapProject: () => showLoginRequiredDialog(
                            context,
                            isKorean: isKorean,
                            title: isKorean ? '프로젝트 상세는 로그인 후 볼 수 있어요' : 'Project details require login',
                            fromRoute: Routes.projectList,
                          ),
                        )
                      : projectsAsync.when(
                          data: (projects) {
                            if (isWide) {
                              // 웹 와이드 레이아웃 — 기존 유지
                              if (projects.isEmpty) {
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                                  child: Column(
                                    children: [
                                      ProjectEmptyState(
                                        onAdd: () => _onAddTap(context, ref, limitReached, gates, count, isKorean),
                                        onOpenMarket: () => context.go(Routes.market),
                                        onOpenCommunity: () => context.go(Routes.community),
                                        onOpenSwatches: () => context.push(Routes.swatchInput),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(t.activeProjects, style: T.h3)),
                                        TextButton.icon(
                                          onPressed: () => _onAddTap(context, ref, limitReached, gates, count, isKorean),
                                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                          label: Text(isKorean ? '새 프로젝트' : 'New project'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isExtraWideWeb ? 3 : 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: isExtraWideWeb ? 1.72 : 1.58,
                                      ),
                                      itemCount: projects.length,
                                      itemBuilder: (_, i) => Stack(
                                        children: [
                                          ProjectCard(
                                            project: projects[i],
                                            compact: true,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ProjectDetailScreen(projectId: projects[i].id),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert, size: 18, color: C.mu),
                                              onSelected: (v) {
                                                if (v == 'edit') {
                                                  Navigator.push(context, MaterialPageRoute(
                                                    builder: (_) => ProjectInputScreen(projectId: projects[i].id, initialProject: projects[i]),
                                                  ));
                                                }
                                                if (v == 'copy') _duplicateProject(context, ref, projects[i], isKorean);
                                                if (v == 'delete') _confirmDeleteFromList(context, ref, projects[i], isKorean);
                                              },
                                              itemBuilder: (_) => [
                                                PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                                                PopupMenuItem(value: 'copy', child: Text(isKorean ? '복사' : 'Duplicate')),
                                                PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // 모바일 레이아웃 — 프로젝트 목록만 표시
                            return _MobileProjectList(
                              projects: projects,
                              isKorean: isKorean,
                              limitReached: limitReached,
                              onAddTap: () => _onAddTap(context, ref, limitReached, gates, count, isKorean),
                              onDuplicate: (project) => _duplicateProject(context, ref, project, isKorean),
                              onEdit: (project) => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ProjectInputScreen(projectId: project.id, initialProject: project),
                              )),
                              onDelete: (project) => _confirmDeleteFromList(context, ref, project, isKorean),
                            );
                          },
                          loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                          error: (e, _) => Center(child: Text('Error: $e', style: T.body)),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddTap(
    BuildContext context,
    WidgetRef ref,
    bool limitReached,
    FeatureGates gates,
    int count,
    bool isKorean,
  ) {
    if (limitReached) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isKorean ? '프로젝트 한도 도달' : 'Project limit reached', style: T.h3),
          content: Text(gates.projectLimitMessage(count), style: T.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isKorean ? '닫기' : 'Close'),
            ),
          ],
        ),
      );
      return;
    }
    _showProjectStartSheet(context, ref);
  }

  Future<void> _duplicateProject(
    BuildContext context,
    WidgetRef ref,
    dynamic project,
    bool isKorean,
  ) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(projectRepositoryProvider).duplicateProject(project);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '복사됐어요.' : 'Duplicated.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  void _showProjectStartSheet(BuildContext context, WidgetRef ref) {
    final builtinTemplates = ref.read(builtinTemplateListProvider).valueOrNull ?? [];
    final isKorean = ref.read(appLanguageProvider).isKorean;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('새 프로젝트', style: T.h3),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ProjectInputScreen(),
                      ));
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: C.bd2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.add_rounded, color: C.tx2),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('빈 프로젝트로 시작', style: T.bodyBold),
                              const SizedBox(height: 4),
                              Text('처음부터 직접 구성해요', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopyProjectSheet(context, ref);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: C.lv.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.copy_rounded, color: C.lv),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('프로젝트 복사로 시작', style: T.bodyBold),
                              const SizedBox(height: 4),
                              Text('기존 프로젝트를 복사해서 시작해요', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (builtinTemplates.isEmpty)
                    const SizedBox.shrink()
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('템플릿으로 시작', style: T.bodyBold.copyWith(color: C.tx2)),
                    ),
                    ...builtinTemplates.map((tpl) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProjectInputScreen(builtinTemplate: tpl),
                          ));
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _colorFromHex(tpl.colorHex).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(_iconFromName(tpl.iconName), color: _colorFromHex(tpl.colorHex)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isKorean ? tpl.titleKo : tpl.titleEn, style: T.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(isKorean ? tpl.descKo : tpl.descEn, style: T.caption.copyWith(color: C.mu)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: C.mu),
                          ],
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCopyProjectSheet(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final projects = ref.read(projectListProvider).valueOrNull ?? [];
    if (projects.isEmpty) {
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '복사할 프로젝트가 없어요.' : 'No projects to copy.',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(isKorean ? '복사할 프로젝트 선택' : 'Select project to copy', style: T.h3),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: projects.length,
                itemBuilder: (_, i) {
                  final p = projects[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _duplicateProjectFromSheet(context, ref, p, isKorean);
                      },
                      child: Row(
                        children: [
                          if (p.coverPhotoUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(p.coverPhotoUrl, width: 48, height: 48, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _ProjectIconPlaceholder()),
                            )
                          else
                            _ProjectIconPlaceholder(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title, style: T.bodyBold),
                                if (p.yarnBrandName.isNotEmpty || p.yarnName.isNotEmpty)
                                  Text('${p.yarnBrandName} ${p.yarnName}'.trim(), style: T.caption.copyWith(color: C.mu)),
                              ],
                            ),
                          ),
                          Icon(Icons.copy_rounded, color: C.mu, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateProjectFromSheet(BuildContext context, WidgetRef ref, dynamic project, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(projectRepositoryProvider).duplicateProject(project),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _confirmDeleteFromList(BuildContext context, WidgetRef ref, dynamic project, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '프로젝트 삭제' : 'Delete Project', style: T.h3),
        content: Text(isKorean ? '"${project.title}" 프로젝트를 삭제할까요?' : 'Delete "${project.title}"?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(projectRepositoryProvider).deleteProject(project.id),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }
}

class _ProjectIconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.folder_rounded, color: C.lv, size: 24),
    );
  }
}

// ─────────────────────────────────────────────
// 모바일 프로젝트 목록 (프로젝트만 표시)
// ─────────────────────────────────────────────
class _MobileProjectList extends StatelessWidget {
  final List<dynamic> projects;
  final bool isKorean;
  final bool limitReached;
  final VoidCallback onAddTap;
  final void Function(dynamic project) onDuplicate;
  final void Function(dynamic project) onEdit;
  final void Function(dynamic project) onDelete;

  const _MobileProjectList({
    required this.projects,
    required this.isKorean,
    required this.limitReached,
    required this.onAddTap,
    required this.onDuplicate,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _projectCard(BuildContext context, dynamic project) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          ProjectCard(
            project: project,
            compact: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(projectId: project.id),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: C.mu),
              onSelected: (v) {
                if (v == 'edit') onEdit(project);
                if (v == 'copy') onDuplicate(project);
                if (v == 'delete') onDelete(project);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                PopupMenuItem(value: 'copy', child: Text(isKorean ? '복사' : 'Duplicate')),
                PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => p.status != 'finished').toList();
    final done = projects.where((p) => p.status == 'finished').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(isKorean ? '진행 중인 프로젝트' : 'Active Projects', style: T.h3)),
            TextButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(isKorean ? '새 프로젝트' : 'New project'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          MoriEmptyState(
            icon: Icons.folder_open_rounded,
            iconColor: C.lv,
            title: isKorean ? '진행 중인 프로젝트가 없어요' : 'No active projects',
            subtitle: isKorean ? '새 프로젝트를 시작해보세요.' : 'Start a new project.',
            buttonLabel: isKorean ? '새 프로젝트' : 'New project',
            onAction: onAddTap,
          )
        else
          ...active.map((project) => _projectCard(context, project)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(isKorean ? '완료된 프로젝트' : 'Completed Projects', style: T.h3.copyWith(color: C.mu))),
              Text('${done.length}', style: T.caption.copyWith(color: C.mu)),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: done.asMap().entries.map((entry) {
                final i = entry.key;
                final project = entry.value;
                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, color: C.bd),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: Row(
                          children: [
                            project.coverPhotoUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Image.network(project.coverPhotoUrl, width: 22, height: 22, fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(width: 22, height: 22, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(5)), child: Icon(Icons.folder_rounded, color: C.lv, size: 13))),
                                  )
                                : Container(width: 22, height: 22, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(5)), child: Icon(Icons.folder_rounded, color: C.lv, size: 13)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(project.title, style: T.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, size: 16, color: C.mu),
                              padding: EdgeInsets.zero,
                              onSelected: (v) {
                                if (v == 'edit') onEdit(project);
                                if (v == 'copy') onDuplicate(project);
                                if (v == 'delete') onDelete(project);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), Text(isKorean ? '수정' : 'Edit')])),
                                PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '복사하기' : 'Duplicate')])),
                                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

}

// ─────────────────────────────────────────────
// 비로그인 쇼케이스 (기존 유지)
// ─────────────────────────────────────────────
class _ProjectShowcase extends StatelessWidget {
  final bool isKorean;
  final bool isWide;
  final VoidCallback onTapProject;

  const _ProjectShowcase({
    required this.isKorean,
    required this.isWide,
    required this.onTapProject,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? '프로젝트 보드 미리보기' : 'Project board preview', style: T.h2),
                        const SizedBox(height: 10),
                        Text(
                          isKorean
                              ? '비회원도 프로젝트 보드 분위기와 카드 구성을 둘러볼 수 있어요. 상세 기록과 편집은 로그인 후 이어집니다.'
                              : 'Guests can preview the project board layout. Detailed records and editing unlock after login.',
                          style: T.body.copyWith(color: C.mu, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? '로그인하면 가능한 것' : 'What unlocks after login', style: T.bodyBold),
                        const SizedBox(height: 10),
                        Text(
                          isKorean
                              ? '진행 중인 프로젝트 상세, 메모와 카운터 연결, 내 도안과 스와치 관리까지 한 흐름으로 이어집니다.'
                              : 'Save progress, open project details, connect notes and counters, and manage patterns and swatches.',
                          style: T.caption.copyWith(color: C.mu, height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onTapProject,
                            child: Text(isKorean ? '무료로 시작하기' : 'Start free'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isKorean ? '프로젝트 보드 미리보기' : 'Project board preview', style: T.h2),
                  const SizedBox(height: 10),
                  Text(
                    isKorean
                        ? '카드 구성과 작업 흐름을 먼저 둘러보고, 로그인 후 내 프로젝트로 이어갈 수 있어요.'
                        : 'Preview the board and workflow first, then log in to continue with your own projects.',
                    style: T.body.copyWith(color: C.mu, height: 1.6),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '로그인 후 열리는 작업 흐름' : 'The workflow after login', style: T.bodyBold),
                const SizedBox(height: 10),
                Text(
                  isKorean
                      ? '프로젝트, 내 도안, 스와치, 작업 도구가 하나의 흐름으로 이어져 작업 공간처럼 사용할 수 있어요.'
                      : 'Projects, patterns, swatches, and tools connect into one working flow after login.',
                  style: T.body.copyWith(color: C.mu, height: 1.6),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MoriChip(label: isKorean ? '프로젝트 보드' : 'Project board', type: ChipType.lavender),
                    MoriChip(label: isKorean ? '내 도안' : 'My patterns', type: ChipType.pink),
                    MoriChip(label: isKorean ? '작업 도구' : 'Workspace tools', type: ChipType.lime),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTapProject,
                    child: Text(isKorean ? '로그인하고 시작하기' : 'Log in to continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 전체 프로젝트 목록 화면 (B 스타일)
// ─────────────────────────────────────────────
class ProjectAllListScreen extends ConsumerWidget {
  const ProjectAllListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final projectsAsync = ref.watch(projectListProvider);
    final projects = projectsAsync.valueOrNull ?? [];
    final inProgress = projects.where((p) => p.status == 'in_progress').length;
    final done = projects.where((p) => p.status == 'finished').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '내 프로젝트' : 'My Projects',
                subtitle: isKorean
                    ? '${projects.length}개의 프로젝트'
                    : '${projects.length} projects',
              ),
            ),
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (_) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    // 통계 GlassCard
                    GlassCard(
                      child: Row(
                        children: [
                          Expanded(child: _ProjStatCell(label: isKorean ? '전체' : 'Total', value: projects.length, color: C.lv)),
                          Expanded(child: _ProjStatCell(label: isKorean ? '진행 중' : 'Active', value: inProgress, color: C.pkD)),
                          Expanded(child: _ProjStatCell(label: isKorean ? '완료' : 'Done', value: done, color: C.lmD)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 헤더 + 새 프로젝트 버튼
                    Row(
                      children: [
                        Expanded(child: Text(isKorean ? '프로젝트 목록' : 'Projects', style: T.h3)),
                        TextButton.icon(
                          onPressed: () => context.push(Routes.projectInput),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                          label: Text(isKorean ? '새 프로젝트' : 'New project'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (projects.isEmpty)
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, color: C.mu, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              isKorean ? '프로젝트를 시작해보세요' : 'Start your first project',
                              style: T.bodyBold.copyWith(color: C.tx2),
                            ),
                          ],
                        ),
                      )
                    else
                      ...projects.map((project) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Stack(
                          children: [
                            ProjectCard(
                              project: project,
                              compact: false,
                              onTap: () => context.push('/project/${project.id}'),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 20, color: C.mu),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ProjectDetailScreen(projectId: project.id),
                                  ));
                                  }
                                  if (v == 'copy') _duplicateProject(context, ref, project, isKorean);
                                  if (v == 'delete') _confirmDelete(context, ref, project, isKorean);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                                  PopupMenuItem(value: 'copy', child: Text(isKorean ? '복사' : 'Duplicate')),
                                  PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.projectInput),
        backgroundColor: C.lv,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _duplicateProject(
    BuildContext context,
    WidgetRef ref,
    dynamic project,
    bool isKorean,
  ) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(projectRepositoryProvider).duplicateProject(project);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '복사됐어요.' : 'Duplicated.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, dynamic project, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '프로젝트 삭제' : 'Delete Project', style: T.h3),
        content: Text(isKorean ? '"${project.title}" 프로젝트를 삭제할까요?' : 'Delete "${project.title}"?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(projectRepositoryProvider).deleteProject(project.id),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }
}

class _ProjStatCell extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ProjStatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$value', style: T.h2.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: T.caption.copyWith(color: C.mu)),
      ],
    );
  }
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'dry_cleaning': return Icons.dry_cleaning_rounded;
    case 'hiking': return Icons.hiking_rounded;
    case 'ac_unit': return Icons.ac_unit_rounded;
    case 'back_hand': return Icons.back_hand_rounded;
    case 'face': return Icons.face_rounded;
    default: return Icons.article_rounded;
  }
}

Color _colorFromHex(String hex) {
  try {
    final v = hex.replaceFirst('#', '');
    return Color(int.parse('FF$v', radix: 16));
  } catch (_) {
    return C.lv;
  }
}
