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
                          return _EmptyState(isKorean: isKorean, onNew: () => context.push(Routes.toolsPattern));
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
                                  onPressed: () => context.push(Routes.toolsPattern),
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
      await ref.read(patternRepositoryProvider).delete(chart.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onNew;
  const _EmptyState({required this.isKorean, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean ? '아직 도안이 없어요' : 'No patterns yet',
            style: T.bodyBold.copyWith(color: C.lvD),
          ),
          const SizedBox(height: 6),
          Text(
            isKorean ? '컬러 또는 기호 모드로 나만의 뜨개 도안을 만들어 보세요.' : 'Create your own chart in color or symbol mode.',
            style: T.caption.copyWith(color: C.lvD, height: 1.5),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: Text(isKorean ? '새 도안 만들기' : 'Create new'),
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PatternRow({required this.chart, required this.isKorean, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_right_rounded, color: C.mu),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
