// 이슈 #723 — 스와치 그룹 요약 화면.
//
// counter_group_screen.dart 와 유사한 블록 패턴 B (블록 안에 콘텐츠).
// 사용자가 직접 그룹 만들기 가능 (FAB).
// 카드 탭 → SwatchGroupDetailScreen 으로 이동.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/swatch_provider.dart';
import '../data/swatch_group_repository.dart';
import '../domain/swatch_group.dart';

class SwatchGroupScreen extends ConsumerWidget {
  const SwatchGroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final groupListAsync = ref.watch(swatchGroupListProvider);
    final swatchListAsync = ref.watch(swatchListProvider);

    return AppShellScaffold(
      title: isKorean ? '스와치 그룹' : 'Swatch groups',
      subtitle: isKorean ? '나만의 스와치 묶음' : 'My swatch collections',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref, isKorean),
        backgroundColor: C.lv,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isKorean ? '새 그룹' : 'New group'),
      ),
      body: groupListAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('$e', style: T.body)),
        data: (groups) {
          final swatches = swatchListAsync.valueOrNull ?? [];
          final totalGrouped =
              groups.fold<int>(0, (sum, g) => sum + g.swatchIds.length);

          return Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // 요약카드
                  SummaryCard_Detail(
                    headers: [
                      isKorean ? '그룹' : 'Groups',
                      isKorean ? '묶인 스와치' : 'Grouped',
                      isKorean ? '전체 스와치' : 'Total',
                    ],
                    rows: [
                      LibrarySummaryRowData(
                        badge: isKorean ? '그룹' : 'Group',
                        badgeColor: C.lv,
                        values: [
                          '${groups.length}',
                          '$totalGrouped',
                          '${swatches.length}',
                        ],
                        valueColors: [C.tx, C.lv, C.mu],
                      ),
                    ],
                    addLabel: isKorean ? '추가' : 'Add',
                    onAdd: () =>
                        _showCreateGroupDialog(context, ref, isKorean),
                  ),
                  const SizedBox(height: 8),
                  // 블록 안에 그룹 카드 목록
                  MoriBlockShell(
                    label: isKorean ? '내 스와치 그룹' : 'My swatch groups',
                    icon: Icons.folder_rounded,
                    accent: C.lvD,
                    child: groups.isEmpty
                        ? _EmptyState(isKorean: isKorean)
                        : Column(
                            children: [
                              // 헤더 카운트 배지
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: C.lv.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${groups.length}',
                                      style: T.caption.copyWith(
                                        color: C.lvD,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (int i = 0; i < groups.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _NumberedItem(
                                  number: i + 1,
                                  child: _SwatchGroupCard(
                                    group: groups[i],
                                    isKorean: isKorean,
                                    onTap: () => context.push(
                                        '/swatch/groups/${groups[i].id}'),
                                    onMore: () => _showGroupActionsSheet(
                                      context,
                                      ref,
                                      isKorean,
                                      groups[i],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateGroupDialog(
      BuildContext context, WidgetRef ref, bool isKorean) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '새 스와치 그룹' : 'New swatch group', style: T.h3),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isKorean ? '그룹 이름' : 'Group name',
                  hintText: isKorean ? '예: 면사 모음, 가을 작업' : 'e.g. Cotton yarns',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isKorean ? '설명 (선택)' : 'Description (optional)',
                ),
              ),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final desc = descCtrl.text.trim();
              final group = SwatchGroup.empty(name: name).copyWith(
                description: desc.isEmpty ? null : desc,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                try {
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                    subtitle: isKorean
                        ? '잠시만 기다려 주세요.'
                        : 'Please wait a moment.',
                    task: () async {
                      await ref
                          .read(swatchGroupRepositoryProvider)
                          .createGroup(group);
                    },
                  );
                  if (context.mounted) {
                    showSavedSnackBar(ScaffoldMessenger.of(context),
                        message: isKorean ? '저장됐어요.' : 'Saved.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSaveErrorSnackBar(ScaffoldMessenger.of(context),
                        message: '$e');
                  }
                }
              }
            },
            child: Text(isKorean ? '만들기' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _showGroupActionsSheet(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    SwatchGroup group,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: C.tx),
              title: Text(isKorean ? '이름 수정' : 'Rename',
                  style: T.body),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameGroupDialog(context, ref, isKorean, group);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: C.og),
              title: Text(isKorean ? '삭제' : 'Delete',
                  style: T.body.copyWith(color: C.og)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteGroup(context, ref, isKorean, group);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameGroupDialog(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    SwatchGroup group,
  ) async {
    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '그룹 수정' : 'Edit group', style: T.h3),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isKorean ? '그룹 이름' : 'Group name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isKorean ? '설명' : 'Description',
                ),
              ),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final desc = descCtrl.text.trim();
              final updated = group.copyWith(
                name: name,
                description: desc.isEmpty ? null : desc,
                updatedAt: DateTime.now(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                try {
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                    subtitle: isKorean
                        ? '잠시만 기다려 주세요.'
                        : 'Please wait a moment.',
                    task: () async {
                      await ref
                          .read(swatchGroupRepositoryProvider)
                          .updateGroup(updated);
                    },
                  );
                  if (context.mounted) {
                    showSavedSnackBar(ScaffoldMessenger.of(context),
                        message: isKorean ? '저장됐어요.' : 'Saved.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSaveErrorSnackBar(ScaffoldMessenger.of(context),
                        message: '$e');
                  }
                }
              }
            },
            child: Text(isKorean ? '저장' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    SwatchGroup group,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '그룹 삭제' : 'Delete group', style: T.h3),
        content: Text(
          isKorean
              ? '"${group.name}" 그룹을 삭제할까요? 그룹 안의 스와치는 삭제되지 않아요.'
              : 'Delete "${group.name}"? Swatches inside the group will not be deleted.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete',
                style: TextStyle(color: C.og)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref
              .read(swatchGroupRepositoryProvider)
              .deleteGroup(group.id);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '삭제됐어요.' : 'Deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context),
            message: '$e');
      }
    }
  }
}

// ── 빈 상태 위젯 ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isKorean;
  const _EmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.folder_open_rounded, color: C.lvD, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isKorean ? '아직 그룹이 없어요.' : 'No groups yet.',
            style: T.bodyBold,
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? '하단 + 버튼으로 첫 그룹을 만들어 보세요.'
                : 'Tap + to create your first group.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 그룹 카드 ───────────────────────────────────────────────
class _SwatchGroupCard extends StatelessWidget {
  final SwatchGroup group;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _SwatchGroupCard({
    required this.group,
    required this.isKorean,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.lv.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.folder_rounded, color: C.lvD, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: T.bodyBold),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: C.lv.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        isKorean
                            ? '스와치 ${group.swatchIds.length}'
                            : '${group.swatchIds.length} swatches',
                        style: T.caption.copyWith(
                            color: C.lvD, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (group.updatedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(group.updatedAt!, isKorean),
                        style: T.caption.copyWith(color: C.mu),
                      ),
                    ],
                  ],
                ),
                if (group.description != null &&
                    group.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    group.description!,
                    style: T.caption.copyWith(color: C.tx2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: C.mu),
            onPressed: onMore,
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }

  String _formatDate(DateTime d, bool isKorean) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return isKorean ? '오늘' : 'Today';
    if (diff.inDays == 1) return isKorean ? '어제' : 'Yesterday';
    if (diff.inDays < 7) {
      return isKorean ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
    }
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

// ── 번호 표시 래퍼 ──────────────────────────────────────────
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
              style: TextStyle(
                  fontSize: 10, color: C.mu, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
