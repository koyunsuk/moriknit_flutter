import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/book_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/project_step_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../my/data/mori_service.dart';
import '../../../providers/yarn_provider.dart';
import '../domain/builtin_template.dart';
import '../domain/project_model.dart';
import '../domain/user_template.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../../ravelry/data/ravelry_repository.dart';
import '../../ravelry/data/ravelry_auth_provider.dart';

class ProjectInputScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final ProjectModel? initialProject;
  final String? templateType;
  final BuiltinTemplate? builtinTemplate;
  final UserTemplate? userTemplate;
  // 이슈 #627 — AI 변환 도안에서 프로젝트 시작. 섹션이 ProjectStep으로 자동 미러링됨.
  final PatternChart? sourcePatternChart;

  const ProjectInputScreen({
    super.key,
    this.projectId,
    this.initialProject,
    this.templateType,
    this.builtinTemplate,
    this.userTemplate,
    this.sourcePatternChart,
  });

  @override
  ConsumerState<ProjectInputScreen> createState() => _ProjectInputScreenState();
}

class _ProjectInputScreenState extends ConsumerState<ProjectInputScreen> {
  bool _isSaving = false;
  bool _uploading = false;
  bool _syncToRavelry = false;
  String? _localCoverPath;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  late final TextEditingController _yarnNameController;
  late final TextEditingController _yarnColorController;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject;
    _titleController = TextEditingController(text: project?.title ?? '');
    _descriptionController = TextEditingController(text: project?.description ?? '');
    _memoController = TextEditingController(text: project?.memo ?? '');
    _yarnNameController = TextEditingController(text: project?.yarnName ?? '');
    _yarnColorController = TextEditingController(text: project?.yarnColor ?? '');

