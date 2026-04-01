import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

// ---------------------------------------------------------------------------
// TemplateEditorScreen
// ---------------------------------------------------------------------------
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final String? templateId;
  final String? initialTitle;
  final List<String>? initialSteps;

  const TemplateEditorScreen({
    super.key,
    this.templateId,
    this.initialTitle,
    this.initialSteps,
  });

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<TextEditingController> _titleCtrls = [];
  final List<TextEditingController> _descCtrls = [];

  bool get _isNew => widget.templateId == null;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _nameController.text = widget.initialTitle!;
    }
    if (widget.initialSteps != null && widget.initialSteps!.isNotEmpty) {
      for (final step in widget.initialSteps!) {
        _titleCtrls.add(TextEditingController(text: step));
        _descCtrls.add(TextEditingController());
      }
    } else {
      _titleCtrls.add(TextEditingController());
      _descCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final c in _titleCtrls) c.dispose();
    for (final c in _descCtrls) c.dispose();
    super.dispose();
  }

  void _insertStep(int afterIndex) {
    setState(() {
      _titleCtrls.insert(afterIndex + 1, TextEditingController());
      _descCtrls.insert(afterIndex + 1, TextEditingController());
    });
  }

  void _removeStep(int index) {
    if (_titleCtrls.length <= 1) return;
    _titleCtrls[index].dispose();
    _descCtrls[index].dispose();
    setState(() {
      _titleCtrls.removeAt(index);
      _descCtrls.removeAt(index);
    });
  }

  Future<void> _save() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await showMissingFieldsDialog(
        context,
        missing: [isKorean ? '템플릿 이름을 입력해 주세요.' : 'Please enter a template name.'],
        isKorean: isKorean,
      );
      return;
    }

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // TODO: Firestore 연동 — TemplateRepository.save() 호출 예정
          await Future.delayed(const Duration(milliseconds: 600));
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '저장됐어요.' : 'Saved.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final title = _isNew
        ? (isKorean ? '새 템플릿' : 'New Template')
        : (isKorean ? '템플릿 수정' : 'Edit Template');

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: T.h3),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(isKorean ? '템플릿 저장' : 'Save Template'),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 기본 정보 ──
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '템플릿 이름' : 'Template Name'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '이름 (필수)' : 'Name (required)',
                          hintText: isKorean ? '예: 기본 스웨터 작업 순서' : 'e.g. Basic Sweater Steps',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SectionTitle(title: isKorean ? '설명 (선택)' : 'Description (optional)'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isKorean ? '이 템플릿에 대해 간단히 설명해 주세요.' : 'Briefly describe this template.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 단계 목록 ──
                SectionTitle(title: isKorean ? '작업 단계 (${_titleCtrls.length}개)' : 'Steps (${_titleCtrls.length})'),
                const SizedBox(height: 8),
                ...List.generate(_titleCtrls.length, (idx) => Column(
                  key: ValueKey(idx),
                  children: [
                    _StepCard(
                      index: idx,
                      titleCtrl: _titleCtrls[idx],
                      descCtrl: _descCtrls[idx],
                      isKorean: isKorean,
                      canDelete: _titleCtrls.length > 1,
                      onDelete: () => _removeStep(idx),
                    ),
                    // 단계 사이 삽입 버튼
                    _InsertStepButton(
                      isKorean: isKorean,
                      isLast: idx == _titleCtrls.length - 1,
                      onTap: () => _insertStep(idx),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 단계 사이 삽입 버튼
// ---------------------------------------------------------------------------
class _InsertStepButton extends StatelessWidget {
  final bool isKorean;
  final bool isLast;
  final VoidCallback onTap;

  const _InsertStepButton({required this.isKorean, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Divider(color: C.bd, thickness: 1)),
          GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.lv.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: C.lvD),
                  const SizedBox(width: 4),
                  Text(
                    isLast
                        ? (isKorean ? '맨 끝에 추가' : 'Add at end')
                        : (isKorean ? '여기에 추가' : 'Insert here'),
                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Divider(color: C.bd, thickness: 1)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 단계 카드
// ---------------------------------------------------------------------------
class _StepCard extends StatelessWidget {
  final int index;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final bool isKorean;
  final bool canDelete;
  final VoidCallback onDelete;

  const _StepCard({
    super.key,
    required this.index,
    required this.titleCtrl,
    required this.descCtrl,
    required this.isKorean,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text('${index + 1}', style: T.captionBold.copyWith(color: C.lvD)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isKorean ? '단계 ${index + 1}' : 'Step ${index + 1}',
                    style: T.captionBold.copyWith(color: C.mu),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: C.og, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: isKorean ? '단계 이름' : 'Step title',
                hintText: isKorean ? '예: 몸판 뜨기' : 'e.g. Knit body',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isKorean ? '단계 설명 (선택)' : 'Step description (optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
