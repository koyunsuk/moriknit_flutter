import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moriknit_flutter/core/localization/app_language.dart';
import 'package:moriknit_flutter/core/localization/app_strings.dart';
import 'package:moriknit_flutter/core/router/app_router.dart';
import 'package:moriknit_flutter/core/theme/app_colors.dart';
import 'package:moriknit_flutter/core/theme/app_theme.dart';
import 'package:moriknit_flutter/core/widgets/common_widgets.dart';
import 'package:moriknit_flutter/features/project/presentation/project_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_input_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/widgets/project_list_sections.dart';
import 'package:moriknit_flutter/features/counter/domain/counter_model.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';
import 'package:moriknit_flutter/providers/counter_provider.dart';
import 'package:moriknit_flutter/providers/project_provider.dart';
import 'package:moriknit_flutter/providers/ui_copy_provider.dart';

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
                                    const SizedBox(height: 20),
                                    SectionTitle(title: t.toolsCreativeSection),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.calculate_rounded, color: C.pk, title: t.gaugeCalculator, description: t.gaugeHeaderSubtitle, onTap: () => context.push(Routes.toolsGauge)),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.menu_book_rounded, color: C.pkD, title: t.myEncyclopedia, description: t.encyclopediaToolDescription, onTap: () => context.push(Routes.toolsEncyclopedia)),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.edit_note_rounded, color: C.pk, title: t.memoPad, description: t.toolsMemoDescription, onTap: () => context.push(Routes.toolsMemo)),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.school_rounded, color: C.lvD, title: isKorean ? '클라스' : 'Class', description: t.coursesToolDescription, onTap: () => context.push(Routes.toolsCourse)),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.grid_on_rounded, color: C.lvD, title: isKorean ? '도안 에디터' : 'Pattern Editor', description: isKorean ? '컬러/기호 모드로 나만의 도안을 그려요' : 'Draw your own chart in color or symbol mode', onTap: () => context.push(Routes.toolsPatterns)),
                                    const SizedBox(height: 10),
                                    _ToolCard(icon: Icons.add_task_rounded, color: C.lmD, title: t.newCounter, description: t.counterTools, onTap: () => _showCreateCounter(context, ref, t)),
                                  ],
                                ),
                              );
                            }

                            if (isWide) {
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
                                      itemBuilder: (_, i) => ProjectCard(
                                        project: projects[i],
                                        compact: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProjectDetailScreen(projectId: projects[i].id),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 8),
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
                                // 첫 번째: 크게
                                ProjectCard(
                                  project: projects.first,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: projects.first.id))),
                                ),
                                // 나머지: compact 리스트
                                if (projects.length > 1) ...[
                                  const SizedBox(height: 12),
                                  Text(isKorean ? '다른 프로젝트' : 'Other projects', style: T.bodyBold.copyWith(color: C.tx2)),
                                  const SizedBox(height: 8),
                                  ...projects.skip(1).map(
                                    (project) => ProjectCard(
                                      project: project,
                                      compact: true,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id))),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                // 내 스와치 / 내 바늘 - 2단 카드
                                Row(
                                  children: [
                                    Expanded(
                                      child: GlassCard(
                                        onTap: () => context.push(Routes.swatchList),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(color: C.lvD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                              child: Icon(Icons.grid_view_rounded, color: C.lvD),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(isKorean ? '내 스와치' : 'My swatches', style: T.bodyBold.copyWith(color: C.lvD)),
                                            const SizedBox(height: 4),
                                            Text(isKorean ? '게이지 · 샘플 기록' : 'Gauge & sample records', style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GlassCard(
                                        onTap: () => context.push(Routes.needles),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                              child: Icon(Icons.straighten_rounded, color: C.lv),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(isKorean ? '내 바늘' : 'My needles', style: T.bodyBold.copyWith(color: C.lv)),
                                            const SizedBox(height: 4),
                                            Text(isKorean ? '바늘 자산 관리' : 'Manage your needles', style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SectionTitle(title: t.toolsCreativeSection),
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
                                  icon: Icons.menu_book_rounded,
                                  color: C.pkD,
                                  title: t.myEncyclopedia,
                                  description: t.encyclopediaToolDescription,
                                  onTap: () => context.push(Routes.toolsEncyclopedia),
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
                                  icon: Icons.school_rounded,
                                  color: C.lvD,
                                  title: isKorean ? '클라스' : 'Class',
                                  description: t.coursesToolDescription,
                                  onTap: () => context.push(Routes.toolsCourse),
                                ),
                                const SizedBox(height: 10),
                                _ToolCard(
                                  icon: Icons.grid_on_rounded,
                                  color: C.lvD,
                                  title: isKorean ? '도안 에디터' : 'Pattern Editor',
                                  description: isKorean ? '컬러/기호 모드로 나만의 도안을 그려요' : 'Draw your own chart in color or symbol mode',
                                  onTap: () => context.push(Routes.toolsPatterns),
                                ),
                                const SizedBox(height: 10),
                                _ToolCard(
                                  icon: Icons.add_task_rounded,
                                  color: C.lmD,
                                  title: t.newCounter,
                                  description: t.counterTools,
                                  onTap: () => _showCreateCounter(context, ref, t),
                                ),
                              ],
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

  Future<void> _showCreateCounter(BuildContext context, WidgetRef ref, AppStrings t) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.createCounter, style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: t.counterNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () async {
              final authUser = ref.read(authStateProvider).valueOrNull;
              final name = nameCtrl.text.trim();
              if (authUser == null || name.isEmpty) { Navigator.pop(ctx); return; }
              final counter = CounterModel.empty(uid: authUser.uid, name: name);
              final saved = await ref.read(counterRepositoryProvider).createCounter(counter);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.push('/counter/${saved.id}');
            },
            child: Text(t.create),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
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
    _showProjectStartSheet(context);
  }

  void _showProjectStartSheet(BuildContext context) {
    final templates = [
      ('topdown', '탑다운 스웨터', Icons.dry_cleaning_rounded, C.lv, '코잡기 → 래글런 → 몸통 → 소매 → 마무리 8단계'),
      ('socks', '양말', Icons.hiking_rounded, C.pkD, '코잡기 → 힐 → 발 → 발끝 8단계'),
      ('scarf', '목도리', Icons.ac_unit_rounded, C.lmD, '코잡기 → 패턴 → 길이 확인 → 마무리 5단계'),
      ('gloves', '장갑', Icons.back_hand_rounded, C.og, '코잡기 → 손목 → 손가락 → 엄지 7단계'),
      ('hat', '모자', Icons.face_rounded, C.pkD, '코잡기 → 브림 → 크라운 → 감소 5단계'),
    ];

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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('템플릿으로 시작', style: T.bodyBold.copyWith(color: C.tx2)),
                  ),
                  ...templates.map((tpl) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProjectInputScreen(templateType: tpl.$1),
                        ));
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: tpl.$4.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(tpl.$3, color: tpl.$4),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tpl.$2, style: T.bodyBold),
                                const SizedBox(height: 4),
                                Text(tpl.$5, style: T.caption.copyWith(color: C.mu)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: C.mu),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            width: 48, height: 48,
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
