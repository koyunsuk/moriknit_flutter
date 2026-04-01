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
  late final TextEditingController _priceCtrl;
  late final TextEditingController _purchasePlaceCtrl;
  late final TextEditingController _nameCtrl;
  String? _localPhotoPath;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final needle = widget.initialNeedle;
    _memoCtrl = TextEditingController(text: needle?.memo ?? '');
    _priceCtrl = TextEditingController(text: needle != null && needle.price > 0 ? '${needle.price}' : '');
    _purchasePlaceCtrl = TextEditingController(text: needle?.purchasePlace ?? '');
    _nameCtrl = TextEditingController(text: needle?.name ?? '');
    // 버그 수정: 기존 사진 URL 초기화
    _photoUrl = needle?.photoUrl.isNotEmpty == true ? needle!.photoUrl : null;

    if (needle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(needleInputProvider.notifier).load(needle);
      });
    }
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePlaceCtrl.dispose();
    _nameCtrl.dispose();
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
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialNeedle == null
              ? (isKorean ? '바늘 추가' : 'Add Needle')
              : (isKorean ? '바늘 수정' : 'Edit Needle'),
          style: T.h3,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _save(context, t),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isKorean ? '저장' : 'Save'),
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
                SectionTitle(title: isKorean ? '바늘 사이즈 *' : 'Needle size *'),
                const SizedBox(height: 10),
                _NeedleSizeSelector(
                  selectedSize: needle.size,
                  onSelected: notifier.setSize,
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '종류' : 'Type'),
                const SizedBox(height: 10),
                _SegmentedSelector(
                  options: [
                    ('straight', isKorean ? '일반 바늘' : 'Straight'),
                    ('circular', isKorean ? '줄바늘' : 'Circular'),
                    ('dpn', isKorean ? '막대바늘' : 'Double-pointed'),
                    ('interchangeable', isKorean ? '조립식바늘' : 'Interchangeable'),
                    ('cable', isKorean ? '케이블 바늘' : 'Cable'),
                  ],
                  selected: needle.type,
                  color: C.lv,
                  onSelected: notifier.setType,
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '재질' : 'Material'),
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
                SectionTitle(title: isKorean ? '브랜드 (선택)' : 'Brand (optional)'),
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
                SectionTitle(title: isKorean ? '바늘 이름 (선택)' : 'Needle name (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  onChanged: notifier.setName,
                  decoration: InputDecoration(
                    labelText: isKorean ? '예: Karbonz, Nova Metal' : 'e.g. Karbonz, Nova Metal',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '수량' : 'Quantity'),
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
                SectionTitle(title: isKorean ? '구입가격 (선택)' : 'Price (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => notifier.setPrice(int.tryParse(v) ?? 0),
                  decoration: InputDecoration(
                    labelText: isKorean ? '예: 15000' : 'e.g. 15000',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '구입처 (선택)' : 'Purchase place (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _purchasePlaceCtrl,
                  onChanged: notifier.setPurchasePlace,
                  decoration: InputDecoration(
                    labelText: isKorean ? '예: 뜨개나라, 네이버쇼핑' : 'e.g. Yarn store, Online',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: t.needlePhoto),
                const SizedBox(height: 8),
                _NeedlePhotoSection(
                  t: t,
                  localPhotoPath: _localPhotoPath,
                  existingPhotoUrl: _photoUrl,
                  onTap: _pickNeedlePhoto,
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '메모 (선택)' : 'Memo (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoCtrl,
                  maxLines: 2,
                  onChanged: notifier.setMemo,
                  decoration: InputDecoration(
                    labelText: isKorean ? '색상, 길이, 특이사항...' : 'Color, length, notes...',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '구입일 (선택)' : 'Purchase date (optional)'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: needle.purchaseDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) notifier.setPurchaseDate(picked);
                  },
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
                        Expanded(
                          child: Text(
                            needle.purchaseDate != null
                                ? '${needle.purchaseDate!.year}.${needle.purchaseDate!.month.toString().padLeft(2, '0')}.${needle.purchaseDate!.day.toString().padLeft(2, '0')}'
                                : (isKorean ? '구입일 선택' : 'Select purchase date'),
                            style: needle.purchaseDate != null
                                ? T.body
                                : T.body.copyWith(color: C.mu),
                          ),
                        ),
                        if (needle.purchaseDate != null)
                          GestureDetector(
                            onTap: () => notifier.setPurchaseDate(null),
                            child: Icon(Icons.clear_rounded, color: C.mu, size: 18),
                          )
                        else
                          Icon(Icons.calendar_today_rounded, color: C.mu, size: 18),
                      ],
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

  Future<void> _pickNeedlePhoto() async {
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
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
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
      children: [
        // 셋트 옵션
        GestureDetector(
          onTap: () => onSelected(0.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selectedSize == 0.0 ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selectedSize == 0.0 ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(
              '셋트',
              style: TextStyle(
                fontSize: 13,
                color: selectedSize == 0.0 ? Colors.white : C.lvD,
                fontWeight: selectedSize == 0.0 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
        ..._sizes.map((size) {
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
        }),
      ],
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
  final String? existingPhotoUrl;
  final VoidCallback onTap;

  const _NeedlePhotoSection({
    required this.t,
    required this.localPhotoPath,
    required this.onTap,
    this.existingPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (localPhotoPath != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(localPhotoPath!), fit: BoxFit.cover, width: double.infinity),
      );
    } else if (existingPhotoUrl != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(existingPhotoUrl!, fit: BoxFit.cover, width: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox()),
      );
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 34),
          const SizedBox(height: 8),
          Text(t.addNeedlePhoto, style: T.caption.copyWith(color: C.mu)),
        ],
      );
    }

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
        child: child,
      ),
    );
  }
}
