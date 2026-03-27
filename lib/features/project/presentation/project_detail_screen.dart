import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../counter/domain/counter_model.dart';
import '../../swatch/domain/swatch_model.dart';
import '../domain/project_model.dart';
import 'project_input_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const MoriKnitTitle(fontSize: 18),
        actions: [
          projectAsync.whenOrNull(
                data: (project) => project == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.edit_outlined, color: C.lv),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectInputScreen(projectId: project.id, initialProject: project),
                          ),
                        ),
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return Center(child: Text('Project not found.', style: T.body));
          }
          return _ProjectBody(project: project);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('Failed to load project: $e', style: T.body)),
      ),
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  final ProjectModel project;

  const _ProjectBody({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countersAsync = ref.watch(countersByProjectProvider(project.id));
    final AsyncValue<SwatchModel?> swatchAsync = project.swatchId.isEmpty
        ? const AsyncValue<SwatchModel?>.data(null)
        : ref.watch(swatchByIdProvider(project.swatchId));

    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            const MoriBrandHeader(
              logoSize: 76,
              titleSize: 24,
              subtitle: 'Keep project details, linked swatches, and counters together.',
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(project.title.isEmpty ? 'Untitled project' : project.title, style: T.h2)),
                      MoriChip(label: project.statusEnum.label, type: ChipType.lavender),
                    ],
                  ),
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(project.description, style: T.body.copyWith(color: C.mu)),
                  ],
                  const SizedBox(height: 12),
                  Text('Progress', style: T.captionBold.copyWith(color: C.mu)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (project.progressPercent / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: C.lv.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(C.lv),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(project.progressDisplay, style: T.caption.copyWith(color: C.lvD)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Materials', style: T.bodyBold),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Yarn brand', value: project.yarnBrandName.isEmpty ? 'Not set' : project.yarnBrandName),
                  _InfoRow(label: 'Yarn name', value: project.yarnName.isEmpty ? 'Not set' : project.yarnName),
                  _InfoRow(label: 'Needle', value: project.needleSize > 0 ? (project.needleSize % 1 == 0 ? '${project.needleSize.toInt()}mm' : '${project.needleSize}mm') : 'Not set'),
                  _InfoRow(label: 'Needle brand', value: project.needleBrandName.isEmpty ? 'Not set' : project.needleBrandName),
                ],
              ),
            ),
            const SizedBox(height: 12),
            swatchAsync.when(
              data: (swatch) => GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Linked swatch', style: T.bodyBold),
                    const SizedBox(height: 8),
                    Text(
                      swatch == null ? 'No swatch linked yet.' : '${swatch.beforeStitchCount} stitches x ${swatch.beforeRowCount} rows',
                      style: T.body,
                    ),
                    if (swatch != null) ...[
                      const SizedBox(height: 4),
                      Text(swatch.yarnBrandName.isEmpty ? 'Brand not set' : swatch.yarnBrandName, style: T.caption),
                    ],
                  ],
                ),
              ),
              loading: () => const GlassCard(child: Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator(color: C.lv)))) ,
              error: (e, _) => GlassCard(child: Text('Failed to load swatch: $e', style: T.body.copyWith(color: C.og))),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Counters', style: T.bodyBold),
                      TextButton(onPressed: () => _addCounter(context, ref), child: const Text('Add')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countersAsync.when(
                    data: (counters) {
                      if (counters.isEmpty) {
                        return Text('No counters connected yet.', style: T.body.copyWith(color: C.mu));
                      }
                      return Column(children: counters.map((counter) => _CounterTile(counter: counter)).toList());
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Text('Failed to load counters: $e', style: T.body.copyWith(color: C.og)),
                  ),
                ],
              ),
            ),
            if (project.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Memo', style: T.bodyBold),
                    const SizedBox(height: 8),
                    Text(project.memo, style: T.body),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _addCounter(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create counter', style: T.h3),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Example: Body rows')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authStateProvider).valueOrNull;
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (user == null || name.isEmpty) return;
              final counter = CounterModel.empty(uid: user.uid, name: name).copyWith(projectId: project.id);
              final saved = await ref.read(counterRepositoryProvider).createCounter(counter);
              await ref.read(projectRepositoryProvider).addCounter(project.id, saved.id);
              if (context.mounted) context.push('/counter/${saved.id}');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: T.captionBold.copyWith(color: C.mu))),
          Expanded(child: Text(value, style: T.body)),
        ],
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  final CounterModel counter;

  const _CounterTile({required this.counter});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: C.lvD),
          const SizedBox(width: 10),
          Expanded(child: Text(counter.name, style: T.bodyBold)),
          Text('S ${counter.stitchCount}  R ${counter.rowCount}', style: T.caption.copyWith(color: C.mu)),
        ],
      ),
    );
  }
}
