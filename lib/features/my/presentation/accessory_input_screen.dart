import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/accessory_provider.dart';
import '../domain/accessory_model.dart';

class AccessoryInputScreen extends ConsumerStatefulWidget {
  final AccessoryModel? initialItem;
  // 이슈 #698 — 기존 악세사리 복사 시작 (즉시 doc 생성 금지)
  final AccessoryModel? copyFrom;

  const AccessoryInputScreen({super.key, this.initialItem, this.copyFrom});

  @override
  ConsumerState<AccessoryInputScreen> createState() => _AccessoryInputScreenState();
}

class _AccessoryInputScreenState extends ConsumerState<AccessoryInputScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _purchasePlaceCtrl;
  late final TextEditingController _memoCtrl;
  // 이슈 #698 — 미저장 변경 추적
  bool _isDirty = false;
  bool _prefillInProgress = false;
  String? _localPhotoPath;
  String? _photoUrl;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void initState() {
    super.initState();
    // 이슈 #698 — initialItem(수정) 또는 copyFrom(복사)로 prefill
    final source = widget.initialItem ?? widget.copyFrom;
    _nameCtrl = TextEditingController(text: source?.name ?? '');
    _brandCtrl = TextEditingController(text: source?.brandName ?? '');
    _priceCtrl = TextEditingController(text: source != null && source.price > 0 ? '${source.price}' : '');
    _purchasePlaceCtrl = TextEditingController(text: source?.purchasePlace ?? '');
    _memoCtrl = TextEditingController(text: source?.memo ?? '');
    _photoUrl = source?.photoUrl.isNotEmpty == true ? source!.photoUrl : null;

    if (source != null) {
      _prefillInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 복사 모드: id 비우고 load → 저장 시 createAccessory 분기
        final loaded = widget.copyFrom != null && widget.initialItem == null
            ? source.copyWith(id: '')
            : source;
        ref.read(accessoryInputProvider.notifier).load(loaded);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _prefillInProgress = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePlaceCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: C.pk),
                title: Text(isKorean ? '즉시 촬영' : 'Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _localPhotoPath = picked.path);
    }
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_localPhotoPath == null) return _photoUrl;
    final ref = FirebaseStorage.instance.ref('users/$uid/accessories/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(_localPhotoPath!));
    return await ref.getDownloadURL();
  }

  Future<void> _save(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final notifier = ref.read(accessoryInputProvider.notifier);
    final item = ref.read(accessoryInputProvider);
    final repo = ref.read(accessoryRepositoryProvider);

    notifier.setName(_nameCtrl.text.trim());
    notifier.setBrand(_brandCtrl.text.trim());
    notifier.setPrice(int.tryParse(_priceCtrl.text.trim()) ?? 0);
    notifier.setPurchasePlace(_purchasePlaceCtrl.text.trim());
    notifier.setMemo(_memoCtrl.text.trim());

    final updated = ref.read(accessoryInputProvider);

    final sm = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final photoUrl = await _uploadPhoto(item.uid);
          if (widget.initialItem == null) {
            await repo.createAccessory(updated, photoUrl: photoUrl);
          } else {
            await repo.updateAccessory(updated, photoUrl: photoUrl);
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(sm, message: isKorean ? '저장됐어요.' : 'Saved.');
      // 이슈 #698 — 저장 성공 시 dirty 해제
      setState(() => _isDirty = false);
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(sm, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(accessoryInputProvider);
    final notifier = ref.read(accessoryInputProvider.notifier);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    // 이슈 #698 — accessoryInputProvider 변경 감지 → dirty 마킹
    // prefill 도중 발생하는 load() 변경은 제외.
    ref.listen<AccessoryModel>(accessoryInputProvider, (prev, next) {
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
          widget.initialItem == null
              ? (widget.copyFrom != null
                  ? (isKorean ? '악세사리 복사' : 'Copy Accessory')
                  : (isKorean ? '악세사리 추가' : 'Add Accessory'))
              : (isKorean ? '악세사리 수정' : 'Edit Accessory'),
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
              onPressed: () => _save(context),
              child: Text(isKorean ? '저장' : 'Save'),
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
                SectionTitle(title: isKorean ? '사진 (선택)' : 'Photo (optional)'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.bd),
                      image: _localPhotoPath != null
                          ? DecorationImage(image: FileImage(File(_localPhotoPath!)), fit: BoxFit.cover)
                          : (_photoUrl != null
                              ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_localPhotoPath == null && _photoUrl == null)
                        ? Icon(Icons.add_a_photo_rounded, color: C.mu, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                // 종류
                SectionTitle(title: isKorean ? '도구 종류 *' : 'Type *'),
                const SizedBox(height: 10),
                _AccessoryTypeDropdown(
                  value: item.type,
                  isKorean: isKorean,
                  onChanged: notifier.setType,
                ),
                const SizedBox(height: 20),

                // 브랜드
                SectionTitle(title: isKorean ? '브랜드 (선택)' : 'Brand (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _brandCtrl,
                  onChanged: notifier.setBrand,
                  decoration: InputDecoration(
                    labelText: isKorean ? '브랜드명' : 'Brand name',
                    hintText: isKorean ? '예: Clover, Addi' : 'e.g. Clover, Addi',
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 이름
                SectionTitle(title: isKorean ? '이름 (선택)' : 'Name (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  onChanged: notifier.setName,
                  decoration: InputDecoration(
                    labelText: isKorean ? '도구 이름' : 'Item name',
                    hintText: isKorean ? '예: 스티치 마커 세트' : 'e.g. Stitch marker set',
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 수량
                SectionTitle(title: isKorean ? '수량' : 'Quantity'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      onTap: () { if (item.quantity > 1) notifier.setQuantity(item.quantity - 1); },
                    ),
                    const SizedBox(width: 16),
                    Text(isKorean ? '${item.quantity}개' : '${item.quantity}', style: T.bodyBold),
                    const SizedBox(width: 16),
                    _QuantityButton(
                      icon: Icons.add, filled: true,
                      onTap: () => notifier.setQuantity(item.quantity + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 가격
                SectionTitle(title: isKorean ? '구입가격 (선택)' : 'Price (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => notifier.setPrice(int.tryParse(v) ?? 0),
                  decoration: InputDecoration(
                    labelText: isKorean ? '가격' : 'Price',
                    hintText: isKorean ? '예: 12000' : 'e.g. 12000',
                    suffixText: isKorean ? '원' : 'KRW',
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 구매처
                SectionTitle(title: isKorean ? '구매처 (선택)' : 'Purchase place (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _purchasePlaceCtrl,
                  onChanged: notifier.setPurchasePlace,
                  decoration: InputDecoration(
                    labelText: isKorean ? '구매처' : 'Where bought',
                    hintText: isKorean ? '예: 무신사, 네이버' : 'e.g. Online store',
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 메모
                SectionTitle(title: isKorean ? '메모 (선택)' : 'Memo (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoCtrl,
                  onChanged: notifier.setMemo,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isKorean ? '메모' : 'Notes',
                    hintText: isKorean ? '자유롭게 기록해요' : 'Free notes',
                    alignLabelWithHint: true,
                    fillColor: C.gx,
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
}

// ── 드롭다운 ─────────────────────────────────────────────────
class _AccessoryTypeDropdown extends StatelessWidget {
  final String value;
  final bool isKorean;
  final ValueChanged<String> onChanged;

  const _AccessoryTypeDropdown({
    required this.value,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: isKorean ? '도구 종류' : 'Tool type',
        fillColor: C.gx,
      ),
      style: T.body.copyWith(color: C.tx),
      items: AccessoryType.values.map((t) {
        return DropdownMenuItem(
          value: t.name,
          child: Text(t.localizedLabel(isKorean), style: T.body),
        );
      }).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

// ── 수량 버튼 ──────────────────────────────────────────────────
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _QuantityButton({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: filled ? C.lv : C.gx,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? C.lv : C.bd),
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.white : C.tx2),
      ),
    );
  }
}
