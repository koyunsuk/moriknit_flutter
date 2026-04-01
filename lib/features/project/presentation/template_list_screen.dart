import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/template_provider.dart';
import '../domain/user_template.dart';

// ---------------------------------------------------------------------------
// 기본 템플릿 데이터 (하드코딩 — 추후 Firestore 연동 예정)
// ---------------------------------------------------------------------------
class _BuiltinTemplate {
  final String titleKo;
  final String titleEn;
  final String descKo;
  final String descEn;
  final IconData icon;
  final Color color;
  final List<String> stepsKo;
  final List<String> stepsEn;

  const _BuiltinTemplate({
    required this.titleKo,
    required this.titleEn,
    required this.descKo,
    required this.descEn,
    required this.icon,
    required this.color,
    required this.stepsKo,
    required this.stepsEn,
  });
}

const _builtinTemplates = [
  _BuiltinTemplate(
    titleKo: '기본 스웨터',
    titleEn: 'Basic Sweater',
    descKo: '몸판 → 소매 → 마무리 단계 포함',
    descEn: 'Body → Sleeves → Finishing steps',
    icon: Icons.checkroom_rounded,
    color: Color(0xFFB47EEB),
    stepsKo: ['스와치 뜨기 & 게이지 확인', '실 & 재료 준비', '코잡기 & 시작단 뜨기', '몸판 뜨기 (앞/뒤)', '소매 뜨기', '연결 & 마무리 뜨기', '세탁 & 블로킹', '사진 촬영 & 기록'],
    stepsEn: ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on & foundation', 'Body knitting (front/back)', 'Sleeve knitting', 'Joining & finishing', 'Washing & blocking', 'Photo & documentation'],
  ),
  _BuiltinTemplate(
    titleKo: '넥워머 / 카울',
    titleEn: 'Neckwarmer / Cowl',
    descKo: '원형 뜨기 기본 단계 포함',
    descEn: 'Basic circular knitting steps',
    icon: Icons.loop_rounded,
    color: Color(0xFF4ADE80),
    stepsKo: ['스와치 & 게이지 확인', '실 & 재료 준비', '시작 코 잡기', '원형 뜨기', '무늬 & 패턴 진행', '마무리 단 뜨기', '세탁 & 블로킹', '사진 촬영 & 기록'],
    stepsEn: ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Circular knitting', 'Pattern work', 'Finishing rows', 'Washing & blocking', 'Photo & documentation'],
  ),
  _BuiltinTemplate(
    titleKo: '모자 (비니)',
    titleEn: 'Hat (Beanie)',
    descKo: '게이지 → 작업 → 감침질 단계 포함',
    descEn: 'Gauge → Work → Seam steps',
    icon: Icons.face_rounded,
    color: Color(0xFFF472B6),
    stepsKo: ['스와치 & 게이지 확인', '실 & 재료 준비', '코잡기', '고무단 뜨기', '모자 몸통 뜨기', '코 줄이기 & 마무리', '세탁 & 정리', '사진 촬영 & 기록'],
    stepsEn: ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Ribbing', 'Hat body', 'Decreases & finishing', 'Washing & care', 'Photo & documentation'],
  ),
  _BuiltinTemplate(
    titleKo: '장갑 / 미튼',
    titleEn: 'Gloves / Mittens',
    descKo: '엄지 분리 단계 포함',
    descEn: 'Thumb gusset steps included',
    icon: Icons.back_hand_rounded,
    color: Color(0xFF38BDF8),
    stepsKo: ['스와치 & 게이지 확인', '실 & 재료 준비', '손목 코잡기 & 고무단', '손 몸통 뜨기', '엄지 거짓 뜨기 (Gusset)', '엄지 분리 & 뜨기', '손가락 마무리', '세탁 & 사진 기록'],
    stepsEn: ['Swatch & gauge check', 'Yarn & materials prep', 'Cuff cast on & ribbing', 'Hand body', 'Thumb gusset', 'Thumb separation & knitting', 'Finger finishing', 'Washing & photo'],
  ),
  _BuiltinTemplate(
    titleKo: '소품 (컵홀더 등)',
    titleEn: 'Accessories',
    descKo: '간단 소품 기본 단계',
    descEn: 'Simple accessory basic steps',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFFBBF24),
    stepsKo: ['스와치 & 게이지 확인', '실 & 재료 준비', '시작 코 잡기', '몸통 뜨기', '마무리 단 뜨기', '연결 & 봉제', '세탁 & 마무리', '사진 촬영 & 기록'],
    stepsEn: ['Swatch & gauge check', 'Yarn & materials prep', 'Cast on', 'Body knitting', 'Finishing rows', 'Joining & seaming', 'Washing & finishing', 'Photo & documentation'],
  ),
];

