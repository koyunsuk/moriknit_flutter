import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../my/data/mori_service.dart';
import '../domain/swatch_model.dart';
import 'brand_search_sheet.dart';

class SwatchInputScreen extends ConsumerStatefulWidget {
  final String? swatchId;
  final SwatchModel? initialSwatch;

  const SwatchInputScreen({super.key, this.swatchId, this.initialSwatch});

  @override
  ConsumerState<SwatchInputScreen> createState() => _SwatchInputScreenState();
}

class _SwatchInputScreenState extends ConsumerState<SwatchInputScreen> {
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSwatch;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(swatchInputProvider.notifier).loadSwatch(initial);
        _memoController.text = initial.memo;
        _nameController.text = initial.swatchName;
      });
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatch = ref.watch(swatchInputProvider);
    final notifier = ref.read(swatchInputProvider.notifier);

    if (_memoController.text != swatch.memo) {
      _memoController.value = TextEditingValue(
        text: swatch.memo,
        selection: TextSelection.collapsed(offset: swatch.memo.length),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.swatchId == null ? t.newSwatch : t.editSwatch, style: T.h3),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _save(context),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.swatchId == null ? t.saveSwatch : t.updateSwatch),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoriBrandHeader(subtitle: t.swatchHeaderSubtitle),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '이름 (닉네임)' : 'Name (nickname)'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '스와치 이름 (선택)' : 'Swatch name (optional)',
                          hintText: isKorean ? '예: 핑크 메리노 테스트' : 'e.g. Pink Merino Test',
                        ),
                        onChanged: notifier.updateSwatchName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ProjectLinkCard(
                  selectedProjectId: swatch.projectId,
                  onChanged: notifier.updateProjectId,
                  isKorean: isKorean,
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: t.gaugeBeforeWash),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GaugeInput(
                              label: t.stitches,
                              value: swatch.beforeStitchCount,
                              onMinus: () => notifier.updateBeforeStitchCount((swatch.beforeStitchCount - 1).clamp(0, 999)),
                              onPlus: () => notifier.updateBeforeStitchCount((swatch.beforeStitchCount + 1).clamp(0, 999)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GaugeInput(
                              label: t.rows,
                              value: swatch.beforeRowCount,
                              onMinus: () => notifier.updateBeforeRowCount((swatch.beforeRowCount - 1).clamp(0, 999)),
                              onPlus: () => notifier.updateBeforeRowCount((swatch.beforeRowCount + 1).clamp(0, 999)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        title: t.gaugeAfterWash,
                        trailing: Switch(
                          value: swatch.hasAfterWash,
                          activeThumbColor: C.lv,
                          onChanged: notifier.toggleAfterWash,
                        ),
                      ),
                      if (swatch.hasAfterWash) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GaugeInput(
                                label: t.stitches,
                                value: swatch.afterStitchCount,
                                color: C.pk,
                                onMinus: () => notifier.updateAfterStitchCount((swatch.afterStitchCount - 1).clamp(0, 999)),
                                onPlus: () => notifier.updateAfterStitchCount((swatch.afterStitchCount + 1).clamp(0, 999)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GaugeInput(
                                label: t.rows,
                                value: swatch.afterRowCount,
                                color: C.pk,
                                onMinus: () => notifier.updateAfterRowCount((swatch.afterRowCount - 1).clamp(0, 999)),
                                onPlus: () => notifier.updateAfterRowCount((swatch.afterRowCount + 1).clamp(0, 999)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        MoriChip(
                          label: t.shrinkageLabel(swatch.calculateShrinkageRate()),
                          type: ChipType.pink,
                        ),
                        const SizedBox(height: 14),
                        _PhotoSection(
                          title: t.afterWashPhoto,
                          addLabel: t.addAfterWashPhoto,
                          photoUrl: swatch.afterPhotoUrl,
                          t: t,
                          onPhotoSelected: notifier.updateAfterPhotoUrl,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: t.needleInfo),
                      const SizedBox(height: 12),
                      _NeedleSizeWrap(selectedSize: swatch.needleSize, onSelected: notifier.updateNeedleSize),
                      const SizedBox(height: 12),
                      _PickerField(
                        label: t.needleBrand,
                        value: swatch.needleBrandName,
                        hint: t.needleBrandHint,
                        onTap: () => BrandSearchSheet.show(
                          context,
                          brandType: BrandType.needle,
                          onSelected: notifier.updateNeedleBrand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: t.yarnInfo),
                      const SizedBox(height: 12),
                      _PickerField(
                        label: t.yarnBrand,
                        value: swatch.yarnBrandName,
                        hint: t.yarnBrandHintSwatch,
                        onTap: () => BrandSearchSheet.show(
                          context,
                          brandType: BrandType.yarn,
                          onSelected: notifier.updateYarnBrand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _PhotoSection(
                  title: t.photo,
                  addLabel: t.addSwatchPhoto,
                  photoUrl: swatch.beforePhotoUrl,
                  t: t,
                  onPhotoSelected: notifier.updateBeforePhotoUrl,
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: t.memo),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _memoController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(hintText: t.memoHintSwatch),
                        onChanged: notifier.updateMemo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final t = ref.read(appStringsProvider);
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) {
      _showLoginRequired(context);
      return;
    }

    final gates = ref.read(featureGatesProvider);
    final count = ref.read(swatchCountProvider);
    if (!gates.canAddSwatch(count) && widget.swatchId == null) {
      _showLimitDialog(context, gates.swatchLimitMessage(count));
      return;
    }

    final notifier = ref.read(swatchInputProvider.notifier);
    final error = notifier.validationError;
    if (error != null) {
      final isKorean = ref.read(appLanguageProvider).isKorean;
      await showMissingFieldsDialog(context, missing: [error], isKorean: isKorean);
      return;
    }

    setState(() => _isSaving = true);
    final ctx = context;
    final navigator = Navigator.of(ctx);

    try {
      final repository = ref.read(swatchRepositoryProvider);
      final swatch = ref.read(swatchInputProvider).copyWith(uid: authUser.uid);

      await runWithMoriLoadingDialog<void>(
        ctx,
        message: widget.swatchId == null ? t.saveSwatch : t.updateSwatch,
        subtitle: t.pleaseWaitMoment,
        task: () async {
          if (widget.swatchId != null) {
            await repository.updateSwatch(swatch);
          } else {
            await repository.createSwatch(swatch);
            MoriService.earn(authUser.uid, amount: 100, reason: 'swatch_save');
          }
        },
      );

      if (!ctx.mounted) return;
      showSavedSnackBar(ctx, message: widget.swatchId == null ? t.swatchSaved : t.swatchUpdated);
      navigator.pop();
    } catch (error) {
      if (!ctx.mounted) return;
      showSaveErrorSnackBar(ctx, message: t.failedToSaveSwatch(error.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLoginRequired(BuildContext context) {
    final t = ref.read(appStringsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.loginRequiredDialogTitle, style: T.h3),
        content: Text(t.saveSwatchLoginRequired, style: T.body),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.close))],
      ),
    );
  }

  void _showLimitDialog(BuildContext context, String message) {
    final t = ref.read(appStringsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.swatchLimitReached, style: T.h3),
        content: Text(message, style: T.body),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.close))],
      ),
    );
  }
}

class _ProjectLinkCard extends ConsumerWidget {
  final String selectedProjectId;
  final ValueChanged<String> onChanged;
  final bool isKorean;

  const _ProjectLinkCard({
    required this.selectedProjectId,
    required this.onChanged,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);
    final projects = projectsAsync.valueOrNull ?? [];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: isKorean ? '프로젝트 연결 (선택)' : 'Link project (optional)'),
          const SizedBox(height: 10),
          DropdownButton<String>(
            value: selectedProjectId.isEmpty ? '' : selectedProjectId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem<String>(
                value: '',
                child: Text(isKorean ? '연결 안 함' : 'No project', style: T.body.copyWith(color: C.mu)),
              ),
              ...projects.map((p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.title, style: T.body, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (value) => onChanged(value ?? ''),
          ),
        ],
      ),
    );
  }
}

