import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../swatch/presentation/brand_search_sheet.dart';
import '../domain/yarn_model.dart';
import 'yarn_color_sheet.dart';
import 'yarn_material_sheet.dart';

class YarnDetailScreen extends ConsumerStatefulWidget {
  final String yarnId;

  const YarnDetailScreen({super.key, required this.yarnId});

  @override
  ConsumerState<YarnDetailScreen> createState() => _YarnDetailScreenState();
}

class _YarnDetailScreenState extends ConsumerState<YarnDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _uploading = false;
  bool _uploadingLabel = false;
  String? _localPhotoPath;
  String? _localLabelPhotoPath;

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

  static const List<String> _weightOptions = [
    'Lace', 'Fingering', 'Sport', 'DK', 'Worsted', 'Bulky', 'Super Bulky',
  ];

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

  void _enterEditMode(YarnModel yarn) {
    ref.read(yarnInputProvider.notifier).loadYarn(yarn);
    _nameController.text = yarn.name;
    _colorController.text = yarn.color;
    _amountController.text = yarn.amountGrams > 0 ? '${yarn.amountGrams}' : '';
    _memoController.text = yarn.memo;
    _yarnLengthController.text = yarn.yarnLength;
    _lotNumberController.text = yarn.lotNumber;
    _priceController.text = yarn.price > 0 ? '${yarn.price}' : '';
    _purchasePlaceController.text = yarn.purchasePlace;
    _quantityController.text = yarn.quantity > 0 ? '${yarn.quantity}' : '';
    _lengthController.text = yarn.lengthMeters > 0 ? '${yarn.lengthMeters}' : '';
    setState(() {
      _isEditing = true;
      _localPhotoPath = null;
      _localLabelPhotoPath = null;
    });
  }

  void _cancelEdit() => setState(() {
    _isEditing = false;
    _localPhotoPath = null;
    _localLabelPhotoPath = null;
  });

  Future<void> _save(BuildContext context, bool isKorean) async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;

    setState(() => _isSaving = true);
    final repository = ref.read(yarnRepositoryProvider);
    final yarn = ref.read(yarnInputProvider).copyWith(uid: authUser.uid);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repository.updateYarn(yarn),
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

  Future<ImageSource?> _showImageSourceDialog(bool isKorean) async {
    if (kIsWeb) return ImageSource.gallery;
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
  }

  Future<void> _pickPhoto(YarnInputNotifier notifier, bool isKorean) async {
    final source = await _showImageSourceDialog(isKorean);
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;

    setState(() { _localPhotoPath = picked.path; _uploading = true; });

    final authUser = ref.read(authStateProvider).valueOrNull;
    final uid = authUser?.uid ?? 'unknown';

    try {
      final ref2 = FirebaseStorage.instance.ref().child('yarn/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final task = await ref2.putFile(File(picked.path));
      final url = await task.ref.getDownloadURL();
      notifier.updatePhotoUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isKorean ? '사진 업로드 실패: $e' : 'Upload failed: $e'),
        backgroundColor: C.og,
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickLabelPhoto(YarnInputNotifier notifier, bool isKorean) async {
    final source = await _showImageSourceDialog(isKorean);
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;

    setState(() { _localLabelPhotoPath = picked.path; _uploadingLabel = true; });

    final authUser = ref.read(authStateProvider).valueOrNull;
    final uid = authUser?.uid ?? 'unknown';

    try {
      final ref2 = FirebaseStorage.instance.ref().child('yarn/$uid/label_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final task = await ref2.putFile(File(picked.path));
      final url = await task.ref.getDownloadURL();
      notifier.updateLabelPhotoUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isKorean ? '라벨 사진 업로드 실패: $e' : 'Label upload failed: $e'),
        backgroundColor: C.og,
      ));
    } finally {
      if (mounted) setState(() => _uploadingLabel = false);
    }
  }

  void _linkToProject(BuildContext context, String yarnId, bool isKorean) {
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
                          final alreadyLinked = project.yarnIds.contains(yarnId);
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
                                  project.copyWith(yarnIds: [...project.yarnIds, yarnId]),
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

  Future<void> _duplicateYarn(YarnModel yarn, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(yarnRepositoryProvider).duplicateYarn(yarn),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _confirmDelete(YarnModel yarn, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '실 삭제' : 'Delete Yarn', style: T.h3),
        content: Text(isKorean ? '정말 삭제하시겠어요?' : 'Are you sure?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
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
        task: () => ref.read(yarnRepositoryProvider).deleteYarn(yarn.id),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    // autoDispose 방지: 편집 모드 진입 전에도 provider를 살려둠
    ref.watch(yarnInputProvider);
    final yarnAsync = ref.watch(yarnListProvider).whenData(
      (list) => list.cast<YarnModel?>().firstWhere((y) => y?.id == widget.yarnId, orElse: () => null),
    );

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: _isEditing
            ? TextButton(
                onPressed: _cancelEdit,
                child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isEditing
              ? (isKorean ? '실 수정' : 'Edit Yarn')
              : (isKorean ? '실 정보' : 'Yarn Details'),
          style: T.h3,
        ),
        actions: _isEditing
            ? [
                TextButton(
                  onPressed: _isSaving ? null : () => _save(context, isKorean),
                  child: Text(isKorean ? '저장' : 'Save',
                      style: T.bodyBold.copyWith(color: C.lv)),
                ),
              ]
            : [
                yarnAsync.whenOrNull(
                      data: (yarn) => yarn == null
                          ? null
                          : PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: C.tx),
                              onSelected: (v) {
                                if (v == 'edit') _enterEditMode(yarn);
                                if (v == 'copy') _duplicateYarn(yarn, isKorean);
                                if (v == 'link_project') _linkToProject(context, yarn.id, isKorean);
                                if (v == 'delete') _confirmDelete(yarn, isKorean);
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
      body: yarnAsync.when(
        data: (yarn) {
          if (yarn == null) {
            return Center(child: Text(isKorean ? '실 정보를 찾을 수 없어요.' : 'Yarn not found.', style: T.body.copyWith(color: C.mu)));
          }
          if (_isEditing) {
            return _buildEditBody(isKorean);
          }
          return _buildDetailBody(yarn, isKorean);
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lm)),
        error: (e, _) => Center(child: Text('$e', style: T.body.copyWith(color: C.og))),
      ),
    );
  }

  // ── 보기 모드 ─────────────────────────────────────────────
  Widget _buildDetailBody(YarnModel yarn, bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // 기본 정보
            SectionTitle(title: isKorean ? '📝 기본 정보' : '📝 Basic Info'),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: isKorean ? '브랜드' : 'Brand', value: yarn.brandName, isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: isKorean ? '이름' : 'Name',
                    value: yarn.name.isNotEmpty ? yarn.name : (isKorean ? '이름 없음' : 'No name'),
                    isKorean: isKorean,
                  ),
                  if (yarn.photoUrl.isNotEmpty || yarn.labelPhotoUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (yarn.photoUrl.isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isKorean ? '실 사진' : 'Yarn', style: T.caption.copyWith(color: C.mu)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(yarn.photoUrl, height: 120, width: double.infinity,
                                      fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                                ),
                              ],
                            ),
                          ),
                        if (yarn.photoUrl.isNotEmpty && yarn.labelPhotoUrl.isNotEmpty)
                          const SizedBox(width: 10),
                        if (yarn.labelPhotoUrl.isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isKorean ? '라벨 사진' : 'Label', style: T.caption.copyWith(color: C.mu)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(yarn.labelPhotoUrl, height: 120, width: double.infinity,
                                      fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 상세 정보
            SectionTitle(title: isKorean ? '🔍 상세 정보' : '🔍 Details'),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (yarn.color.isNotEmpty || yarn.colorCode.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(isKorean ? '색상' : 'Color', style: T.caption.copyWith(color: C.mu)),
                        ),
                        if (yarn.colorCode.isNotEmpty)
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _parseColor(yarn.colorCode) ?? C.lmG,
                              border: Border.all(color: C.bd),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            yarn.color.isNotEmpty ? yarn.color : '-',
                            style: yarn.color.isNotEmpty ? T.body : T.body.copyWith(color: C.mu),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  _InfoRow(label: isKorean ? '소재' : 'Material', value: yarn.material, isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '굵기' : 'Weight', value: yarn.weight, isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '보유량' : 'Amount', value: yarn.amountGrams > 0 ? '${yarn.amountGrams}g' : '', isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '보유 타래' : 'Skeins', value: yarn.quantity > 0 ? '${yarn.quantity}${isKorean ? '타래' : ''}' : '', isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '총 길이' : 'Total length', value: yarn.lengthMeters > 0 ? '${yarn.lengthMeters}m' : '', isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '실길이' : 'Length', value: yarn.yarnLength, isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '로트번호' : 'Lot No.', value: yarn.lotNumber, isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '가격' : 'Price', value: yarn.price > 0 ? (isKorean ? '${yarn.price}원' : '${yarn.price}') : '', isKorean: isKorean),
                  const SizedBox(height: 8),
                  _InfoRow(label: isKorean ? '구입처' : 'Purchased at', value: yarn.purchasePlace, isKorean: isKorean),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 메모
            SectionTitle(title: isKorean ? '📝 메모' : '📝 Notes'),
            const SizedBox(height: 8),
            GlassCard(
              child: Text(
                yarn.memo.isNotEmpty ? yarn.memo : (isKorean ? '(없음)' : '(none)'),
                style: yarn.memo.isNotEmpty ? T.body : T.body.copyWith(color: C.mu),
              ),
            ),
            if (yarn.createdAt != null) ...[
              const SizedBox(height: 12),
              Text(
                '${isKorean ? '저장일' : 'Saved'}: ${_formatDate(yarn.createdAt!)}',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── 수정 모드 ─────────────────────────────────────────────
  Widget _buildEditBody(bool isKorean) {
    final yarn = ref.watch(yarnInputProvider);
    final notifier = ref.read(yarnInputProvider.notifier);

    return Stack(
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
                        _EditPhotoPicker(
                          photoUrl: yarn.photoUrl,
                          localPath: _localPhotoPath,
                          uploading: _uploading,
                          emptyIcon: Icons.texture,
                          emptyLabel: isKorean ? '실 사진' : 'Yarn',
                          isKorean: isKorean,
                          onTap: () => _pickPhoto(notifier, isKorean),
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
                        _EditPhotoPicker(
                          photoUrl: yarn.labelPhotoUrl,
                          localPath: _localLabelPhotoPath,
                          uploading: _uploadingLabel,
                          emptyIcon: Icons.label_outline_rounded,
                          emptyLabel: isKorean ? '라벨 사진' : 'Label',
                          isKorean: isKorean,
                          onTap: () => _pickLabelPhoto(notifier, isKorean),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 브랜드
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '🏷️ 브랜드' : '🏷️ Brand'),
                  const SizedBox(height: 10),
                  _PickerField(
                    label: isKorean ? '브랜드명' : 'Brand name',
                    value: yarn.brandName,
                    hint: isKorean ? '브랜드 검색 또는 직접 입력' : 'Search or enter brand',
                    onTap: () => BrandSearchSheet.show(
                      context,
                      brandType: BrandType.yarn,
                      onSelected: (_, name) => notifier.updateBrandName(name),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 실 이름
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '🧵 실 정보' : '🧵 Yarn Info'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: isKorean ? '실 이름' : 'Yarn name',
                      hintText: isKorean ? '예: 메리노 엑스트라 파인' : 'e.g. Merino Extra Fine',
                    ),
                    onChanged: notifier.updateName,
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 소재
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '🌿 소재' : '🌿 Material'),
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
                ]),
              ),
              const SizedBox(height: 14),
              // 색상
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '🎨 색상' : '🎨 Color'),
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
                      decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bd)),
                      child: Row(
                        children: [
                          if (yarn.colorCode.isNotEmpty) ...[
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: () {
                                  try {
                                    final hex = yarn.colorCode.replaceAll('#', '');
                                    return Color(int.parse('FF$hex', radix: 16));
                                  } catch (_) { return C.bd2; }
                                }(),
                                border: Border.all(color: C.bd),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              yarn.color.isEmpty ? (isKorean ? '색상을 선택하세요' : 'Select a color') : yarn.color,
                              style: yarn.color.isEmpty ? T.body.copyWith(color: C.mu) : T.body,
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
                      hintText: isKorean ? '예: 핑크, #FFC0CB' : 'e.g. Pink',
                    ),
                    onChanged: notifier.updateColor,
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 굵기
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '📏 굵기' : '📏 Weight'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _weightOptions.map((w) {
                      final isSelected = yarn.weight == w;
                      return MoriChip(
                        label: w,
                        type: isSelected ? ChipType.lavender : ChipType.white,
                        onTap: () => notifier.updateWeight(isSelected ? '' : w),
                      );
                    }).toList(),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 보유 정보
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '📦 보유 정보' : '📦 Stock Info'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isKorean ? '보유량 (g)' : 'Amount (g)',
                      hintText: isKorean ? '예: 200' : 'e.g. 200',
                      suffixText: 'g',
                    ),
                    onChanged: (v) => notifier.updateAmountGrams(int.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _yarnLengthController,
                    decoration: InputDecoration(
                      labelText: isKorean ? '실길이' : 'Length',
                      hintText: isKorean ? '예: 200m' : 'e.g. 200m',
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
                      hintText: isKorean ? '예: 뜨개나라' : 'e.g. Yarn store',
                    ),
                    onChanged: notifier.updatePurchasePlace,
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 보유 현황
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '📦 보유 현황' : '📦 Stock'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isKorean ? '보유 타래 수' : 'Skeins owned',
                      hintText: isKorean ? '예: 3' : 'e.g. 3',
                      suffixText: isKorean ? '타래' : 'skeins',
                    ),
                    onChanged: (v) => notifier.updateQuantity(int.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lengthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isKorean ? '총 길이 (m)' : 'Total length (m)',
                      hintText: isKorean ? '예: 600' : 'e.g. 600',
                      suffixText: 'm',
                    ),
                    onChanged: (v) => notifier.updateLengthMeters(int.tryParse(v) ?? 0),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // 메모
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title: isKorean ? '📝 메모' : '📝 Memo'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _memoController,
                    minLines: 3, maxLines: 5,
                    decoration: InputDecoration(
                      hintText: isKorean ? '실에 대한 메모를 입력하세요' : 'Add notes about this yarn',
                    ),
                    onChanged: notifier.updateMemo,
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(context, isKorean),
                  child: Text(isKorean ? '저장' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color? _parseColor(String hexCode) {
    if (hexCode.isEmpty) return null;
    try {
      final hex = hexCode.replaceAll('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    return null;
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
            value.isNotEmpty ? value : (isKorean ? '-' : '-'),
            style: value.isNotEmpty ? T.body : T.body.copyWith(color: C.mu),
          ),
        ),
      ],
    );
  }
}

// ── 선택 필드 (수정 모드) ──────────────────────────────────
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
    return GestureDetector(
      onTap: onTap,
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
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: value.isEmpty ? T.body.copyWith(color: C.mu) : T.body,
              ),
            ),
            Icon(Icons.chevron_right, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EditPhotoPicker extends StatelessWidget {
  final String photoUrl;
  final String? localPath;
  final bool uploading;
  final IconData emptyIcon;
  final String emptyLabel;
  final bool isKorean;
  final VoidCallback onTap;

  const _EditPhotoPicker({
    required this.photoUrl,
    this.localPath,
    required this.uploading,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.isKorean,
    required this.onTap,
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
                          ? Image.file(File(localPath!), fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                          : Image.network(photoUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(emptyIcon, color: C.lv, size: 36),
                        const SizedBox(height: 8),
                        Text(emptyLabel, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
                      ],
                    ),
        ),
      ),
    );
  }
}
