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
import '../../ravelry/domain/ravelry_models.dart';
import '../../ravelry/presentation/ravelry_yarn_search_sheet.dart';
import '../../swatch/data/public_brand_repository.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../domain/yarn_model.dart';
import 'yarn_color_sheet.dart';
import 'yarn_material_sheet.dart';

class YarnInputScreen extends ConsumerStatefulWidget {
  final String? yarnId;
  final YarnModel? initialYarn;
  // 이슈 #698 — 기존 실 복사로 시작. 즉시 새 doc 생성하지 않고 prefill만.
  final YarnModel? copyFrom;

  const YarnInputScreen({super.key, this.yarnId, this.initialYarn, this.copyFrom});

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
  final _quantityController = TextEditingController();
  final _lengthController = TextEditingController();
  bool _isSaving = false;
  bool _uploading = false;
  bool _uploadingLabel = false;
  // 이슈 #698 — 미저장 변경 추적
  bool _isDirty = false;
  bool _prefillInProgress = false;
  String? _localPhotoPath;
  String? _localLabelPhotoPath;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  static const List<String> _weightOptions = [
    'Lace', 'Fingering', 'Sport', 'DK', 'Worsted', 'Bulky', 'Super Bulky',
  ];

  @override
  void initState() {
    super.initState();
    // 이슈 #698 — initialYarn(수정) 또는 copyFrom(복사)로 prefill.
    final source = widget.initialYarn ?? widget.copyFrom;
    if (source != null) {
      _prefillInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 복사 모드: id 비우고 load → 저장 시 createYarn 분기 (yarnId == null).
        final loaded = widget.copyFrom != null && widget.initialYarn == null
            ? source.copyWith(id: '')
            : source;
        ref.read(yarnInputProvider.notifier).loadYarn(loaded);
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _prefillInProgress = false;
        });
        _nameController.text = source.name;
        _colorController.text = source.color;
        _amountController.text = source.amountGrams > 0 ? '${source.amountGrams}' : '';
        _memoController.text = source.memo;
        _yarnLengthController.text = source.yarnLength;
        _lotNumberController.text = source.lotNumber;
        _priceController.text = source.price > 0 ? '${source.price}' : '';
        _purchasePlaceController.text = source.purchasePlace;
        _quantityController.text = source.quantity > 0 ? '${source.quantity}' : '';
        _lengthController.text = source.lengthMeters > 0 ? '${source.lengthMeters}' : '';
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
    _quantityController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final yarn = ref.watch(yarnInputProvider);
    final notifier = ref.read(yarnInputProvider.notifier);

