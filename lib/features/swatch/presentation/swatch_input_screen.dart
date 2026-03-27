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
import '../../../providers/swatch_provider.dart';
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSwatch;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(swatchInputProvider.notifier).loadSwatch(initial);
        _memoController.text = initial.memo;
      });
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.swatchId == null ? (isKorean ? '새 스와치' : 'New Swatch') : (isKorean ? '스와치 수정' : 'Edit Swatch'), style: T.h3),
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
                  : Text(widget.swatchId == null ? (isKorean ? '스와치 저장' : 'Save Swatch') : (isKorean ? '스와치 업데이트' : 'Update Swatch')),
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
                MoriBrandHeader(
                  logoSize: 72,
                  titleSize: 24,
                  subtitle: isKorean
                      ? '게이지와 실, 바늘, 사진을 한곳에 기록해두세요.'
                      : 'Capture your gauge, yarn, needle, and photo in one place.',
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '세탁 전 게이지' : 'Gauge Before Wash'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GaugeInput(
                              label: isKorean ? '코' : 'Stitches',
                              value: swatch.beforeStitchCount,
                              onMinus: () => notifier.updateBeforeStitchCount((swatch.beforeStitchCount - 1).clamp(0, 999)),
                              onPlus: () => notifier.updateBeforeStitchCount((swatch.beforeStitchCount + 1).clamp(0, 999)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GaugeInput(
                              label: isKorean ? '단' : 'Rows',
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
                        title: isKorean ? '세탁 후 게이지' : 'Gauge After Wash',
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
                                label: isKorean ? '코' : 'Stitches',
                                value: swatch.afterStitchCount,
                                color: C.pk,
                                onMinus: () => notifier.updateAfterStitchCount((swatch.afterStitchCount - 1).clamp(0, 999)),
                                onPlus: () => notifier.updateAfterStitchCount((swatch.afterStitchCount + 1).clamp(0, 999)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GaugeInput(
                                label: isKorean ? '단' : 'Rows',
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
                          label: isKorean
                              ? '수축률 ${swatch.calculateShrinkageRate().toStringAsFixed(1)}%'
                              : 'Shrinkage ${swatch.calculateShrinkageRate().toStringAsFixed(1)}%',
                          type: ChipType.pink,
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
                      SectionTitle(title: isKorean ? '바늘 정보' : 'Needle'),
                      const SizedBox(height: 12),
                      _NeedleSizeWrap(selectedSize: swatch.needleSize, onSelected: notifier.updateNeedleSize),
                      const SizedBox(height: 12),
                      _PickerField(
                        label: isKorean ? '바늘 브랜드' : 'Needle Brand',
                        value: swatch.needleBrandName,
                        hint: isKorean ? '바늘 브랜드 검색 또는 직접 입력' : 'Search or enter a needle brand',
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
                      SectionTitle(title: isKorean ? '실 정보' : 'Yarn'),
                      const SizedBox(height: 12),
                      _PickerField(
                        label: isKorean ? '실 브랜드' : 'Yarn Brand',
                        value: swatch.yarnBrandName,
                        hint: isKorean ? '실 브랜드 검색 또는 직접 입력' : 'Search or enter a yarn brand',
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
                  photoUrl: swatch.beforePhotoUrl,
                  isKorean: isKorean,
                  onPhotoSelected: notifier.updateBeforePhotoUrl,
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '메모' : 'Memo'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _memoController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: isKorean ? '질감, 세탁, 블로킹, 다음 작업 참고 메모' : 'Notes about texture, blocking, yarn feel, or future reference',
                        ),
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
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) {
      _showLoginRequired(context, isKorean);
      return;
    }

    final gates = ref.read(featureGatesProvider);
    final count = ref.read(swatchCountProvider);
    if (!gates.canAddSwatch(count) && widget.swatchId == null) {
      _showLimitDialog(context, gates.swatchLimitMessage(count), isKorean);
      return;
    }

    final notifier = ref.read(swatchInputProvider.notifier);
    final error = notifier.validationError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: C.og));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final repository = ref.read(swatchRepositoryProvider);
      final swatch = ref.read(swatchInputProvider).copyWith(uid: authUser.uid);

      if (widget.swatchId != null) {
        await repository.updateSwatch(swatch);
      } else {
        await repository.createSwatch(swatch);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.swatchId == null ? (isKorean ? '스와치를 저장했어요.' : 'Swatch saved.') : (isKorean ? '스와치를 업데이트했어요.' : 'Swatch updated.')),
          backgroundColor: C.lv,
        ),
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(isKorean ? '스와치 저장에 실패했어요: $error' : 'Failed to save swatch: $error'),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLoginRequired(BuildContext context, bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKorean ? '로그인이 필요해요' : 'Login required', style: T.h3),
        content: Text(isKorean ? '스와치를 저장하려면 먼저 로그인해주세요.' : 'Please sign in before saving a swatch.', style: T.body),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(isKorean ? '닫기' : 'Close'))],
      ),
    );
  }

  void _showLimitDialog(BuildContext context, String message, bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKorean ? '스와치 한도 도달' : 'Swatch limit reached', style: T.h3),
        content: Text(message, style: T.body),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(isKorean ? '닫기' : 'Close'))],
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
                const Icon(Icons.search_rounded, color: C.mu, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoSection extends StatefulWidget {
  final String photoUrl;
  final bool isKorean;
  final ValueChanged<String> onPhotoSelected;

  const _PhotoSection({required this.photoUrl, required this.isKorean, required this.onPhotoSelected});

  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  bool _uploading = false;
  String? _localPath;

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
          content: Text(widget.isKorean ? '이미지 업로드에 실패했어요: $error' : 'Failed to upload image: $error'),
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
              leading: const Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(widget.isKorean ? '갤러리에서 선택' : 'Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(widget.isKorean ? '카메라로 촬영' : 'Take photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            if (widget.photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: C.og),
                title: Text(widget.isKorean ? '사진 제거' : 'Remove photo'),
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
          SectionTitle(title: widget.isKorean ? '사진' : 'Photo'),
          const SizedBox(height: 8),
          Text(
            widget.isKorean ? '사진을 남겨두면 질감과 게이지를 나중에 비교하기 쉬워져요.' : 'A photo makes it easier to compare texture and gauge later.',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showPickerMenu,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd2)),
              child: _uploading
                  ? const Center(child: CircularProgressIndicator(color: C.lv))
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
                            const Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 34),
                            const SizedBox(height: 8),
                            Text(widget.isKorean ? '스와치 사진 추가' : 'Add a swatch photo', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
