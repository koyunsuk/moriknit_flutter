import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/parsed_pattern_provider.dart';

class MyParsedPatternsScreen extends ConsumerWidget {
  const MyParsedPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final patternsAsync = ref.watch(aiPatternsProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
        title: Text(
          isKorean ? '변환된 도안' : 'Converted Patterns',
          style: T.h3,
        ),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: C.lv),
            onPressed: () => context.push(Routes.toolsPatternConverter),
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          patternsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (patterns) {
              if (patterns.isEmpty) {
                return _EmptyState(isKorean: isKorean);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: patterns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _PatternCard(
                  pattern: patterns[i],
                  isKorean: isKorean,
                  onTap: () => context.push(
                      '${Routes.toolsMyParsedPatterns}/${patterns[i].id}'),
                  onDelete: () =>
                      _confirmDelete(context, ref, patterns[i], isKorean),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PatternChart pattern,
    bool isKorean,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '삭제하시겠어요?' : 'Delete?'),
        content: Text(pattern.title),
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
    if (confirm != true || !context.mounted) return;

    await runWithMoriLoadingDialog<void>(
      context,
      message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
      task: () => ref
          .read(patternConverterRepositoryProvider)
          .deleteAiPattern(pattern.id),
    );
    if (context.mounted) {
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '삭제됐어요.' : 'Deleted.');
    }
  }
}

class _PatternCard extends StatelessWidget {
  final PatternChart pattern;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PatternCard({
    required this.pattern,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sections = pattern.aiSections ?? [];
    final totalSteps = sections.fold<int>(0, (acc, sec) => acc + sec.steps.length);
    final completedSteps = sections.fold<int>(
      0,
      (acc, sec) => acc + sec.steps.where((s) => s.isCompleted).length,
    );
    final progress =
        totalSteps == 0 ? 0.0 : completedSteps / totalSteps;
    final pct = (progress * 100).toInt();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.description_rounded, color: C.lv, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.title,
                      style: T.body.copyWith(
                          fontWeight: FontWeight.w600, color: C.tx),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    isKorean
                        ? '${sections.length}섹션 · $totalSteps단계 · $pct% 완료'
                        : '${sections.length} sections · $totalSteps steps · $pct% done',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: C.lv.withValues(alpha: 0.15),
                    color: C.lv,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: C.tx2, size: 20),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    isKorean ? '삭제' : 'Delete',
                    style: TextStyle(color: C.og),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isKorean;
  const _EmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: C.tx2),
          const SizedBox(height: 16),
          Text(
            isKorean ? '변환된 도안이 없어요' : 'No converted patterns yet',
            style: T.body.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? 'PDF나 이미지 도안을 업로드해 보세요'
                : 'Upload a PDF or image pattern',
            style: T.caption.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(Routes.toolsPatternConverter),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(isKorean ? '도안 업로드' : 'Upload Pattern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
