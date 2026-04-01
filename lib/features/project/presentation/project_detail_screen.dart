import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../providers/needle_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/template_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../counter/domain/counter_model.dart';
import '../../my/domain/needle_model.dart';
import '../../swatch/domain/swatch_model.dart';
import '../../yarn/domain/yarn_model.dart';
import '../../swatch/presentation/swatch_input_screen.dart';
import '../../../core/router/routes.dart';
import '../domain/project_model.dart';
import '../domain/project_step.dart';
import 'project_input_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final t = ref.read(appStringsProvider);
    bool deleteSwatches = false;
    bool deleteCounters = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.deleteProject, style: T.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.deleteProjectConfirm, style: T.body),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isKorean ? '연결된 스와치도 삭제' : 'Also delete linked swatches',
                  style: T.body,
                ),
                value: deleteSwatches,
                onChanged: (v) => setState(() => deleteSwatches = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isKorean ? '연결된 카운터도 삭제' : 'Also delete linked counters',
                  style: T.body,
                ),
                value: deleteCounters,
                onChanged: (v) => setState(() => deleteCounters = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: C.og),
              onPressed: () async {
                Navigator.pop(ctx);
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                  task: () async {
                    if (deleteSwatches) {
                      final swatchDocs = await FirebaseFirestore.instance
                          .collection('swatches')
                          .where('projectId', isEqualTo: id)
                          .get();
                      for (final doc in swatchDocs.docs) {
                        await doc.reference.delete();
                      }
                    }
                    if (deleteCounters) {
                      final counterDocs = await FirebaseFirestore.instance
                          .collection('counters')
                          .where('projectId', isEqualTo: id)
                          .get();
                      for (final doc in counterDocs.docs) {
                        await doc.reference.delete();
                      }
                    }
                    await ref.read(projectRepositoryProvider).deleteProject(id);
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(t.deleteProject),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateProject(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final copied = await ref.read(projectRepositoryProvider).duplicateProject(project);
          await ref.read(projectStepRepositoryProvider).copySteps(project.id, copied.id);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '복사됐어요.' : 'Duplicated.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
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
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: C.tx),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectInputScreen(
                                  projectId: project.id,
                                  initialProject: project,
                                ),
                              ),
                            );
                          } else if (value == 'copy') {
                            _duplicateProject(context, ref, project);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, project.id);
                          }
                        },
                        itemBuilder: (_) {
                          final isKorean = ref.read(appLanguageProvider).isKorean;
                          return [
                            PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                            PopupMenuItem(value: 'copy', child: Text(isKorean ? '복사' : 'Duplicate')),
                            PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                          ];
                        },
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
    final linkedSwatches = ref.watch(swatchesByProjectIdProvider(project.id));

    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
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
                  _ProgressSection(project: project),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 실(Yarn) 카드
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/yarn-list'),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: C.pk, size: 18),
                        const SizedBox(width: 6),
                        Text(isKorean ? '실 정보' : 'Yarn', style: T.bodyBold),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: C.mu, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MaterialThumbnail(
                          photoUrl: ref.watch(yarnListProvider).valueOrNull
                              ?.firstWhere(
                                (y) => project.yarnBrandName.isNotEmpty
                                    ? y.brandName == project.yarnBrandName
                                    : false,
                                orElse: () => YarnModel.empty(uid: ''),
                              )
                              .photoUrl ?? '',
                          defaultIcon: Icons.bolt_rounded,
                          iconColor: C.pk,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: t.yarnBrand, value: project.yarnBrandName.isEmpty ? t.brandNotSet : project.yarnBrandName),
                              _InfoRow(label: t.yarnName, value: project.yarnName.isEmpty ? t.notAvailable : project.yarnName),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 바늘(Needle) 카드
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(Routes.needles),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_rounded, color: C.lv, size: 18),
                        const SizedBox(width: 6),
                        Text(isKorean ? '바늘 정보' : 'Needle', style: T.bodyBold),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: C.mu, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MaterialThumbnail(
                          photoUrl: ref.watch(needleListProvider).valueOrNull
                              ?.firstWhere(
                                (n) => project.needleBrandName.isNotEmpty
                                    ? n.brandName == project.needleBrandName
                                    : project.needleSize > 0 && n.size == project.needleSize,
                                orElse: () => NeedleModel.empty(uid: ''),
                              )
                              .photoUrl ?? '',
                          defaultIcon: Icons.edit_rounded,
                          iconColor: C.lv,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: t.needle, value: project.needleSize > 0 ? t.needleSize(project.needleSize) : t.needleNotSet),
                              _InfoRow(label: t.needleBrand, value: project.needleBrandName.isEmpty ? t.brandNotSet : project.needleBrandName),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // #112: 연결된 스와치 섹션 (단일, 스와치 추가 버튼 포함)
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isKorean ? '연결된 스와치' : 'Linked Swatches',
                        style: T.bodyBold,
                      ),
                      TextButton(
                        onPressed: () => _addSwatch(context, ref, isKorean),
                        child: Text(isKorean ? '스와치 추가' : 'Add swatch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (linkedSwatches.isEmpty)
                    Text(
                      isKorean ? '연결된 스와치가 없어요.' : 'No linked swatches yet.',
                      style: T.body.copyWith(color: C.mu),
                    )
                  else
                    ...linkedSwatches.map(
                      (s) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('${Routes.swatchList}/${s.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: C.lmG,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _MaterialThumbnail(
                                photoUrl: s.beforePhotoUrl.isNotEmpty
                                    ? s.beforePhotoUrl
                                    : s.afterPhotoUrl,
                                defaultIcon: Icons.grid_view_rounded,
                                iconColor: C.lmD,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.swatchName.isNotEmpty
                                      ? s.swatchName
                                      : s.yarnName.isNotEmpty
                                          ? s.yarnName
                                          : (isKorean ? '이름 없음' : 'Untitled'),
                                  style: T.bodyBold,
                                ),
                              ),
                              Text(
                                '${s.beforeStitchCount}코×${s.beforeRowCount}단',
                                style: T.caption.copyWith(color: C.mu),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16, color: C.mu),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _linkExistingCounter(context, ref),
                            child: Text(isKorean ? '기존 연결' : 'Link'),
                          ),
                          TextButton(onPressed: () => _addCounter(context, ref), child: Text(t.add)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countersAsync.when(
                    data: (counters) {
                      if (counters.isEmpty) {
                        return Text(t.noCountersConnectedYet, style: T.body.copyWith(color: C.mu));
                      }
                      // 단수 진행률 집계 (targetRowCount > 0인 카운터만)
                      final rowTargetCounters = counters.where((c) => c.targetRowCount > 0).toList();
                      final totalRows = rowTargetCounters.fold<int>(0, (acc, c) => acc + c.rowCount);
                      final totalTargetRows = rowTargetCounters.fold<int>(0, (acc, c) => acc + c.targetRowCount);
                      final rowRatio = totalTargetRows > 0 ? (totalRows / totalTargetRows).clamp(0.0, 1.0) : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (totalTargetRows > 0) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.straighten_rounded, color: C.pk, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        isKorean
                                            ? '전체 단수 진행률: $totalRows / $totalTargetRows 단 (${(rowRatio * 100).toStringAsFixed(0)}%)'
                                            : 'Total rows: $totalRows / $totalTargetRows rows (${(rowRatio * 100).toStringAsFixed(0)}%)',
                                        style: T.caption.copyWith(color: C.pk),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: rowRatio,
                                      minHeight: 6,
                                      backgroundColor: C.pk.withValues(alpha: 0.12),
                                      valueColor: AlwaysStoppedAnimation(C.pk),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          ...counters.map((counter) => _CounterTile(
                                counter: counter,
                                onTap: () => context.push('/counter/${counter.id}'),
                              )),
                        ],
                      );
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
            const SizedBox(height: 12),
            _ProjectPhotosSection(project: project),
          ],
        ),
      ],
    );
  }

  void _addSwatch(BuildContext context, WidgetRef ref, bool isKorean) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SwatchInputScreen(
          initialSwatch: SwatchModel.empty(uid: ref.read(authStateProvider).valueOrNull?.uid ?? '')
              .copyWith(projectId: project.id),
        ),
      ),
    );
  }

  void _linkExistingCounter(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final t = ref.read(appStringsProvider);
    final allCounters = ref.read(counterListProvider).valueOrNull ?? [];
    final unlinked = allCounters.where((c) => c.projectId != project.id).toList();

    if (unlinked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '연결할 수 있는 카운터가 없어요.' : 'No available counters to link.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '기존 카운터 연결' : 'Link Existing Counter', style: T.h3),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unlinked.length,
            itemBuilder: (_, i) {
              final counter = unlinked[i];
              return ListTile(
                leading: Icon(Icons.tune_rounded, color: C.lv),
                title: Text(counter.name, style: T.body),
                subtitle: Text('S ${counter.stitchCount}  R ${counter.rowCount}', style: T.caption.copyWith(color: C.mu)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                    task: () async {
                      await ref.read(counterRepositoryProvider).updateCounter(counter.copyWith(projectId: project.id));
                      await ref.read(projectRepositoryProvider).addCounter(project.id, counter.id);
                    },
                  );
                  if (context.mounted) {
                    showSavedSnackBar(
                      ScaffoldMessenger.of(context),
                      message: isKorean ? '연결됐어요.' : 'Linked.',
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
        ],
      ),
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
              final completedCount = steps.where((s) => s.isDone).length;
              final totalCount = steps.length;
              final progressValue = totalCount > 0 ? completedCount / totalCount : 0.0;
              final isKorean = ref.watch(appLanguageProvider).isKorean;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      backgroundColor: C.lv.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(C.lv),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isKorean
                        ? '$completedCount/$totalCount 완료 (${(progressValue * 100).toStringAsFixed(0)}%)'
                        : '$completedCount/$totalCount done (${(progressValue * 100).toStringAsFixed(0)}%)',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  const SizedBox(height: 8),
                  ...steps
                      .map(
                        (step) => _StepTile(
                          step: step,
                          projectId: project.id,
                          onToggle: () => ref.read(projectStepRepositoryProvider).toggleStep(project.id, step),
                          onEdit: () => _editStep(context, ref, step),
                          onDelete: () => _deleteStep(context, ref, step),
                        ),
                      ),
                ],
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
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final builtins = [
      ('topdown', isKorean ? '탑다운 스웨터' : 'Top-down Sweater', Icons.dry_cleaning_rounded),
      ('socks', isKorean ? '양말' : 'Socks', Icons.hiking_rounded),
      ('scarf', isKorean ? '목도리' : 'Scarf', Icons.ac_unit_rounded),
      ('gloves', isKorean ? '장갑' : 'Gloves', Icons.back_hand_rounded),
      ('hat', isKorean ? '모자' : 'Hat', Icons.face_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final customTemplates = cRef.watch(userTemplateListProvider).valueOrNull ?? [];
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const SizedBox(height: 8),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Text(isKorean ? '템플릿 선택' : 'Select Template', style: T.h3),
                  const SizedBox(height: 12),
                  // 기본 템플릿
                  Text(isKorean ? '기본 템플릿' : 'Built-in', style: T.caption.copyWith(color: C.mu)),
                  const SizedBox(height: 6),
                  ...builtins.map((tpl) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(tpl.$3, color: C.lv, size: 20),
                    ),
                    title: Text(tpl.$2, style: T.body),
                    trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      runWithMoriLoadingDialog<void>(
                        context,
                        message: isKorean ? '단계 추가 중...' : 'Adding steps...',
                        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                        task: () => ref.read(projectStepRepositoryProvider).addTemplateSteps(project.id, tpl.$1),
                      );
                    },
                  )),
                  // 커스텀 템플릿
                  if (customTemplates.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(isKorean ? '나의 커스텀 템플릿' : 'My Custom Templates', style: T.caption.copyWith(color: C.mu)),
                    const SizedBox(height: 6),
                    ...customTemplates.map((tmpl) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 20),
                      ),
                      title: Text(tmpl.title, style: T.body),
                      subtitle: Text(
                        isKorean ? '${tmpl.stepTitles.length}개 단계' : '${tmpl.stepTitles.length} steps',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        runWithMoriLoadingDialog<void>(
                          context,
                          message: isKorean ? '단계 추가 중...' : 'Adding steps...',
                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                          task: () async {
                            final stepRepo = ref.read(projectStepRepositoryProvider);
                            for (int i = 0; i < tmpl.stepTitles.length; i++) {
                              await stepRepo.addStep(
                                project.id,
                                tmpl.stepTitles[i],
                                i,
                                description: i < tmpl.stepDescs.length ? tmpl.stepDescs[i] : '',
                              );
                            }
                          },
                        );
                      },
                    )),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addStep(BuildContext context, WidgetRef ref) {
    _showStepDialog(context, ref);
  }

  void _editStep(BuildContext context, WidgetRef ref, ProjectStep step) {
    _showStepDialog(context, ref, existingStep: step);
  }

  void _deleteStep(BuildContext context, WidgetRef ref, ProjectStep step) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '단계 삭제' : 'Delete Step', style: T.h3),
        content: Text(
          isKorean ? '"${step.name}" 단계를 삭제할까요?' : 'Delete step "${step.name}"?',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                  task: () => ref.read(projectStepRepositoryProvider).deleteStep(project.id, step.id),
                );
                if (context.mounted) {
                  showSavedSnackBar(
                    ScaffoldMessenger.of(context),
                    message: isKorean ? '삭제됐어요.' : 'Deleted.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                }
              }
            },
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showStepDialog(BuildContext context, WidgetRef ref, {ProjectStep? existingStep}) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final t = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: existingStep?.name ?? '');
    final descCtrl = TextEditingController(text: existingStep?.description ?? '');
    final noteCtrl = TextEditingController(text: existingStep?.note ?? '');
    final targetRowCtrl = TextEditingController(
      text: (existingStep?.targetRow ?? 0) > 0 ? '${existingStep!.targetRow}' : '',
    );
    var selectedBlockType = existingStep?.blockType ?? StepBlockType.text;
    final isEdit = existingStep != null;

    final blockTypeLabels = <StepBlockType, String>{
      StepBlockType.text: isKorean ? '텍스트' : 'Text',
      StepBlockType.stitchCount: isKorean ? '코수' : 'Stitches',
      StepBlockType.patternLink: isKorean ? '도안' : 'Pattern',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? (isKorean ? '단계 수정' : 'Edit Step') : t.addStep, style: T.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: isKorean ? '단계 이름' : 'Step name', hintText: t.stepNameHint),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '소제목 (선택)' : 'Subtitle (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetRowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '목표단 (선택)' : 'Target rows (optional)',
                    hintText: '0',
                    suffixText: isKorean ? '단' : 'rows',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isKorean ? '메모 (선택)' : 'Note (optional)',
                    hintText: isKorean ? '예: 전체 콧수 120코, 래글런 마커 4개' : 'e.g. Cast on 120 sts',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(isKorean ? '유형' : 'Type', style: TextStyle(fontSize: 12, color: C.mu, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: StepBlockType.values.map((type) {
                    final isSelected = selectedBlockType == type;
                    return GestureDetector(
                      onTap: () => setState(() => selectedBlockType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? C.lv : C.lvL,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
                        ),
                        child: Text(
                          blockTypeLabels[type]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : C.lvD,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameCtrl.dispose();
                descCtrl.dispose();
                noteCtrl.dispose();
                targetRowCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final note = noteCtrl.text.trim();
                final targetRow = int.tryParse(targetRowCtrl.text.trim()) ?? 0;
                final blockType = selectedBlockType;
                nameCtrl.dispose();
                descCtrl.dispose();
                noteCtrl.dispose();
                targetRowCtrl.dispose();
                Navigator.pop(ctx);
                if (name.isEmpty) return;
                Future.microtask(() async {
                  if (!context.mounted) return;
                  if (isEdit) {
                    try {
                      await runWithMoriLoadingDialog<void>(
                        context,
                        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                        task: () => ref.read(projectStepRepositoryProvider).updateStep(
                          project.id,
                          existingStep.id,
                          name: name,
                          description: desc,
                          note: note,
                          targetRow: targetRow,
                          blockType: blockType,
                        ),
                      );
                      if (context.mounted) {
                        showSavedSnackBar(
                          ScaffoldMessenger.of(context),
                          message: isKorean ? '저장됐어요.' : 'Saved.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                      }
                    }
                  } else {
                    final stepsAsync = ref.read(projectStepsProvider(project.id));
                    final order = stepsAsync.valueOrNull?.length ?? 0;
                    await runWithMoriLoadingDialog<void>(
                      context,
                      message: t.addingStep,
                      subtitle: t.pleaseWaitMoment,
                      task: () => ref.read(projectStepRepositoryProvider).addStep(
                        project.id,
                        name,
                        order,
                        description: desc,
                        note: note,
                        targetRow: targetRow,
                        blockType: blockType,
                      ),
                    );
                  }
                });
              },
              child: Text(isEdit ? (isKorean ? '저장' : 'Save') : t.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends ConsumerStatefulWidget {
  final ProjectStep step;
  final String projectId;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StepTile({
    required this.step,
    required this.projectId,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends ConsumerState<_StepTile> {
  bool _uploading = false;

  Future<ImageSource?> _showImageSourceDialog() {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from Gallery', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(isKorean ? '즉시 촬영' : 'Take a Photo', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
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
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: C.mu),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'edit') widget.onEdit();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (ctx) {
                        final isKorean = ref.read(appLanguageProvider).isKorean;
                        return [
                          PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                          PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                        ];
                      },
                    ),
                  ],
                ),
                if (step.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.description,
                      style: T.captionBold.copyWith(color: C.lv),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (step.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.note,
                      style: T.caption.copyWith(color: C.mu),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (step.targetRow > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: C.lmD.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '목표: ${step.targetRow}단',
                        style: T.caption.copyWith(color: C.lmD, fontSize: 11),
                      ),
                    ),
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
  final VoidCallback? onTap;

  const _CounterTile({required this.counter, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasRowTarget = counter.targetRowCount > 0;
    final hasStitchTarget = counter.targetStitchCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: C.lvD),
                const SizedBox(width: 10),
                Expanded(child: Text(counter.name, style: T.bodyBold)),
                Text('S ${counter.stitchCount}  R ${counter.rowCount}', style: T.caption.copyWith(color: C.mu)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: C.mu),
              ],
            ),
            if (hasRowTarget) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.unfold_more_rounded, color: C.pk, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: counter.rowProgress,
                        minHeight: 5,
                        backgroundColor: C.pk.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(C.pk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counter.rowCount}/${counter.targetRowCount}단',
                    style: T.caption.copyWith(color: C.pk),
                  ),
                ],
              ),
            ],
            if (hasStitchTarget) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.more_horiz_rounded, color: C.lv, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: counter.stitchProgress,
                        minHeight: 5,
                        backgroundColor: C.lv.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(C.lv),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counter.stitchCount}/${counter.targetStitchCount}코',
                    style: T.caption.copyWith(color: C.lv),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectPhotosSection extends ConsumerStatefulWidget {
  final ProjectModel project;
  const _ProjectPhotosSection({required this.project});

  @override
  ConsumerState<_ProjectPhotosSection> createState() => _ProjectPhotosSectionState();
}

class _ProjectPhotosSectionState extends ConsumerState<_ProjectPhotosSection> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    if (widget.project.photoUrls.length >= 4) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      final updatedUrls = [...widget.project.photoUrls, url];
      await ref.read(projectRepositoryProvider).updateProject(
        widget.project.copyWith(photoUrls: updatedUrls),
      );
    } catch (e) {
      if (mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '사진 삭제' : 'Delete Photo', style: T.h3),
        content: Text(isKorean ? '이 사진을 삭제할까요?' : 'Delete this photo?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final updatedUrls = widget.project.photoUrls.where((u) => u != url).toList();
          await ref.read(projectRepositoryProvider).updateProject(
            widget.project.copyWith(photoUrls: updatedUrls),
          );
        },
      );
      if (mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _viewPhoto(String url, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImageViewer(imageUrl: url, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final photos = widget.project.photoUrls;
    final canAdd = photos.length < 4;

    return Container(
      decoration: BoxDecoration(
        color: C.pk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.pk.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: C.pk, size: 18),
              const SizedBox(width: 6),
              Text(isKorean ? '착용샷 / 사용샷' : 'Wearing / Usage', style: T.bodyBold.copyWith(color: C.pkD)),
              const Spacer(),
              if (canAdd)
                GestureDetector(
                  onTap: _isUploading ? null : _pickAndUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.pk,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(isKorean ? '사진 추가' : 'Add', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: C.pk.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.pk.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: C.pk.withValues(alpha: 0.5), size: 32),
                    const SizedBox(height: 4),
                    Text(
                      isKorean ? '사진을 추가해보세요 (최대 4장)' : 'Add photos (max 4)',
                      style: T.caption.copyWith(color: C.pk.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: photos.map((url) {
                final heroTag = 'project_photo_${widget.project.id}_${url.hashCode}';
                return GestureDetector(
                  onTap: () => _viewPhoto(url, heroTag),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: C.bd,
                              child: Icon(Icons.broken_image, color: C.mu),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deletePhoto(url),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${photos.length}/4',
                style: T.caption.copyWith(color: C.pk.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Hero(
                tag: heroTag,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialThumbnail extends StatelessWidget {
  final String photoUrl;
  final IconData defaultIcon;
  final Color iconColor;

  const _MaterialThumbnail({
    required this.photoUrl,
    required this.defaultIcon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(10),
        image: photoUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoUrl.isEmpty
          ? Icon(defaultIcon, color: iconColor, size: 22)
          : null,
    );
  }
}

// ── 진행률 섹션 (단계로그 | 카운터 모드 선택) ──────────────────
class _ProgressSection extends ConsumerStatefulWidget {
  final ProjectModel project;
  const _ProgressSection({required this.project});

  @override
  ConsumerState<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends ConsumerState<_ProgressSection> {
  String _source = 'steps'; // 'steps' | 'counter'

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final stepsAsync = ref.watch(projectStepsProvider(widget.project.id));
    final countersAsync = ref.watch(countersByProjectProvider(widget.project.id));

    double progressValue = widget.project.progressPercent / 100;
    String progressLabel = widget.project.progressDisplay;

    if (_source == 'steps') {
      stepsAsync.whenData((steps) {
        if (steps.isNotEmpty) {
          final completed = steps.where((s) => s.isDone).length;
          progressValue = completed / steps.length;
          progressLabel = isKorean
              ? '$completed/${steps.length} 완료 (${(progressValue * 100).toStringAsFixed(0)}%)'
              : '$completed/${steps.length} done (${(progressValue * 100).toStringAsFixed(0)}%)';
        }
      });
    } else {
      countersAsync.whenData((counters) {
        final withTarget = counters.where((c) => c.targetRowCount > 0);
        if (withTarget.isNotEmpty) {
          final c = withTarget.first;
          progressValue = c.rowProgress;
          progressLabel = isKorean
              ? '${c.rowCount}/${c.targetRowCount}단 (${(progressValue * 100).toStringAsFixed(0)}%)'
              : '${c.rowCount}/${c.targetRowCount} rows (${(progressValue * 100).toStringAsFixed(0)}%)';
        } else {
          progressLabel = isKorean ? '카운터에 목표단수를 설정해 주세요.' : 'Set target rows in counter.';
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(isKorean ? '진행률' : 'Progress', style: T.captionBold.copyWith(color: C.mu)),
            const Spacer(),
            for (final entry in [
              ('steps', isKorean ? '단계' : 'Steps'),
              ('counter', isKorean ? '카운터' : 'Counter'),
            ])
              GestureDetector(
                onTap: () => setState(() => _source = entry.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _source == entry.$1 ? C.lv : C.lvL,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _source == entry.$1 ? C.lv : C.lv.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _source == entry.$1 ? FontWeight.w700 : FontWeight.w500,
                      color: _source == entry.$1 ? Colors.white : C.lvD,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progressValue.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: C.lv.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(C.lv),
          ),
        ),
        const SizedBox(height: 6),
        Text(progressLabel, style: T.caption.copyWith(color: C.lvD)),
      ],
    );
  }
}
