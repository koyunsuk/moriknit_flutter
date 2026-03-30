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
import '../../../providers/needle_provider.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../domain/needle_model.dart';

class NeedleInputScreen extends ConsumerStatefulWidget {
  final NeedleModel? initialNeedle;

  const NeedleInputScreen({super.key, this.initialNeedle});

  @override
  ConsumerState<NeedleInputScreen> createState() => _NeedleInputScreenState();
}

class _NeedleInputScreenState extends ConsumerState<NeedleInputScreen> {
  bool _isSaving = false;
  late final TextEditingController _memoCtrl;
  String? _localPhotoPath;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final needle = widget.initialNeedle;
    _memoCtrl = TextEditingController(text: needle?.memo ?? '');

    if (needle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(needleInputProvider.notifier).load(needle);
      });
    }
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = ref.watch(needleInputProvider);
    final notifier = ref.read(needleInputProvider.notifier);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final t = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: widget.initialNeedle == null ? t.addNeedle : (isKorean ? '바늘 수정' : 'Edit needle'),
                subtitle: t.manageNeedles,
                trailing: [
                  MoriChip(label: t.needleLibrary, type: ChipType.lavender),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(isKorean ? '바늘 사이즈 *' : 'Needle size *'),
                    const SizedBox(height: 10),
                    _NeedleSizeSelector(
                      selectedSize: needle.size,
                      onSelected: notifier.setSize,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(isKorean ? '종류' : 'Type'),
                    const SizedBox(height: 10),
                    _SegmentedSelector(
                      options: [
                        ('straight', isKorean ? '일반 바늘' : 'Straight'),
                        ('circular', isKorean ? '줄바늘' : 'Circular'),
                        ('dpn', isKorean ? '양두 바늘' : 'Double-pointed'),
                        ('cable', isKorean ? '케이블 바늘' : 'Cable'),
                      ],
                      selected: needle.type,
                      color: C.lv,
                      onSelected: notifier.setType,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(isKorean ? '재질' : 'Material'),
                    const SizedBox(height: 10),
                    _SegmentedSelector(
                      options: [
                        ('bamboo', isKorean ? '대나무' : 'Bamboo'),
                        ('metal', isKorean ? '금속' : 'Metal'),
                        ('wood', isKorean ? '나무' : 'Wood'),
                        ('plastic', isKorean ? '플라스틱' : 'Plastic'),
                      ],
                      selected: needle.material,
                      color: C.pk,
                      onSelected: notifier.setMaterial,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(isKorean ? '브랜드 (선택)' : 'Brand (optional)'),
                    const SizedBox(height: 8),
                    _PickerField(
                      label: t.needleBrand,
                      value: needle.brandName,
                      hint: t.needleBrandHint,
                      onTap: () => BrandSearchSheet.show(
                        context,
                        brandType: BrandType.needle,
                        onSelected: (_, name) => notifier.setBrand(name),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(isKorean ? '수량' : 'Quantity'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QuantityButton(
                          icon: Icons.remove,
                          onTap: () {
                            if (needle.quantity > 1) {
                              notifier.setQuantity(needle.quantity - 1);
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(
                          isKorean ? '${needle.quantity}개' : '${needle.quantity}',
                          style: T.bodyBold,
                        ),
                        const SizedBox(width: 16),
                        _QuantityButton(
                          icon: Icons.add,
                          filled: true,
                          onTap: () => notifier.setQuantity(needle.quantity + 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(t.needlePhoto),
                    const SizedBox(height: 8),
                    _NeedlePhotoSection(
                      t: t,
                      localPhotoPath: _localPhotoPath,
                      onTap: _pickNeedlePhoto,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(isKorean ? '메모 (선택)' : 'Memo (optional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _memoCtrl,
                      maxLines: 2,
                      onChanged: notifier.setMemo,
                      decoration: _inputDecoration(
                        isKorean ? '색상, 길이, 특이사항...' : 'Color, length, notes...',
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _save(context, t),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(t.save),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: T.body.copyWith(color: C.mu),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: C.bd2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: C.lv),
      ),
      filled: true,
      fillColor: C.gx,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _pickNeedlePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (picked == null) return;
    setState(() {
      _localPhotoPath = picked.path;
    });
  }

  Future<void> _save(BuildContext context, AppStrings t) async {
    final notifier = ref.read(needleInputProvider.notifier);
    final error = notifier.validationError;
    if (error != null) {
      final isKorean = ref.read(appLanguageProvider).isKorean;
      await showMissingFieldsDialog(context, missing: [error], isKorean: isKorean);
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: t.save,
        subtitle: t.pleaseWaitMoment,
        task: () async {
          if (_localPhotoPath != null) {
            final file = File(_localPhotoPath!);
            final refPath = FirebaseStorage.instance.ref().child('needles/${DateTime.now().millisecondsSinceEpoch}.jpg');
            await refPath.putFile(file);
            _photoUrl = await refPath.getDownloadURL();
          }

          final needle = ref.read(needleInputProvider);
          final repository = ref.read(needleRepositoryProvider);

          if (widget.initialNeedle != null) {
            await repository.updateNeedle(needle, photoUrl: _photoUrl);
          } else {
            await repository.createNeedle(needle, photoUrl: _photoUrl);
          }
        },
      );

      if (mounted) navigator.pop();
    } catch (_) {
      // runWithSaveFeedback handles error snackbar
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
    return Text(
      text,
      style: T.caption.copyWith(
        color: C.mu,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _NeedleSizeSelector extends StatelessWidget {
  final double selectedSize;
  final ValueChanged<double> onSelected;

  const _NeedleSizeSelector({
    required this.selectedSize,
    required this.onSelected,
  });

  static const List<double> _sizes = [
    2.0,
    2.5,
    3.0,
    3.25,
    3.5,
    3.75,
    4.0,
    4.5,
    5.0,
    5.5,
    6.0,
    6.5,
    7.0,
    8.0,
    9.0,
    10.0,
    12.0,
  ];

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : C.lvD,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SegmentedSelector extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  const _SegmentedSelector({
    required this.options,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option.$1;
        return GestureDetector(
          onTap: () => onSelected(option.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.20)),
            ),
            child: Text(
              option.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: filled ? Colors.white : C.lv, size: 20),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

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

class _NeedlePhotoSection extends StatelessWidget {
  final AppStrings t;
  final String? localPhotoPath;
  final VoidCallback onTap;

  const _NeedlePhotoSection({
    required this.t,
    required this.localPhotoPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.bd2),
        ),
        child: localPhotoPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(localPhotoPath!), fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 34),
                  const SizedBox(height: 8),
                  Text(t.addNeedlePhoto, style: T.caption.copyWith(color: C.mu)),
                ],
              ),
      ),
    );
  }
}
