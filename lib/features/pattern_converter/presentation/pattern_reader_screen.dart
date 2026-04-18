import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/pattern/domain/ai_pattern_section.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/parsed_pattern_provider.dart';

class PatternReaderScreen extends ConsumerWidget {
  final String patternId;
  const PatternReaderScreen({super.key, required this.patternId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final patternAsync = ref.watch(aiPatternDetailProvider(patternId));

    return patternAsync.when(
      loading: () => Scaffold(
        backgroundColor: C.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$e')),
      ),
      data: (pattern) {
        if (pattern == null) {
          return Scaffold(
            backgroundColor: C.bg,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                color: C.tx,
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
              child: Text(
                  isKorean ? '도안을 찾을 수 없어요.' : 'Pattern not found.'),
            ),
          );
        }
        return _PatternReaderView(
            pattern: pattern, ref: ref, isKorean: isKorean);
      },
    );
  }
}

class _PatternReaderView extends StatelessWidget {
  final PatternChart pattern;
  final WidgetRef ref;
  final bool isKorean;
  const _PatternReaderView(
      {required this.pattern, required this.ref, required this.isKorean});

  List<AiSection> get _sections => pattern.aiSections ?? [];

  int get _totalSteps =>
      _sections.fold<int>(0, (acc, sec) => acc + sec.steps.length);

  int get _completedSteps => _sections.fold<int>(
        0,
        (acc, sec) => acc + sec.steps.where((s) => s.isCompleted).length,
      );

  double get _progress =>
      _totalSteps == 0 ? 0.0 : _completedSteps / _totalSteps;

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).toInt();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
        title: Text(pattern.title,
            style: T.h3, overflow: TextOverflow.ellipsis),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          CustomScrollView(
            slivers: [
              // 진행률 헤더
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor:
                                  C.lv.withValues(alpha: 0.15),
                              color: C.lv,
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$pct%',
                            style: T.caption.copyWith(
                                color: C.lv,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isKorean
                            ? '$_completedSteps/$_totalSteps단계 완료'
                            : '$_completedSteps/$_totalSteps steps done',
                        style: T.caption.copyWith(color: C.tx2),
                      ),
                    ],
                  ),
                ),
              ),

              // 섹션별 단계 목록
              for (final section in _sections) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      section.title,
                      style: T.h3.copyWith(color: C.lv),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final step = section.steps[i];
                      return _StepTile(
                        stepId: step.id,
                        index: i + 1,
                        instruction: step.instruction,
                        isCompleted: step.isCompleted,
                        onToggle: (val) => ref
                            .read(patternConverterRepositoryProvider)
                            .toggleStep(
                              patternId: pattern.id,
                              sectionId: section.id,
                              stepId: step.id,
                              isCompleted: val,
                            ),
                      );
                    },
                    childCount: section.steps.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatefulWidget {
  final String stepId;
  final int index;
  final String instruction;
  final bool isCompleted;
  final ValueChanged<bool> onToggle;
  const _StepTile({
    required this.stepId,
    required this.index,
    required this.instruction,
    required this.isCompleted,
    required this.onToggle,
  });

  @override
  State<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends State<_StepTile> {
  late bool _localDone;

  @override
  void initState() {
    super.initState();
    _localDone = widget.isCompleted;
  }

  @override
  void didUpdateWidget(_StepTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted != widget.isCompleted) {
      _localDone = widget.isCompleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _localDone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () {
          final newValue = !_localDone;
          setState(() => _localDone = newValue);
          widget.onToggle(newValue);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: done ? C.lv.withValues(alpha: 0.08) : C.gx,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? C.lv.withValues(alpha: 0.35) : C.bd,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? C.lv : Colors.transparent,
                  border: Border.all(
                    color: done ? C.lv : C.tx2,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : Center(
                        child: Text(
                          '${widget.index}',
                          style: T.caption.copyWith(
                              color: C.tx2,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.instruction,
                  style: T.sm.copyWith(
                    color: done ? C.tx2 : C.tx,
                    decoration:
                        done ? TextDecoration.lineThrough : null,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
