import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import 'swatch_detail_screen.dart';
import 'swatch_input_screen.dart';
import 'widgets/swatch_list_sections.dart';

class SwatchListScreen extends ConsumerStatefulWidget {
  const SwatchListScreen({super.key});

  @override
  ConsumerState<SwatchListScreen> createState() => _SwatchListScreenState();
}

class _SwatchListScreenState extends ConsumerState<SwatchListScreen> {
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchListAsync = ref.watch(swatchListProvider);
    final projectListAsync = ref.watch(projectListProvider);
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
                              return MoriEmptyState(
                                icon: Icons.grid_view_rounded,
                                iconColor: C.lmD,
                                title: isKorean ? '아직 스와치가 없어요' : 'No swatches yet',
                                subtitle: isKorean ? '게이지를 기록하면 나중에 같은 실을 쓸 때 참고할 수 있어요.' : 'Record your gauge to reference later.',
                                buttonLabel: isKorean ? '스와치 추가' : 'Add swatch',
                                onAction: isLimitReached ? null : () => _showSwatchStartSheet(context),
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
                                          ? () => _showLimitDialog(isKorean)
                                          : () => _showSwatchStartSheet(context),
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                      label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...swatches.map(
                                  (swatch) {
                                    final projects = projectListAsync.valueOrNull ?? [];
                                    final linked = projects.where((p) => p.id == swatch.projectId).firstOrNull;
                                    return SwatchCard(
                                    swatch: swatch,
                                    projectName: linked?.title,
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
                                            SwatchInputScreen(swatchId: swatch.id),
                                      ),
                                    ),
                                    onDelete: () => _confirmDelete(ref, swatch.id, isKorean),
                                    onDuplicate: () => _confirmDuplicate(ref, swatch, isKorean),
                                  );
                                  },
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

  Future<void> _confirmDelete(WidgetRef ref, String swatchId, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '스와치 삭제' : 'Delete swatch', style: T.h3),
        content: Text(isKorean ? '정말 삭제하시겠어요?' : 'Are you sure you want to delete?', style: T.body),
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
    if (confirm == true && mounted) {
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () async {
            await ref.read(swatchRepositoryProvider).deleteSwatch(swatchId);
          },
        );
        if (!mounted) return;
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
      } catch (e) {
        if (!mounted) return;
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _confirmDuplicate(WidgetRef ref, dynamic swatch, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(swatchRepositoryProvider).duplicateSwatch(swatch);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _showSwatchStartSheet(BuildContext context) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
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
              child: Row(children: [Text(isKorean ? '스와치 추가' : 'Add swatch', style: T.h3)]),
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SwatchInputScreen()));
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '빈 스와치로 시작' : 'Start blank', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '처음부터 직접 게이지를 기록해요' : 'Record gauge from scratch', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopySwatchSheet(context);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.lmD)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 스와치 복사로 시작' : 'Copy existing swatch', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 스와치를 복사해서 시작해요' : 'Duplicate an existing swatch', style: T.caption.copyWith(color: C.mu)),
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

  void _showCopySwatchSheet(BuildContext context) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final swatches = ref.read(swatchListProvider).valueOrNull ?? [];
    if (swatches.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 스와치가 없어요.' : 'No swatches to copy.');
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 스와치 선택' : 'Select swatch to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: swatches.length,
                itemBuilder: (_, i) {
                  final s = swatches[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _confirmDuplicate(ref, s, isKorean);
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.grid_view_rounded, color: C.lmD, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.swatchName, style: T.bodyBold),
                            if (s.yarnBrandName.isNotEmpty || s.yarnName.isNotEmpty)
                              Text('${s.yarnBrandName} ${s.yarnName}'.trim(), style: T.caption.copyWith(color: C.mu)),
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

  void _showLimitDialog(bool isKorean) {
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
