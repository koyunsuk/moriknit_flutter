import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/project_step_provider.dart';
import '../domain/counter_model.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern/presentation/pattern_viewer_screen.dart';

class CounterScreen extends ConsumerStatefulWidget {
  final String counterId;
  const CounterScreen({super.key, required this.counterId});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends ConsumerState<CounterScreen> {
  int _stepSize = 1;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _localPhotoPath;
  String? _photoUrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _stitchCtrl;
  late final TextEditingController _rowCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _stitchCtrl = TextEditingController();
    _rowCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stitchCtrl.dispose();
    _rowCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode(CounterModel counter) {
    _nameCtrl.text = counter.name;
    _stitchCtrl.text = counter.targetStitchCount > 0 ? '${counter.targetStitchCount}' : '';
    _rowCtrl.text = counter.targetRowCount > 0 ? '${counter.targetRowCount}' : '';
    _photoUrl = counter.photoUrl.isNotEmpty ? counter.photoUrl : null;
    setState(() {
      _isEditing = true;
      _localPhotoPath = null;
    });
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _pickPhoto(bool isKorean) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  Future<void> _saveEdit(CounterModel counter, bool isKorean) async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    final newStitch = int.tryParse(_stitchCtrl.text.trim()) ?? 0;
    final newRow = int.tryParse(_rowCtrl.text.trim()) ?? 0;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          String? uploadedUrl = _photoUrl;
          if (_localPhotoPath != null) {
            final file = File(_localPhotoPath!);
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('counters/${DateTime.now().millisecondsSinceEpoch}.jpg');
            await storageRef.putFile(file);
            uploadedUrl = await storageRef.getDownloadURL();
          }
          await ref.read(counterRepositoryProvider).updateCounter(
            counter.copyWith(
              name: newName,
              targetStitchCount: newStitch,
              targetRowCount: newRow,
              photoUrl: uploadedUrl ?? '',
            ),
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '수정됐어요.' : 'Updated.');
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildEditBody(CounterModel counter, bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CounterPhotoSection(
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
              SectionTitle(title: isKorean ? '카운터 이름' : 'Counter name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isKorean ? '카운터 이름' : 'Counter name',
                  hintText: isKorean ? '예: 소매 카운터' : 'e.g. Sleeve counter',
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle(title: isKorean ? '목표 코수 (선택)' : 'Target stitches (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _stitchCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isKorean ? '목표 코수' : 'Target stitches',
                  hintText: '0',
                  suffixText: isKorean ? '코' : 'sts',
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle(title: isKorean ? '목표 단수 (선택)' : 'Target rows (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _rowCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isKorean ? '목표 단수' : 'Target rows',
                  hintText: '0',
                  suffixText: isKorean ? '단' : 'rows',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _update(CounterModel counter, {int stitchDelta = 0, int rowDelta = 0}) async {
    final repo = ref.read(counterRepositoryProvider);
    if (stitchDelta != 0) {
      final newVal = (counter.stitchCount + stitchDelta).clamp(0, 99999);
      final actualDelta = newVal - counter.stitchCount;
      if (actualDelta != 0) await repo.incrementStitch(counter.id, actualDelta);
    }
    if (rowDelta != 0) {
      final newVal = (counter.rowCount + rowDelta).clamp(0, 99999);
      final actualDelta = newVal - counter.rowCount;
      if (actualDelta != 0) await repo.incrementRow(counter.id, actualDelta);
    }
  }

  Future<void> _editMark(CounterModel counter, CounterMark mark) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final noteCtrl = TextEditingController(text: mark.note);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '마크 수정' : 'Edit mark', style: T.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean
                  ? '코 ${mark.stitchCount} · 단 ${mark.rowCount}'
                  : 'Stitch ${mark.stitchCount} · Row ${mark.rowCount}',
              style: T.body.copyWith(color: C.mu),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: isKorean ? '코멘트' : 'Comment',
                hintText: isKorean ? '예: 단추구멍단' : 'e.g. Buttonhole row',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx, true); },
            child: Text(isKorean ? '저장' : 'Save'),
          ),
        ],
      ),
    );
    final newNote = noteCtrl.text.trim();
    if (confirm != true || !mounted) return;
    final repo = ref.read(counterRepositoryProvider);
    await runWithMoriLoadingDialog<void>(
      context,
      message: isKorean ? '저장하는 중입니다.' : 'Saving...',
      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
      task: () async {
        await repo.removeMark(counter.id, mark);
        await repo.addMark(counter.id, mark.copyWith(note: newNote));
      },
    );
    if (mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '저장됐어요.' : 'Saved.');
  }

