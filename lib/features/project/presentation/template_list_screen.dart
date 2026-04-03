import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/template_provider.dart';
import '../../market/domain/market_item.dart';
import '../domain/builtin_template.dart';
import '../domain/user_template.dart';

// ---------------------------------------------------------------------------
// 기본 템플릿 seed 데이터 (어드민 초기 데이터 입력용 — UI에는 미사용)
// ---------------------------------------------------------------------------
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
    final builtinAsync = ref.watch(builtinTemplateListProvider);

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

  Future<void> _registerToMarket(BuildContext context, WidgetRef ref, UserTemplate tmpl) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      await showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: Routes.templateList);
      return;
    }
    final titleCtrl = TextEditingController(text: tmpl.title);
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool isFree = true;
    String? imageFilePath;
    String? pdfFilePath;
    final accentHex = ['#FA5BB4', '#B47EEB', '#A3E635', '#F472B6', '#60A5FA', '#34D399', '#FB923C', '#F9A8D4'][Random().nextInt(8)];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '마켓에 등록하기' : 'Sell on Market', style: T.h3),
                const SizedBox(height: 4),
                Text(isKorean ? '도안 마켓에 나의 템플릿을 등록해요. 관리자 승인 후 게시됩니다.' : 'List your template on the market. Posted after admin approval.',
                    style: T.caption.copyWith(color: C.mu)),
                const SizedBox(height: 14),
                TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '상품 이름' : 'Title', hintText: tmpl.title, fillColor: C.gx, filled: true)),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: isKorean ? '설명' : 'Description', hintText: isKorean ? '템플릿에 대해 설명해주세요' : 'Describe your template', fillColor: C.gx, filled: true)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PriceChip(label: isKorean ? '무료' : 'Free', selected: isFree, onTap: () => setState(() { isFree = true; priceCtrl.clear(); })),
                    const SizedBox(width: 8),
                    _PriceChip(label: isKorean ? '유료' : 'Paid', selected: !isFree, onTap: () => setState(() => isFree = false)),
                  ],
                ),
                if (!isFree) ...[
                  const SizedBox(height: 10),
                  TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isKorean ? '가격 (모리)' : 'Price (Mori)', hintText: '0', fillColor: C.gx, filled: true)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null) setState(() => imageFilePath = result.files.single.path);
                    },
                    icon: const Icon(Icons.image_rounded, size: 18),
                    label: Text(imageFilePath != null ? (isKorean ? '✓ 이미지 선택됨' : '✓ Image selected') : (isKorean ? '썸네일 이미지 선택' : 'Select thumbnail')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: imageFilePath != null ? C.lmD : C.tx2,
                      side: BorderSide(color: imageFilePath != null ? C.lmD : C.bd),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                      if (result != null) setState(() => pdfFilePath = result.files.single.path);
                    },
                    icon: const Icon(Icons.description_rounded, size: 18),
                    label: Text(pdfFilePath != null ? (isKorean ? '✓ PDF 선택됨' : '✓ PDF selected') : (isKorean ? 'PDF 파일 선택 (선택)' : 'Select PDF (optional)')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: pdfFilePath != null ? C.lmD : C.tx2,
                      side: BorderSide(color: pdfFilePath != null ? C.lmD : C.bd),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final price = isFree ? 0 : (int.tryParse(priceCtrl.text.trim()) ?? 0);
                      if (titleCtrl.text.trim().isEmpty) {
                        showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: isKorean ? '상품 이름을 입력해주세요.' : 'Please enter a title.');
                        return;
                      }
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                          task: () async {
                            final item = MarketItem(
                              id: '',
                              sellerUid: user.uid,
                              sellerName: user.displayName ?? user.email ?? '',
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              price: price,
                              category: 'pattern',
                              accentHex: accentHex,
                              imageType: 'pattern',
                              isSoldOut: false,
                              isOfficial: false,
                              status: price > 0 ? 'pending' : 'approved',
                              createdAt: DateTime.now(),
                            );
                            await ref.read(marketRepositoryProvider).createItem(item, imageFile: imageFilePath, pdfFile: pdfFilePath);
                          },
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '마켓에 등록됐어요.' : 'Listed on market.');
                        }
                      } catch (e) {
                        if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                      }
                    },
                    child: Text(isKorean ? '마켓에 등록하기' : 'List on Market'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                        'stepDescs': tmpl.stepDescs,
                      });
                    }
                    if (value == 'market') _registerToMarket(context, ref, tmpl);
                    if (value == 'delete') _delete(context, ref, tmpl);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), Text(isKorean ? '수정' : 'Edit')])),
                    PopupMenuItem(value: 'market', child: Row(children: [Icon(Icons.storefront_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '마켓에 등록하기' : 'Sell on Market', style: TextStyle(color: C.lmD))])),
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
// 가격 타입 칩 (무료/유료 선택)
// ---------------------------------------------------------------------------
class _PriceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: T.body.copyWith(
            color: selected ? Colors.white : C.lvD,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
