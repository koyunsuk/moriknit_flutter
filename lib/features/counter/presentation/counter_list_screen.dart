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

enum _CounterSort { recent, oldest }

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

                  bool isCounterDone(CounterModel c) {
                    if (c.hasTargets && c.stitchProgress >= 1.0 && c.rowProgress >= 1.0) return true;
                    if (c.projectId.isNotEmpty) {
                      final proj = projects.where((p) => p.id == c.projectId).firstOrNull;
                      if (proj != null && proj.status == 'finished') return true;
                    }
                    return false;
                  }
                  final done = counters.where(isCounterDone).length;
                  final inProgress = counters.where((c) => !isCounterDone(c) && (c.hasTargets || c.projectId.isNotEmpty)).length;
                  final unset = counters.where((c) => !isCounterDone(c) && !c.hasTargets && c.projectId.isEmpty).length;

                  return Stack(
                    children: [
                      const BgOrbs(),
                      Positioned.fill(
                        child: _SortableCounterList(
                          counters: counters,
                          projects: projects,
                          isKorean: isKorean,
                          done: done,
                          inProgress: inProgress,
                          unset: unset,
                          isCounterDone: isCounterDone,
                          onAdd: () => _showCounterStartSheet(context, ref, isKorean, projects),
                          onTap: (id) => context.push('/counter/$id'),
                        ),
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

// ── 정렬 가능한 카운터 목록 ─────────────────────────────────────────
class _SortableCounterList extends StatefulWidget {
  final List<CounterModel> counters;
  final List<ProjectModel> projects;
  final bool isKorean;
  final int done;
  final int inProgress;
  final int unset;
  final bool Function(CounterModel) isCounterDone;
  final VoidCallback onAdd;
  final void Function(String id) onTap;

  const _SortableCounterList({
    required this.counters,
    required this.projects,
    required this.isKorean,
    required this.done,
    required this.inProgress,
    required this.unset,
    required this.isCounterDone,
    required this.onAdd,
    required this.onTap,
  });

  @override
  State<_SortableCounterList> createState() => _SortableCounterListState();
}

class _SortableCounterListState extends State<_SortableCounterList> {
  _CounterSort _sortMode = _CounterSort.recent;

  List<CounterModel> _sorted(List<CounterModel> counters) {
    final list = [...counters];
    switch (_sortMode) {
      case _CounterSort.recent:
        list.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      case _CounterSort.oldest:
        list.sort((a, b) => (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted(widget.counters);
    final isKorean = widget.isKorean;
    return Column(
      children: [
        // 요약카드 고정
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: LibrarySummaryCard(
            headers: [
              isKorean ? '전체' : 'Total',
              isKorean ? '진행' : 'Active',
              isKorean ? '완료' : 'Done',
            ],
            rows: [
              LibrarySummaryRowData(
                badge: isKorean ? '카운터' : 'Counter',
                badgeColor: C.lmD,
                values: ['${widget.counters.length}', '${widget.inProgress}', '${widget.done}'],
                valueColors: [C.tx, C.lv, C.pkD],
              ),
            ],
            addLabel: isKorean ? '추가' : 'Add',
            onAdd: widget.onAdd,
          ),
        ),
        // 스크롤 목록
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 8) : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _LibrarySectionHeader(
                  title: isKorean ? '카운터 목록' : 'Counters',
                  total: widget.counters.length,
                  sortLabels: isKorean ? ['최근순', '오래된순'] : ['Recent', 'Oldest'],
                  selectedIndex: _CounterSort.values.indexOf(_sortMode),
                  onSort: (i) => setState(() => _sortMode = _CounterSort.values[i]),
                );
              }
              final counter = sorted[index - 1];
              final linked = counter.projectId.isNotEmpty
                  ? widget.projects.where((p) => p.id == counter.projectId).firstOrNull
                  : null;
              return _NumberedItem(
                number: index,
                child: _CounterListCard(
                  counter: counter,
                  isKorean: isKorean,
                  projectName: linked?.title,
                  onTap: () => widget.onTap(counter.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 섹션 헤더 ─────────────────────────────────────────────────────────
class _LibrarySectionHeader extends StatelessWidget {
  final String title;
  final int total;
  final List<String> sortLabels;
  final int selectedIndex;
  final ValueChanged<int> onSort;

  const _LibrarySectionHeader({
    required this.title,
    required this.total,
    required this.sortLabels,
    required this.selectedIndex,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(title, style: T.bodyBold),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: C.lmD.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$total', style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          PopupMenuButton<int>(
            onSelected: onSort,
            color: C.bg,
            offset: const Offset(0, 32),
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 16, color: C.mu),
                const SizedBox(width: 2),
                Text(sortLabels[selectedIndex], style: T.caption.copyWith(color: C.mu)),
              ],
            ),
            itemBuilder: (ctx) => sortLabels
                .asMap()
                .entries
                .map((e) => PopupMenuItem<int>(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: T.body.copyWith(
                          color: e.key == selectedIndex ? C.lmD : C.tx,
                          fontWeight: e.key == selectedIndex ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── 번호 표시 래퍼 ────────────────────────────────────────────────────
class _NumberedItem extends StatelessWidget {
  final int number;
  final Widget child;

  const _NumberedItem({required this.number, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: C.bd2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$number',
              style: TextStyle(fontSize: 10, color: C.mu, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 카운터 목록 카드 ───────────────────────────────────────────────────
class _CounterListCard extends StatelessWidget {
  final CounterModel counter;
  final bool isKorean;
  final String? projectName;
  final VoidCallback onTap;

  const _CounterListCard({
    required this.counter,
    required this.isKorean,
    required this.onTap,
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
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: C.lmD,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${counter.rowCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
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
