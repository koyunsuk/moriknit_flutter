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
    // 이슈 #719 — 일부 옛 도안(#687 이전 생성분)에서 stream emit이 안 되는 회귀로 무한로딩.
    // future provider는 캐시 우선 + 5s 서버 timeout + null 폴백으로 안전.
    final patternAsync = ref.watch(aiPatternDetailFutureProvider(patternId));

    return patternAsync.when(
      loading: () => Scaffold(
        backgroundColor: C.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _PatternLoadErrorScreen(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(aiPatternDetailFutureProvider(patternId)),
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                Stack(
                  children: [
                    MoriPageHeaderShell(
                      child: MoriWideHeader(
                        title: pattern.title,
                        subtitle: isKorean ? '단계별로 진행해요' : 'Step by step',
                        trailing: [
                          IconButton(
                            icon: const Icon(Icons.menu_book_rounded, size: 22),
                            color: C.lv,
                            tooltip: isKorean ? '텍스트 뷰어' : 'Text Viewer',
                            onPressed: () => context.push('/tools/my-parsed-patterns/${pattern.id}/text'),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        color: C.tx,
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: CustomScrollView(
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
                ),
              ],
            ),
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

// ── #684 로드 실패 플레이스홀더 (친화 메시지 + 재시도) ───────────────────────
class _PatternLoadErrorScreen extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onRetry;
  const _PatternLoadErrorScreen({required this.isKorean, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: C.tx2),
                  const SizedBox(height: 16),
                  Text(
                    isKorean
                        ? '도안 데이터를 불러오지 못했어요'
                        : 'Failed to load pattern data.',
                    textAlign: TextAlign.center,
                    style: T.h3.copyWith(color: C.tx2),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(isKorean ? '다시 시도' : 'Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
