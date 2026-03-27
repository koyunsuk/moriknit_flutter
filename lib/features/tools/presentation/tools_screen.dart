import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../counter/domain/counter_model.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final countersAsync = ref.watch(counterListProvider);
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, title: const MoriKnitTitle(fontSize: 20)),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              MoriBrandHeader(
                logoSize: 90,
                titleSize: 28,
                subtitle: isKorean
                    ? '도구를 만들고, 카운터를 관리하고, 다음 뜨개 작업으로 바로 이동하세요.'
                    : 'Create tools, track rows, and jump into your next knitting task.',
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(child: _StatChip(label: isKorean ? '스와치' : 'Swatches', value: '$swatchCount')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(label: isKorean ? '프로젝트' : 'Projects', value: '$projectCount')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(label: isKorean ? '카운터' : 'Counters', value: '$counterCount')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(title: isKorean ? '주요 도구' : 'Creative Tools'),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.grid_on_rounded,
                color: C.lv,
                title: isKorean ? '도안 제작' : 'Pattern Editor',
                description: isKorean ? '차트와 반복 패턴 메모를 만들 수 있어요.' : 'Build charts and save repeat ideas for future patterns.',
                onTap: () => context.push(Routes.toolsPattern),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.calculate_rounded,
                color: C.pk,
                title: isKorean ? '게이지 계산기' : 'Gauge Calculator',
                description: isKorean ? '새 치수에 맞춰 코수와 단수를 빠르게 계산할 수 있어요.' : 'Convert stitches and rows for new measurements quickly.',
                onTap: () => context.push(Routes.toolsGauge),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.menu_book_rounded,
                color: C.pkD,
                title: isKorean ? '뜨개 사전' : 'Encyclopedia',
                description: isKorean ? '용어, 약어, 기법 설명을 모아둘 사전 공간이에요.' : 'Keep stitch terms, abbreviations, and technique notes in one place.',
                onTap: () => context.push(Routes.toolsEncyclopedia),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.school_rounded,
                color: C.lvD,
                title: isKorean ? '강의' : 'Courses',
                description: isKorean ? '입문부터 응용까지 학습 콘텐츠 흐름을 이어갈 수 있어요.' : 'Add learning paths from beginner lessons to advanced techniques.',
                onTap: () => context.push(Routes.toolsCourse),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.add_task_rounded,
                color: C.lmD,
                title: isKorean ? '새 카운터' : 'New Counter',
                description: isKorean ? '소매, 반복무늬, 단수 추적용 카운터를 바로 만들어요.' : 'Create a row or stitch counter directly from the tools tab.',
                onTap: () => _showCreateCounter(context, ref, isKorean),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isKorean ? '최근 카운터' : 'Recent Counters',
                    style: const TextStyle(fontSize: 13, color: C.mu, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                  ),
                  TextButton(onPressed: () => _showCreateCounter(context, ref, isKorean), child: Text(isKorean ? '새로 만들기' : 'New')),
                ],
              ),
              const SizedBox(height: 8),
              countersAsync.when(
                data: (counters) {
                  if (counters.isEmpty) {
                    return GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            const Icon(Icons.checkroom_rounded, color: C.mu, size: 30),
                            const SizedBox(height: 10),
                            Text(
                              isKorean ? '카운터가 아직 없어요' : 'No counters yet',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.tx),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isKorean ? '소매, 반복무늬, 단수 추적용 카운터를 시작해보세요.' : 'Start one for sleeves, repeats, or rows you want to track.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: C.mu),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: counters
                        .take(6)
                        .map((counter) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CounterCard(counter: counter, isKorean: isKorean),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: C.lv)),
                ),
                error: (error, _) => GlassCard(child: Text('Failed to load counters: $error', style: T.body.copyWith(color: C.og))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCounter(BuildContext context, WidgetRef ref, bool isKorean) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '카운터 만들기' : 'Create Counter', style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isKorean ? '예: 몸판 단수' : 'Example: Body rows'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
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
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Text(value, style: T.h3.copyWith(color: C.lvD)),
          const SizedBox(height: 4),
          Text(label, style: T.caption.copyWith(color: C.mu)),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _ToolCard({required this.icon, required this.color, required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold),
                const SizedBox(height: 4),
                Text(description, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final CounterModel counter;
  final bool isKorean;
  const _CounterCard({required this.counter, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/counter/${counter.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: C.lm.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune_rounded, color: C.lmD),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counter.name, style: T.bodyBold),
                const SizedBox(height: 4),
                Text(
                  isKorean ? '코 ${counter.stitchCount} · 단 ${counter.rowCount}' : 'Stitch ${counter.stitchCount} · Row ${counter.rowCount}',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}
