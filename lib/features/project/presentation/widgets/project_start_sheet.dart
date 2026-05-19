import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../features/pattern/data/pattern_repository.dart';
import '../../../../features/pattern/domain/pattern_chart.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/template_provider.dart';
import '../../domain/builtin_template.dart';
import '../project_input_screen.dart';

/// 새 프로젝트 시작 시트 — 어디서든 호출 가능한 공통 함수
/// FAB, 홈화면 추가 카드, 프로젝트 라이브러리 모두 이 함수 사용
void showProjectStartSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ProjectStartSheetContent(outerContext: context),
  );
}

/// 바텀시트 내부 콘텐츠 — Consumer로 직접 watch하여 템플릿 로드 타이밍 문제 해소
class _ProjectStartSheetContent extends ConsumerWidget {
  final BuildContext outerContext;
  const _ProjectStartSheetContent({required this.outerContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builtinTemplates =
        ref.watch(builtinTemplateListProvider).valueOrNull ?? [];
    final userTemplates =
        ref.watch(userTemplateListProvider).valueOrNull ?? [];
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return DraggableScrollableSheet(
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
            decoration: BoxDecoration(
                color: C.bd2, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(isKorean ? '새 프로젝트' : 'New Project', style: T.h3),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // ① 빈 프로젝트로 시작
                GlassCard(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      outerContext,
                      MaterialPageRoute(
                          builder: (_) => const ProjectInputScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: C.bd2,
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.add_rounded, color: C.tx2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isKorean
                                  ? '빈 프로젝트로 시작'
                                  : 'Start blank',
                              style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                              isKorean
                                  ? '처음부터 직접 구성해요'
                                  : 'Build from scratch',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ② 프로젝트 복사로 시작
                GlassCard(
                  onTap: () {
                    // ref에서 값을 먼저 읽고 팝 (팝 후 ref 무효화 방지)
                    final projectsSnapshot = ref.read(projectListProvider).valueOrNull ?? [];
                    final korean = isKorean;
                    Navigator.pop(context);
                    _showCopyProjectSheet(outerContext, korean, projectsSnapshot);
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
                          Text(
                              isKorean
                                  ? '프로젝트 복사로 시작'
                                  : 'Copy from existing',
                              style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                              isKorean
                                  ? '기존 프로젝트를 복사해서 시작해요'
                                  : 'Start from a copy',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 이슈 #863 — ③ 도안 라이브러리에서 시작 (AI도안/일반도안 모두 노출)
                //   기존 'AI 도안에서 시작' (섹션 있는 AI 변환 도안만) → 모든 도안 노출로 확장.
                //   일반도안 선택 시 빈 단계로그 + AI 처리 시 자동 sync (Cloud Function 트리거).
                GlassCard(
                  onTap: () {
                    final korean = isKorean;
                    Navigator.pop(context);
                    _showPatternLibrarySheet(outerContext, korean);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: C.pk.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.menu_book_rounded, color: C.pkD),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isKorean
                                  ? '도안 라이브러리에서 시작'
                                  : 'Start from pattern library',
                              style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                              isKorean
                                  ? 'AI도안은 단계로그 자동 생성, 일반도안도 선택 가능해요'
                                  : 'AI patterns auto-create step logs; regular patterns are also supported',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
                // ④ 커스텀 템플릿
                if (userTemplates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      isKorean
                          ? '내 커스텀 템플릿'
                          : 'My Custom Templates',
                      style: T.bodyBold.copyWith(color: C.tx2),
                    ),
                  ),
                  ...userTemplates.map((tpl) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              outerContext,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProjectInputScreen(userTemplate: tpl)),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: C.lvL,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.folder_special_rounded,
                                    color: C.lvD),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tpl.title, style: T.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    isKorean
                                        ? '${tpl.stepTitles.length}개 단계'
                                        : '${tpl.stepTitles.length} steps',
                                    style:
                                        T.caption.copyWith(color: C.mu),
                                  ),
                                ],
                              )),
                              Icon(Icons.chevron_right_rounded, color: C.mu),
                            ],
                          ),
                        ),
                      )),
                ],
                // ④ 기본 프리셋 (모리니트 제공) — 템플릿/인형치수 통합 노출 (#626/#639)
                // kind별로 분기: projectSteps → ProjectInputScreen, bodyMeasurement → 게이지 계산기
                ...() {
                  final stepTemplates = builtinTemplates
                      .where((t) => t.kind == BuiltinTemplateKind.projectSteps)
                      .toList();
                  final measurementTemplates = builtinTemplates
                      .where((t) => t.kind == BuiltinTemplateKind.bodyMeasurement)
                      .toList();
                  return [
                    if (stepTemplates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          isKorean ? '기본 템플릿' : 'Built-in Templates',
                          style: T.bodyBold.copyWith(color: C.tx2),
                        ),
                      ),
                      ...stepTemplates.map((tpl) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  outerContext,
                                  MaterialPageRoute(
                                      builder: (_) => ProjectInputScreen(
                                          builtinTemplate: tpl)),
                                );
                              },
                              child: _BuiltinRow(tpl: tpl, isKorean: isKorean),
                            ),
                          )),
                    ],
                    if (measurementTemplates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          isKorean ? '인형 치수 프리셋' : 'Doll Measurement Presets',
                          style: T.bodyBold.copyWith(color: C.tx2),
                        ),
                      ),
                      ...measurementTemplates.map((tpl) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              onTap: () {
                                Navigator.pop(context);
                                // #638 연계 — 게이지 계산기로 치수 자동 입력
                                outerContext.push(
                                  Routes.toolsGauge,
                                  extra: tpl.measurementData,
                                );
                              },
                              child: _BuiltinRow(tpl: tpl, isKorean: isKorean),
                            ),
                          )),
                    ],
                  ];
                }(),
                // ⑤ 템플릿 로딩 중
                if (builtinTemplates.isEmpty && userTemplates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: C.lv),
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

