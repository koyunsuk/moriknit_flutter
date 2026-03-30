import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../counter/domain/counter_model.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final headerSubtitle = resolveUiCopy(data: uiCopy, language: language, key: 'tools_header_subtitle', fallback: t.toolsHeaderSubtitle);
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.tools,
                subtitle: headerSubtitle,
              ),
            ),
            // 스크롤 바디
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              GlassCard(
                child: Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => context.go(Routes.swatchList), child: _StatChip(label: t.swatches, value: '$swatchCount'))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(onTap: () => context.go(Routes.projectList), child: _StatChip(label: t.projects, value: '$projectCount'))),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(label: t.counters, value: '$counterCount')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(title: t.toolsCreativeSection),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.calculate_rounded,
                color: C.pk,
                title: t.gaugeCalculator,
                description: t.gaugeHeaderSubtitle,
                onTap: () => context.push(Routes.toolsGauge),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.menu_book_rounded,
                color: C.pkD,
                title: t.myEncyclopedia,
                description: t.encyclopediaToolDescription,
                onTap: () => context.push(Routes.toolsEncyclopedia),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.straighten_rounded,
                color: C.lv,
                title: t.needles,
                description: t.needleToolDescription,
                onTap: () => context.push(Routes.needles),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.edit_note_rounded,
                color: C.pk,
                title: t.memoPad,
                description: t.toolsMemoDescription,
                onTap: () => context.push(Routes.toolsMemo),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.school_rounded,
                color: C.lvD,
                title: isKorean ? '클라스' : 'Class',
                description: t.coursesToolDescription,
                onTap: () => context.push(Routes.toolsCourse),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.grid_on_rounded,
                color: C.lvD,
                title: isKorean ? '도안 에디터' : 'Pattern Editor',
                description: isKorean ? '컬러/기호 모드로 나만의 도안을 그려요' : 'Draw your own chart in color or symbol mode',
                onTap: () => context.push(Routes.toolsPatterns),
              ),
              const SizedBox(height: 10),
              _ToolCard(
                icon: Icons.add_task_rounded,
                color: C.lmD,
                title: t.newCounter,
                description: t.counterTools,
                onTap: () => _showCreateCounter(context, ref, t),
              ),
                  ],
                ),
              ),
            ),
  ],
        ),
      ),
    );
  }

  Future<void> _showCreateCounter(BuildContext context, WidgetRef ref, AppStrings t) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.createCounter, style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: t.counterNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
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
            child: Text(t.create),
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
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

