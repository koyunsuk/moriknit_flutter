// lib/features/blueprint/presentation/step_log_view.dart
//
// 이슈 #687 (Phase C) — 단계로그 통일 view.
//
// 4가지 작성 경로(PDF AI · 도안에디터 자동 · 템플릿 · 직접 편집)가 모두 본
// 위젯을 통해 동일한 UX로 단계로그를 표시·편집한다.
//
// 모드
//  - blueprintId만 : 청사진 모드 (작자가 단계 add/edit/delete)
//  - blueprintId + runId : 인스턴스 모드 (사용자가 체크/사진/메모 기록)

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/step_run_provider.dart';
import '../domain/step_blueprint.dart';
import '../domain/step_blueprint_unit.dart';
import '../domain/step_run_progress.dart';

/// 단계로그 통일 view 위젯.
///
/// - [blueprintId] 만 주어지면 청사진 모드 (작자 권한일 때 단계 추가/편집/삭제 가능).
/// - [runId] 까지 주어지면 인스턴스 모드 (체크박스·사진·메모 기록).
class StepLogView extends ConsumerWidget {
  const StepLogView({
    super.key,
    required this.blueprintId,
    this.runId,
  });

  final String blueprintId;
  final String? runId;

  bool get _isInstanceMode => runId != null && runId!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final blueprintAsync = ref.watch(blueprintByIdProvider(blueprintId));
    final unitsAsync = ref.watch(blueprintUnitsProvider(blueprintId));
    final progressAsync = _isInstanceMode
        ? ref.watch(runProgressProvider(runId!))
        : const AsyncValue<List<StepRunProgress>>.data(<StepRunProgress>[]);

