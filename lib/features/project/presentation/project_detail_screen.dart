import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/project_step_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../counter/domain/counter_model.dart';
import '../../swatch/domain/swatch_model.dart';
import '../domain/project_model.dart';
import '../domain/project_step.dart';
import 'project_input_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final t = ref.read(appStringsProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteProject, style: T.h3),
        content: Text(t.deleteProjectConfirm, style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () async {
              Navigator.pop(ctx);
              await runWithMoriLoadingDialog<void>(
                context,
                message: t.deletingProject,
                subtitle: t.pleaseWaitMoment,
                task: () => ref.read(projectRepositoryProvider).deleteProject(id),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(t.deleteProject),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final projectAsync = ref.watch(projectByIdProvider(projectId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const MoriKnitTitle(fontSize: 18),
        actions: [
          projectAsync.whenOrNull(
                data: (project) => project == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: C.lv),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectInputScreen(
                                  projectId: project.id,
                                  initialProject: project,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: C.og),
                            onPressed: () => _confirmDelete(context, ref, project.id),
                          ),
                        ],
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return Center(child: Text(t.projectNotFound, style: T.body));
          }
          return _ProjectBody(project: project);
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(
          child: Text(t.failedToLoadProject(e.toString()), style: T.body),
        ),
      ),
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  final ProjectModel project;

  const _ProjectBody({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final t = ref.watch(appStringsProvider);
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
            if (project.coverPhotoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  project.coverPhotoUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title.isEmpty ? t.untitledProject : project.title,
                          style: T.h2,
                        ),
                      ),
                      MoriChip(
                        label: project.statusEnum.localizedLabel(isKorean),
                        type: ChipType.lavender,
                      ),
                    ],
                  ),
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(project.description, style: T.body.copyWith(color: C.mu)),
                  ],
                  const SizedBox(height: 12),
                  Text(t.progress, style: T.captionBold.copyWith(color: C.mu)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (project.progressPercent / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: C.lv.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(C.lv),
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
                  Text(t.materials, style: T.bodyBold),
                  const SizedBox(height: 10),
                  _InfoRow(label: t.yarnBrand, value: project.yarnBrandName.isEmpty ? t.brandNotSet : project.yarnBrandName),
                  _InfoRow(label: t.yarnName, value: project.yarnName.isEmpty ? t.notAvailable : project.yarnName),
                  _InfoRow(label: t.needle, value: project.needleSize > 0 ? t.needleSize(project.needleSize) : t.needleNotSet),
                  _InfoRow(label: t.needleBrand, value: project.needleBrandName.isEmpty ? t.brandNotSet : project.needleBrandName),
                ],
              ),
            ),
            const SizedBox(height: 12),
            swatchAsync.when(
              data: (swatch) => GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.linkedSwatch, style: T.bodyBold),
                    const SizedBox(height: 8),
                    Text(
                      swatch == null ? t.noSwatchLinkedYet : t.stitchesRows(swatch.beforeStitchCount, swatch.beforeRowCount),
                      style: T.body,
                    ),
                    if (swatch != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        swatch.yarnBrandName.isEmpty ? t.brandNotSet : swatch.yarnBrandName,
                        style: T.caption,
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator(color: C.lv)),
                ),
              ),
              error: (e, _) => GlassCard(
                child: Text(
                  t.failedToLoadSwatch(e.toString()),
                  style: T.body.copyWith(color: C.og),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.counters, style: T.bodyBold),
                      TextButton(onPressed: () => _addCounter(context, ref), child: Text(t.add)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countersAsync.when(
                    data: (counters) {
                      if (counters.isEmpty) {
                        return Text(t.noCountersConnectedYet, style: T.body.copyWith(color: C.mu));
                      }
                      return Column(children: counters.map((counter) => _CounterTile(counter: counter)).toList());
                    },
                    loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Text(
                      t.failedToLoadCounters(e.toString()),
                      style: T.body.copyWith(color: C.og),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StepsSection(project: project),
            if (project.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.memo, style: T.bodyBold),
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
    final t = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();
    showDialog<void>(
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
              final user = ref.read(authStateProvider).valueOrNull;
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (user == null || name.isEmpty) return;
              final counter = CounterModel.empty(uid: user.uid, name: name).copyWith(projectId: project.id);
              late final CounterModel saved;
              await runWithMoriLoadingDialog<void>(
                context,
                message: t.creatingCounter,
                subtitle: t.pleaseWaitMoment,
                task: () async {
                  saved = await ref.read(counterRepositoryProvider).createCounter(counter);
                  await ref.read(projectRepositoryProvider).addCounter(project.id, saved.id);
                },
              );
              if (context.mounted) context.push('/counter/${saved.id}');
            },
            child: Text(t.create),
          ),
        ],
      ),
    );
  }
}