    // 템플릿 선택 시 제목 자동 입력
    if (project == null && widget.templateType != null) {
      final name = _templateName(widget.templateType!);
      _titleController.text = name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(projectInputProvider.notifier).setTitle(name);
      });
    }

    if (project == null && widget.builtinTemplate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isKorean = ref.read(appLanguageProvider).isKorean;
        final bt = widget.builtinTemplate!;
        final name = isKorean ? bt.titleKo : bt.titleEn;
        _titleController.text = name;
        ref.read(projectInputProvider.notifier).setTitle(name);
      });
    }

    if (project == null && widget.userTemplate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final name = widget.userTemplate!.title;
        _titleController.text = name;
        ref.read(projectInputProvider.notifier).setTitle(name);
      });
    }

    if (project != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(projectInputProvider.notifier).load(project);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    _yarnNameController.dispose();
    _yarnColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final t = ref.watch(appStringsProvider);
    final project = ref.watch(projectInputProvider);
    final notifier = ref.read(projectInputProvider.notifier);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.projectId != null
              ? t.editProject
              : widget.templateType != null
                  ? _templateName(widget.templateType!)
                  : t.newProject,
          style: T.h3,
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _isSaving ? null : () => _save(context),
              icon: Icon(Icons.save_rounded, size: 18, color: C.lvD),
              label: Text('저장', style: TextStyle(color: C.lvD)),
            ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.templateType != null) _TemplateBanner(templateType: widget.templateType!),
                _CoverImagePicker(
                  photoUrl: project.coverPhotoUrl,
                  localPath: _localCoverPath,
                  uploading: _uploading,
                  t: t,
                  onTap: () => _pickCover(notifier),
                  onRemove: (project.coverPhotoUrl.isNotEmpty || _localCoverPath != null)
                      ? () {
                          setState(() => _localCoverPath = null);
                          notifier.setCoverPhoto('');
                        }
                      : null,
                ),
                const SizedBox(height: 20),
                SectionTitle(title:t.projectTitle),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _titleController,
                  hint: t.projectTitleHint,
                  onChanged: notifier.setTitle,
                ),
                const SizedBox(height: 16),
                SectionTitle(title:t.description),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _descriptionController,
                  hint: t.projectDescriptionHint,
                  maxLines: 2,
                  onChanged: notifier.setDescription,
                ),
                const SizedBox(height: 20),
                SectionTitle(title:t.status),
                const SizedBox(height: 10),
                _StatusSelector(selected: project.status, isKorean: isKorean, onSelected: notifier.setStatus),
                const SizedBox(height: 20),
                SectionTitle(title:t.yarnInformation),
                const SizedBox(height: 8),
                _BrandSearchField(
                  hint: t.yarnBrandHint,
                  value: project.yarnBrandName,
                  onTap: () => BrandSearchSheet.show(
                    context,
                    brandType: BrandType.yarn,
                    onSelected: notifier.setYarnBrand,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StyledField(
                        controller: _yarnNameController,
                        hint: t.yarnName,
                        onChanged: notifier.setYarnName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StyledField(
                        controller: _yarnColorController,
                        hint: t.color,
                        onChanged: notifier.setYarnColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _YarnWeightSelector(selected: project.yarnWeight, isKorean: isKorean, onSelected: notifier.setYarnWeight),
                const SizedBox(height: 20),
                SectionTitle(title:t.needleSizeLabel),
                const SizedBox(height: 10),
                _NeedleSizeSelector(selectedSize: project.needleSize, onSelected: notifier.setNeedleSize),
                const SizedBox(height: 8),
                _BrandSearchField(
                  hint: t.needleBrandHint,
                  value: project.needleBrandName,
                  onTap: () => BrandSearchSheet.show(
                    context,
                    brandType: BrandType.needle,
                    onSelected: (id, name) => notifier.setNeedleBrand(name),
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title:t.timeline),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: t.startDate,
                        date: project.startDate,
                        onSelected: notifier.setStartDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: t.targetDate,
                        date: project.targetDate,
                        onSelected: notifier.setTargetDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionTitle(title:t.memo),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _memoController,
                  hint: t.memoHintProject,
                  maxLines: 3,
                  onChanged: notifier.setMemo,
                ),
                if (ref.watch(ravelryAuthProvider).isLoggedIn && widget.projectId == null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setState(() => _syncToRavelry = !_syncToRavelry),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _syncToRavelry ? C.lv.withValues(alpha: 0.08) : C.gx,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _syncToRavelry ? C.lv : C.bd),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _syncToRavelry ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: _syncToRavelry ? C.lv : C.mu,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isKorean ? '라벨리에도 올리기' : 'Also add to Ravelry',
                                  style: T.body.copyWith(
                                    color: _syncToRavelry ? C.lv : C.tx,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  isKorean ? '제목, 메모가 라벨리 프로젝트로 함께 저장돼요' : 'Title and notes will be synced to Ravelry',
                                  style: T.caption.copyWith(color: C.mu),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // 템플릿 단계로그 미리보기 (#647 — AI 도안 sections 미리보기 포함)
                if (widget.builtinTemplate != null ||
                    widget.userTemplate != null ||
                    widget.sourcePatternChart != null) ...[
                  const SizedBox(height: 20),
                  _TemplateStepsPreview(
                    isKorean: isKorean,
                    builtinTemplate: widget.builtinTemplate,
                    userTemplate: widget.userTemplate,
                    patternChart: widget.sourcePatternChart,
                  ),
                ],
                const SizedBox(height: 20),
                SectionTitle(title:isKorean ? '연결된 스와치 (선택)' : 'Linked Swatch (optional)'),
                const SizedBox(height: 8),
                _SwatchDropdown(
                  selectedSwatchId: project.swatchId,
                  isKorean: isKorean,
                  onChanged: notifier.setSwatchId,
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '연결된 도안 (선택)' : 'Linked Pattern (optional)'),
                const SizedBox(height: 8),
                _PatternDropdown(
                  selectedPatternId: project.sourcePatternId,
                  isKorean: isKorean,
                  onChanged: notifier.setSourcePatternId,
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '참고 도서 (선택)' : 'Reference Book (optional)'),
                const SizedBox(height: 8),
                _BookDropdown(
                  selectedBookId: project.referenceBookId,
                  isKorean: isKorean,
                  onChanged: notifier.setReferenceBookId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _templateName(String type) {
    const names = {
      'topdown': '탑다운 스웨터',
      'crop_raglan_topdown': '크롭 레글런 탑다운',
      'socks': '양말',
      'scarf': '목도리',
      'gloves': '장갑',
      'hat': '모자',
    };
    return names[type] ?? '새 프로젝트';
  }

  Future<void> _pickCover(ProjectInputNotifier notifier) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;

    setState(() {
      _localCoverPath = picked.path;
      _uploading = true;
    });

    try {
      final reference = FirebaseStorage.instance.ref().child('projects/${DateTime.now().millisecondsSinceEpoch}_cover.jpg');
      final task = await reference.putFile(File(picked.path));
      final url = await task.ref.getDownloadURL();
      notifier.setCoverPhoto(url);
    } catch (error) {
      if (!mounted) return;
      final t = ref.read(appStringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.failedToUploadCoverImage(error.toString())),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    if (kIsWeb) return ImageSource.gallery;
    final t = ref.read(appStringsProvider);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(t.chooseFromGallery, style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(t.takePhoto, style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final t = ref.read(appStringsProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final gates = ref.read(featureGatesProvider);
    final count = ref.read(projectCountProvider);
    if (!gates.canAddProject(count) && widget.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gates.projectLimitMessage(count)), backgroundColor: C.og),
      );
      return;
    }

    final notifier = ref.read(projectInputProvider.notifier);
    final error = notifier.validationError;
    if (error != null) {
      final isKorean = ref.read(appLanguageProvider).isKorean;
      await showMissingFieldsDialog(context, missing: [error], isKorean: isKorean);
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final project = ref.read(projectInputProvider);
      final repository = ref.read(projectRepositoryProvider);

      await runWithMoriLoadingDialog<void>(
        context,
        message: t.projectUpdateLoading,
        subtitle: t.pleaseWaitMoment,
        task: () async {
          if (widget.projectId != null) {
            // 이슈 #644 — 수정 시 ravelryProjectId 있으면 Ravelry에도 동기화
            await repository.updateProject(project);
            await _syncProjectUpdateToRavelry(project);
          } else {
            // 이슈 #644 — Phase 4: 도안/실의 Ravelry IDs 수집해서 createProject에 전달
            final ravelryPatternId = _resolveRavelryPatternId(project);
            final ravelryStashIds = _resolveRavelryStashIds(project);
            // ProjectModel에 매핑 정보 미리 박아 두고 저장 (createProject 응답 받기 전)
            var prepared = project.copyWith(
              uid: user.uid,
              ravelryPatternId: ravelryPatternId,
              ravelryStashIds: ravelryStashIds,
            );
            final saved = await repository.createProject(prepared);
            MoriService.earn(user.uid, amount: 100, reason: 'project_save');
            if (_syncToRavelry) {
              final ravelryRepo = ref.read(ravelryRepositoryProvider);
              if (ravelryRepo != null) {
                int statusTypeId = 1;
                if (project.status == 'finished') statusTypeId = 3;
                final packs = ravelryStashIds
                    .map((id) => <String, dynamic>{'stash_id': id})
                    .toList();
                final created = await ravelryRepo.createProject(
                  name: project.title,
                  notes: project.memo.trim().isEmpty ? null : project.memo.trim(),
                  statusTypeId: statusTypeId,
                  patternId: ravelryPatternId,
                  packs: packs.isEmpty ? null : packs,
                );
                // 반환된 ravelryProjectId를 모리니트 프로젝트에 역동기화
                if (created.id > 0) {
                  await repository.updateProject(saved.copyWith(
                    ravelryProjectId: created.id,
                    ravelryPatternId: ravelryPatternId,
                    ravelryStashIds: ravelryStashIds,
                  ));
                }
              }
            }
            if (widget.templateType != null) {
              await ref.read(projectStepRepositoryProvider).addTemplateSteps(saved.id, widget.templateType!);
            }
            if (widget.builtinTemplate != null) {
              final isKorean = ref.read(appLanguageProvider).isKorean;
              await ref.read(projectStepRepositoryProvider).addBuiltinTemplateSteps(saved.id, widget.builtinTemplate!, isKorean);
            }
            if (widget.userTemplate != null) {
              final tmpl = widget.userTemplate!;
              final stepRepo = ref.read(projectStepRepositoryProvider);
              for (int i = 0; i < tmpl.stepTitles.length; i++) {
                await stepRepo.addStep(
                  saved.id,
                  tmpl.stepTitles[i],
                  i,
                  description: i < tmpl.stepDescs.length ? tmpl.stepDescs[i] : '',
                );
              }
            }
            // 이슈 #627 (B-1) — AI 변환 도안에서 섹션 + 카운터 자동 미러링
            if (widget.sourcePatternChart != null) {
              final isKorean = ref.read(appLanguageProvider).isKorean;
              await ref
                  .read(projectStepRepositoryProvider)
                  .addPatternSectionStepsWithCounters(
                    saved.id,
                    widget.sourcePatternChart!,
                    isKorean,
                    ref.read(counterRepositoryProvider),
                  );
            }
          }
        },
      );

      if (!mounted) return;
      showSavedSnackBar(messenger, message: t.projectSaved);
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: t.failedToSaveProject(error.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 이슈 #644 — 프로젝트의 sourcePatternId로 PatternChart를 찾아 ravelryPatternId 반환
  int? _resolveRavelryPatternId(ProjectModel project) {
    if (widget.sourcePatternChart != null) {
      return widget.sourcePatternChart!.ravelryPatternId;
    }
    if (project.sourcePatternId.isEmpty) return null;
    final patterns = ref.read(patternListProvider).valueOrNull ?? [];
    for (final p in patterns) {
      if (p.id == project.sourcePatternId) return p.ravelryPatternId;
    }
    return null;
  }

  /// 이슈 #644 — 프로젝트의 yarnIds 각각에 대해 ravelryStashId 수집 (없는 것 제외)
  List<int> _resolveRavelryStashIds(ProjectModel project) {
    if (project.yarnIds.isEmpty) return const [];
    final yarns = ref.read(yarnListProvider).valueOrNull ?? [];
    final ids = <int>[];
    for (final yarnId in project.yarnIds) {
      for (final y in yarns) {
        if (y.id == yarnId && y.ravelryStashId != null && y.ravelryStashId! > 0) {
          ids.add(y.ravelryStashId!);
          break;
        }
      }
    }
    return ids;
  }

  /// 이슈 #644 — Phase 5: 수정 시 ravelryProjectId가 있으면 Ravelry에도 업데이트
  Future<void> _syncProjectUpdateToRavelry(ProjectModel project) async {
    final ravelryProjectId = project.ravelryProjectId;
    if (ravelryProjectId == null || ravelryProjectId <= 0) return;
    final ravelryRepo = ref.read(ravelryRepositoryProvider);
    if (ravelryRepo == null) return;

    int statusTypeId = 1;
    if (project.status == 'finished') statusTypeId = 3;

    // 도안/실 IDs 재수집 (수정 흐름에서도 packs 다시 동기화)
    final ravelryStashIds = _resolveRavelryStashIds(project);
    final packs = ravelryStashIds
        .map((id) => <String, dynamic>{'stash_id': id})
        .toList();

    try {
      await ravelryRepo.updateProject(
        projectId: ravelryProjectId,
        name: project.title,
        notes: project.memo.trim(),
        statusTypeId: statusTypeId,
        packs: packs.isEmpty ? null : packs,
      );
      // 새 stash IDs를 ProjectModel에도 반영
      if (ravelryStashIds.isNotEmpty &&
          !_listEquals(ravelryStashIds, project.ravelryStashIds)) {
        await ref.read(projectRepositoryProvider).updateProject(
              project.copyWith(ravelryStashIds: ravelryStashIds),
            );
      }
    } catch (_) {
      // Ravelry 동기화 실패해도 모리니트 저장은 이미 성공이므로 무시
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}


// ──────────────────────────────────────────────────────────────────────────────
// 템플릿 단계로그 미리보기
// ──────────────────────────────────────────────────────────────────────────────
class _TemplateStepsPreview extends StatelessWidget {
  final bool isKorean;
  final BuiltinTemplate? builtinTemplate;
  final UserTemplate? userTemplate;
  // 이슈 #647 — AI 변환 도안 sections 미리보기 지원
  final PatternChart? patternChart;

  const _TemplateStepsPreview({
    required this.isKorean,
    this.builtinTemplate,
    this.userTemplate,
    this.patternChart,
  });

  List<String> get _steps {
    if (builtinTemplate != null) {
      return isKorean ? builtinTemplate!.stepsKo : builtinTemplate!.stepsEn;
    }
    if (userTemplate != null) return userTemplate!.stepTitles;
    // 이슈 #647 — AI 도안 섹션 제목을 단계 미리보기로 표시
    if (patternChart != null) {
      final sections = patternChart!.aiSections ?? const [];
      return [
        for (int i = 0; i < sections.length; i++)
          () {
            final s = sections[i];
            final title = isKorean ? (s.titleKo ?? s.title) : s.title;
            return title.trim().isEmpty
                ? (isKorean ? '섹션 ${i + 1}' : 'Section ${i + 1}')
                : title;
          }(),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: isKorean ? '단계로그 (저장 시 자동 생성)' : 'Steps (auto-created on save)'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: C.gx,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.bd),
          ),
          child: Column(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.lv,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(steps[i], style: T.sm.copyWith(color: C.tx)),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Divider(height: 1, color: C.bd),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _StyledField({required this.controller, required this.hint, required this.onChanged, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _BrandSearchField extends StatelessWidget {
  final String hint;
  final String value;
  final VoidCallback onTap;

  const _BrandSearchField({required this.hint, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bd2)),
        child: Row(
          children: [
            Expanded(child: Text(value.isEmpty ? hint : value, style: T.body.copyWith(color: value.isEmpty ? C.mu : C.tx))),
            Icon(Icons.search_rounded, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  final String photoUrl;
  final String? localPath;
  final bool uploading;
  final AppStrings t;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _CoverImagePicker({
    required this.photoUrl,
    this.localPath,
    required this.uploading,
    required this.t,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || photoUrl.isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: C.lvL,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.bd2),
                ),
                child: uploading
                    ? Center(child: CircularProgressIndicator(color: C.lv))
                    : hasPhoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: localPath != null
                                ? Image.file(File(localPath!), fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                                : Image.network(photoUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: C.lv, size: 40),
                              const SizedBox(height: 10),
                              Text(t.addCoverImage, style: T.bodyBold.copyWith(color: C.lvD)),
                              const SizedBox(height: 4),
                              Text(t.coverImageHint, style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
              ),
            ),
            // 이미지가 있을 때 우상단 버튼들 표시
            if (hasPhoto && !uploading) ...[
              // X 버튼 (이미지 제거)
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 48,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              // 변경 버튼
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final String selected;
  final bool isKorean;
  final ValueChanged<String> onSelected;

  const _StatusSelector({required this.selected, required this.isKorean, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProjectStatus.values.map((status) {
        final isSelected = selected == status.value;
        return GestureDetector(
          onTap: () => onSelected(status.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(
              status.localizedLabel(isKorean),
              style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : C.lvD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _YarnWeightSelector extends StatelessWidget {
  final String selected;
  final bool isKorean;
  final ValueChanged<String> onSelected;

  const _YarnWeightSelector({required this.selected, required this.isKorean, required this.onSelected});

  static const List<(String, String, String)> _weights = [
    ('lace', '레이스', 'Lace'),
    ('fingering', '핑거링', 'Fingering'),
    ('sport', '스포트', 'Sport'),
    ('dk', 'DK', 'DK'),
    ('worsted', '워스티드', 'Worsted'),
    ('bulky', '벌키', 'Bulky'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _weights.map((weight) {
        final isSelected = selected == weight.$1;
        return GestureDetector(
          onTap: () => onSelected(isSelected ? '' : weight.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? C.pk : C.pkL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.pk : C.pk.withValues(alpha: 0.20)),
            ),
            child: Text(
              isKorean ? weight.$2 : weight.$3,
              style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : C.pkD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NeedleSizeSelector extends StatelessWidget {
  final double selectedSize;
  final ValueChanged<double> onSelected;

  const _NeedleSizeSelector({required this.selectedSize, required this.onSelected});

  static const List<double> _sizes = [2.0, 2.5, 3.0, 3.25, 3.5, 3.75, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 8.0, 9.0, 10.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sizes.map((size) {
        final isSelected = selectedSize == size;
        final label = '${size.toStringAsFixed(1)}mm';
        return GestureDetector(
          onTap: () => onSelected(size),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : C.lvD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onSelected;

  const _DateField({required this.label, required this.date, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (dialogContext, child) => Theme(
            data: Theme.of(dialogContext).copyWith(colorScheme: ColorScheme.light(primary: C.lv)),
            child: child!,
          ),
        );
        onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bd2)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: C.mu, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? label : '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}',
                style: T.body.copyWith(color: date == null ? C.mu : C.tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchDropdown extends ConsumerWidget {
  final String selectedSwatchId;
  final bool isKorean;
  final ValueChanged<String> onChanged;

  const _SwatchDropdown({
    required this.selectedSwatchId,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swatchesAsync = ref.watch(swatchListProvider);
    final swatches = swatchesAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: swatches.any((s) => s.id == selectedSwatchId) ? selectedSwatchId : '',
          isExpanded: true,
          dropdownColor: C.bg,
          style: T.body.copyWith(color: C.tx),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                isKorean ? '연결 안 함' : 'No swatch linked',
                style: T.body.copyWith(color: C.mu),
              ),
            ),
            ...swatches.map((swatch) => DropdownMenuItem(
              value: swatch.id,
              child: Text(
                swatch.swatchName.isNotEmpty ? swatch.swatchName : swatch.yarnBrandName.isNotEmpty ? swatch.yarnBrandName : 'Swatch',
                style: T.body,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }
}

class _PatternDropdown extends ConsumerWidget {
  final String selectedPatternId;
  final bool isKorean;
  final ValueChanged<String> onChanged;

  const _PatternDropdown({
    required this.selectedPatternId,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(patternListProvider);
    final patterns = patternsAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: patterns.any((p) => p.id == selectedPatternId) ? selectedPatternId : '',
          isExpanded: true,
          dropdownColor: C.bg,
          style: T.body.copyWith(color: C.tx),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                isKorean ? '연결 안 함' : 'No pattern linked',
                style: T.body.copyWith(color: C.mu),
              ),
            ),
            ...patterns.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(
                p.title.isNotEmpty ? p.title : 'Untitled',
                style: T.body,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }
}

class _BookDropdown extends ConsumerWidget {
  final String selectedBookId;
  final bool isKorean;
  final ValueChanged<String> onChanged;

  const _BookDropdown({
    required this.selectedBookId,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookListProvider);
    final books = booksAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: books.any((b) => b.id == selectedBookId) ? selectedBookId : '',
          isExpanded: true,
          dropdownColor: C.bg,
          style: T.body.copyWith(color: C.tx),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                isKorean ? '연결 안 함' : 'No book linked',
                style: T.body.copyWith(color: C.mu),
              ),
            ),
            ...books.map((book) => DropdownMenuItem(
              value: book.id,
              child: Text(
                book.title.isNotEmpty ? book.title : 'ISBN: ${book.isbn}',
                style: T.body,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }
}

class _TemplateBanner extends StatelessWidget {
  final String templateType;
  const _TemplateBanner({required this.templateType});

  static const _info = <String, (IconData, String, String)>{
    'topdown': (Icons.dry_cleaning_rounded, '탑다운 스웨터', '8단계 가이드 자동 생성'),
    'crop_raglan_topdown': (Icons.checkroom_rounded, '크롭 레글런 탑다운', 'Banul 도안 기반 12단계 자동 생성'),
    'socks':   (Icons.hiking_rounded,         '양말',           '8단계 힐 가이드 자동 생성'),
    'scarf':   (Icons.ac_unit_rounded,        '목도리',         '5단계 가이드 자동 생성'),
    'gloves':  (Icons.back_hand_rounded,      '장갑',           '7단계 가이드 자동 생성'),
    'hat':     (Icons.face_rounded,           '모자',           '5단계 가이드 자동 생성'),
  };

  @override
  Widget build(BuildContext context) {
    final info = _info[templateType];
    if (info == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: C.lv.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.lv.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(info.$1, color: C.lvD, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${info.$2} 템플릿', style: T.bodyBold.copyWith(color: C.lvD)),
                const SizedBox(height: 2),
                Text(info.$3, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: C.lv, size: 18),
        ],
      ),
    );
  }
}
