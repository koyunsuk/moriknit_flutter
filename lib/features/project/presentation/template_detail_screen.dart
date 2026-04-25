import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/template_provider.dart';
import '../domain/user_template.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final UserTemplate template;
  const TemplateDetailScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late List<TextEditingController> _stepTitleCtrls;
  late List<TextEditingController> _stepDescCtrls;

  String? _localPhotoPath;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _stepTitleCtrls = [];
    _stepDescCtrls = [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _stepTitleCtrls) {
      c.dispose();
    }
    for (final c in _stepDescCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _enterEditMode() {
    _titleCtrl.text = widget.template.title;
    _descCtrl.text = widget.template.description;
    for (final c in _stepTitleCtrls) {
      c.dispose();
    }
    for (final c in _stepDescCtrls) {
      c.dispose();
    }
    _stepTitleCtrls = widget.template.stepTitles.map((t) => TextEditingController(text: t)).toList();
    _stepDescCtrls = widget.template.stepDescs.map((d) => TextEditingController(text: d)).toList();
    _photoUrl = widget.template.photoUrl.isNotEmpty ? widget.template.photoUrl : null;
    setState(() {
      _isEditing = true;
      _localPhotoPath = null;
    });
  }

  void _cancelEdit() {
    for (final c in _stepTitleCtrls) {
      c.dispose();
    }
    for (final c in _stepDescCtrls) {
      c.dispose();
    }
    _stepTitleCtrls = [];
    _stepDescCtrls = [];
    setState(() {
      _isEditing = false;
      _localPhotoPath = null;
    });
  }

  void _addStep() {
    setState(() {
      _stepTitleCtrls.add(TextEditingController());
      _stepDescCtrls.add(TextEditingController());
    });
  }

  void _removeStep(int index) {
    _stepTitleCtrls[index].dispose();
    _stepDescCtrls[index].dispose();
    setState(() {
      _stepTitleCtrls.removeAt(index);
      _stepDescCtrls.removeAt(index);
    });
  }

  Future<void> _pickPhoto(bool isKorean) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(isKorean ? '사진 촬영' : 'Take a photo', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    setState(() => _localPhotoPath = picked.path);
  }

  Future<void> _saveEdit(bool isKorean) async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty) return;
    final stepTitles = _stepTitleCtrls.map((c) => c.text.trim()).toList();
    final stepDescs = _stepDescCtrls.map((c) => c.text.trim()).toList();
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          if (_localPhotoPath != null) {
            final file = File(_localPhotoPath!);
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('templates/${DateTime.now().millisecondsSinceEpoch}.jpg');
            await storageRef.putFile(file);
            _photoUrl = await storageRef.getDownloadURL();
          }
          await ref.read(templateRepositoryProvider).update(
            id: widget.template.id,
            title: newTitle,
            description: _descCtrl.text.trim(),
            stepTitles: stepTitles,
            stepDescs: stepDescs,
            photoUrl: _photoUrl ?? '',
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '수정됐어요.' : 'Updated.');
      _cancelEdit();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _duplicate(bool isKorean) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(templateRepositoryProvider).create(
          title: isKorean ? '${widget.template.title} (복사)' : '${widget.template.title} (copy)',
          description: widget.template.description,
          stepTitles: [...widget.template.stepTitles],
          stepDescs: [...widget.template.stepDescs],
          photoUrl: widget.template.photoUrl,
        ),
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  Future<void> _confirmDelete(bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '템플릿 삭제' : 'Delete template', style: T.h3),
        content: Text(
          isKorean ? '"${widget.template.title}"을 삭제할까요?' : 'Delete "${widget.template.title}"?',
          style: T.body,
        ),
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
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(templateRepositoryProvider).delete(widget.template.id),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSavedSnackBar(messenger, message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: _isEditing
            ? TextButton(
                onPressed: _cancelEdit,
                child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isEditing ? (isKorean ? '템플릿 수정' : 'Edit Template') : widget.template.title,
          style: T.h3,
        ),
        actions: _isEditing
            ? [
                TextButton(
                  onPressed: _isSaving ? null : () => _saveEdit(isKorean),
                  child: Text(isKorean ? '저장' : 'Save', style: T.bodyBold.copyWith(color: C.lv)),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: C.tx),
                  onSelected: (v) {
                    if (v == 'edit') _enterEditMode();
                    if (v == 'copy') _duplicate(isKorean);
                    if (v == 'delete') _confirmDelete(isKorean);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18, color: C.lv),
                        const SizedBox(width: 8),
                        Text(isKorean ? '수정' : 'Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(children: [
                        Icon(Icons.copy_rounded, size: 18, color: C.lv),
                        const SizedBox(width: 8),
                        Text(isKorean ? '복사' : 'Duplicate'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: C.og),
                        const SizedBox(width: 8),
                        Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og)),
                      ]),
                    ),
                  ],
                ),
              ],
      ),
      body: _isEditing ? _buildEditBody(isKorean) : _buildDetailBody(isKorean),
    );
  }

  Widget _buildDetailBody(bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (widget.template.photoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.template.photoUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (widget.template.description.isNotEmpty) ...[
              SectionTitle(title: isKorean ? '설명' : 'Description'),
              const SizedBox(height: 8),
              GlassCard(child: Text(widget.template.description, style: T.body)),
              const SizedBox(height: 14),
            ],
            SectionTitle(
              title: isKorean
                  ? '단계 목록 (${widget.template.stepTitles.length}개)'
                  : 'Steps (${widget.template.stepTitles.length})',
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                children: widget.template.stepTitles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final title = entry.value;
                  final desc = i < widget.template.stepDescs.length ? widget.template.stepDescs[i] : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: C.lv.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: T.bodyBold),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(desc, style: T.caption.copyWith(color: C.mu)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditBody(bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TemplatePhotoSection(
                localPath: _localPhotoPath,
                networkUrl: _photoUrl,
                isKorean: isKorean,
                onTap: () => _pickPhoto(isKorean),
                onRemove: () => setState(() {
                  _localPhotoPath = null;
                  _photoUrl = null;
                }),
              ),
              const SizedBox(height: 20),
              SectionTitle(title: isKorean ? '템플릿 이름' : 'Template name'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isKorean ? '템플릿 이름' : 'Template name',
                  hintText: isKorean ? '예: 스웨터 기본 단계' : 'e.g. Basic Sweater Steps',
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle(title: isKorean ? '설명 (선택)' : 'Description (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isKorean ? '설명' : 'Description',
                  hintText: isKorean ? '템플릿 설명을 입력하세요' : 'Describe this template',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: SectionTitle(title: isKorean ? '단계 목록' : 'Steps')),
                  TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(isKorean ? '추가' : 'Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(
                _stepTitleCtrls.length,
                (i) => GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _stepTitleCtrls[i],
                              decoration: InputDecoration(
                                labelText: isKorean ? '단계 이름' : 'Step name',
                                hintText: isKorean ? '예: 코잡기' : 'e.g. Cast on',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _stepDescCtrls[i],
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: isKorean ? '설명 (선택)' : 'Description (optional)',
                                hintText: isKorean ? '단계 설명' : 'Step description',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeStep(i),
                        icon: Icon(Icons.delete_outline, color: C.og, size: 20),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              if (_stepTitleCtrls.isEmpty)
                GlassCard(
                  child: Text(
                    isKorean ? '단계를 추가해주세요.' : 'Add steps above.',
                    style: T.body.copyWith(color: C.mu),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplatePhotoSection extends StatelessWidget {
  final String? localPath;
  final String? networkUrl;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TemplatePhotoSection({
    required this.isKorean,
    required this.onTap,
    required this.onRemove,
    this.localPath,
    this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || networkUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPhoto) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: localPath != null
                    ? Image.file(
                        File(localPath!),
                        width: double.infinity,
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        networkUrl!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(
              hasPhoto ? Icons.edit_rounded : Icons.add_photo_alternate_outlined,
              size: 18,
            ),
            label: Text(
              hasPhoto
                  ? (isKorean ? '사진 변경' : 'Change photo')
                  : (isKorean ? '사진 추가' : 'Add photo'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.lv,
              side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
