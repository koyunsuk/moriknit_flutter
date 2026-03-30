import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/swatch_provider.dart';
import 'swatch_detail_screen.dart';
import 'swatch_input_screen.dart';
import 'widgets/swatch_list_sections.dart';

class SwatchListScreen extends ConsumerWidget {
  const SwatchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchListAsync = ref.watch(swatchListProvider);
    final isLimitReached = ref.watch(swatchLimitReachedProvider);
    final progress = ref.watch(swatchLimitProgressProvider);
    final gates = ref.watch(featureGatesProvider);
    final count = ref.watch(swatchCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.swatches,
                subtitle: t.swatchLibrary,
              ),
            ),
            // 스크롤 바디
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  // 1단: 통계 GlassCard
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SwatchStatCell(
                                label: isKorean ? '보유 스와치' : 'Total swatches',
                                value: swatchListAsync.maybeWhen(
                                  data: (s) => '${s.length}',
                                  orElse: () => '$count',
                                ),
                                color: C.lmD,
                              ),
                            ),
                          ],
                        ),
                        if (gates.isFree) ...[
                          const SizedBox(height: 12),
                          SwatchLimitBar(
                            current: count,
                            max: 5,
                            progress: progress,
                            isReached: isLimitReached,
                            onUpgrade: () {},
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 2단: 리스트 GlassCard
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        swatchListAsync.when(
                          loading: () => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: C.lm),
                            ),
                          ),
                          error: (e, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Failed to load swatches: $e',
                                style: T.body.copyWith(color: C.mu),
                              ),
                            ),
                          ),
                          data: (swatches) {
                            if (swatches.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: C.lmG,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isKorean ? '아직 스와치가 없어요' : 'No swatches yet',
                                      style: T.bodyBold.copyWith(color: C.lmD),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isKorean
                                          ? '게이지를 기록하면 나중에 같은 실을 쓸 때 참고할 수 있어요.'
                                          : 'Record your gauge so you can reference it when using the same yarn later.',
                                      style: T.caption.copyWith(color: C.lmD, height: 1.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: isLimitReached
                                              ? null
                                              : () => _navigateToInput(context),
                                          icon: const Icon(Icons.add_rounded),
                                          label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isKorean ? '스와치 목록' : 'Swatch list',
                                        style: T.bodyBold,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: isLimitReached
                                          ? () => _showLimitDialog(context, ref, isKorean)
                                          : () => _navigateToInput(context),
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                      label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...swatches.map(
                                  (swatch) => SwatchCard(
                                    swatch: swatch,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SwatchDetailScreen(swatchId: swatch.id),
                                      ),
                                    ),
                                    onEdit: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SwatchDetailScreen(swatchId: swatch.id),
                                      ),
                                    ),
                                    onDelete: () => _confirmDelete(context, ref, swatch.id, isKorean),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String swatchId, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '스와치 삭제' : 'Delete swatch', style: T.h3),
        content: Text(isKorean ? '이 스와치를 삭제할까요?' : 'Delete this swatch?', style: T.body),
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
      await ref.read(swatchRepositoryProvider).deleteSwatch(swatchId);
    }
  }

  void _navigateToInput(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SwatchInputScreen()));
  }

  void _showLimitDialog(BuildContext context, WidgetRef ref, bool isKorean) {
    final gates = ref.read(featureGatesProvider);
    final count = ref.read(swatchCountProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isKorean ? '스와치 한도 도달' : 'Swatch limit reached',
          style: T.h3,
        ),
        content: Text(gates.swatchLimitMessage(count), style: T.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '닫기' : 'Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lm,
              foregroundColor: const Color(0xFF1a3000),
            ),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(isKorean ? '업그레이드' : 'Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _SwatchStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SwatchStatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 4),
          Text(value, style: T.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}
