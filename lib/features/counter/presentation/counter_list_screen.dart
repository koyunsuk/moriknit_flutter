import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../domain/counter_model.dart';

class CounterListScreen extends ConsumerWidget {
  const CounterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counterListAsync = ref.watch(counterListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '카운터' : 'Counters',
                subtitle: isKorean ? '코·단 카운터 관리' : 'Manage stitch & row counters',
              ),
            ),
            Expanded(
              child: counterListAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lmD)),
                error: (e, _) => Center(child: Text('$e', style: T.body)),
                data: (counters) {
                  if (counters.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: C.lmD.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isKorean ? '카운터가 없어요.' : 'No counters yet.',
                              style: T.bodyBold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isKorean ? '새 카운터를 만들어 코와 단을 기록해보세요.' : 'Create a counter to track stitches and rows.',
                              style: T.caption.copyWith(color: C.mu),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateCounterDialog(context, ref, isKorean),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(isKorean ? '카운터 만들기' : 'Create counter'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      const BgOrbs(),
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: counters.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final counter = counters[index];
                          return _CounterListCard(
                            counter: counter,
                            isKorean: isKorean,
                            onTap: () => context.push('/counter/${counter.id}'),
                            onDelete: () => _confirmDelete(context, ref, counter.id, isKorean),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.lmD,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateCounterDialog(context, ref, isKorean),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _showCreateCounterDialog(BuildContext context, WidgetRef ref, bool isKorean) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '새 카운터' : 'New counter', style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isKorean ? '카운터 이름' : 'Counter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authUser = ref.read(authStateProvider).valueOrNull;
              final name = nameCtrl.text.trim();
              if (authUser == null || name.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final counter = CounterModel.empty(uid: authUser.uid, name: name);
              final saved = await ref.read(counterRepositoryProvider).createCounter(counter);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.push('/counter/${saved.id}');
            },
            child: Text(isKorean ? '만들기' : 'Create'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String counterId, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '카운터 삭제' : 'Delete counter', style: T.h3),
        content: Text(isKorean ? '이 카운터를 삭제할까요? 되돌릴 수 없어요.' : 'Delete this counter? This cannot be undone.', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(counterRepositoryProvider).deleteCounter(counterId);
    }
  }
}

class _CounterListCard extends StatelessWidget {
  final CounterModel counter;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CounterListCard({
    required this.counter,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: C.lmD.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.exposure_plus_1_rounded, color: C.lmD, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counter.name, style: T.bodyBold),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _CountBadge(
                      label: isKorean ? '코' : 'Sts',
                      value: counter.stitchCount,
                      color: C.lv,
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(
                      label: isKorean ? '단' : 'Rows',
                      value: counter.rowCount,
                      color: C.pk,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: C.mu, size: 20),
            onPressed: onDelete,
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        '$label $value',
        style: T.caption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
