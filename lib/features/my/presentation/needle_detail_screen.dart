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
import '../../../providers/project_provider.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../domain/needle_model.dart';

class NeedleDetailScreen extends ConsumerStatefulWidget {
  final String needleId;

  const NeedleDetailScreen({super.key, required this.needleId});

  @override
  ConsumerState<NeedleDetailScreen> createState() => _NeedleDetailScreenState();
}

class _NeedleDetailScreenState extends ConsumerState<NeedleDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _localPhotoPath;
  String? _photoUrl;

  late final TextEditingController _memoCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _purchasePlaceCtrl;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _purchasePlaceCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePlaceCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode(NeedleModel needle) {
    ref.read(needleInputProvider.notifier).load(needle);
    _memoCtrl.text = needle.memo;
    _priceCtrl.text = needle.price > 0 ? '${needle.price}' : '';
    _purchasePlaceCtrl.text = needle.purchasePlace;
    _nameCtrl.text = needle.name;
    _photoUrl = needle.photoUrl.isNotEmpty ? needle.photoUrl : null;
    setState(() {
      _isEditing = true;
      _localPhotoPath = null;
    });
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _save(BuildContext context, bool isKorean, AppStrings t) async {
    setState(() => _isSaving = true);
    final repository = ref.read(needleRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          if (_localPhotoPath != null) {
            final file = File(_localPhotoPath!);
            final refPath = FirebaseStorage.instance
                .ref()
                .child('needles/${DateTime.now().millisecondsSinceEpoch}.jpg');
            await refPath.putFile(file);
            _photoUrl = await refPath.getDownloadURL();
          }
          final needle = ref.read(needleInputProvider);
          await repository.updateNeedle(needle, photoUrl: _photoUrl);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '수정됐어요.' : 'Updated.');
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickNeedlePhoto(bool isKorean) async {
    final source = await showModalBottomSheet<ImageSource>(
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
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(isKorean ? '사진 촬영' : 'Take a photo', style: T.body),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
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

  void _linkToProject(BuildContext context, String needleId, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allProjects = cRef.watch(projectListProvider).valueOrNull ?? [];
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(isKorean ? '프로젝트에 연결' : 'Link to Project', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (allProjects.isEmpty)
                    Expanded(child: Center(child: Text(isKorean ? '등록된 프로젝트가 없어요.' : 'No projects available.', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey))))
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: allProjects.length,
                        itemBuilder: (_, i) {
                          final project = allProjects[i];
                          final alreadyLinked = project.needleIds.contains(needleId);
                          return ListTile(
                            leading: project.coverPhotoUrl.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(project.coverPhotoUrl, width: 40, height: 40, fit: BoxFit.cover))
                                : Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.folder_outlined, size: 20)),
                            title: Text(project.title, style: Theme.of(ctx).textTheme.bodyMedium),
                            trailing: alreadyLinked ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18) : null,
                            onTap: alreadyLinked ? null : () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                task: () => cRef.read(projectRepositoryProvider).updateProject(
                                  project.copyWith(needleIds: [...project.needleIds, needleId]),
                                ),
                              );
                              if (context.mounted) {
                                showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결됐어요.' : 'Linked.');
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _duplicateNeedle(NeedleModel needle, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(needleRepositoryProvider).duplicateNeedle(needle),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _confirmDelete(NeedleModel needle, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '바늘 삭제' : 'Delete Needle', style: T.h3),
        content: Text(
          isKorean ? '정말 삭제하시겠어요?' : 'Are you sure you want to delete?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
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
        task: () => ref.read(needleRepositoryProvider).deleteNeedle(needle.id),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final friendly = (msg.contains('인터넷') || msg.contains('TimeoutException'))
          ? (isKorean ? '인터넷 연결을 확인해 주세요' : 'Check your internet connection')
          : msg;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: friendly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final t = ref.watch(appStringsProvider);
    final needleAsync = ref.watch(needleListProvider).whenData(
      (list) => list.cast<NeedleModel?>().firstWhere(
            (n) => n?.id == widget.needleId,
            orElse: () => null,
          ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: _isEditing
                    ? (isKorean ? '바늘 수정' : 'Edit Needle')
                    : (isKorean ? '바늘 정보' : 'Needle Details'),
                subtitle: isKorean ? '바늘 상세' : 'Needle details',
                trailing: _isEditing
                    ? [
                        TextButton(
                          onPressed: _cancelEdit,
                          child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
                        ),
                        TextButton(
                          onPressed: _isSaving ? null : () => _save(context, isKorean, t),
                          child: Text(isKorean ? '저장' : 'Save',
                              style: T.bodyBold.copyWith(color: C.lv)),
                        ),
                      ]
                    : [
                        needleAsync.whenOrNull(
                              data: (needle) => needle == null
                                  ? null
                                  : PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded, color: C.tx),
                                      onSelected: (v) {
                                        if (v == 'edit') _enterEditMode(needle);
                                        if (v == 'copy') _duplicateNeedle(needle, isKorean);
                                        if (v == 'link_project') _linkToProject(context, needle.id, isKorean);
                                        if (v == 'delete') _confirmDelete(needle, isKorean);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit_outlined, size: 18, color: C.lv),
                                            const SizedBox(width: 8),
                                            Text(isKorean ? '수정' : 'Edit'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'copy',
                                          child: Row(children: [
                                            Icon(Icons.copy_rounded, size: 18, color: C.lv),
                                            const SizedBox(width: 8),
                                            Text(isKorean ? '복사' : 'Duplicate'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'link_project',
                                          child: Row(children: [
                                            Icon(Icons.folder_outlined, size: 18, color: C.lv),
                                            const SizedBox(width: 8),
                                            Text(isKorean ? '프로젝트 연결' : 'Link to project'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline, size: 18, color: C.og),
                                            const SizedBox(width: 8),
                                            Text(isKorean ? '삭제' : 'Delete',
                                                style: TextStyle(color: C.og)),
                                          ]),
                                        ),
                                      ],
                                    ),
                            ) ??
                            const SizedBox.shrink(),
                      ],
              ),
            ),
            Expanded(
              child: needleAsync.when(
                data: (needle) {
                  if (needle == null) {
                    return Center(
                      child: Text(
                        isKorean ? '바늘 정보를 찾을 수 없어요.' : 'Needle not found.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    );
                  }
                  if (_isEditing) {
                    return _buildEditBody(isKorean, t);
                  }
                  return _buildDetailBody(needle, isKorean);
                },
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (e, _) => Center(child: Text('$e', style: T.body.copyWith(color: C.og))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 보기 모드 ─────────────────────────────────────────────
  Widget _buildDetailBody(NeedleModel needle, bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // ── 핵심 정보 히어로 카드 ──────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 사이즈 강조
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              needle.sizeDisplay,
                              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: C.lvD, height: 1.0),
                            ),
                            const SizedBox(height: 4),
                            if (needle.brandName.isNotEmpty)
                              Text(needle.brandName, style: T.body.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
                            if (needle.name.isNotEmpty)
                              Text(needle.name, style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      // 사진 (있을 때만)
                      if (needle.photoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            needle.photoUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, st) => const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoChip(label: needle.localizedTypeLabel(isKorean), icon: Icons.circle_outlined, color: C.lv),
                      _InfoChip(label: needle.localizedMaterialLabel(isKorean), icon: Icons.texture, color: C.pk),
                      _InfoChip(
                        label: isKorean ? '${needle.quantity}개 보유' : '${needle.quantity} pcs',
                        icon: Icons.inventory_2_outlined,
                        color: C.lmD,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 구매 정보 ─────────────────────────────────────────
            SectionTitle(title: isKorean ? '구매 정보' : 'Purchase Info'),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: isKorean ? '가격' : 'Price',
                    value: needle.price > 0 ? (isKorean ? '${needle.price}원' : '${needle.price}') : '',
                    isKorean: isKorean,
                  ),
                  if (needle.purchasePlace.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(label: isKorean ? '구매처' : 'Purchased at', value: needle.purchasePlace, isKorean: isKorean),
                  ],
                  if (needle.purchaseDate != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: isKorean ? '구매일' : 'Purchase date',
                      value: _formatDate(needle.purchaseDate!),
                      isKorean: isKorean,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 메모 ─────────────────────────────────────────────
            SectionTitle(title: isKorean ? '메모' : 'Notes'),
            const SizedBox(height: 8),
            GlassCard(
              child: Text(
                needle.memo.isNotEmpty ? needle.memo : (isKorean ? '메모가 없어요.' : 'No notes.'),
                style: needle.memo.isNotEmpty ? T.body : T.body.copyWith(color: C.mu),
              ),
            ),
            const SizedBox(height: 14),

            // ── 날짜 정보 ──────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needle.createdAt != null)
                    _InfoRow(
                      label: isKorean ? '등록일' : 'Added on',
                      value: _formatDate(needle.createdAt!),
                      isKorean: isKorean,
                    ),
                  if (needle.updatedAt != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: isKorean ? '수정일' : 'Updated on',
                      value: _formatDate(needle.updatedAt!),
                      isKorean: isKorean,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 수정 모드 ─────────────────────────────────────────────
  Widget _buildEditBody(bool isKorean, AppStrings t) {
    final needle = ref.watch(needleInputProvider);
    final notifier = ref.read(needleInputProvider.notifier);

    return Stack(
      children: [
        const BgOrbs(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 바늘 사이즈
              SectionTitle(title: isKorean ? '바늘 사이즈' : 'Needle size'),
              const SizedBox(height: 10),
              _NeedleSizeSelector(
                selectedSize: needle.size,
                onSelected: notifier.setSize,
              ),
              const SizedBox(height: 20),
              // 종류
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
              // 재질
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
              // 브랜드
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
              // 바늘 이름
              SectionTitle(title: isKorean ? '바늘 이름 (선택)' : 'Needle name (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                onChanged: notifier.setName,
                decoration: InputDecoration(
                  labelText: isKorean ? '예: Karbonz, Nova Metal' : 'e.g. Karbonz, Nova Metal',
                  hintText: isKorean ? '예: Karbonz, Nova Metal' : 'e.g. Karbonz, Nova Metal',
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
                    onTap: () {
                      if (needle.quantity > 1) notifier.setQuantity(needle.quantity - 1);
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
              // 가격
              SectionTitle(title: isKorean ? '구입가격 (선택)' : 'Price (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => notifier.setPrice(int.tryParse(v) ?? 0),
                decoration: InputDecoration(
                  labelText: isKorean ? '예: 15000' : 'e.g. 15000',
                  hintText: isKorean ? '예: 15000' : 'e.g. 15000',
                ),
              ),
              const SizedBox(height: 20),
              // 구입처
              SectionTitle(title: isKorean ? '구입처 (선택)' : 'Purchase place (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _purchasePlaceCtrl,
                onChanged: notifier.setPurchasePlace,
                decoration: InputDecoration(
                  labelText: isKorean ? '예: 뜨개나라, 네이버쇼핑' : 'e.g. Yarn store, Online',
                  hintText: isKorean ? '예: 뜨개나라, 네이버쇼핑' : 'e.g. Yarn store, Online',
                ),
              ),
              const SizedBox(height: 20),
              // 사진
              SectionTitle(title: t.needlePhoto),
              const SizedBox(height: 8),
              _NeedlePhotoSection(
                t: t,
                localPhotoPath: _localPhotoPath,
                existingPhotoUrl: _photoUrl,
                onTap: () => _pickNeedlePhoto(isKorean),
              ),
              const SizedBox(height: 20),
              // 메모
              SectionTitle(title: isKorean ? '메모 (선택)' : 'Memo (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                maxLines: 2,
                onChanged: notifier.setMemo,
                decoration: InputDecoration(
                  labelText: isKorean ? '색상, 길이, 특이사항...' : 'Color, length, notes...',
                  hintText: isKorean ? '색상, 길이, 특이사항...' : 'Color, length, notes...',
                ),
              ),
              const SizedBox(height: 20),
              // 구입일
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(context, isKorean, t),
                  child: Text(isKorean ? '저장' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

// ── 정보 행 (보기 모드) ────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isKorean;

  const _InfoRow({required this.label, required this.value, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: T.caption.copyWith(color: C.mu)),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: value.isNotEmpty ? T.body : T.body.copyWith(color: C.mu),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── 복사된 입력 위젯들 (needle_input_screen.dart에서) ──────

class _NeedleSizeSelector extends StatelessWidget {
  final double selectedSize;
  final ValueChanged<double> onSelected;

  const _NeedleSizeSelector({
    required this.selectedSize,
    required this.onSelected,
  });

  static const List<double> _sizes = [
    2.0, 2.5, 3.0, 3.25, 3.5, 3.75, 4.0, 4.5, 5.0, 5.5,
    6.0, 6.5, 7.0, 8.0, 9.0, 10.0, 12.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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
                Expanded(
                    child: Text(value.isEmpty ? hint : value,
                        style: value.isEmpty ? T.body.copyWith(color: C.mu) : T.body)),
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
            errorBuilder: (ctx, err, stack) => const SizedBox()),
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