    return blueprintAsync.when(
      loading: () => AsyncLoadingFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(blueprintByIdProvider(blueprintId)),
      ),
      error: (e, _) => AsyncDelayedFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(blueprintByIdProvider(blueprintId)),
      ),
      data: (blueprint) {
        if (blueprint == null) {
          return _EmptyState(isKorean: isKorean);
        }
        final isOwner =
            currentUid != null && blueprint.ownerUid == currentUid;
        // 청사진 모드에서 작자(또는 admin/editor 협업자)만 단계 편집.
        final myRole = blueprint.members[currentUid];
        final canEdit = !_isInstanceMode &&
            (isOwner ||
                myRole == BlueprintMemberRole.admin ||
                myRole == BlueprintMemberRole.editor);

        return unitsAsync.when(
          loading: () => AsyncLoadingFriendly(
            isKorean: isKorean,
            onRetry: () => ref.invalidate(blueprintUnitsProvider(blueprintId)),
          ),
          error: (e, _) => AsyncDelayedFriendly(
            isKorean: isKorean,
            onRetry: () => ref.invalidate(blueprintUnitsProvider(blueprintId)),
          ),
          data: (units) {
            final progress = progressAsync.valueOrNull ??
                const <StepRunProgress>[];
            final progressMap = {for (final p in progress) p.unitId: p};

            if (units.isEmpty && !canEdit) {
              return _EmptyState(isKorean: isKorean);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: units.length + (canEdit ? 1 : 0),
              itemBuilder: (context, idx) {
                if (canEdit && idx == units.length) {
                  return _AddUnitCard(
                    blueprintId: blueprintId,
                    isKorean: isKorean,
                    order: units.length,
                  );
                }
                final unit = units[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StepUnitCard(
                    unit: unit,
                    progress: progressMap[unit.id],
                    isKorean: isKorean,
                    canEdit: canEdit,
                    isInstanceMode: _isInstanceMode,
                    runId: runId,
                    totalUnits: units.length,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── _EmptyState ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isKorean});

  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt_rounded, size: 56, color: C.mu),
            const SizedBox(height: 12),
            Text(
              isKorean ? '아직 단계가 없어요.' : 'No steps yet.',
              style: T.body.copyWith(color: C.tx2),
            ),
            const SizedBox(height: 4),
            Text(
              isKorean
                  ? '+ 버튼으로 첫 단계를 추가해 보세요.'
                  : 'Add your first step with the + button.',
              style: T.sm.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _StepUnitCard ───────────────────────────────────────────────────────────

class _StepUnitCard extends ConsumerStatefulWidget {
  const _StepUnitCard({
    required this.unit,
    required this.progress,
    required this.isKorean,
    required this.canEdit,
    required this.isInstanceMode,
    required this.runId,
    required this.totalUnits,
  });

  final StepBlueprintUnit unit;
  final StepRunProgress? progress;
  final bool isKorean;
  final bool canEdit;
  final bool isInstanceMode;
  final String? runId;
  final int totalUnits;

  @override
  ConsumerState<_StepUnitCard> createState() => _StepUnitCardState();
}

class _StepUnitCardState extends ConsumerState<_StepUnitCard> {
  bool _editingNote = false;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.progress?.note ?? '');
  }

  @override
  void didUpdateWidget(covariant _StepUnitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNote = widget.progress?.note ?? '';
    if (!_editingNote && _noteController.text != newNote) {
      _noteController.text = newNote;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final isDone = widget.progress?.isDone ?? false;
    final images = widget.progress?.progressImages ?? const <ProgressImage>[];

    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? C.lv.withValues(alpha: 0.5)
              : C.bd.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 행: 체크박스(인스턴스 모드) + 순번 + 제목 + 메뉴(작자)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isInstanceMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: isDone,
                        activeColor: C.lv,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => _toggleDone(v ?? false),
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unit.order + 1}',
                    style: T.sm.copyWith(
                      color: C.lvD,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    unit.localizedTitle(widget.isKorean),
                    style: T.bodyBold.copyWith(
                      color: isDone ? C.mu : C.tx,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (widget.canEdit)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: C.mu,
                      size: 20,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _showEditDialog();
                      } else if (v == 'delete') {
                        _confirmDelete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                color: C.lv, size: 18),
                            const SizedBox(width: 10),
                            Text(widget.isKorean ? '수정' : 'Edit',
                                style: T.body),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: C.og, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              widget.isKorean ? '삭제' : 'Delete',
                              style: T.body.copyWith(color: C.og),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // 본문 (instruction)
            if (unit.localizedInstruction(widget.isKorean).trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 6, 12, 0),
                child: Text(
                  unit.localizedInstruction(widget.isKorean),
                  style: T.body.copyWith(color: C.tx2),
                ),
              ),
            // targetRows 표시
            if (unit.targetRows > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 12, 0),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 14, color: C.mu),
                    const SizedBox(width: 4),
                    Text(
                      widget.isKorean
                          ? '목표 ${unit.targetRows}단'
                          : 'Target ${unit.targetRows} rows',
                      style: T.sm.copyWith(color: C.mu),
                    ),
                  ],
                ),
              ),
            // 인스턴스 모드: 사진·메모 영역
            if (widget.isInstanceMode) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _ProgressEditor(
                  images: images,
                  noteController: _noteController,
                  onAddImage: _addImage,
                  onRemoveImage: _removeImage,
                  onNoteFocus: () =>
                      setState(() => _editingNote = true),
                  onNoteSave: _saveNote,
                  isKorean: widget.isKorean,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDone(bool next) async {
    final runId = widget.runId;
    if (runId == null || runId.isEmpty) return;

    // legacy 모드(runId가 'legacy_'로 시작)는 Repository가 쓰기를 막아두었으므로
    // 우선 신규 컬렉션 진입을 안내.
    if (runId.startsWith('legacy_')) {
      _toast(widget.isKorean
          ? '먼저 단계로그를 마이그레이션해 주세요.'
          : 'Please migrate this run first.');
      return;
    }

    final repo = ref.read(stepRunRepositoryProvider);
    final base = widget.progress ??
        StepRunProgress(unitId: widget.unit.id, runId: runId);
    final patch = base.copyWith(
      isDone: next,
      doneAt: next ? DateTime.now() : null,
      targetRow: widget.unit.targetRows,
    );
    try {
      await repo.saveProgress(
        rid: runId,
        progress: patch,
        totalUnits: widget.totalUnits,
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _addImage() async {
    final runId = widget.runId;
    if (runId == null || runId.isEmpty) return;
    if (runId.startsWith('legacy_')) {
      _toast(widget.isKorean
          ? '먼저 단계로그를 마이그레이션해 주세요.'
          : 'Please migrate this run first.');
      return;
    }

    final source = await _showImageSourceDialog();
    if (source == null) return;
    if (!mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return;
      if (!mounted) return;

      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: widget.isKorean
            ? '잠시만 기다려 주세요.'
            : 'Please wait a moment.',
        task: () async {
          final ref0 = FirebaseStorage.instance.ref().child(
                'step_runs/$runId/${widget.unit.id}_'
                '${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
          final UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await picked.readAsBytes();
            uploadTask = ref0.putData(bytes);
          } else {
            uploadTask = ref0.putFile(File(picked.path));
          }
          final snap = await uploadTask;
          final url = await snap.ref.getDownloadURL();

          final base = widget.progress ??
              StepRunProgress(unitId: widget.unit.id, runId: runId);
          final next = base.copyWith(
            progressImages: [
              ...base.progressImages,
              ProgressImage(
                url: url,
                takenAt: DateTime.now(),
                order: base.progressImages.length,
              ),
            ],
            targetRow: widget.unit.targetRows,
          );
          await ref
              .read(stepRunRepositoryProvider)
              .saveProgress(
                rid: runId,
                progress: next,
                totalUnits: widget.totalUnits,
              );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _removeImage(ProgressImage img) async {
    final runId = widget.runId;
    if (runId == null || runId.isEmpty || widget.progress == null) return;
    if (runId.startsWith('legacy_')) return;

    final remaining =
        widget.progress!.progressImages.where((e) => e.url != img.url).toList();
    final next = widget.progress!.copyWith(progressImages: remaining);
    try {
      await ref.read(stepRunRepositoryProvider).saveProgress(
            rid: runId,
            progress: next,
            totalUnits: widget.totalUnits,
          );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _saveNote() async {
    final runId = widget.runId;
    if (runId == null || runId.isEmpty) return;
    if (runId.startsWith('legacy_')) {
      setState(() => _editingNote = false);
      return;
    }
    final base = widget.progress ??
        StepRunProgress(unitId: widget.unit.id, runId: runId);
    final note = _noteController.text.trim();
    final next = base.copyWith(
      note: note.isEmpty ? null : note,
      targetRow: widget.unit.targetRows,
    );
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: widget.isKorean
            ? '잠시만 기다려 주세요.'
            : 'Please wait a moment.',
        task: () async {
          await ref.read(stepRunRepositoryProvider).saveProgress(
                rid: runId,
                progress: next,
                totalUnits: widget.totalUnits,
              );
        },
      );
      if (!mounted) return;
      setState(() => _editingNote = false);
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(
                widget.isKorean ? '갤러리에서 선택' : 'Choose from gallery',
                style: T.body,
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(
                widget.isKorean ? '사진 촬영' : 'Take photo',
                style: T.body,
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final result = await showDialog<_StepUnitDraft>(
      context: context,
      builder: (_) => _StepUnitDialog(
        isKorean: widget.isKorean,
        initial: _StepUnitDraft(
          title: widget.unit.title,
          instruction: widget.unit.instruction,
          targetRows: widget.unit.targetRows,
        ),
      ),
    );
    if (result == null || !mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: widget.isKorean
            ? '잠시만 기다려 주세요.'
            : 'Please wait a moment.',
        task: () async {
          await ref.read(stepBlueprintRepositoryProvider).saveUnit(
                widget.unit.copyWith(
                  title: result.title,
                  instruction: result.instruction,
                  targetRows: result.targetRows,
                ),
              );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(
          widget.isKorean ? '단계 삭제' : 'Delete step',
          style: T.h3,
        ),
        content: Text(
          widget.isKorean
              ? '이 단계를 삭제할까요? 되돌릴 수 없어요.'
              : 'Delete this step? This cannot be undone.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.isKorean ? '삭제' : 'Delete',
              style: TextStyle(color: C.og),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: widget.isKorean
            ? '잠시만 기다려 주세요.'
            : 'Please wait a moment.',
        task: () async {
          await ref
              .read(stepBlueprintRepositoryProvider)
              .deleteUnit(widget.unit.blueprintId, widget.unit.id);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '삭제됐어요.' : 'Deleted.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─── _ProgressEditor (인스턴스 모드 사진·메모 영역) ──────────────────────────

class _ProgressEditor extends StatelessWidget {
  const _ProgressEditor({
    required this.images,
    required this.noteController,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onNoteFocus,
    required this.onNoteSave,
    required this.isKorean,
  });

  final List<ProgressImage> images;
  final TextEditingController noteController;
  final Future<void> Function() onAddImage;
  final Future<void> Function(ProgressImage img) onRemoveImage;
  final VoidCallback onNoteFocus;
  final Future<void> Function() onNoteSave;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사진 행
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              if (i == images.length) {
                return GestureDetector(
                  onTap: onAddImage,
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                      color: C.lvL,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: C.lv.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: C.lv),
                  ),
                );
              }
              final img = images[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      img.url,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 76,
                        height: 76,
                        color: C.bd,
                        child: Icon(Icons.broken_image,
                            color: C.mu),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: IconButton(
                      iconSize: 18,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(),
                      onPressed: () => onRemoveImage(img),
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // 메모
        TextField(
          controller: noteController,
          maxLines: 3,
          minLines: 1,
          onTap: onNoteFocus,
          onEditingComplete: () => onNoteSave(),
          decoration: InputDecoration(
            filled: true,
            fillColor: C.gx,
            isDense: true,
            hintText: isKorean ? '메모 (자동 저장 안 됨, 완료 후 탭)' : 'Note',
            labelText: isKorean ? '메모' : 'Note',
            suffixIcon: IconButton(
              icon: Icon(Icons.check_rounded, color: C.lv),
              onPressed: onNoteSave,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── _AddUnitCard ────────────────────────────────────────────────────────────

class _AddUnitCard extends ConsumerWidget {
  const _AddUnitCard({
    required this.blueprintId,
    required this.isKorean,
    required this.order,
  });

  final String blueprintId;
  final bool isKorean;
  final int order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDialog(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: C.gx,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: C.lv.withValues(alpha: 0.4),
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: C.lv, size: 22),
              const SizedBox(width: 6),
              Text(
                isKorean ? '단계 추가' : 'Add step',
                style: T.bodyBold.copyWith(color: C.lvD),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_StepUnitDraft>(
      context: context,
      builder: (_) => _StepUnitDialog(
        isKorean: isKorean,
        initial: const _StepUnitDraft(),
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle:
            isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(stepBlueprintRepositoryProvider);
          final now = DateTime.now();
          await repo.saveUnit(
            StepBlueprintUnit(
              id: '',
              blueprintId: blueprintId,
              order: order,
              title: result.title,
              instruction: result.instruction,
              targetRows: result.targetRows,
              createdAt: now,
            ),
          );
          await repo.update(blueprintId, {
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
      );
      if (!context.mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }
}

// ─── _StepUnitDialog ─────────────────────────────────────────────────────────

class _StepUnitDraft {
  final String title;
  final String instruction;
  final int targetRows;

  const _StepUnitDraft({
    this.title = '',
    this.instruction = '',
    this.targetRows = 0,
  });
}

class _StepUnitDialog extends StatefulWidget {
  const _StepUnitDialog({
    required this.isKorean,
    required this.initial,
  });

  final bool isKorean;
  final _StepUnitDraft initial;

  @override
  State<_StepUnitDialog> createState() => _StepUnitDialogState();
}

class _StepUnitDialogState extends State<_StepUnitDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _instructionCtrl;
  late TextEditingController _targetCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial.title);
    _instructionCtrl =
        TextEditingController(text: widget.initial.instruction);
    _targetCtrl = TextEditingController(
      text: widget.initial.targetRows > 0
          ? widget.initial.targetRows.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ko = widget.isKorean;
    return AlertDialog(
      backgroundColor: C.bg,
      title: Text(ko ? '단계 편집' : 'Step', style: T.h3),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(title: ko ? '제목' : 'Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: ko ? '예: 본판 시작' : 'e.g. Start body',
                labelText: ko ? '제목' : 'Title',
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(title: ko ? '설명' : 'Instruction'),
            const SizedBox(height: 6),
            TextField(
              controller: _instructionCtrl,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: ko
                    ? '단계에 필요한 안내를 입력해 주세요.'
                    : 'Describe this step.',
                labelText: ko ? '설명' : 'Instruction',
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(title: ko ? '목표 단수' : 'Target rows'),
            const SizedBox(height: 6),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: '0',
                labelText: ko ? '목표 단수' : 'Target rows',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ko ? '취소' : 'Cancel'),
        ),
        TextButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ko ? '제목을 입력해 주세요.' : 'Please enter a title.',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _StepUnitDraft(
                title: title,
                instruction: _instructionCtrl.text.trim(),
                targetRows: int.tryParse(_targetCtrl.text.trim()) ?? 0,
              ),
            );
          },
          child: Text(ko ? '저장' : 'Save'),
        ),
      ],
    );
  }
}
