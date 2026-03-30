import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: C.og),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: counterAsync.when(
        data: (counter) {
          if (counter == null) {
            return Center(child: Text(isKorean ? '카운터를 찾을 수 없어요.' : 'Counter not found.', style: T.body));
          }
          return Stack(
            children: [
              const BgOrbs(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(counter.name, style: T.h2),
                        Text(isKorean ? '코 · 단 카운터' : 'Stitch & Row Counter', style: T.caption),
                      ])),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                        child: Row(children: [Icon(Icons.bookmark_rounded, color: C.lmD, size: 16), const SizedBox(width: 8), Expanded(child: Text(isKorean ? '코 ${mark.stitchCount} · 단 ${mark.rowCount}' : 'Stitch ${mark.stitchCount} · Row ${mark.rowCount}', style: T.body)), Text(DateFormat('MM/dd HH:mm').format(mark.timestamp), style: T.caption.copyWith(color: C.mu))]),
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
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('카운터 삭제', style: T.h3),
        content: const Text('이 카운터를 삭제할까요? 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(counterRepositoryProvider).deleteCounter(counterId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(children: [
        Text(label, style: T.sm.copyWith(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onMinus(); },
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Icon(Icons.remove_rounded, color: color, size: 30),
              ),
            ),
            Text('$count', style: T.numXL.copyWith(color: color)),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onPlus(); },
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