// ---------------------------------------------------------------------------
// TemplateListScreen
// ---------------------------------------------------------------------------
class TemplateListScreen extends ConsumerWidget {
  const TemplateListScreen({super.key});

  void _showTemplateSteps(BuildContext context, _BuiltinTemplate tmpl, bool isKorean) {
    final steps = isKorean ? tmpl.stepsKo : tmpl.stepsEn;
    final title = isKorean ? tmpl.titleKo : tmpl.titleEn;
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
                    decoration: BoxDecoration(color: tmpl.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(tmpl.icon, color: tmpl.color, size: 18),
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
                              color: tmpl.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text('${entry.key + 1}', style: T.caption.copyWith(color: tmpl.color, fontWeight: FontWeight.w700))),
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
                    final route = Routes.templateEditor;
                    final extra = {'mode': 'view_builtin', 'title': title, 'steps': isKorean ? tmpl.stepsKo : tmpl.stepsEn};
                    Navigator.pop(ctx);
                    Future.microtask(() {
                      if (context.mounted) context.push(route, extra: extra);
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  // 기본 템플릿 섹션
                  Row(
                    children: [
                      Expanded(child: SectionTitle(title: isKorean ? '기본 템플릿' : 'Built-in Templates')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._builtinTemplates.map((tmpl) => _BuiltinTemplateRow(
                              template: tmpl,
                              isKorean: isKorean,
                              onTap: () => _showTemplateSteps(context, tmpl, isKorean),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 커스텀 템플릿 섹션
                  Row(
                    children: [
                      Expanded(child: SectionTitle(title: isKorean ? '나의 커스텀 템플릿' : 'My Custom Templates')),
                      TextButton.icon(
                        onPressed: () => context.push(Routes.templateEditor),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: Text(isKorean ? '새 템플릿' : 'New Template'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CustomTemplateSection(isKorean: isKorean),
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

  Future<void> _delete(BuildContext context, WidgetRef ref, UserTemplate tmpl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '템플릿 삭제' : 'Delete template', style: T.h3),
        content: Text(isKorean ? '"${tmpl.title}"을 삭제할까요?' : 'Delete "${tmpl.title}"?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () => ref.read(templateRepositoryProvider).delete(tmpl.id),
        );
        if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
      } catch (e) {
        if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

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
              onAction: () => context.push(Routes.templateEditor),
            ),
          );
        }
        return GlassCard(
          child: Column(
            children: templates.map((tmpl) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 20),
                ),
                title: Text(tmpl.title, style: T.bodyBold),
                subtitle: Text(
                  isKorean ? '${tmpl.stepTitles.length}개 단계' : '${tmpl.stepTitles.length} steps',
                  style: T.caption.copyWith(color: C.mu),
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 22),
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push(Routes.templateEditor, extra: {
                        'templateId': tmpl.id,
                        'title': tmpl.title,
                        'steps': tmpl.stepTitles,
                      });
                    }
                    if (value == 'delete') _delete(context, ref, tmpl);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), Text(isKorean ? '수정' : 'Edit')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
                  ],
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 기본 템플릿 행
// ---------------------------------------------------------------------------
class _BuiltinTemplateRow extends StatelessWidget {
  final _BuiltinTemplate template;
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
                color: template.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(template.icon, color: template.color, size: 20),
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