/// 이슈 #863 — 도안 라이브러리 시트. AI도안/일반도안 모두 노출.
///   - 모든 도안(patternListProvider) 노출, isComplete 필터 제거.
///   - AI도안(isComplete) : 선택 즉시 단계로그 자동 미러링 (pattern_detail 흐름과 동일).
///   - 일반도안 : 빈 단계로그로 프로젝트 생성, 추후 AI 처리 완료 시 Cloud Function 트리거로 자동 sync.
void _showPatternLibrarySheet(BuildContext context, bool isKorean) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Consumer(
        builder: (ctx2, ref, _) {
          final async = ref.watch(patternListProvider);
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  isKorean ? '도안 라이브러리에서 선택' : 'Select from pattern library',
                  style: T.h3,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  isKorean
                      ? 'AI도안은 단계로그가 자동 생성돼요. 일반도안은 빈 단계로그로 시작하고, AI 처리되면 자동으로 채워집니다.'
                      : 'AI patterns auto-create step logs. Regular patterns start blank — they auto-sync once AI processed.',
                  style: T.caption.copyWith(color: C.mu, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: async.when(
                  loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                  error: (e, _) => Center(
                    child: Text(
                      isKorean ? '오류: $e' : 'Error: $e',
                      style: T.caption.copyWith(color: C.og),
                    ),
                  ),
                  data: (all) {
                    if (all.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_outlined, size: 40, color: C.mu),
                              const SizedBox(height: 12),
                              Text(
                                isKorean
                                    ? '저장된 도안이 없어요.\n도안 등록 또는 에디터에서 먼저 만들어 주세요.'
                                    : 'No saved patterns yet.\nRegister or create one in the editor first.',
                                style: T.caption.copyWith(color: C.mu, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    // AI도안 먼저, 그 다음 일반도안 (가독성). updatedAt 기준 정렬은 repo 에서 이미 보장.
                    // ignore: deprecated_member_use
                    final aiCharts = all.where((p) => p.isComplete).toList();
                    // ignore: deprecated_member_use
                    final regularCharts = all.where((p) => !p.isComplete).toList();
                    final merged = <PatternChart>[...aiCharts, ...regularCharts];
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: merged.length,
                      itemBuilder: (_, i) {
                        final chart = merged[i];
                        // ignore: deprecated_member_use
                        final isAi = chart.isComplete;
                        final sectionCount = chart.aiSections?.length ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectInputScreen(
                                    sourcePatternChart: chart,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: (isAi ? C.pk : C.lv)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isAi
                                        ? Icons.auto_awesome_rounded
                                        : Icons.description_outlined,
                                    color: isAi ? C.pkD : C.lvD,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(chart.title,
                                                style: T.bodyBold,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isAi ? C.pk : C.mu)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isAi
                                                  ? (isKorean ? 'AI' : 'AI')
                                                  : (isKorean ? '일반' : 'Reg'),
                                              style: T.caption.copyWith(
                                                color: isAi ? C.pkD : C.mu,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isAi
                                            ? (isKorean
                                                ? '$sectionCount개 섹션 · 단계로그 자동 생성'
                                                : '$sectionCount sections · auto step logs')
                                            : (isKorean
                                                ? '빈 단계로그로 시작 · AI 처리 시 자동 sync'
                                                : 'Starts blank · auto-syncs after AI'),
                                        style: T.caption.copyWith(color: C.mu),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: C.mu),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void _showCopyProjectSheet(BuildContext context, bool isKorean, List<dynamic> projects) {
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isKorean ? '복사할 프로젝트 선택' : 'Select project to copy',
              style: T.h3,
            ),
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
                      await _duplicateProjectFromSheet(context, p, isKorean);
                    },
                    child: Row(
                      children: [
                        if (p.coverPhotoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: p.coverPhotoUrl,
                              width: 48, height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _ProjectIconPlaceholder(),
                            ),
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
                                Text(
                                  '${p.yarnBrandName} ${p.yarnName}'.trim(),
                                  style: T.caption.copyWith(color: C.mu),
                                ),
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

Future<void> _duplicateProjectFromSheet(BuildContext context, dynamic project, bool isKorean) async {
  try {
    final container = ProviderScope.containerOf(context);
    await runWithMoriLoadingDialog<void>(
      context,
      message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
      task: () => container.read(projectRepositoryProvider).duplicateProject(project),
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

/// BuiltinTemplate 행 UI — 공통 카드 내용 (아이콘 + 제목 + 설명 + chevron)
class _BuiltinRow extends StatelessWidget {
  final BuiltinTemplate tpl;
  final bool isKorean;
  const _BuiltinRow({required this.tpl, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(tpl.colorHex);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_iconFromName(tpl.iconName), color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? tpl.titleKo : tpl.titleEn, style: T.bodyBold),
              const SizedBox(height: 4),
              Text(
                isKorean ? tpl.descKo : tpl.descEn,
                style: T.caption.copyWith(color: C.mu),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: C.mu),
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
    case 'checkroom': return Icons.checkroom_rounded;
    case 'face_retouching_natural': return Icons.face_retouching_natural_rounded;
    case 'child_care': return Icons.child_care_rounded;
    case 'child_friendly': return Icons.child_friendly_rounded;
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
