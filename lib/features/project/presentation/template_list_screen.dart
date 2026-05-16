import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/template_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../../blueprint/presentation/step_log_screen.dart';
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
class TemplateListScreen extends ConsumerWidget {
  const TemplateListScreen({super.key});

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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 이슈 #687 Phase D3 — 빌트인 템플릿 → step_log_screen 진입.
                    // 마이그레이션으로 step_blueprints에 'tmpl_builtin_{id}'로 이식됨.
                    final blueprintId = 'tmpl_builtin_${tmpl.id}';
                    Navigator.pop(ctx);
                    Future.microtask(() {
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StepLogScreen(blueprintId: blueprintId),
                        ),
                      );
                    });
                  },
                  child: Text(isKorean ? '이 템플릿으로 만들기' : 'Use this template'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final builtinAsync = ref.watch(builtinTemplateListProvider);

    final userTemplatesAsync = ref.watch(userTemplateListProvider);
    final userCount = userTemplatesAsync.valueOrNull?.length ?? 0;
    final builtinCount = builtinAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '나의 템플릿' : 'My Templates',
                subtitle: isKorean ? '프로젝트 시작 단계를 템플릿으로 관리해요' : 'Manage project steps as templates',
              ),
            ),
            // 스크롤 바디
            Expanded(
              child: Stack(
                children: [
                  const BgOrbs(),
                  Positioned.fill(
                    child: Column(
                      children: [
                        // 요약카드 고정
                        Padding(
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
                        // 스크롤 목록
                        Expanded(
                          child: ListView(
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
                                  if (templates.isEmpty) {
                                    return GlassCard(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          isKorean ? '기본 템플릿이 없습니다.' : 'No built-in templates.',
                                          style: T.caption.copyWith(color: C.mu),
                                        ),
                                      ),
                                    );
                                  }
                                  return GlassCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: templates.map((tmpl) => _BuiltinTemplateRow(
                                        template: tmpl,
                                        isKorean: isKorean,
                                        onTap: () => _showTemplateSteps(context, tmpl, isKorean),
                                      )).toList(),
                                    ),
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
                                child: MoriEmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  iconColor: C.mu,
                                  title: isKorean ? '구매한 템플릿이 없어요' : 'No purchased templates',
                                  subtitle: isKorean ? '마켓에서 프리미엄 템플릿을 구매해보세요' : 'Browse premium templates in the market',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// 커스텀 템플릿 섹션 (Firestore 연동)
// ---------------------------------------------------------------------------
class _CustomTemplateSection extends ConsumerWidget {
  final bool isKorean;
  const _CustomTemplateSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userTemplateListProvider);
    return templatesAsync.when(
      loading: () => GlassCard(
        child: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: C.lv),
        )),
      ),
      error: (e, _) => GlassCard(child: Text('$e', style: T.caption.copyWith(color: C.og))),
      data: (templates) {
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
            children: templates.map((tmpl) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                // 이슈 #687 Phase D3 — 커스텀 템플릿 → step_log_screen 진입.
                // 마이그레이션으로 step_blueprints에 'tmpl_user_{id}'로 이식됨.
                onTap: () {
                  final blueprintId = 'tmpl_user_${tmpl.id}';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StepLogScreen(blueprintId: blueprintId),
                    ),
                  );
                },
                leading: tmpl.photoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        tmpl.photoUrl,
                        width: 42, height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
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
                title: Text(tmpl.title, style: T.bodyBold),
                subtitle: Text(
                  isKorean ? '${tmpl.stepTitles.length}개 단계' : '${tmpl.stepTitles.length} steps',
                  style: T.caption.copyWith(color: C.mu),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
              ),
            )).toList(),
          ),
        );
      },
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
