import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/blueprint/domain/step_blueprint_unit.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/parsed_pattern_provider.dart';
import 'pattern_text_tracker_screen.dart';

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
            pattern: pattern, isKorean: isKorean);
      },
    );
  }
}

// #905 — Phase E1 이후 aiSections은 pattern_charts에 항상 빈 배열.
// 실제 단계 데이터는 step_blueprints/{id}/units 에 있으므로
// blueprintUnitsProvider로 읽어서 표시한다.
class _PatternReaderView extends ConsumerWidget {
  final PatternChart pattern;
  final bool isKorean;
  const _PatternReaderView(
      {required this.pattern, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(blueprintUnitsProvider(pattern.id));

    return unitsAsync.when(
      loading: () => Scaffold(
        backgroundColor: C.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text(isKorean ? '단계를 불러오지 못했어요.' : 'Failed to load steps.')),
      ),
      data: (rawUnits) {
        final units = [...rawUnits]..sort((a, b) => a.order.compareTo(b.order));
        return _PatternStepsBody(
          pattern: pattern,
          units: units,
          isKorean: isKorean,
          ref: ref,
        );
      },
    );
  }
}

class _PatternStepsBody extends StatelessWidget {
  final PatternChart pattern;
  final List<StepBlueprintUnit> units;
  final bool isKorean;
  final WidgetRef ref;
  const _PatternStepsBody({
    required this.pattern,
    required this.units,
    required this.isKorean,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final total = units.length;
    // 완료 상태는 blueprintUnit 자체에 없으므로 진행률은 0으로 시작
    // (StepLogView의 인스턴스 모드가 체크 상태 관리 — 여기선 미지원)
    const progress = 0.0;
    final pct = (progress * 100).toInt();

    return AppShellScaffold(
      title: pattern.title,
      subtitle: isKorean ? '단계별로 진행해요' : 'Step by step',
      showBackButton: true,
      trailing: [
        IconButton(
          icon: const Icon(Icons.menu_book_rounded, size: 22),
          color: C.lv,
          tooltip: isKorean ? '텍스트 뷰어' : 'Text Viewer',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: RouteSettings(
                name: 'pattern-text-${pattern.id}-${DateTime.now().microsecondsSinceEpoch}',
              ),
              builder: (_) => PatternTextTrackerScreen(patternId: pattern.id),
            ),
          ),
        ),
      ],
      body: units.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers_outlined, size: 48, color: C.tx2),
                    const SizedBox(height: 12),
                    Text(
                      isKorean ? '단계가 없어요.\nAI 변환 후 저장하면 단계가 표시됩니다.' : 'No steps yet.\nSave after AI conversion to see steps.',
                      textAlign: TextAlign.center,
                      style: T.body.copyWith(color: C.tx2),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
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
                                value: progress,
                                backgroundColor: C.lv.withValues(alpha: 0.15),
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
                          isKorean ? '0/$total단계 완료' : '0/$total steps done',
                          style: T.caption.copyWith(color: C.tx2),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final unit = units[i];
                      final text = unit.instructionKo?.isNotEmpty == true
                          ? unit.instructionKo!
                          : unit.instruction;
                      return _StepTile(
                        stepId: unit.id,
                        index: i + 1,
                        instruction: text,
                        isCompleted: false,
                        onToggle: (_) {},
                      );
                    },
                    childCount: units.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
