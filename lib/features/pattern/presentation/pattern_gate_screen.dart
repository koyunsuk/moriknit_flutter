import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';

class PatternGateScreen extends ConsumerWidget {
  const PatternGateScreen({super.key});

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
                subtitle: isKorean ? '나만의 뜨개 도안을 그려요' : 'Draw your own knitting chart',
              ),
            ),
            Expanded(
              child: patternsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e', style: T.body)),
                data: (all) {
                  final charts = all.where((c) => c.type == PatternType.chart).toList();
                  return Stack(
                    children: [
                      const BgOrbs(),
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: charts.length + 1,
                        separatorBuilder: (_, i) =>
                            SizedBox(height: i == 0 ? 14 : 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return WorkspaceSummaryBar(
                              stats: [
                                WorkStat(
                                  '${charts.length}',
                                  isKorean ? '전체' : 'Total',
                                  color: C.lvD,
                                ),
                              ],
                              addLabel: isKorean ? '새 도안' : 'New',
                              onAdd: () => context.push(Routes.toolsPattern),
                            );
                          }
                          return _PatternCard(
                            chart: charts[i - 1],
                            isKorean: isKorean,
                          );
                        },
                      ),
                      if (charts.isEmpty)
                        Positioned(
                          top: 90,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _EmptyState(isKorean: isKorean),
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
}

class _PatternCard extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;

  const _PatternCard({required this.chart, required this.isKorean});

  String _modeLabel(ChartMode mode) {
    switch (mode) {
      case ChartMode.color:      return isKorean ? '색상' : 'Color';
      case ChartMode.symbol:     return isKorean ? '기호' : 'Symbol';
      case ChartMode.colorChart: return isKorean ? '컬러차트' : 'Color Chart';
      case ChartMode.narrative:  return isKorean ? '서술형' : 'Narrative';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('${Routes.toolsPatternViewer}/${chart.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.lvL,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.grid_on_rounded, color: C.lvD, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chart.title, style: T.bodyBold),
                const SizedBox(height: 2),
                Text(
                  '${chart.rows}${isKorean ? '단' : 'r'} × ${chart.cols}${isKorean ? '코' : 'c'}  ·  ${_modeLabel(chart.mode)}',
                  style: T.caption.copyWith(color: C.tx2),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
        ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_off_rounded, size: 48, color: C.mu),
          const SizedBox(height: 12),
          Text(
            isKorean ? '저장된 도안이 없어요' : 'No patterns yet',
            style: T.bodyBold.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 4),
          Text(
            isKorean ? '위 버튼으로 새 도안을 만들어보세요' : 'Tap the button above to create one',
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ),
    );
  }
}
