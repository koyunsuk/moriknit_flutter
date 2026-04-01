import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';

class PatternListScreen extends ConsumerWidget {
  const PatternListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final patternsAsync = ref.watch(patternListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '도안 에디터' : 'Pattern Editor',
                subtitle: isKorean ? '나만의 뜨개 도안을 만들어요' : 'Create your own knitting charts',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  GlassCard(
                    child: patternsAsync.when(
                      loading: () => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(color: C.lv),
                        ),
                      ),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                      data: (patterns) {
                        if (patterns.isEmpty) {
                          return MoriEmptyState(
                            icon: Icons.grid_on_rounded,
                            iconColor: C.lvD,
                            title: isKorean ? '아직 도안이 없어요' : 'No patterns yet',
                            subtitle: isKorean ? '나만의 도안을 만들어보세요.' : 'Create your own pattern.',
                            buttonLabel: isKorean ? '새 도안 만들기' : 'Create new',
                            onAction: () => _showPatternStartSheet(context, ref),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isKorean ? '내 도안 ${patterns.length}개' : '${patterns.length} patterns',
                                    style: T.bodyBold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showPatternStartSheet(context, ref),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                  label: Text(isKorean ? '새 도안' : 'New pattern'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...patterns.map((p) => _PatternRow(
                              chart: p,
                              isKorean: isKorean,
                              onTap: () => context.push('${Routes.toolsPattern}/${p.id}'),
                              onDelete: () => _confirmDelete(context, ref, p, isKorean),
                              onDuplicate: () => _confirmDuplicate(context, ref, p, isKorean),
                            )),
                          ],
                        );
                      },
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

  Future<void> _confirmDuplicate(BuildContext context, WidgetRef ref, PatternChart chart, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(patternRepositoryProvider).duplicate(chart),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _showPatternStartSheet(BuildContext context, WidgetRef ref) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final scrollCtrl = ScrollController();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: ListView(
            controller: scrollCtrl,
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: C.bd2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(isKorean ? '도안 만들기' : 'Create Pattern', style: T.h3),
              const SizedBox(height: 16),
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(Routes.toolsPattern);
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.photo_library_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? '사진에서 만들기' : 'From photo',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? '갤러리나 카메라로 사진을 찍어요' : 'Take or pick a photo',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  showSavedSnackBar(
                    context,
                    message: isKorean ? '준비 중이에요.' : 'Coming soon.',
                  );
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.og.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: C.og),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? 'PDF에서 만들기' : 'From PDF',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? 'PDF 파일에서 도안을 가져와요' : 'Import pattern from PDF',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PatternChart chart, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '도안 삭제' : 'Delete pattern', style: T.h3),
        content: Text(
          isKorean ? '"${chart.title}" 도안을 삭제할까요?' : 'Delete "${chart.title}"?',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () async {
            await ref.read(patternRepositoryProvider).delete(chart.id);
          },
        );
        if (context.mounted) {
          showSavedSnackBar(context, message: isKorean ? '삭제됐어요.' : 'Deleted.');
        }
      } catch (e) {
        if (context.mounted) {
          showSaveErrorSnackBar(context, message: '$e');
        }
      }
    }
  }
}

class _PatternRow extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  const _PatternRow({required this.chart, required this.isKorean, required this.onTap, required this.onDelete, required this.onDuplicate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: C.lv.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.grid_on_rounded, color: C.lvD),
        ),
        title: Text(chart.title, style: T.bodyBold),
        subtitle: Text(
          '${chart.rows} × ${chart.cols}  |  ${chart.mode == ChartMode.color ? (isKorean ? '컬러' : 'Color') : (isKorean ? '기호' : 'Symbol')}',
          style: T.caption.copyWith(color: C.mu),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 22),
          padding: EdgeInsets.zero,
          onSelected: (value) {
            if (value == 'edit') onTap();
            if (value == 'delete') onDelete();
            if (value == 'copy') onDuplicate();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), const Text('수정')]),
            ),
            PopupMenuItem(
              value: 'copy',
              child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lvD), const SizedBox(width: 8), const Text('복사')]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), const SizedBox(width: 8), const Text('삭제', style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
      ),
    );
  }
}
