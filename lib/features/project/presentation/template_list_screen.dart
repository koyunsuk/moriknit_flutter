import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/project_step_provider.dart';
import '../../../providers/step_run_provider.dart';
import '../../../providers/template_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../../blueprint/domain/step_run.dart';
import '../../blueprint/presentation/step_blueprint_editor_screen.dart';
import '../../blueprint/presentation/step_log_screen.dart';
import '../../project/domain/project_model.dart';
// ignore: deprecated_member_use_from_same_package
import '../domain/builtin_template.dart';
// ignore: unused_import, deprecated_member_use_from_same_package
import '../domain/user_template.dart'; // UserTemplate passed via extra

// ---------------------------------------------------------------------------
// 기본 템플릿 seed 데이터 (어드민 초기 데이터 입력용 — UI에는 미사용)
// ---------------------------------------------------------------------------
// ignore: unused_element
final _builtinTemplateSeedData = [
  {'titleKo': '기본 스웨터', 'titleEn': 'Basic Sweater', 'descKo': '몸판 → 소매 → 마무리 단계 포함', 'descEn': 'Body → Sleeves → Finishing steps', 'iconName': 'checkroom_rounded', 'colorHex': '#B47EEB', 'order': 0, 'isActive': true, 'stepsKo': ['스와치 뜨기 & 게이지 확인', '실 & 재료 준비', '코잡기 & 시작단 뜨기', '몸판 뜨기 (앞/뒤)', '소매 뜨기', '연결 & 마무리 뜨기', '세탁 & 블로킹', '사진 촬영 & 기록'], 'stepsEn': ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on & foundation', 'Body knitting (front/back)', 'Sleeve knitting', 'Joining & finishing', 'Washing & blocking', 'Photo & documentation']},
  {'titleKo': '넥워머 / 카울', 'titleEn': 'Neckwarmer / Cowl', 'descKo': '원형 뜨기 기본 단계 포함', 'descEn': 'Basic circular knitting steps', 'iconName': 'loop_rounded', 'colorHex': '#4ADE80', 'order': 1, 'isActive': true, 'stepsKo': ['스와치 & 게이지 확인', '실 & 재료 준비', '시작 코 잡기', '원형 뜨기', '무늬 & 패턴 진행', '마무리 단 뜨기', '세탁 & 블로킹', '사진 촬영 & 기록'], 'stepsEn': ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Circular knitting', 'Pattern work', 'Finishing rows', 'Washing & blocking', 'Photo & documentation']},
  {'titleKo': '모자 (비니)', 'titleEn': 'Hat (Beanie)', 'descKo': '게이지 → 작업 → 감침질 단계 포함', 'descEn': 'Gauge → Work → Seam steps', 'iconName': 'face_rounded', 'colorHex': '#F472B6', 'order': 2, 'isActive': true, 'stepsKo': ['스와치 & 게이지 확인', '실 & 재료 준비', '코잡기', '고무단 뜨기', '모자 몸통 뜨기', '코 줄이기 & 마무리', '세탁 & 정리', '사진 촬영 & 기록'], 'stepsEn': ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Ribbing', 'Hat body', 'Decreases & finishing', 'Washing & care', 'Photo & documentation']},
  {'titleKo': '장갑 / 미튼', 'titleEn': 'Gloves / Mittens', 'descKo': '엄지 분리 단계 포함', 'descEn': 'Thumb gusset steps included', 'iconName': 'back_hand_rounded', 'colorHex': '#38BDF8', 'order': 3, 'isActive': true, 'stepsKo': ['스와치 & 게이지 확인', '실 & 재료 준비', '손목 코잡기 & 고무단', '손 몸통 뜨기', '엄지 거짓 뜨기 (Gusset)', '엄지 분리 & 뜨기', '손가락 마무리', '세탁 & 사진 기록'], 'stepsEn': ['Swatch & gauge check', 'Yarn & materials prep', 'Cuff cast on & ribbing', 'Hand body', 'Thumb gusset', 'Thumb separation & knitting', 'Finger finishing', 'Washing & photo']},
  {'titleKo': '소품 (컵홀더 등)', 'titleEn': 'Accessories', 'descKo': '간단 소품 기본 단계', 'descEn': 'Simple accessory basic steps', 'iconName': 'local_cafe_rounded', 'colorHex': '#FBBF24', 'order': 4, 'isActive': true, 'stepsKo': ['스와치 & 게이지 확인', '실 & 재료 준비', '시작 코 잡기', '몸통 뜨기', '마무리 단 뜨기', '연결 & 봉제', '세탁 & 마무리', '사진 촬영 & 기록'], 'stepsEn': ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Body knitting', 'Finishing rows', 'Joining & seaming', 'Washing & finishing', 'Photo & documentation']},
];

// 아이콘 이름 → IconData 매핑
IconData _iconFromName(String name) {
  switch (name) {
    case 'checkroom_rounded': return Icons.checkroom_rounded;
    case 'loop_rounded': return Icons.loop_rounded;
    case 'face_rounded': return Icons.face_rounded;
    case 'back_hand_rounded': return Icons.back_hand_rounded;
    case 'local_cafe_rounded': return Icons.local_cafe_rounded;
    default: return Icons.folder_special_rounded;
  }
}

// colorHex → Color 변환
Color _colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// ---------------------------------------------------------------------------
// 신규 템플릿(=청사진 kind=template) 생성 후 step_log_screen 진입.
// Phase E3 (#687) — TemplateEditorScreen 진입 경로 대체.
// ---------------------------------------------------------------------------
Future<void> _createTemplateBlueprintAndEdit(
  BuildContext context,
  WidgetRef ref,
  bool isKorean,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return;
  try {
    final repo = ref.read(stepBlueprintRepositoryProvider);
    final blueprint = StepBlueprint(
      id: '',
      ownerUid: uid,
      title: isKorean ? '새 템플릿' : 'New Template',
      kind: BlueprintKind.template,
      visibility: BlueprintVisibility.draft,
      createdAt: DateTime.now(),
    );
    final created = await repo.create(blueprint);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StepLogScreen(blueprintId: created.id),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
  }
}

// ---------------------------------------------------------------------------
// TemplateListScreen
// ---------------------------------------------------------------------------
// 이슈 #787 — 기본 템플릿 카테고리 필터 칩(전체/의상/소품/인형/아기용) 추가.
// 카테고리 선택 상태를 유지하기 위해 ConsumerStatefulWidget 로 전환.
class TemplateListScreen extends ConsumerStatefulWidget {
  const TemplateListScreen({super.key});

  @override
  ConsumerState<TemplateListScreen> createState() => _TemplateListScreenState();
}

/// 이슈 #787 — 카테고리 탭. index 0=전체, 1~ 카테고리.
class _TemplateListScreenState extends ConsumerState<TemplateListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _categoryTab;
  BuiltinTemplateCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _categoryTab =
        TabController(length: BuiltinTemplateCategory.values.length + 1, vsync: this);
    _categoryTab.addListener(() {
      if (_categoryTab.indexIsChanging) return;
      final idx = _categoryTab.index;
      setState(() {
        _selectedCategory =
            idx == 0 ? null : BuiltinTemplateCategory.values[idx - 1];
      });
    });
  }

  @override
  void dispose() {
    _categoryTab.dispose();
    super.dispose();
  }

  void _showTemplateSteps(BuildContext context, BuiltinTemplate tmpl, bool isKorean) {
    final steps = isKorean ? tmpl.stepsKo : tmpl.stepsEn;
    final title = isKorean ? tmpl.titleKo : tmpl.titleEn;
    final icon = _iconFromName(tmpl.iconName);
    final color = _colorFromHex(tmpl.colorHex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: T.h3)),
                ],
              ),
              const SizedBox(height: 16),
              Text(isKorean ? '단계별 진행' : 'Step-by-step', style: T.caption.copyWith(color: C.mu)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: steps.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text('${entry.key + 1}', style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(entry.value, style: T.body)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 이슈 #788 — 2-옵션 버튼: 프로젝트 시작 / 템플릿 편집(사본 복제).
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Future.microtask(() {
                          if (!context.mounted) return;
                          _openTemplateForEdit(context, tmpl, isKorean);
                        });
                      },
                      icon: Icon(Icons.edit_outlined, size: 18, color: C.lv),
                      label: Text(
                        isKorean ? '템플릿 편집' : 'Edit template',
                        style: T.bodyBold.copyWith(color: C.lvD),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: C.lv.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Future.microtask(() {
                          if (!context.mounted) return;
                          _openTemplateForProjectStart(
                              context, tmpl, isKorean);
                        });
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        isKorean ? '프로젝트 시작' : 'Start project',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── #788 — 프로젝트 시작 ────────────────────────────────────────────────
  //
  // 빌트인 청사진(`tmpl_builtin_{id}`)을 미리 보장 조회한 뒤
  // 갭 #2/#3 fix — 그냥 StepLogScreen 띄우지 않고 Project + StepRun 자동 생성 후 진입.
  // 단계 체크가 어디에도 기록되지 않던 회귀 fix.
  Future<void> _openTemplateForProjectStart(
    BuildContext context,
    BuiltinTemplate tmpl,
    bool isKorean,
  ) async {
    final blueprintId = 'tmpl_builtin_${tmpl.id}';
    final repo =
        ProviderScope.containerOf(context).read(stepBlueprintRepositoryProvider);
    try {
      final blueprint = await runWithMoriLoadingDialog<StepBlueprint?>(
        context,
        message: isKorean ? '템플릿을 불러오는 중입니다.' : 'Loading template...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.ensureBuiltinBlueprint(blueprintId),
      );
      if (!context.mounted) return;
      if (blueprint == null) {
        showSaveErrorSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean
              ? '인터넷 상태를 확인해 주세요. 캐시된 템플릿이 없어요.'
              : 'Please check your network. No cached template available.',
        );
        return;
      }
      // 갭 #2/#3 — 빌트인이라도 Project + StepRun 을 만들어 단계 체크가 기록되도록 한다.
      await _startProjectFromBlueprint(context, ref, blueprint, isKorean);
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean
            ? '템플릿을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'
            : 'Could not load the template. Please try again later.',
      );
    }
  }

  // ── #788 — 템플릿 편집 (사용자 본인 사본 복제) ───────────────────────────
  //
  // 1) 원본 빌트인 청사진 보장 조회.
  // 2) duplicateAsUserCopy → user_template 사본 생성.
  // 3) StepBlueprintEditorScreen 진입 (사본 ID).
  Future<void> _openTemplateForEdit(
    BuildContext context,
    BuiltinTemplate tmpl,
    bool isKorean,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '로그인이 필요해요.' : 'Please sign in.',
      );
      return;
    }
    final blueprintId = 'tmpl_builtin_${tmpl.id}';
    final repo =
        ProviderScope.containerOf(context).read(stepBlueprintRepositoryProvider);
    try {
      final copy = await runWithMoriLoadingDialog<StepBlueprint>(
        context,
        message: isKorean ? '내 템플릿으로 복제하는 중입니다.' : 'Duplicating to your templates...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.duplicateAsUserCopy(blueprintId),
      );
      if (!context.mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '내 템플릿이 만들어졌어요.' : 'Your template was created.',
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StepBlueprintEditorScreen(blueprintId: copy.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean
            ? '템플릿을 복제하지 못했어요. 인터넷 상태를 확인해 주세요.'
            : 'Could not duplicate the template. Please check your network.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final builtinAsync = ref.watch(builtinTemplateListProvider);

    // 갭 #1 — 옛 컬렉션 대신 step_blueprints 기반 청사진 목록을 사용해 카운트 표시.
    // _CustomTemplateSection 과 동일한 필터(kind=template, ownerUid=self, 빌트인 제외)
    // 를 적용해 카드 수와 일치하도록 보장.
    final blueprintsAsync = ref.watch(myBlueprintsWithLegacyProvider);
    final userCount = (blueprintsAsync.valueOrNull ?? const <StepBlueprint>[])
        .where((b) =>
            b.kind == BlueprintKind.template &&
            !b.id.startsWith('tmpl_builtin_'))
        .length;
    final builtinCount = builtinAsync.valueOrNull?.length ?? 0;

    return AppShellScaffold(
      title: isKorean ? '나의 템플릿' : 'My Templates',
      subtitle: isKorean ? '프로젝트 시작 단계를 템플릿으로 관리해요' : 'Manage project steps as templates',
      aboveBody: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SummaryCard_Detail(
          headers: [
            isKorean ? '기본' : 'Built-in',
            isKorean ? '커스텀' : 'Custom',
            isKorean ? '구매' : 'Paid',
          ],
          rows: [
            LibrarySummaryRowData(
              badge: isKorean ? '템플릿' : 'Template',
              badgeColor: C.lv,
              values: ['$builtinCount', '$userCount', '0'],
              valueColors: [C.lv, C.pkD, C.mu],
            ),
          ],
          addLabel: isKorean ? '추가' : 'Add',
          // Phase E3 (#687) — 빈 청사진(kind=template) 생성 후 step_log_screen 진입.
          onAdd: () => _createTemplateBlueprintAndEdit(context, ref, isKorean),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const SizedBox(height: 16),
          // 기본 템플릿 섹션
          SectionTitle(title: isKorean ? '📋 기본 템플릿' : '📋 Built-in Templates'),
          const SizedBox(height: 8),
          builtinAsync.when(
            loading: () => GlassCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: C.lv),
                ),
              ),
            ),
            error: (e, _) => GlassCard(child: Text('$e', style: T.caption.copyWith(color: C.og))),
            data: (templates) {
              // 이슈 #787 — 카테고리 필터 칩 + 카운트.
              // 칩 라벨: "전체 N · 의상 N · 소품 N · 인형 N · 아기용 N".
              final counts = <BuiltinTemplateCategory, int>{
                for (final c in BuiltinTemplateCategory.values) c: 0,
              };
              for (final t in templates) {
                counts[t.category] = (counts[t.category] ?? 0) + 1;
              }
              final filtered = _selectedCategory == null
                  ? templates
                  : templates.where((t) => t.category == _selectedCategory).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryTabBar(
                    isKorean: isKorean,
                    controller: _categoryTab,
                    counts: counts,
                    totalCount: templates.length,
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          isKorean
                              ? '이 카테고리에 해당하는 템플릿이 없어요.'
                              : 'No templates in this category.',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ),
                    )
                  else
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: filtered
                            .map((tmpl) => _BuiltinTemplateRow(
                                  template: tmpl,
                                  isKorean: isKorean,
                                  onTap: () =>
                                      _showTemplateSteps(context, tmpl, isKorean),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // 커스텀 템플릿 섹션
          SectionTitle(title: isKorean ? '✨ 나의 커스텀 템플릿' : '✨ My Custom Templates'),
          const SizedBox(height: 8),
          _CustomTemplateSection(isKorean: isKorean),
          const SizedBox(height: 16),
          // 구매한 템플릿 섹션 (플레이스홀더)
          SectionTitle(title: isKorean ? '🛍️ 구매한 템플릿' : '🛍️ Purchased Templates'),
          const SizedBox(height: 8),
          GlassCard(
            // 이슈 #859 — 템플릿 없을 때 "마켓 가기" 버튼 추가 (다른 블록과 UI 일관, MoriEmptyState 공통 위젯 사용)
            child: MoriEmptyState(
              icon: Icons.shopping_bag_outlined,
              iconColor: C.mu,
              title: isKorean ? '구매한 템플릿이 없어요' : 'No purchased templates',
              subtitle: isKorean ? '마켓에서 프리미엄 템플릿을 구매해보세요' : 'Browse premium templates in the market',
              buttonLabel: isKorean ? '+ 템플릿 구경하기' : '+ Browse templates',
              onAction: () => context.push(Routes.market),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 커스텀 템플릿 섹션 (Firestore 연동)
//
// 갭 #1 fix — `userTemplateListProvider` (옛 users/{uid}/templates) 대신
// `myBlueprintsWithLegacyProvider` 를 사용해 `duplicateAsUserCopy` 로 만든
// step_blueprints 루트의 사본까지 즉시 노출.
// 노출 조건:
//   - ownerUid == 현재 사용자
//   - kind == BlueprintKind.template
//   - 빌트인 id(`tmpl_builtin_*`) 제외 (혹시 fallback 캐시가 owner 로 적힌 경우 방어)
// ---------------------------------------------------------------------------
class _CustomTemplateSection extends ConsumerWidget {
  final bool isKorean;
  const _CustomTemplateSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blueprintsAsync = ref.watch(myBlueprintsWithLegacyProvider);
    return blueprintsAsync.when(
      loading: () => GlassCard(
        child: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: C.lv),
        )),
      ),
      error: (e, _) => GlassCard(child: Text('$e', style: T.caption.copyWith(color: C.og))),
      data: (allBlueprints) {
        final templates = allBlueprints.where((b) {
          if (b.kind != BlueprintKind.template) return false;
          if (b.id.startsWith('tmpl_builtin_')) return false; // 빌트인 방어 필터
          return true;
        }).toList();
        if (templates.isEmpty) {
          return GlassCard(
            child: MoriEmptyState(
              icon: Icons.folder_special_rounded,
              iconColor: C.lv,
              title: isKorean ? '아직 커스텀 템플릿이 없어요' : 'No custom templates yet',
              subtitle: isKorean ? "'새 템플릿' 버튼을 눌러 나만의 단계를 만들어보세요." : "Tap 'New Template' to create your own steps.",
              buttonLabel: isKorean ? '새 템플릿 만들기' : 'Create Template',
              // Phase E3 (#687) — 빈 청사진(kind=template) 생성 후 step_log_screen 진입.
              onAction: () => _createTemplateBlueprintAndEdit(context, ref, isKorean),
            ),
          );
        }
        return GlassCard(
          child: Column(
            children: templates.map((tmpl) {
              final title = tmpl.localizedTitle(isKorean);
              final stepCount = tmpl.groups.fold<int>(
                0,
                (sum, g) => sum + g.unitIds.length,
              );
              final photoUrl = (tmpl.attachedImageUrls ?? const <String>[])
                  .firstWhere((u) => u.isNotEmpty, orElse: () => '');
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  // 커스텀 템플릿 행 탭 → 단계 미리보기 시트 (빌트인과 동일 UX).
                  // 시트에서 [프로젝트 시작] / [템플릿 편집] 두 옵션 제공.
                  onTap: () => _showUserTemplateSheet(context, ref, tmpl, isKorean),
                  leading: photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: 42, height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (ctx, err, st) => Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 20),
                          ),
                        ),
                      )
                    : Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 20),
                      ),
                  title: Text(title, style: T.bodyBold),
                  subtitle: Text(
                    isKorean ? '$stepCount개 단계' : '$stepCount steps',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// 커스텀 템플릿 진입 시트 — [프로젝트 시작] / [템플릿 편집] 옵션 제공.
///
/// 갭 #1 + #2 fix — 빌트인과 동일하게 사본도 즉시 프로젝트화/편집 가능하도록 통일.
void _showUserTemplateSheet(
  BuildContext context,
  WidgetRef ref,
  StepBlueprint tmpl,
  bool isKorean,
) {
  final title = tmpl.localizedTitle(isKorean);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: T.h3)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isKorean ? '나의 템플릿' : 'My Template',
              style: T.caption.copyWith(color: C.mu),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Future.microtask(() {
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                StepBlueprintEditorScreen(blueprintId: tmpl.id),
                          ),
                        );
                      });
                    },
                    icon: Icon(Icons.edit_outlined, size: 18, color: C.lv),
                    label: Text(
                      isKorean ? '템플릿 편집' : 'Edit template',
                      style: T.bodyBold.copyWith(color: C.lvD),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: C.lv.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Future.microtask(() {
                        if (!context.mounted) return;
                        _startProjectFromBlueprint(
                            context, ref, tmpl, isKorean);
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(isKorean ? '프로젝트 시작' : 'Start project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 갭 #2/#3 fix — 청사진 → Project 자동 생성 + StepRun 생성 + StepLogScreen 진입.
///
/// 흐름:
///   1) ProjectRepository.createProject (title=청사진명, sourcePatternId=blueprintId,
///      status=in_progress, uid=self)
///   2) StepRunRepository.create (project.id == run.id 정책 — 같은 id 발급)
///   3) 청사진 units → 프로젝트 ProjectStep 미러링 (사용자가 단계 체크 가능)
///   4) StepLogScreen(blueprintId, runId) 진입
///
/// 사용자에게 노출되는 에러는 친화 메시지로만 전달.
Future<void> _startProjectFromBlueprint(
  BuildContext context,
  WidgetRef ref,
  StepBlueprint blueprint,
  bool isKorean,
) async {
  final title = blueprint.localizedTitle(isKorean);
  try {
    final created = await runWithMoriLoadingDialog<({ProjectModel project, StepRun run})>(
      context,
      message: isKorean ? '프로젝트를 만드는 중입니다.' : 'Creating project...',
      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
      task: () async {
        final projectRepo = ref.read(projectRepositoryProvider);
        final stepRunRepo = ref.read(stepRunRepositoryProvider);
        final stepRepo = ref.read(projectStepRepositoryProvider);
        final counterRepo = ref.read(counterRepositoryProvider);

        // 1) Project 생성
        final now = DateTime.now();
        final draft = ProjectModel.empty(uid: '').copyWith(
          title: title,
          sourcePatternId: blueprint.id,
          status: ProjectStatus.inProgress.value,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        );
        final project = await projectRepo.createProject(draft);

        // 2) StepRun 생성 — project.id 와 동일 id 정책.
        //    StepRunRepository.create 는 입력 id 가 비어 있지 않으면 그 id 로 생성.
        final run = await stepRunRepo.create(StepRun(
          id: project.id,
          userUid: '',
          blueprintId: blueprint.id,
          projectId: project.id,
          startedAt: now,
        ));

        // 3) 청사진 units → ProjectStep 미러링.
        //    addBuiltinTemplateSteps 와 동등한 흐름 — units 의 title/instruction/targetRows 를
        //    그대로 ProjectStep 으로 옮긴다. step_blueprints 가 비었으면 skip.
        try {
          final units = await ref
              .read(stepBlueprintRepositoryProvider)
              .listUnits(blueprint.id);
          for (int i = 0; i < units.length; i++) {
            final u = units[i];
            await stepRepo.addStep(
              project.id,
              u.localizedTitle(isKorean).isNotEmpty
                  ? u.localizedTitle(isKorean)
                  : (isKorean ? '단계 ${i + 1}' : 'Step ${i + 1}'),
              i,
              note: u.localizedInstruction(isKorean),
              targetRow: u.targetRows,
            );
          }
          // counterRepo 는 향후 단계별 카운터 자동 생성 확장 여지로 보존.
          // 현재는 ProjectStep 만 만들고 카운터는 사용자가 필요 시 추가.
          // unused 회피용 no-op.
          // ignore: unused_local_variable
          final _ = counterRepo;
        } catch (_) {
          // units 조회 실패해도 Project + StepRun 은 이미 만들어졌으므로 흐름 유지.
        }

        return (project: project, run: run);
      },
    );
    if (!context.mounted) return;
    showSavedSnackBar(
      ScaffoldMessenger.of(context),
      message: isKorean ? '프로젝트가 시작됐어요.' : 'Project started.',
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StepLogScreen(
          blueprintId: blueprint.id,
          runId: created.run.id,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    showSaveErrorSnackBar(
      ScaffoldMessenger.of(context),
      message: isKorean
          ? '프로젝트를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.'
          : 'Could not start the project. Please try again later.',
    );
  }
}

// ---------------------------------------------------------------------------
// 기본 템플릿 행 (Firestore BuiltinTemplate 기반)
// ---------------------------------------------------------------------------
class _BuiltinTemplateRow extends StatelessWidget {
  final BuiltinTemplate template;
  final bool isKorean;
  final VoidCallback onTap;

  const _BuiltinTemplateRow({
    required this.template,
    required this.isKorean,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = isKorean ? template.titleKo : template.titleEn;
    final desc = isKorean ? template.descKo : template.descEn;
    final icon = _iconFromName(template.iconName);
    final color = _colorFromHex(template.colorHex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.bodyBold),
                  const SizedBox(height: 2),
                  Text(desc, style: T.caption.copyWith(color: C.mu)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 이슈 #787 — 카테고리 필터 칩.
// 5개 선택지: 전체 / 의상 / 소품 / 인형 / 아기용.
// 각 칩에 카운트 표시. 선택값 null = 전체.
// 이슈 #787 — 카테고리 탭 (tools_screen 스타일 TabBar).
// ---------------------------------------------------------------------------
class _CategoryTabBar extends StatelessWidget {
  final bool isKorean;
  final TabController controller;
  final Map<BuiltinTemplateCategory, int> counts;
  final int totalCount;

  const _CategoryTabBar({
    required this.isKorean,
    required this.controller,
    required this.counts,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      Tab(text: '${isKorean ? '전체' : 'All'} $totalCount'),
      for (final c in BuiltinTemplateCategory.values)
        Tab(text: '${c.label(isKorean: isKorean)} ${counts[c] ?? 0}'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.lv.withValues(alpha: 0.15)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: C.lvD,
        labelStyle: T.caption.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            T.caption.copyWith(fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: C.lv,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: tabs,
      ),
    );
  }
}