class _StepsSection extends ConsumerWidget {
  final ProjectModel project;
  const _StepsSection({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final stepsAsync = ref.watch(projectStepsProvider(project.id));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.stepLog, style: T.bodyBold),
              TextButton(onPressed: () => _addStep(context, ref), child: Text(t.add)),
            ],
          ),
          const SizedBox(height: 4),
          stepsAsync.when(
            data: (steps) {
              if (steps.isEmpty) {
                return Column(
                  children: [
                    Text(t.noStepsYet, style: T.body.copyWith(color: C.mu)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showTemplateSheet(context, ref),
                        child: const Text('템플릿으로 시작하기'),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: steps
                    .map(
                      (step) => _StepTile(
                        step: step,
                        projectId: project.id,
                        onToggle: () => ref.read(projectStepRepositoryProvider).toggleStep(project.id, step),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
            error: (e, _) => Text(
              t.failedToLoadSteps(e.toString()),
              style: T.body.copyWith(color: C.og),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplateSheet(BuildContext context, WidgetRef ref) {
    final templates = [
      ('topdown', '탑다운 스웨터', Icons.dry_cleaning_rounded),
      ('socks', '양말', Icons.hiking_rounded),
      ('scarf', '목도리', Icons.ac_unit_rounded),
      ('gloves', '장갑', Icons.back_hand_rounded),
      ('hat', '모자', Icons.face_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('템플릿 선택', style: T.bodyBold),
            const SizedBox(height: 8),
            ...templates.map((tpl) => ListTile(
              leading: Icon(tpl.$3, color: C.lv),
              title: Text(tpl.$2, style: T.body),
              onTap: () {
                Navigator.pop(ctx);
                runWithMoriLoadingDialog<void>(
                  context,
                  message: '스텝 추가 중...',
                  subtitle: '잠시만 기다려 주세요.',
                  task: () => ref.read(projectStepRepositoryProvider).addTemplateSteps(project.id, tpl.$1),
                );
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addStep(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addStep, style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: t.stepNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              final stepsAsync = ref.read(projectStepsProvider(project.id));
              final order = stepsAsync.valueOrNull?.length ?? 0;
              await runWithMoriLoadingDialog<void>(
                context,
                message: t.addingStep,
                subtitle: t.pleaseWaitMoment,
                task: () => ref.read(projectStepRepositoryProvider).addStep(project.id, name, order),
              );
            },
            child: Text(t.add),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends ConsumerStatefulWidget {
  final ProjectStep step;
  final String projectId;
  final VoidCallback onToggle;
  const _StepTile({required this.step, required this.projectId, required this.onToggle});

  @override
  ConsumerState<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends ConsumerState<_StepTile> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.projectId}/steps/${widget.step.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(picked.path));
      final url = await storageRef.getDownloadURL();
      await ref.read(projectStepRepositoryProvider).updateStepPhoto(widget.projectId, widget.step.id, url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.isDone ? C.lv : Colors.transparent,
                  border: Border.all(color: step.isDone ? C.lv : C.bd, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: step.isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.name,
                        style: T.body.copyWith(
                          color: step.isDone ? C.mu : C.tx,
                          decoration: step.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _uploading ? null : _pickPhoto,
                      child: _uploading
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.lv))
                          : Icon(Icons.add_photo_alternate_outlined, size: 18, color: C.mu),
                    ),
                  ],
                ),
                if (step.isDone && step.doneAt != null)
                  Text(
                    '완료: ${step.doneAt!.month}/${step.doneAt!.day}',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                if (step.photoUrl != null && step.photoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        step.photoUrl!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
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
          Icon(Icons.tune_rounded, color: C.lvD),
          const SizedBox(width: 10),
          Expanded(child: Text(counter.name, style: T.bodyBold)),
          Text('S ${counter.stitchCount}  R ${counter.rowCount}', style: T.caption.copyWith(color: C.mu)),
        ],
      ),
    );
  }
}
