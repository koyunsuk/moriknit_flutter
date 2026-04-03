import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../features/project/domain/project_model.dart';
import '../domain/counter_model.dart';

class CounterListScreen extends ConsumerWidget {
  const CounterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counterListAsync = ref.watch(counterListProvider);
    final projectListAsync = ref.watch(projectListProvider);
    final projects = projectListAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '카운터' : 'Counters',
                subtitle: isKorean ? '코·단 카운터 관리' : 'Manage stitch & row counters',
              ),
            ),
            Expanded(
              child: counterListAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lmD)),
                error: (e, _) => Center(child: Text('$e', style: T.body)),
                data: (counters) {
                  if (counters.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: C.lmD.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isKorean ? '카운터가 없어요.' : 'No counters yet.',
                              style: T.bodyBold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isKorean ? '새 카운터를 만들어 코와 단을 기록해보세요.' : 'Create a counter to track stitches and rows.',
                              style: T.caption.copyWith(color: C.mu),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showCounterStartSheet(context, ref, isKorean, projects),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(isKorean ? '카운터 만들기' : 'Create counter'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      const BgOrbs(),
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: counters.length + 1,
                        separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 14) : const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return GlassCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isKorean ? '내 카운터 ${counters.length}개' : '${counters.length} Counters',
                                          style: T.bodyBold.copyWith(color: C.lmD),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isKorean ? '코·단 카운터 목록' : 'Stitch & row counters',
                                          style: T.caption.copyWith(color: C.mu),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showCounterStartSheet(context, ref, isKorean, projects),
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(isKorean ? '카운터 추가' : 'Add counter'),
                                  ),
                                ],
                              ),
                            );
                          }
                          final counter = counters[index - 1];
                          final linkedProject = counter.projectId.isNotEmpty
                              ? projects.where((p) => p.id == counter.projectId).firstOrNull
                              : null;
                          return _CounterListCard(
                            counter: counter,
                            isKorean: isKorean,
                            projectName: linkedProject?.title,
                            onTap: () => context.push('/counter/${counter.id}'),
                            onEdit: () => _showRenameDialog(context, ref, counter, isKorean),
                            onDelete: () => _confirmDelete(context, ref, counter.id, isKorean),
                            onDuplicate: () => _confirmDuplicate(context, ref, counter, isKorean),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateCounterDialog(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    List<ProjectModel> projects,
  ) async {
    final nameCtrl = TextEditingController();
    final targetStitchCtrl = TextEditingController();
    final targetRowCtrl = TextEditingController();
    String? selectedProjectId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isKorean ? '새 카운터' : 'New counter', style: T.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: isKorean ? '카운터 이름' : 'Counter name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetStitchCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '목표 코수 (선택)' : 'Target stitches (optional)',
                    hintText: '0',
                    suffixText: isKorean ? '코' : 'sts',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetRowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '목표 단수 (선택)' : 'Target rows (optional)',
                    hintText: '0',
                    suffixText: isKorean ? '단' : 'rows',
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    isKorean ? '프로젝트 연결 (선택)' : 'Link project (optional)',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: C.mu.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String?>(
                      value: selectedProjectId,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: Text(isKorean ? '연결 안 함' : 'No project', style: T.body.copyWith(color: C.mu)),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(isKorean ? '연결 안 함' : 'No project', style: T.body),
                        ),
                        ...projects.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.title, style: T.body, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => selectedProjectId = val),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isKorean ? '취소' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final authUser = ref.read(authStateProvider).valueOrNull;
                final name = nameCtrl.text.trim();
                if (authUser == null || name.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                final targetStitch = int.tryParse(targetStitchCtrl.text.trim()) ?? 0;
                final targetRow = int.tryParse(targetRowCtrl.text.trim()) ?? 0;
                final counter = CounterModel.empty(uid: authUser.uid, name: name).copyWith(
                  projectId: selectedProjectId ?? '',
                  targetStitchCount: targetStitch,
                  targetRowCount: targetRow,
                );
                CounterModel? saved;
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                    task: () async {
                      saved = await ref.read(counterRepositoryProvider).createCounter(counter);
                    },
                  );
                }
                if (context.mounted && saved != null) context.push('/counter/${saved!.id}');
              },
              child: Text(isKorean ? '만들기' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    CounterModel counter,
    bool isKorean,
  ) async {
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
    if (confirm == true && newName.isNotEmpty && context.mounted) {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        task: () => ref.read(counterRepositoryProvider).updateCounter(counter.copyWith(name: newName)),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String counterId, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '카운터 삭제' : 'Delete counter', style: T.h3),
        content: Text(isKorean ? '이 카운터를 삭제할까요? 되돌릴 수 없어요.' : 'Delete this counter? This cannot be undone.', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        task: () => ref.read(counterRepositoryProvider).deleteCounter(counterId),
      );
    }
  }

  Future<void> _confirmDuplicate(
    BuildContext context,
    WidgetRef ref,
    CounterModel counter,
    bool isKorean,
  ) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(counterRepositoryProvider).duplicateCounter(counter);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '복사됐어요.' : 'Duplicated.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  void _showCounterStartSheet(BuildContext context, WidgetRef ref, bool isKorean, List<ProjectModel> projects) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        maxChildSize: 0.6,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [Text(isKorean ? '카운터 추가' : 'Add counter', style: T.h3)]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateCounterDialog(context, ref, isKorean, projects);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '새 카운터 만들기' : 'Create new counter', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '이름과 목표를 직접 설정해요' : 'Set name and target manually', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopyCounterSheet(context, ref, isKorean);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.lmD)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 카운터 복사로 시작' : 'Copy existing counter', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 카운터를 복사해서 시작해요' : 'Duplicate an existing counter', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
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

  void _showCopyCounterSheet(BuildContext context, WidgetRef ref, bool isKorean) {
    final counters = ref.read(counterListProvider).valueOrNull ?? [];
    if (counters.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 카운터가 없어요.' : 'No counters to copy.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 카운터 선택' : 'Select counter to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: counters.length,
                itemBuilder: (_, i) {
                  final c = counters[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await runWithMoriLoadingDialog<void>(
                            context,
                            message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                            task: () => ref.read(counterRepositoryProvider).duplicateCounter(c),
                          );
                          if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
                        } catch (e) {
                          if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: T.bodyBold),
                            Text(isKorean ? '코 ${c.stitchCount} · 단 ${c.rowCount}' : 'Sts ${c.stitchCount} · Rows ${c.rowCount}', style: T.caption.copyWith(color: C.mu)),
                          ])),
                          Icon(Icons.copy_rounded, color: C.mu, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterListCard extends StatelessWidget {
  final CounterModel counter;
  final bool isKorean;
  final String? projectName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _CounterListCard({
    required this.counter,
    required this.isKorean,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: C.lmD.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counter.name, style: T.bodyBold),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _CountBadge(
                      label: isKorean ? '코' : 'Sts',
                      value: counter.stitchCount,
                      color: C.lv,
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(
                      label: isKorean ? '단' : 'Rows',
                      value: counter.rowCount,
                      color: C.pk,
                    ),
                  ],
                ),
                if (projectName != null && projectName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ProjectBadge(name: projectName!),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'duplicate') onDuplicate();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit_rounded, color: C.mu, size: 18), const SizedBox(width: 8), Text(isKorean ? '이름 변경' : 'Rename')]),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(children: [Icon(Icons.copy_rounded, color: C.lmD, size: 18), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline, color: C.og, size: 18), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))]),
              ),
            ],
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _ProjectBadge extends StatelessWidget {
  final String name;
  const _ProjectBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: C.lmD.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.lmD.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, color: C.lmD, size: 12),
          const SizedBox(width: 4),
          Text(
            name,
            style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        '$label $value',
        style: T.caption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
