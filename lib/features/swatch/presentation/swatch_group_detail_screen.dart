// 이슈 #723 — 스와치 그룹 상세 화면.
//
// 그룹 안에 포함된 스와치 목록 표시.
// AppBar에서 스와치 추가/제거 가능.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/swatch_provider.dart';
import '../data/swatch_group_repository.dart';
import '../domain/swatch_group.dart';
import '../domain/swatch_model.dart';
import 'swatch_detail_screen.dart';
import 'widgets/swatch_list_sections.dart';

class SwatchGroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const SwatchGroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final groupAsync = ref.watch(swatchGroupByIdProvider(groupId));
    final swatchListAsync = ref.watch(swatchListProvider);

    return groupAsync.when(
      loading: () => AppShellScaffold(
        title: isKorean ? '스와치 그룹' : 'Swatch group',
        showBackButton: true,
        body: Center(child: CircularProgressIndicator(color: C.lv)),
      ),
      error: (e, _) => AppShellScaffold(
        title: isKorean ? '스와치 그룹' : 'Swatch group',
        showBackButton: true,
        body: Center(child: Text('$e', style: T.body)),
      ),
      data: (group) {
        if (group == null) {
          return AppShellScaffold(
            title: isKorean ? '스와치 그룹' : 'Swatch group',
            showBackButton: true,
            body: Center(
              child: Text(
                isKorean ? '그룹을 찾을 수 없어요.' : 'Group not found.',
                style: T.body,
              ),
            ),
          );
        }

        final allSwatches = swatchListAsync.valueOrNull ?? [];
        final included = allSwatches
            .where((s) => group.swatchIds.contains(s.id))
            .toList();

        return AppShellScaffold(
          title: group.name,
          subtitle: isKorean
              ? '스와치 ${included.length}개'
              : '${included.length} swatches',
          showBackButton: true,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddSwatchSheet(
                context, ref, isKorean, group, allSwatches),
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
          ),
          body: Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    GlassCard(
                      child: Row(
                        children: [
                          Icon(Icons.notes_rounded, color: C.lvD, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              group.description!,
                              style: T.body.copyWith(color: C.tx2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  MoriBlockShell(
                    label: isKorean ? '그룹 안 스와치' : 'Swatches in group',
                    icon: Icons.texture,
                    accent: C.lvD,
                    child: included.isEmpty
                        ? _EmptyInGroup(
                            isKorean: isKorean,
                            onAdd: () => _showAddSwatchSheet(
                                context, ref, isKorean, group, allSwatches),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < included.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _RemovableSwatchCard(
                                  swatch: included[i],
                                  isKorean: isKorean,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SwatchDetailScreen(
                                          swatchId: included[i].id),
                                    ),
                                  ),
                                  onRemove: () => _removeSwatch(
                                      context, ref, isKorean, group,
                                      included[i].id),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddSwatchSheet(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    SwatchGroup group,
    List<SwatchModel> allSwatches,
  ) {
    final candidates =
        allSwatches.where((s) => !group.swatchIds.contains(s.id)).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(isKorean ? '그룹에 추가할 스와치' : 'Add swatch to group',
                      style: T.h3),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          isKorean
                              ? '추가할 수 있는 스와치가 없어요.'
                              : 'No swatches to add.',
                          style: T.body.copyWith(color: C.mu),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: candidates.length,
                      itemBuilder: (_, i) {
                        final s = candidates[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: () async {
                              Navigator.pop(ctx);
                              try {
                                await runWithMoriLoadingDialog<void>(
                                  context,
                                  message: isKorean
                                      ? '저장하는 중입니다.'
                                      : 'Saving...',
                                  subtitle: isKorean
                                      ? '잠시만 기다려 주세요.'
                                      : 'Please wait a moment.',
                                  task: () async {
                                    await ref
                                        .read(swatchGroupRepositoryProvider)
                                        .addSwatch(group.id, s.id);
                                  },
                                );
                                if (context.mounted) {
                                  showSavedSnackBar(
                                      ScaffoldMessenger.of(context),
                                      message: isKorean
                                          ? '추가됐어요.'
                                          : 'Added.');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showSaveErrorSnackBar(
                                      ScaffoldMessenger.of(context),
                                      message: '$e');
                                }
                              }
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: C.lvL,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.texture,
                                      color: C.lv, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.swatchName.isEmpty
                                            ? (isKorean
                                                ? '이름 없음'
                                                : 'Untitled')
                                            : s.swatchName,
                                        style: T.bodyBold,
                                      ),
                                      if (s.yarnBrandName.isNotEmpty ||
                                          s.yarnName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${s.yarnBrandName} ${s.yarnName}'
                                              .trim(),
                                          style: T.caption.copyWith(
                                              color: C.mu),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.add_circle_outline_rounded,
                                    color: C.lv),
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

  Future<void> _removeSwatch(
    BuildContext context,
    WidgetRef ref,
    bool isKorean,
    SwatchGroup group,
    String swatchId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '그룹에서 제거' : 'Remove from group', style: T.h3),
        content: Text(
          isKorean
              ? '이 스와치를 그룹에서 제거할까요? 스와치 자체는 삭제되지 않아요.'
              : 'Remove this swatch from the group? The swatch itself will not be deleted.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '제거' : 'Remove',
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
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref
              .read(swatchGroupRepositoryProvider)
              .removeSwatch(group.id, swatchId);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '제거됐어요.' : 'Removed.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context),
            message: '$e');
      }
    }
  }
}

class _EmptyInGroup extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onAdd;
  const _EmptyInGroup({required this.isKorean, required this.onAdd});

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
            child: Icon(Icons.texture, color: C.lvD, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isKorean ? '그룹이 비어있어요.' : 'Group is empty.',
            style: T.bodyBold,
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? '아래 버튼으로 스와치를 추가해 보세요.'
                : 'Tap below to add swatches.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
          ),
        ],
      ),
    );
  }
}

class _RemovableSwatchCard extends StatelessWidget {
  final SwatchModel swatch;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RemovableSwatchCard({
    required this.swatch,
    required this.isKorean,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SwatchCard(swatch: swatch, onTap: onTap),
        Positioned(
          right: 6,
          top: 6,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              tooltip: isKorean ? '그룹에서 제거' : 'Remove from group',
              icon: Icon(Icons.close_rounded, color: C.mu, size: 18),
              onPressed: onRemove,
            ),
          ),
        ),
      ],
    );
  }
}