    // 이슈 #698 — yarnInputProvider 변경 감지 → dirty 마킹
    // prefill 도중 발생하는 loadYarn() 변경은 제외.
    ref.listen<YarnModel>(yarnInputProvider, (prev, next) {
      if (_prefillInProgress) return;
      if (prev != null && prev != next) {
        _markDirty();
      }
    });

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleUnsavedBack(context);
      },
      child: Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () async {
            if (!_isDirty) {
              Navigator.pop(context);
              return;
            }
            await _handleUnsavedBack(context);
          },
        ),
        title: Text(
          widget.yarnId == null
              ? (widget.copyFrom != null
                  ? (isKorean ? '실 복사' : 'Copy Yarn')
                  : (isKorean ? '실 추가' : 'Add Yarn'))
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
                // 사진 (실사진 + 라벨사진 2단)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isKorean ? '실 사진' : 'Yarn Photo',
                              style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _YarnPhotoPicker(
                            photoUrl: yarn.photoUrl,
                            localPath: _localPhotoPath,
                            uploading: _uploading,
                            isKorean: isKorean,
                            emptyIcon: Icons.texture,
                            emptyLabel: isKorean ? '실 사진' : 'Yarn',
                            onTap: () => _pickPhoto(notifier),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isKorean ? '라벨 사진' : 'Label Photo',
                              style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _YarnPhotoPicker(
                            photoUrl: yarn.labelPhotoUrl,
                            localPath: _localLabelPhotoPath,
                            uploading: _uploadingLabel,
                            isKorean: isKorean,
                            emptyIcon: Icons.label_outline_rounded,
                            emptyLabel: isKorean ? '라벨 사진' : 'Label',
                            onTap: () => _pickLabelPhoto(notifier),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 이슈 #644 Phase 7 — Ravelry yarn DB 검색 카드 (자동 채우기)
                _RavelryYarnSearchCard(
                  isKorean: isKorean,
                  linkedYarnId: yarn.ravelryYarnId,
                  onPick: (item) {
                    notifier.updateRavelryYarnId(item.id);
                    notifier.updateName(item.name);
                    _nameController.text = item.name;
                    if (item.yarnCompanyName != null) {
                      notifier.updateBrandName(item.yarnCompanyName!);
                    }
                    if (item.yarnWeight != null) {
                      notifier.updateWeight(item.yarnWeight!);
                    }
                    if (item.fiberContent != null) {
                      notifier.updateComposition(item.fiberContent!);
                      notifier.updateMaterial(item.fiberContent!);
                    }
                  },
                  onClear: () => notifier.updateRavelryYarnId(null),
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
                      SectionTitle(title: isKorean ? '보유 현황' : 'Stock'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean ? '갯수 (볼/타래)' : 'Quantity (balls/skeins)',
                          hintText: isKorean ? '예: 3' : 'e.g. 3',
                          fillColor: C.gx,
                        ),
                        onChanged: (v) => notifier.updateQuantity(int.tryParse(v) ?? 0),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lengthController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean ? '길이 (m)' : 'Length (m)',
                          hintText: isKorean ? '예: 200' : 'e.g. 200',
                          fillColor: C.gx,
                        ),
                        onChanged: (v) => notifier.updateLengthMeters(int.tryParse(v) ?? 0),
                      ),
                      const SizedBox(height: 12),
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
    ),
    );
  }

  // 이슈 #698 — 미저장 변경 뒤로가기 가드
  Future<void> _handleUnsavedBack(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final navigator = Navigator.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '저장하지 않은 변경 사항' : 'Unsaved changes', style: T.h3),
        content: Text(isKorean ? '저장하지 않고 나가시겠어요?' : 'Leave without saving?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(isKorean ? '취소' : 'Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(isKorean ? '저장하고 나가기' : 'Save & Leave')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: C.og),
            child: Text(isKorean ? '저장 안 함' : 'Discard'),
          ),
        ],
      ),
    );
    if (action == 'discard') {
      if (!mounted) return;
      setState(() => _isDirty = false);
      navigator.pop();
    } else if (action == 'save') {
      if (!mounted) return;
      await _save(context);
    }
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

  Future<void> _pickLabelPhoto(YarnInputNotifier notifier) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;
    setState(() { _localLabelPhotoPath = picked.path; _uploadingLabel = true; });
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? 'unknown';
    try {
      final ref2 = FirebaseStorage.instance.ref().child('yarn/$uid/label_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final task = await ref2.putFile(File(picked.path));
      notifier.updateLabelPhotoUrl(await task.ref.getDownloadURL());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: C.og));
    } finally {
      if (mounted) setState(() => _uploadingLabel = false);
    }
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
          // #650 — 사용자 입력 브랜드를 공용 yarn_brands에 자동 upsert
          if (yarn.brandName.trim().isNotEmpty) {
            await ref
                .read(publicBrandRepositoryProvider)
                .upsertYarnBrand(yarn.brandName);
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
      // 이슈 #698 — 저장 성공 시 dirty 해제
      if (mounted) setState(() => _isDirty = false);
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
  final IconData emptyIcon;
  final String emptyLabel;

  const _YarnPhotoPicker({
    required this.photoUrl,
    this.localPath,
    required this.uploading,
    required this.isKorean,
    required this.onTap,
    this.emptyIcon = Icons.add_photo_alternate_outlined,
    this.emptyLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 140,
        width: double.infinity,
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
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity)
                            : Image.network(photoUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(emptyIcon, color: C.lv, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            emptyLabel.isNotEmpty ? emptyLabel : (isKorean ? '사진 추가' : 'Add Photo'),
                            style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
          ),
        ),
    );
  }
}


// ── 이슈 #644 Phase 7 — Ravelry yarn DB 검색 카드 ─────────
class _RavelryYarnSearchCard extends StatelessWidget {
  final bool isKorean;
  final int? linkedYarnId;
  final ValueChanged<RavelryYarnSearchItem> onPick;
  final VoidCallback onClear;

  const _RavelryYarnSearchCard({
    required this.isKorean,
    required this.linkedYarnId,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = linkedYarnId != null && linkedYarnId! > 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: C.lv, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: SectionTitle(
                  title: isKorean ? 'Ravelry yarn 검색' : 'Search Ravelry yarn',
                ),
              ),
              if (hasLink)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isKorean ? '연결됨' : 'Linked',
                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? 'Ravelry 글로벌 yarn DB(10만+ 항목)에서 검색하면\n실 정보가 자동으로 채워지고 stash 매핑됩니다.'
                : 'Search Ravelry yarn DB to auto-fill yarn info\nand link with stash entries.',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(
                      hasLink
                          ? (isKorean ? '다시 검색' : 'Search again')
                          : (isKorean ? 'Ravelry yarn 검색' : 'Search Ravelry yarn'),
                    ),
                    onPressed: () async {
                      final picked = await RavelryYarnSearchSheet.show(context);
                      if (picked != null) onPick(picked);
                    },
                  ),
                ),
              ),
              if (hasLink) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isKorean ? '연결 해제' : 'Unlink',
                  icon: Icon(Icons.link_off, color: C.og),
                  onPressed: onClear,
                ),
              ],
            ],
          ),
          if (!hasLink) ...[
            const SizedBox(height: 6),
            Text(
              isKorean
                  ? 'Ravelry에 없는 한국 브랜드는 아래 항목에 직접 입력해 주세요.'
                  : 'Not on Ravelry? Enter manually below.',
              style: T.caption.copyWith(color: C.mu),
            ),
          ],
        ],
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