  Future<void> _deleteMark(CounterModel counter, CounterMark mark) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '마크 삭제' : 'Delete mark', style: T.h3),
        content: Text(
          isKorean ? '이 마크를 삭제할까요?' : 'Delete this mark?',
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
    await runWithMoriLoadingDialog<void>(
      context,
      message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
      task: () => ref.read(counterRepositoryProvider).removeMark(counter.id, mark),
    );
  }

  Future<void> _saveMark(CounterModel counter) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '현재 위치 저장' : 'Save mark', style: T.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean
                  ? '코 ${counter.stitchCount} · 단 ${counter.rowCount}'
                  : 'Stitch ${counter.stitchCount} · Row ${counter.rowCount}',
              style: T.body.copyWith(color: C.mu),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: isKorean ? '코멘트 (선택)' : 'Comment (optional)',
                hintText: isKorean ? '예: 단추구멍단, 소매 분리' : 'e.g. Buttonhole row',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
            child: Text(isKorean ? '저장' : 'Save'),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;
    await ref.read(counterRepositoryProvider).addMark(
      counter.id,
      CounterMark(
        timestamp: DateTime.now(),
        stitchCount: counter.stitchCount,
        rowCount: counter.rowCount,
        note: note,
      ),
    );
  }

  void _linkToProject(BuildContext context, String counterId, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allProjects = cRef.watch(projectListProvider).valueOrNull ?? [];
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(isKorean ? '프로젝트에 연결' : 'Link to Project', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (allProjects.isEmpty)
                    Expanded(child: Center(child: Text(isKorean ? '등록된 프로젝트가 없어요.' : 'No projects available.', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey))))
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: allProjects.length,
                        itemBuilder: (_, i) {
                          final project = allProjects[i];
                          final alreadyLinked = project.counterIds.contains(counterId);
                          return ListTile(
                            leading: project.coverPhotoUrl.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: project.coverPhotoUrl, width: 40, height: 40, fit: BoxFit.cover))
                                : Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.folder_outlined, size: 20)),
                            title: Text(project.title, style: Theme.of(ctx).textTheme.bodyMedium),
                            trailing: alreadyLinked ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18) : null,
                            onTap: alreadyLinked ? null : () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                task: () => ref.read(projectRepositoryProvider).updateProject(
                                      project.copyWith(counterIds: [...project.counterIds, counterId]),
                                    ),
                              );
                              if (context.mounted) {
                                showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결됐어요.' : 'Linked.');
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _duplicateCounter(CounterModel counter, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(counterRepositoryProvider).duplicateCounter(counter),
      );
      if (mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _linkToPattern(BuildContext context, CounterModel counter, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, child3) {
          final patterns = cRef.watch(patternListProvider).valueOrNull ?? [];
          final viewable = patterns
              .where((p) => p.type == PatternType.image || p.type == PatternType.pdf)
              .toList();
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(isKorean ? '도안 연결' : 'Link Pattern',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (viewable.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isKorean
                              ? '연결 가능한 이미지/PDF 도안이 없어요.'
                              : 'No image or PDF patterns available.',
                          style: Theme.of(ctx)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: viewable.length,
                        itemBuilder: (_, i) {
                          final p = viewable[i];
                          final linked = counter.patternChartId == p.id;
                          return ListTile(
                            leading: Icon(
                              p.type == PatternType.pdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.image_rounded,
                              color: linked ? C.lv : C.mu,
                            ),
                            title: Text(p.title,
                                style:
                                    Theme.of(ctx).textTheme.bodyMedium),
                            trailing: linked
                                ? Icon(Icons.check_circle_rounded,
                                    color: Colors.green.shade400, size: 18)
                                : null,
                            onTap: linked
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await runWithMoriLoadingDialog<void>(
                                      context,
                                      message: isKorean
                                          ? '연결하는 중입니다.'
                                          : 'Linking...',
                                      subtitle: isKorean
                                          ? '잠시만 기다려 주세요.'
                                          : 'Please wait.',
                                      task: () => ref
                                          .read(counterRepositoryProvider)
                                          .updateCounter(counter.copyWith(
                                              patternChartId: p.id)),
                                    );
                                    if (context.mounted) {
                                      showSavedSnackBar(
                                          ScaffoldMessenger.of(context),
                                          message: isKorean
                                              ? '연결됐어요.'
                                              : 'Linked.');
                                    }
                                  },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '카운터 삭제' : 'Delete counter', style: T.h3),
        content: Text(isKorean ? '이 카운터를 삭제할까요? 되돌릴 수 없어요.' : 'Delete this counter? This cannot be undone.', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () async {
              Navigator.pop(ctx);
              // #821 — silent fail 차단: transaction 실패 시 에러 SnackBar 표시.
              //   이전 코드는 await throw 무시 → 사용자에게 "삭제됨" UI 표시 but 실제 Firestore 안 지워짐.
              try {
                await ref.read(counterRepositoryProvider).deleteCounter(widget.counterId);
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    isKorean ? '삭제 실패: $e' : 'Delete failed: $e',
                    style: T.body.copyWith(color: Colors.white),
                  ),
                  backgroundColor: C.og,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counterAsync = ref.watch(counterByIdProvider(widget.counterId));

    final counter = counterAsync.valueOrNull;

    final headerTitle = _isEditing
        ? (isKorean ? '카운터 수정' : 'Edit Counter')
        : (counter?.name ?? '');
    final headerSubtitle = _isEditing
        ? (isKorean ? '카운터 정보 변경' : 'Edit counter info')
        : (isKorean ? '카운터' : 'Counter');

    final List<Widget> trailing = _isEditing
        ? [
            TextButton(
              onPressed: _cancelEdit,
              child: Text(isKorean ? '취소' : 'Cancel',
                  style: T.body.copyWith(color: C.mu)),
            ),
            TextButton(
              onPressed: _isSaving || counter == null
                  ? null
                  : () => _saveEdit(counter, isKorean),
              child: Text(isKorean ? '저장' : 'Save',
                  style: T.bodyBold.copyWith(color: C.lv)),
            ),
          ]
        : [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: C.mu),
              onSelected: (value) {
                final c = counterAsync.valueOrNull;
                if (c == null) return;
                if (value == 'edit') {
                  _enterEditMode(c);
                } else if (value == 'copy') {
                  _duplicateCounter(c, isKorean);
                } else if (value == 'link_project') {
                  _linkToProject(context, c.id, isKorean);
                } else if (value == 'link_pattern') {
                  _linkToPattern(context, c, isKorean);
                } else if (value == 'delete') {
                  _confirmDelete(isKorean);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: C.lv, size: 18),
                      const SizedBox(width: 10),
                      Text(isKorean ? '수정' : 'Edit', style: T.body),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 10),
                      Text(isKorean ? '복사' : 'Duplicate', style: T.body),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'link_project',
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, color: C.lv, size: 18),
                      const SizedBox(width: 10),
                      Text(isKorean ? '프로젝트 연결' : 'Link to project',
                          style: T.body),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'link_pattern',
                  child: Row(
                    children: [
                      Icon(Icons.image_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 10),
                      Text(isKorean ? '도안 연결' : 'Link pattern',
                          style: T.body),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: C.og, size: 18),
                      const SizedBox(width: 10),
                      Text(isKorean ? '삭제' : 'Delete',
                          style: T.body.copyWith(color: C.og)),
                    ],
                  ),
                ),
              ],
            ),
          ];

    return AppShellScaffold(
      title: headerTitle,
      subtitle: headerSubtitle,
      trailing: trailing,
      showBackButton: true,
      showBgOrbs: false,
      body: counterAsync.when(
        data: (counter) {
          if (counter == null) {
            return Center(child: Text(isKorean ? '카운터를 찾을 수 없어요.' : 'Counter not found.', style: T.body));
          }
          if (_isEditing) return _buildEditBody(counter, isKorean);
          return Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (counter.photoUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: counter.photoUrl,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (counter.patternChartId.isNotEmpty) ...[
                    Builder(builder: (ctx2) {
                      final allPatterns = ref.watch(patternListProvider).valueOrNull ?? [];
                      final linked = allPatterns.firstWhere(
                        (p) => p.id == counter.patternChartId,
                        orElse: () => PatternChart(id: '', title: '', rows: 0, cols: 0,
                            mode: ChartMode.color, grid: const []),
                      );
                      if (linked.id.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          // 이슈 #696 — Navigator GlobalKey 크래시 fix.
                          // settings.name을 유일하게 부여하여 restoration scope key 충돌 방지.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(
                                name: 'pattern-viewer/${linked.id}-${DateTime.now().millisecondsSinceEpoch}',
                              ),
                              builder: (_) => PatternViewerScreen(chart: linked),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                linked.type == PatternType.pdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.image_rounded,
                                color: C.lmD,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(linked.title,
                                    style: T.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(isKorean ? '도안 열기' : 'Open',
                                  style: TextStyle(
                                      color: C.lv,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  color: C.mu, size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (counter.projectId.isNotEmpty && counter.projectStepId.isNotEmpty)
                    _StepGuideBanner(
                      projectId: counter.projectId,
                      stepId: counter.projectStepId,
                      rowCount: counter.rowCount,
                      isKorean: isKorean,
                    ),
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(counter.name, style: T.h2),
                        Text(isKorean ? '코 · 단 카운터' : 'Stitch & Row Counter', style: T.caption),
                      ])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 증감단위 선택 칩
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                    child: Row(
                      children: [
                        Text(isKorean ? '증감단위' : 'Step', style: T.caption.copyWith(color: C.mu)),
                        const SizedBox(width: 12),
                        for (final step in [1, 5, 10, 100])
                          GestureDetector(
                            onTap: () => setState(() => _stepSize = step),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _stepSize == step ? C.lv : C.lvL,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _stepSize == step ? C.lv : C.lv.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Text(
                                '$step',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _stepSize == step ? FontWeight.w700 : FontWeight.w500,
                                  color: _stepSize == step ? Colors.white : C.lvD,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CounterPanel(
                    label: isKorean ? '코' : 'Stitches',
                    count: counter.stitchCount,
                    targetCount: counter.targetStitchCount,
                    progress: counter.stitchProgress,
                    color: C.lv,
                    onMinus: () => _update(counter, stitchDelta: -_stepSize),
                    onPlus: () => _update(counter, stitchDelta: _stepSize),
                    onLongPressMinus: () => _update(counter, stitchDelta: -_stepSize),
                    onLongPressPlus: () => _update(counter, stitchDelta: _stepSize),
                  ),
                  const SizedBox(height: 12),
                  _CounterPanel(
                    label: isKorean ? '단' : 'Rows',
                    targetUnit: isKorean ? '목표단' : 'target',
                    count: counter.rowCount,
                    targetCount: counter.targetRowCount,
                    progress: counter.rowProgress,
                    color: C.pk,
                    onMinus: () => _update(counter, rowDelta: -_stepSize),
                    onPlus: () => _update(counter, rowDelta: _stepSize),
                    onLongPressMinus: () => _update(counter, rowDelta: -_stepSize),
                    onLongPressPlus: () => _update(counter, rowDelta: _stepSize),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isKorean ? '🔖 최근 마크' : '🔖 Recent marks', style: T.bodyBold),
                      const SizedBox(height: 10),
                      if (counter.marks.isEmpty) Text(isKorean ? '아직 저장한 마크가 없어요.' : 'No saved marks yet.', style: T.caption.copyWith(color: C.mu)),
                      ...counter.marks.reversed.take(3).map((mark) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.bookmark_rounded, color: C.lmD, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isKorean ? '코 ${mark.stitchCount} · 단 ${mark.rowCount}' : 'Stitch ${mark.stitchCount} · Row ${mark.rowCount}', style: T.body),
                                  if (mark.note.isNotEmpty)
                                    Text(mark.note, style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Text(DateFormat('MM/dd HH:mm').format(mark.timestamp), style: T.caption.copyWith(color: C.mu)),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: C.mu, size: 18),
                              padding: EdgeInsets.zero,
                              onSelected: (value) {
                                if (value == 'edit') { _editMark(counter, mark); }
                                else if (value == 'delete') { _deleteMark(counter, mark); }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                                PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                              ],
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _saveMark(counter),
                          child: Text(isKorean ? '현재 위치 저장' : 'Save current mark'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('$e', style: T.body)),
      ),
    );
  }
}

class _StepGuideBanner extends ConsumerWidget {
  final String projectId;
  final String stepId;
  final int rowCount;
  final bool isKorean;

  const _StepGuideBanner({
    required this.projectId,
    required this.stepId,
    required this.rowCount,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepAsync = ref.watch(projectStepByIdProvider((projectId: projectId, stepId: stepId)));

    return stepAsync.when(
      data: (step) {
        if (step == null || step.targetRow == 0) return const SizedBox.shrink();
        final progress = (rowCount / step.targetRow).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, color: C.lmD, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isKorean
                            ? '다음 체크포인트: ${step.targetRow}단'
                            : 'Next checkpoint: ${step.targetRow} rows',
                        style: T.bodyBold.copyWith(color: C.lmD),
                      ),
                    ),
                    Text(
                      '$rowCount / ${step.targetRow}',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: C.lmD.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(C.lmD),
                  ),
                ),
                if (step.name.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(step.name, style: T.caption.copyWith(color: C.mu)),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _CounterPanel extends StatefulWidget {
  final String label;
  final String targetUnit;
  final int count;
  final int targetCount;
  final double progress;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onLongPressMinus;
  final VoidCallback onLongPressPlus;

  const _CounterPanel({
    required this.label,
    required this.count,
    required this.color,
    required this.onMinus,
    required this.onPlus,
    required this.onLongPressMinus,
    required this.onLongPressPlus,
    this.targetUnit = '',
    this.targetCount = 0,
    this.progress = 0.0,
  });

  @override
  State<_CounterPanel> createState() => _CounterPanelState();
}

class _CounterPanelState extends State<_CounterPanel> {
  Timer? _timer;

  void _startLongPress(VoidCallback callback) {
    callback(); // 즉시 1회 실행
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      callback();
    });
  }

  void _stopLongPress() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.label, style: T.sm.copyWith(fontWeight: FontWeight.w700, color: widget.color)),
            if (widget.targetCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                widget.targetUnit.isNotEmpty
                    ? '${widget.count} / ${widget.targetUnit} ${widget.targetCount}'
                    : '${widget.count} / ${widget.targetCount}',
                style: T.caption.copyWith(color: widget.color.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); widget.onMinus(); },
              onLongPressStart: (_) => _startLongPress(() { HapticFeedback.selectionClick(); widget.onLongPressMinus(); }),
              onLongPressEnd: (_) => _stopLongPress(),
              onLongPressCancel: _stopLongPress,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color.withValues(alpha: 0.28)),
                ),
                child: Icon(Icons.remove_rounded, color: widget.color, size: 30),
              ),
            ),
            Text('${widget.count}', style: T.numXL.copyWith(color: widget.color)),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); widget.onPlus(); },
              onLongPressStart: (_) => _startLongPress(() { HapticFeedback.selectionClick(); widget.onLongPressPlus(); }),
              onLongPressEnd: (_) => _stopLongPress(),
              onLongPressCancel: _stopLongPress,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
        if (widget.targetCount > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 6,
              backgroundColor: widget.color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(widget.color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(widget.progress * 100).toStringAsFixed(0)}%',
            style: T.caption.copyWith(color: widget.color.withValues(alpha: 0.7)),
          ),
        ],
      ]),
    );
  }
}

class _CounterPhotoSection extends StatelessWidget {
  final String? localPath;
  final String? networkUrl;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CounterPhotoSection({
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
                    ? Image.file(File(localPath!), width: double.infinity, height: 220, fit: BoxFit.contain)
                    : CachedNetworkImage(
                        imageUrl: networkUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
            icon: Icon(hasPhoto ? Icons.edit_rounded : Icons.add_photo_alternate_outlined, size: 18),
            label: Text(hasPhoto
                ? (isKorean ? '사진 변경' : 'Change photo')
                : (isKorean ? '사진 추가' : 'Add photo')),
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
