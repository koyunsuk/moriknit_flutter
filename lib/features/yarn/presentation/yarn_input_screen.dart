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
import '../../../providers/yarn_provider.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../domain/yarn_model.dart';
import 'yarn_color_sheet.dart';
import 'yarn_material_sheet.dart';

class YarnInputScreen extends ConsumerStatefulWidget {
  final String? yarnId;
  final YarnModel? initialYarn;

  const YarnInputScreen({super.key, this.yarnId, this.initialYarn});

  @override
  ConsumerState<YarnInputScreen> createState() => _YarnInputScreenState();
}

class _YarnInputScreenState extends ConsumerState<YarnInputScreen> {
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _yarnLengthController = TextEditingController();
  final _lotNumberController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchasePlaceController = TextEditingController();
  bool _isSaving = false;
  bool _uploading = false;
  String? _localPhotoPath;

  static const List<String> _weightOptions = [
    'Lace', 'Fingering', 'Sport', 'DK', 'Worsted', 'Bulky', 'Super Bulky',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialYarn;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(yarnInputProvider.notifier).loadYarn(initial);
        _nameController.text = initial.name;
        _colorController.text = initial.color;
        _amountController.text = initial.amountGrams > 0 ? '${initial.amountGrams}' : '';
        _memoController.text = initial.memo;
        _yarnLengthController.text = initial.yarnLength;
        _lotNumberController.text = initial.lotNumber;
        _priceController.text = initial.price > 0 ? '${initial.price}' : '';
        _purchasePlaceController.text = initial.purchasePlace;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _yarnLengthController.dispose();
    _lotNumberController.dispose();
    _priceController.dispose();
    _purchasePlaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final yarn = ref.watch(yarnInputProvider);
    final notifier = ref.read(yarnInputProvider.notifier);

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
          widget.yarnId == null
              ? (isKorean ? '실 추가' : 'Add Yarn')
              : (isKorean ? '실 수정' : 'Edit Yarn'),
          style: T.h3,
        ),
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
                  : Text(widget.yarnId == null
                      ? (isKorean ? '저장' : 'Save')
                      : (isKorean ? '수정' : 'Update')),
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
                // 사진
                _YarnPhotoPicker(
                  photoUrl: yarn.photoUrl,
                  localPath: _localPhotoPath,
                  uploading: _uploading,
                  isKorean: isKorean,
                  onTap: () => _pickPhoto(notifier),
                ),
                const SizedBox(height: 14),
                // 브랜드명
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '브랜드' : 'Brand'),
                      const SizedBox(height: 10),
                      _PickerField(
                        label: isKorean ? '브랜드명' : 'Brand name',
                        value: yarn.brandName,
                        hint: isKorean ? '브랜드를 검색하거나 직접 입력하세요' : 'Search or enter brand name',
                        onTap: () => BrandSearchSheet.show(
                          context,
                          brandType: BrandType.yarn,
                          onSelected: (_, name) => notifier.updateBrandName(name),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 실 이름
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '실 정보' : 'Yarn Info'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '실 이름' : 'Yarn name',
                          hintText: isKorean ? '예: 메리노 엑스트라 파인' : 'e.g. Merino Extra Fine',
                        ),
                        onChanged: notifier.updateName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 소재
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '소재' : 'Material'),
                      const SizedBox(height: 10),
                      _PickerField(
                        label: isKorean ? '소재 선택' : 'Select material',
                        value: yarn.material,
                        hint: isKorean ? '소재를 선택하세요' : 'Select a material',
                        onTap: () => YarnMaterialSheet.show(
                          context,
                          onSelected: (id, name) => notifier.updateMaterial(name),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 색상
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '색상' : 'Color'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => YarnColorSheet.show(
                          context,
                          onSelected: (id, name, code) {
                            notifier.updateColor(name);
                            notifier.updateColorCode(code);
                            _colorController.text = name;
                          },
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: C.gx,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.bd),
                          ),
                          child: Row(
                            children: [
                              if (yarn.colorCode.isNotEmpty) ...[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: () {
                                      try {
                                        final hex = yarn.colorCode.replaceAll('#', '');
                                        return Color(int.parse('FF$hex', radix: 16));
                                      } catch (_) {
                                        return C.bd2;
                                      }
                                    }(),
                                    border: Border.all(color: C.bd, width: 1),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  yarn.color.isEmpty
                                      ? (isKorean ? '색상을 선택하세요' : 'Select a color')
                                      : yarn.color,
                                  style: yarn.color.isEmpty
                                      ? T.body.copyWith(color: C.mu)
                                      : T.body,
                                ),
                              ),
                              Icon(Icons.palette_outlined, color: C.mu, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '색상명 직접 입력' : 'Enter color name',
                          hintText: isKorean ? '예: 핑크, #FFC0CB' : 'e.g. Pink, Cream',
                        ),
                        onChanged: notifier.updateColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 굵기
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '굵기' : 'Weight'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weightOptions.map((w) {
                          final isSelected = yarn.weight == w;
                          return MoriChip(
                            label: w,
                            type: isSelected ? ChipType.lavender : ChipType.white,
                            onTap: () => notifier.updateWeight(isSelected ? '' : w),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 보유량 + 구입일 + 추가 정보
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '보유 정보' : 'Stock Info'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean ? '보유량 (g)' : 'Amount (g)',
                          hintText: isKorean ? '예: 200' : 'e.g. 200',
                          suffixText: 'g',
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v) ?? 0;
                          notifier.updateAmountGrams(parsed);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _yarnLengthController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: isKorean ? '실길이' : 'Length',
                          hintText: isKorean ? '예: 200m, 400yards' : 'e.g. 200m',
                        ),
                        onChanged: notifier.updateYarnLength,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lotNumberController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '로트번호' : 'Lot number',
                          hintText: isKorean ? '예: A001' : 'e.g. A001',
                        ),
                        onChanged: notifier.updateLotNumber,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean ? '가격 (원)' : 'Price',
                          hintText: isKorean ? '예: 15000' : 'e.g. 15000',
                          suffixText: isKorean ? '원' : '',
                        ),
                        onChanged: (v) => notifier.updatePrice(int.tryParse(v) ?? 0),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _purchasePlaceController,
                        decoration: InputDecoration(
                          labelText: isKorean ? '구입처' : 'Purchase place',
                          hintText: isKorean ? '예: 뜨개나라, 네이버쇼핑' : 'e.g. Yarn store',
                        ),
                        onChanged: notifier.updatePurchasePlace,
                      ),
                      const SizedBox(height: 12),
                      _DatePickerField(
                        label: isKorean ? '구입일' : 'Purchase date',
                        selectedDate: yarn.purchaseDate,
                        isKorean: isKorean,
                        onChanged: notifier.updatePurchaseDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 메모
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
                          hintText: isKorean
                              ? '실에 대한 메모를 입력하세요'
                              : 'Add notes about this yarn',
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

  Future<ImageSource?> _showImageSourceDialog() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery',
                  style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title:
                  Text(isKorean ? '사진 촬영' : 'Take a photo', style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(YarnInputNotifier notifier) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;

    setState(() {
      _localPhotoPath = picked.path;
      _uploading = true;
    });

    final isKorean = ref.read(appLanguageProvider).isKorean;
    final authUser = ref.read(authStateProvider).valueOrNull;
    final uid = authUser?.uid ?? 'unknown';

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final reference = FirebaseStorage.instance
          .ref()
          .child('yarn/$uid/$timestamp.jpg');
      final task = await reference.putFile(File(picked.path));
      final url = await task.ref.getDownloadURL();
      notifier.updatePhotoUrl(url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '사진 업로드에 실패했어요: $error'
              : 'Failed to upload photo: $error'),
          backgroundColor: C.og,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isKorean ? '로그인 필요' : 'Login required', style: T.h3),
          content: Text(
            isKorean ? '저장하려면 로그인이 필요해요.' : 'Please log in to save.',
            style: T.body,
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ctx = context;
    final navigator = Navigator.of(ctx);
    final repository = ref.read(yarnRepositoryProvider);
    final yarn = ref.read(yarnInputProvider).copyWith(uid: authUser.uid);

    try {
      await runWithMoriLoadingDialog<void>(
        ctx,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          if (widget.yarnId != null) {
            await repository.updateYarn(yarn);
          } else {
            await repository.createYarn(yarn);
          }
        },
      );
      if (!ctx.mounted) return;
      showSavedSnackBar(
        ctx,
        message: widget.yarnId == null
            ? (isKorean ? '저장됐어요.' : 'Saved.')
            : (isKorean ? '수정됐어요.' : 'Updated.'),
      );
      navigator.pop();
    } catch (e) {
      if (!ctx.mounted) return;
      showSaveErrorSnackBar(ctx, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── 사진 선택 위젯 ────────────────────────────────────────
class _YarnPhotoPicker extends StatelessWidget {
  final String photoUrl;
  final String? localPath;
  final bool uploading;
  final bool isKorean;
  final VoidCallback onTap;

  const _YarnPhotoPicker({
    required this.photoUrl,
    this.localPath,
    required this.uploading,
    required this.isKorean,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: AspectRatio(
          aspectRatio: 4 / 3,
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
                            ? Image.file(File(localPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
                            : Image.network(photoUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: C.lv, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            isKorean ? '사진 추가' : 'Add Photo',
                            style: T.bodyBold.copyWith(color: C.lvD),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isKorean ? '실 사진을 추가해보세요' : 'Add a photo of your yarn',
                            style: T.caption.copyWith(color: C.mu),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

// ── 브랜드 픽커 필드 ──────────────────────────────────────
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

// ── 날짜 선택 필드 ────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final bool isKorean;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.isKorean,
    required this.onChanged,
  });

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.captionBold.copyWith(color: C.mu)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? now,
              firstDate: DateTime(2000),
              lastDate: now,
            );
            if (picked != null) onChanged(picked);
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
                    selectedDate != null
                        ? _formatDate(selectedDate!)
                        : (isKorean ? '날짜 선택' : 'Select date'),
                    style: selectedDate != null
                        ? T.body
                        : T.body.copyWith(color: C.mu),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, color: C.mu, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
