import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../domain/project_model.dart';
import '../../swatch/presentation/brand_search_sheet.dart';

class ProjectInputScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final ProjectModel? initialProject;

  const ProjectInputScreen({super.key, this.projectId, this.initialProject});

  @override
  ConsumerState<ProjectInputScreen> createState() => _ProjectInputScreenState();
}

class _ProjectInputScreenState extends ConsumerState<ProjectInputScreen> {
  bool _isSaving = false;
  bool _uploading = false;
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
    final project = ref.watch(projectInputProvider);
    final notifier = ref.read(projectInputProvider.notifier);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.projectId == null ? (isKorean ? '새 프로젝트' : 'New Project') : (isKorean ? '프로젝트 수정' : 'Edit Project'), style: T.h3),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _save(context),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: C.lv),
                  )
                : Text(isKorean ? '저장' : 'Save', style: T.bodyBold.copyWith(color: C.lv)),
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
                _CoverImagePicker(
                  photoUrl: project.coverPhotoUrl,
                  localPath: _localCoverPath,
                  uploading: _uploading,
                  isKorean: isKorean,
                  onTap: () => _pickCover(notifier),
                ),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '프로젝트 이름 *' : 'Project title *'),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _titleController,
                  hint: isKorean ? '작품 이름을 입력해주세요' : 'Enter a project title',
                  onChanged: notifier.setTitle,
                ),
                const SizedBox(height: 16),
                _SectionLabel(isKorean ? '설명' : 'Description'),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _descriptionController,
                  hint: isKorean ? '어떤 작품인지 간단히 적어주세요' : 'Add a short project description',
                  maxLines: 2,
                  onChanged: notifier.setDescription,
                ),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '상태' : 'Status'),
                const SizedBox(height: 10),
                _StatusSelector(selected: project.status, isKorean: isKorean, onSelected: notifier.setStatus),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '실 정보' : 'Yarn information'),
                const SizedBox(height: 8),
                _BrandSearchField(
                  hint: isKorean ? '실 브랜드 검색 또는 직접 입력' : 'Search or enter a yarn brand',
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
                        hint: isKorean ? '실 이름' : 'Yarn name',
                        onChanged: notifier.setYarnName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StyledField(
                        controller: _yarnColorController,
                        hint: isKorean ? '색상' : 'Color',
                        onChanged: notifier.setYarnColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _YarnWeightSelector(selected: project.yarnWeight, isKorean: isKorean, onSelected: notifier.setYarnWeight),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '바늘 사이즈' : 'Needle size'),
                const SizedBox(height: 10),
                _NeedleSizeSelector(selectedSize: project.needleSize, onSelected: notifier.setNeedleSize),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '일정' : 'Timeline'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: isKorean ? '시작일' : 'Start date',
                        date: project.startDate,
                        onSelected: notifier.setStartDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: isKorean ? '목표일' : 'Target date',
                        date: project.targetDate,
                        onSelected: notifier.setTargetDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionLabel(isKorean ? '메모' : 'Memo'),
                const SizedBox(height: 8),
                _StyledField(
                  controller: _memoController,
                  hint: isKorean ? '패턴 출처, 수정 사항, 참고 메모를 남겨보세요' : 'Add pattern notes, revisions, or reminders',
                  maxLines: 3,
                  onChanged: notifier.setMemo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      final isKorean = ref.read(appLanguageProvider).isKorean;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean ? '커버 이미지 업로드에 실패했어요: $error' : 'Failed to upload cover image: $error'),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(isKorean ? '카메라로 촬영' : 'Take photo', style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: C.og));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final project = ref.read(projectInputProvider);
      final repository = ref.read(projectRepositoryProvider);

      if (widget.projectId != null) {
        await repository.updateProject(project);
      } else {
        await repository.createProject(project.copyWith(uid: user.uid));
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(isKorean ? '프로젝트를 저장했어요.' : 'Project saved.'),
          backgroundColor: C.lv,
        ),
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(isKorean ? '저장에 실패했어요: $error' : 'Failed to save project: $error'),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600, letterSpacing: 0.5));
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
        hintStyle: T.body.copyWith(color: C.mu),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.bd2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.lv)),
        filled: true,
        fillColor: C.gx,
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
            const Icon(Icons.search_rounded, color: C.mu, size: 18),
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
  final bool isKorean;
  final VoidCallback onTap;

  const _CoverImagePicker({required this.photoUrl, this.localPath, required this.uploading, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.bd2)),
          child: uploading
              ? const Center(child: CircularProgressIndicator(color: C.lv))
              : hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: localPath != null
                          ? Image.file(File(localPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                          : Image.network(photoUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: C.lv, size: 40),
                        const SizedBox(height: 10),
                        Text(isKorean ? '커버 사진 추가' : 'Add cover image', style: T.bodyBold.copyWith(color: C.lvD)),
                        const SizedBox(height: 4),
                        Text(isKorean ? '가로형 사진이 가장 자연스럽게 보여요.' : 'Landscape images look best here.', style: T.caption.copyWith(color: C.mu)),
                      ],
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(
              status.localizedLabel(isKorean),
              style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : C.lvD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? C.pk : C.pkL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.pk : C.pk.withValues(alpha: 0.20)),
            ),
            child: Text(
              isKorean ? weight.$2 : weight.$3,
              style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : C.pkD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
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
        final label = size % 1 == 0 ? '${size.toInt()}mm' : '${size}mm';
        return GestureDetector(
          onTap: () => onSelected(size),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : C.lvD, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
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
            data: Theme.of(dialogContext).copyWith(colorScheme: const ColorScheme.light(primary: C.lv)),
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
            const Icon(Icons.calendar_today_outlined, color: C.mu, size: 16),
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
