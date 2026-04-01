import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_step_provider.dart';
import '../domain/counter_model.dart';

class CounterScreen extends ConsumerStatefulWidget {
  final String counterId;
  const CounterScreen({super.key, required this.counterId});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends ConsumerState<CounterScreen> {
  int _stepSize = 1;

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
            onPressed: () { noteCtrl.dispose(); Navigator.pop(ctx, false); },
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
    noteCtrl.dispose();
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
            onPressed: () { noteCtrl.dispose(); Navigator.pop(ctx); },
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () { final v = noteCtrl.text.trim(); noteCtrl.dispose(); Navigator.pop(ctx, v); },
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

  Future<void> _showTargetDialog(CounterModel counter, bool isKorean) async {
    final stitchCtrl = TextEditingController(text: counter.targetStitchCount > 0 ? '${counter.targetStitchCount}' : '');
    final rowCtrl = TextEditingController(text: counter.targetRowCount > 0 ? '${counter.targetRowCount}' : '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '목표 설정' : 'Set targets', style: T.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stitchCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isKorean ? '목표 코수 (선택)' : 'Target stitches (optional)',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rowCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isKorean ? '목표 단수 (선택)' : 'Target rows (optional)',
                hintText: '0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isKorean ? '저장' : 'Save')),
        ],
      ),
    );
    final newStitch = int.tryParse(stitchCtrl.text.trim()) ?? 0;
    final newRow = int.tryParse(rowCtrl.text.trim()) ?? 0;
    stitchCtrl.dispose();
    rowCtrl.dispose();
    if (confirm == true && mounted) {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(counterRepositoryProvider).updateTargets(
          counter.id,
          targetStitchCount: newStitch,
          targetRowCount: newRow,
        ),
      );
      if (mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '저장됐어요.' : 'Saved.');
      }
    }
  }

  Future<void> _showRenameDialog(CounterModel counter, bool isKorean) async {
    final nameCtrl = TextEditingController(text: counter.name);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '이름 변경' : 'Rename counter', style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isKorean ? '카운터 이름' : 'Counter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '저장' : 'Save'),
          ),
        ],
      ),
    );
    final newName = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (confirm == true && newName.isNotEmpty && mounted) {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        task: () => ref.read(counterRepositoryProvider).updateCounter(counter.copyWith(name: newName)),
      );
    }
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
              await ref.read(counterRepositoryProvider).deleteCounter(widget.counterId);
              if (mounted) Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: C.mu),
            onSelected: (value) {
              final counter = counterAsync.valueOrNull;
              if (counter == null) return;
              if (value == 'rename') {
                _showRenameDialog(counter, isKorean);
              } else if (value == 'copy') {
                _duplicateCounter(counter, isKorean);
              } else if (value == 'target') {
                _showTargetDialog(counter, isKorean);
              } else if (value == 'delete') {
                _confirmDelete(isKorean);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: C.mu, size: 18),
                    const SizedBox(width: 10),
                    Text(isKorean ? '이름 변경' : 'Rename', style: T.body),
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
                value: 'target',
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, color: C.lmD, size: 18),
                    const SizedBox(width: 10),
                    Text(isKorean ? '목표단수 설정' : 'Set target rows', style: T.body),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: C.og, size: 18),
                    const SizedBox(width: 10),
                    Text(isKorean ? '삭제' : 'Delete', style: T.body.copyWith(color: C.og)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: counterAsync.when(
        data: (counter) {
          if (counter == null) {
            return Center(child: Text(isKorean ? '카운터를 찾을 수 없어요.' : 'Counter not found.', style: T.body));
          }
          return Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
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
                      Text(isKorean ? '최근 마크' : 'Recent marks', style: T.bodyBold),
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
