import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/counter_provider.dart';
import '../domain/counter_model.dart';

class CounterScreen extends ConsumerWidget {
  final String counterId;
  const CounterScreen({super.key, required this.counterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counterAsync = ref.watch(counterByIdProvider(counterId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0),
      body: counterAsync.when(
        data: (counter) {
          if (counter == null) {
            return Center(child: Text(isKorean ? '카운터를 찾을 수 없어요.' : 'Counter not found.', style: T.body));
          }
          return Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  MoriBrandHeader(logoSize: 84, titleSize: 24, subtitle: isKorean ? '단수와 코 수를 빠르게 기록하는 카운터 화면이에요.' : 'Track rows and stitches in one place.'),
                  const SizedBox(height: 14),
                  _FeatureHero(icon: Icons.exposure_plus_1_rounded, color: C.lmD, title: counter.name, caption: isKorean ? '현재 작업 위치를 빠르게 저장하고 다시 이어갈 수 있어요.' : 'Save your place and continue later.'),
                  const SizedBox(height: 14),
                  _CounterPanel(label: isKorean ? '코' : 'Stitches', count: counter.stitchCount, color: C.lv, onMinus: () => _update(ref, counter, stitchDelta: -1), onPlus: () => _update(ref, counter, stitchDelta: 1)),
                  const SizedBox(height: 12),
                  _CounterPanel(label: isKorean ? '단' : 'Rows', count: counter.rowCount, color: C.pk, onMinus: () => _update(ref, counter, rowDelta: -1), onPlus: () => _update(ref, counter, rowDelta: 1)),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isKorean ? '최근 마크' : 'Recent marks', style: T.bodyBold),
                      const SizedBox(height: 10),
                      if (counter.marks.isEmpty) Text(isKorean ? '아직 저장한 마크가 없어요.' : 'No saved marks yet.', style: T.caption.copyWith(color: C.mu)),
                      ...counter.marks.reversed.take(3).map((mark) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [const Icon(Icons.bookmark_rounded, color: C.lmD, size: 16), const SizedBox(width: 8), Expanded(child: Text(isKorean ? '코 ${mark.stitchCount} · 단 ${mark.rowCount}' : 'Stitch ${mark.stitchCount} · Row ${mark.rowCount}', style: T.body)), Text(DateFormat('MM/dd HH:mm').format(mark.timestamp), style: T.caption.copyWith(color: C.mu))]),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _saveMark(ref, counter), child: Text(isKorean ? '현재 위치 저장' : 'Save current mark'))),
                    ]),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('$e', style: T.body)),
      ),
    );
  }

  Future<void> _update(WidgetRef ref, CounterModel counter, {int stitchDelta = 0, int rowDelta = 0}) async {
    await ref.read(counterRepositoryProvider).updateCounter(counter.copyWith(stitchCount: (counter.stitchCount + stitchDelta).clamp(0, 99999), rowCount: (counter.rowCount + rowDelta).clamp(0, 99999)));
  }

  Future<void> _saveMark(WidgetRef ref, CounterModel counter) async {
    await ref.read(counterRepositoryProvider).addMark(counter.id, CounterMark(timestamp: DateTime.now(), stitchCount: counter.stitchCount, rowCount: counter.rowCount, note: ''));
  }
}

class _CounterPanel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _CounterPanel({required this.label, required this.count, required this.color, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) {
    return GlassCard(child: Column(children: [Text(label, style: T.captionBold.copyWith(color: color)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: onMinus, icon: Icon(Icons.remove_circle_outline, color: color)), Text('$count', style: T.numLG.copyWith(color: color, fontSize: 42)), IconButton(onPressed: onPlus, icon: Icon(Icons.add_circle, color: color))]) ]));
  }
}

class _FeatureHero extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String caption;
  const _FeatureHero({required this.icon, required this.color, required this.title, required this.caption});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(26), border: Border.all(color: color.withValues(alpha: 0.20))), child: Row(children: [Container(width: 84, height: 84, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 42, color: color)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: T.h3), const SizedBox(height: 6), Text(caption, style: T.body.copyWith(color: C.tx2))]))]));
  }
}