class _NeedleSizeWrap extends StatelessWidget {
  final double selectedSize;
  final ValueChanged<double> onSelected;

  const _NeedleSizeWrap({required this.selectedSize, required this.onSelected});

  static const List<double> _sizes = <double>[2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sizes.map((size) {
        final isSelected = size == selectedSize;
        final label = size % 1 == 0 ? '${size.toInt()} mm' : '$size mm';
        return MoriChip(
          label: label,
          type: isSelected ? ChipType.lavender : ChipType.white,
          onTap: () => onSelected(size),
        );
      }).toList(),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.captionBold.copyWith(color: C.mu)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value.isEmpty ? hint : value, style: value.isEmpty ? T.body.copyWith(color: C.mu) : T.body)),
                Icon(Icons.search_rounded, color: C.mu, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoSection extends StatefulWidget {
  final String title;
  final String addLabel;
  final String photoUrl;
  final AppStrings t;
  final ValueChanged<String> onPhotoSelected;

  const _PhotoSection({
    required this.title,
    required this.addLabel,
    required this.photoUrl,
    required this.t,
    required this.onPhotoSelected,
  });

  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  bool _uploading = false;
  String? _localPath;

  AppStrings get t => widget.t;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _localPath = picked.path;
      _uploading = true;
    });

    try {
      final file = File(picked.path);
      final reference = FirebaseStorage.instance.ref().child('swatches/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final task = await reference.putFile(file);
      final url = await task.ref.getDownloadURL();
      widget.onPhotoSelected(url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.failedToUploadImage(error.toString())),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPickerMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(t.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(t.takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            if (widget.photoUrl.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline, color: C.og),
                title: Text(t.removePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _localPath = null);
                  widget.onPhotoSelected('');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _localPath != null || widget.photoUrl.isNotEmpty;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: widget.title),
          const SizedBox(height: 8),
          Text(t.photoHelpText, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showPickerMenu,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd2)),
              child: _uploading
                  ? Center(child: CircularProgressIndicator(color: C.lv))
                  : hasPhoto
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _localPath != null
                              ? Image.file(File(_localPath!), fit: BoxFit.cover, width: double.infinity)
                              : Image.network(widget.photoUrl, fit: BoxFit.cover, width: double.infinity),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 34),
                            const SizedBox(height: 8),
                            Text(widget.addLabel, style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
