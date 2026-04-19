import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/ravelry_repository.dart';

// 라벨리 프로젝트 상태 목록
const _kStatusTypes = [
  (id: 1, ko: '진행 중', en: 'In Progress'),
  (id: 2, ko: '일시정지', en: 'Hibernating'),
  (id: 3, ko: '완성', en: 'Finished'),
  (id: 4, ko: '해체함', en: 'Frogged'),
];

/// 프로젝트 생성 시트 (pattern detail에서 호출)
Future<void> showRavelryProjectEditSheet(
  BuildContext context,
  WidgetRef ref, {
  int? patternId,
  String? patternName,
  required bool isKorean,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectCreateSheet(
      ref: ref,
      patternId: patternId,
      patternName: patternName,
      isKorean: isKorean,
    ),
  );
}

/// 프로젝트 수정 시트 (project detail에서 호출)
Future<void> showRavelryProjectUpdateSheet(
  BuildContext context,
  WidgetRef ref, {
  required int projectId,
  required String projectName,
  int? statusTypeId,
  String? notes,
  required bool isKorean,
  VoidCallback? onUpdated,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectUpdateSheet(
      ref: ref,
      projectId: projectId,
      projectName: projectName,
      statusTypeId: statusTypeId,
      notes: notes,
      isKorean: isKorean,
      onUpdated: onUpdated,
    ),
  );
}

// ── 프로젝트 생성 시트 ─────────────────────────────────────────────────────────
class _ProjectCreateSheet extends StatefulWidget {
  const _ProjectCreateSheet({
    required this.ref,
    this.patternId,
    this.patternName,
    required this.isKorean,
  });
  final WidgetRef ref;
  final int? patternId;
  final String? patternName;
  final bool isKorean;

  @override
  State<_ProjectCreateSheet> createState() => _ProjectCreateSheetState();
}

class _ProjectCreateSheetState extends State<_ProjectCreateSheet> {
  late final TextEditingController _nameCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  int _statusTypeId = 1;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.patternName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isKorean = widget.isKorean;
    final repo = widget.ref.read(ravelryRepositoryProvider);
    if (repo == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '프로젝트 이름을 입력해 주세요.' : 'Enter a project name.')),
      );
      return;
    }
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.createProject(
          name: name,
          patternId: widget.patternId,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          statusTypeId: _statusTypeId,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '라벨리에 프로젝트가 생성됐어요.' : 'Project created on Ravelry.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(isKorean ? '라벨리 프로젝트 시작' : 'Start Ravelry Project', style: T.h3),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: isKorean ? '프로젝트 이름' : 'Project name',
                hintText: isKorean ? '예: 케이블 스웨터' : 'e.g. Cable Sweater',
                filled: true,
                fillColor: C.gx,
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle(title: isKorean ? '상태' : 'Status'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kStatusTypes.map((s) {
                final selected = _statusTypeId == s.id;
                return GestureDetector(
                  onTap: () => setState(() => _statusTypeId = s.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? C.lv : C.lvL,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      isKorean ? s.ko : s.en,
                      style: T.caption.copyWith(
                        color: selected ? Colors.white : C.lvD,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isKorean ? '메모 (선택)' : 'Notes (optional)',
                filled: true,
                fillColor: C.gx,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(isKorean ? '프로젝트 생성' : 'Create Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 프로젝트 수정 시트 ─────────────────────────────────────────────────────────
class _ProjectUpdateSheet extends StatefulWidget {
  const _ProjectUpdateSheet({
    required this.ref,
    required this.projectId,
    required this.projectName,
    this.statusTypeId,
    this.notes,
    required this.isKorean,
    this.onUpdated,
  });
  final WidgetRef ref;
  final int projectId;
  final String projectName;
  final int? statusTypeId;
  final String? notes;
  final bool isKorean;
  final VoidCallback? onUpdated;

  @override
  State<_ProjectUpdateSheet> createState() => _ProjectUpdateSheetState();
}

class _ProjectUpdateSheetState extends State<_ProjectUpdateSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late int _statusTypeId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.projectName);
    _notesCtrl = TextEditingController(text: widget.notes ?? '');
    _statusTypeId = widget.statusTypeId ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isKorean = widget.isKorean;
    final repo = widget.ref.read(ravelryRepositoryProvider);
    if (repo == null) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.updateProject(
          projectId: widget.projectId,
          name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          statusTypeId: _statusTypeId,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onUpdated?.call();
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '라벨리 프로젝트가 수정됐어요.' : 'Project updated on Ravelry.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(isKorean ? '프로젝트 수정' : 'Edit Project', style: T.h3),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: isKorean ? '프로젝트 이름' : 'Project name',
                filled: true,
                fillColor: C.gx,
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle(title: isKorean ? '상태' : 'Status'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kStatusTypes.map((s) {
                final selected = _statusTypeId == s.id;
                return GestureDetector(
                  onTap: () => setState(() => _statusTypeId = s.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? C.lv : C.lvL,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      isKorean ? s.ko : s.en,
                      style: T.caption.copyWith(
                        color: selected ? Colors.white : C.lvD,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isKorean ? '메모 (선택)' : 'Notes (optional)',
                filled: true,
                fillColor: C.gx,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(isKorean ? '저장' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
