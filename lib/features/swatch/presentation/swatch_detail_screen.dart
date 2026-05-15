import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/needle_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../my/domain/needle_model.dart';
import '../../project/domain/project_model.dart';
import '../../project/presentation/project_input_screen.dart';
import '../data/swatch_timer_repository.dart';
import '../domain/swatch_model.dart';
import 'brand_search_sheet.dart';

class SwatchDetailScreen extends ConsumerStatefulWidget {
  final String swatchId;

  const SwatchDetailScreen({super.key, required this.swatchId});

  @override
  ConsumerState<SwatchDetailScreen> createState() => _SwatchDetailScreenState();
}

class _SwatchDetailScreenState extends ConsumerState<SwatchDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _linkedNeedleName;
  String? _linkedYarnName;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _memoCtrl;

  String? _localBeforePhotoPath;
  String? _localAfterPhotoPath;
  String? _beforePhotoUrl;
  String? _afterPhotoUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode(SwatchModel swatch) {
    _nameCtrl.text = swatch.swatchName;
    _memoCtrl.text = swatch.memo;
    _beforePhotoUrl = swatch.beforePhotoUrl.isNotEmpty ? swatch.beforePhotoUrl : null;
    _afterPhotoUrl = swatch.afterPhotoUrl.isNotEmpty ? swatch.afterPhotoUrl : null;
    setState(() {
      _isEditing = true;
      _localBeforePhotoPath = null;
      _localAfterPhotoPath = null;
    });
    // autoDispose 방지: setState 후 loadSwatch 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(swatchInputProvider.notifier).loadSwatch(swatch);
    });
  }

  void _cancelEdit() => setState(() { _isEditing = false; _linkedNeedleName = null; _linkedYarnName = null; });

  Future<void> _pickPhoto({required bool isBefore, required bool isKorean}) async {
    final ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: C.bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: C.lv),
                title: Text(isKorean ? '사진 촬영' : 'Take a photo', style: T.body),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    setState(() {
      if (isBefore) {
        _localBeforePhotoPath = picked.path;
      } else {
        _localAfterPhotoPath = picked.path;
      }
    });
  }

  void _selectNeedleFromMyNeedles(BuildContext context, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final notifier = ref.read(swatchInputProvider.notifier);
          final needles = cRef.watch(needleListProvider).valueOrNull ?? [];
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 8),
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                      isKorean ? '나의 바늘에서 선택' : 'Select from My Needles',
                      style: T.h3),
                ),
                if (needles.isEmpty)
                  Expanded(
                      child: Center(
                          child: Text(
                              isKorean ? '등록된 바늘이 없어요.' : 'No needles found.',
                              style: T.body.copyWith(color: C.mu))))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: needles.length,
                      itemBuilder: (_, i) {
                        final needle = needles[i];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: C.lv.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.settings_outlined, color: C.lvD, size: 20),
                          ),
                          title: Text(
                              needle.name.isNotEmpty ? needle.name : needle.sizeDisplay,
                              style: T.bodyBold),
                          subtitle: Text(
                              '${needle.sizeDisplay} · ${needle.brandName.isNotEmpty ? needle.brandName : (isKorean ? "브랜드 없음" : "No brand")}',
                              style: T.caption.copyWith(color: C.mu)),
                          onTap: () {
                            notifier.updateNeedleSize(needle.size);
                            notifier.updateMyNeedleId(needle.id);
                            notifier.updateMyNeedlePhotoUrl(needle.photoUrl);
                            if (needle.brandName.isNotEmpty) {
                              notifier.updateNeedleBrand('', needle.brandName);
                            }
                            setState(() => _linkedNeedleName = needle.name.isNotEmpty ? needle.name : needle.sizeDisplay);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectYarnFromMyYarns(BuildContext context, bool isKorean) {
    final notifier = ref.read(swatchInputProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Consumer(
            builder: (context, ref, _) {
              final yarnsAsync = ref.watch(yarnListProvider);
              return yarnsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (yarns) => yarns.isEmpty
                    ? Center(
                        child: Text(
                          isKorean ? '등록된 실이 없어요' : 'No yarns found',
                          style: T.body.copyWith(color: C.mu),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: yarns.length,
                        itemBuilder: (ctx, i) {
                          final yarn = yarns[i];
                          return ListTile(
                            leading: yarn.photoUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(yarn.photoUrl,
                                        width: 44, height: 44, fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: C.lv.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.color_lens_outlined, color: C.lvD, size: 20),
                                        )),
                                  )
                                : Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: C.lv.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.color_lens_outlined, color: C.lvD, size: 20),
                                  ),
                            title: Text(
                                yarn.name.isNotEmpty ? yarn.name : yarn.brandName,
                                style: T.bodyBold),
                            subtitle: Text(
                                '${yarn.brandName.isNotEmpty ? yarn.brandName : (isKorean ? "브랜드 없음" : "No brand")}${yarn.color.isNotEmpty ? " · ${yarn.color}" : ""}',
                                style: T.caption.copyWith(color: C.mu)),
                            onTap: () {
                              notifier.updateMyYarnId(yarn.id);
                              notifier.updateMyYarnPhotoUrl(yarn.photoUrl);
                              if (yarn.brandName.isNotEmpty) {
                                notifier.updateYarnBrand('', yarn.brandName);
                              }
                              setState(() => _linkedYarnName = yarn.name.isNotEmpty ? yarn.name : yarn.brandName);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveEdit(bool isKorean) async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 세탁 전 사진 업로드
          if (_localBeforePhotoPath != null) {
            final file = File(_localBeforePhotoPath!);
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('swatches/before_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await storageRef.putFile(file);
            _beforePhotoUrl = await storageRef.getDownloadURL();
          }
          // 세탁 후 사진 업로드
          if (_localAfterPhotoPath != null) {
            final file = File(_localAfterPhotoPath!);
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('swatches/after_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await storageRef.putFile(file);
            _afterPhotoUrl = await storageRef.getDownloadURL();
          }
          final updatedSwatch = ref.read(swatchInputProvider).copyWith(
            memo: _memoCtrl.text.trim(),
            swatchName: _nameCtrl.text.trim(),
            beforePhotoUrl: _beforePhotoUrl ?? '',
            afterPhotoUrl: _afterPhotoUrl ?? '',
          );
          await ref.read(swatchRepositoryProvider).updateSwatch(updatedSwatch);
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

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchAsync = ref.watch(swatchByIdProvider(widget.swatchId));
    // autoDispose 방지: 수정 모드 진입 시 provider 살아있도록 항상 watch
    ref.watch(swatchInputProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: _isEditing ? (isKorean ? '스와치 수정' : 'Edit Swatch') : t.swatchDetails,
                subtitle: isKorean ? '스와치 상세' : 'Swatch details',
                trailing: _isEditing
                    ? [
                        TextButton(
                          onPressed: _cancelEdit,
                          child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
                        ),
                        TextButton(
                          onPressed: _isSaving ? null : () => _saveEdit(isKorean),
                          child: Text(
                            isKorean ? '저장' : 'Save',
                            style: T.bodyBold.copyWith(color: C.lv),
                          ),
                        ),
                      ]
                    : [
                        swatchAsync.whenOrNull(
                              data: (swatch) => swatch == null
                                  ? null
                                  : Builder(
                                      builder: (ctx) {
                                        return PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, color: C.tx),
                                          onSelected: (v) {
                                            if (v == 'edit') _enterEditMode(swatch);
                                            if (v == 'copy') _duplicateSwatch(context, ref, swatch);
                                            if (v == 'link_project') _linkToProject(context, ref, swatch.id, isKorean);
                                            if (v == 'timer') {
                                              context.push(
                                                '/swatch/${swatch.id}/timer?name=${Uri.encodeQueryComponent(swatch.swatchName)}',
                                              );
                                            }
                                            if (v == 'delete') _confirmDelete(context, ref, swatch);
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18, color: C.lv),
                                                  const SizedBox(width: 8),
                                                  Text(isKorean ? '수정' : 'Edit'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'copy',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.copy_rounded, size: 18, color: C.lv),
                                                  const SizedBox(width: 8),
                                                  Text(isKorean ? '복사' : 'Duplicate'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'link_project',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.folder_outlined, size: 18, color: C.lv),
                                                  const SizedBox(width: 8),
                                                  Text(isKorean ? '프로젝트에 연결' : 'Link to project'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'timer',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.timer_rounded, size: 18, color: C.lv),
                                                  const SizedBox(width: 8),
                                                  Text(isKorean ? '작업 타이머' : 'Work Timer'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isKorean ? '삭제' : 'Delete',
                                                    style: TextStyle(color: Colors.red.shade400),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ) ??
                            const SizedBox.shrink(),
                      ],
              ),
            ),
            Expanded(
              child: swatchAsync.when(
                data: (swatch) {
                  if (swatch == null) {
                    return Center(child: Text(t.swatchNotFound, style: T.body.copyWith(color: C.mu)));
                  }
                  if (_isEditing) return _buildEditBody(swatch, isKorean);
                  return _SwatchDetailBody(swatch: swatch);
                },
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (error, _) => Center(
                  child: Text(t.failedToLoadSwatch(error.toString()), style: T.body.copyWith(color: C.og)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isEditing
          ? null
          : swatchAsync.whenOrNull(
              data: (swatch) => swatch == null
                  ? null
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: ElevatedButton.icon(
                          onPressed: () => _startProjectWithSwatch(context, ref, swatch),
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                          label: Text(isKorean ? '이 스와치로 프로젝트 시작하기' : 'Start Project with This Swatch'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            backgroundColor: C.lv,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _buildEditBody(SwatchModel initialSwatch, bool isKorean) {
    final swatch = ref.watch(swatchInputProvider);
    final notifier = ref.read(swatchInputProvider.notifier);
    final t = ref.watch(appStringsProvider);

    return Stack(
      children: [
        const BgOrbs(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: isKorean ? '이름 (닉네임)' : 'Name (nickname)'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      onChanged: notifier.updateSwatchName,
                      decoration: InputDecoration(
                        labelText: isKorean ? '스와치 이름 (선택)' : 'Swatch name (optional)',
                        hintText: isKorean ? '예: 핑크 메리노 테스트' : 'e.g. Pink Merino Test',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 세탁 전 게이지
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
                    const SizedBox(height: 14),
                    _PhotoEditTile(
                      label: isKorean ? '세탁 전 사진' : 'Before wash photo',
                      localPath: _localBeforePhotoPath,
                      networkUrl: _beforePhotoUrl,
                      onTap: () => _pickPhoto(isBefore: true, isKorean: isKorean),
                      onRemove: () => setState(() {
                        _localBeforePhotoPath = null;
                        _beforePhotoUrl = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 세탁 후 게이지
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
                      const SizedBox(height: 10),
                      _PhotoEditTile(
                        label: isKorean ? '세탁 후 사진' : 'After wash photo',
                        localPath: _localAfterPhotoPath,
                        networkUrl: _afterPhotoUrl,
                        onTap: () => _pickPhoto(isBefore: false, isKorean: isKorean),
                        onRemove: () => setState(() {
                          _localAfterPhotoPath = null;
                          _afterPhotoUrl = null;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 바늘 정보
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: t.needleInfo),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _selectNeedleFromMyNeedles(context, isKorean),
                      icon: Icon(Icons.settings_outlined, size: 16, color: C.lv),
                      label: Text(
                        isKorean ? '나의 바늘에서 선택' : 'Select from My Needles',
                        style: T.body.copyWith(color: C.lv),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_linkedNeedleName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.lv.withValues(alpha: 0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_outline, color: C.lv, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isKorean ? '나의 바늘 연동됨: $_linkedNeedleName' : 'Linked: $_linkedNeedleName',
                            style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
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
              // 실 정보
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: t.yarnInfo),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _selectYarnFromMyYarns(context, isKorean),
                      icon: Icon(Icons.color_lens_outlined, size: 16, color: C.lv),
                      label: Text(
                        isKorean ? '나의 실에서 선택' : 'Select from My Yarns',
                        style: T.body.copyWith(color: C.lv),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_linkedYarnName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.lv.withValues(alpha: 0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_outline, color: C.lv, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isKorean ? '나의 실 연동됨: $_linkedYarnName' : 'Linked: $_linkedYarnName',
                            style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 4),
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
              // 메모
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: t.memo),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _memoCtrl,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: notifier.updateMemo,
                      decoration: InputDecoration(
                        hintText: t.memoHintSwatch,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startProjectWithSwatch(BuildContext context, WidgetRef ref, SwatchModel swatch) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final initialProject = ProjectModel.empty(uid: user.uid).copyWith(swatchId: swatch.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectInputScreen(initialProject: initialProject)),
    );
  }

  void _linkToProject(BuildContext context, WidgetRef ref, String swatchId, bool isKorean) {
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
                          final alreadyLinked = project.swatchId == swatchId;
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
                                task: () => ref.read(projectRepositoryProvider).updateProject(project.copyWith(swatchId: swatchId)),
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

  Future<void> _duplicateSwatch(BuildContext context, WidgetRef ref, SwatchModel swatch) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(swatchRepositoryProvider).duplicateSwatch(swatch),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SwatchModel swatch) async {
    final t = ref.read(appStringsProvider);
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.deleteSwatch, style: T.h3),
        content: Text(t.deleteSwatchConfirm, style: T.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.deleteSwatch),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () async {
            await ref.read(swatchRepositoryProvider).deleteSwatch(swatch.id);
          },
        );
        if (!context.mounted) return;
        Navigator.pop(context);
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '삭제됐어요.' : 'Deleted.',
        );
      } catch (e) {
        if (!context.mounted) return;
        final msg = e.toString();
        final friendly = (msg.contains('인터넷') || msg.contains('TimeoutException'))
            ? (isKorean ? '인터넷 연결을 확인해 주세요' : 'Check your internet connection')
            : msg;
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: friendly);
      }
    }
  }
}

class _SwatchDetailBody extends ConsumerWidget {
  final SwatchModel swatch;

  const _SwatchDetailBody({required this.swatch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final needleAsync = ref.watch(needleListProvider);
    final yarnAsync = ref.watch(yarnListProvider);

    // 연동된 바늘 찾기
    NeedleModel? myNeedle;
    if (swatch.myNeedleId.isNotEmpty) {
      final needles = needleAsync.valueOrNull ?? [];
      for (final n in needles) {
        if (n.id == swatch.myNeedleId) { myNeedle = n; break; }
      }
    }

    // 연동된 실 찾기
    final yarnList = yarnAsync.valueOrNull ?? [];
    dynamic myYarn;
    if (swatch.myYarnId.isNotEmpty) {
      for (final y in yarnList) {
        if (y.id == swatch.myYarnId) { myYarn = y; break; }
      }
    }

    // 바늘 카드 표시 여부
    final showNeedle = myNeedle != null || swatch.needleSize > 0 || swatch.needleBrandName.isNotEmpty;
    // 실 카드 표시 여부
    final showYarn = myYarn != null || swatch.yarnBrandName.isNotEmpty || swatch.yarnWeight.isNotEmpty || swatch.yarnColor.isNotEmpty;

    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _PhotoHeader(beforePhotoUrl: swatch.beforePhotoUrl, afterPhotoUrl: swatch.afterPhotoUrl, swatchId: swatch.id),
            const SizedBox(height: 12),
            // 이슈 #630 (B-5) — 작업 시간 카드 (⋮ 메뉴 의존도 낮추기)
            _SwatchTimerSummaryCard(swatch: swatch, isKorean: isKorean),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (swatch.isDirty) ...[
                    _SyncPendingBadge(label: t.pendingSync),
                    const SizedBox(height: 12),
                  ],
                  if (swatch.swatchName.isNotEmpty) ...[
                    Text(swatch.swatchName, style: T.h2.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                  ],
                  if (swatch.yarnName.isNotEmpty) ...[
                    Text(swatch.yarnName, style: T.h2),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    t.stitchesRows(swatch.beforeStitchCount, swatch.beforeRowCount),
                    style: T.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    swatch.yarnBrandName.isEmpty ? t.yarnBrandNotSet : swatch.yarnBrandName,
                    style: T.body.copyWith(color: C.mu),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GaugeCard(swatch: swatch),
            const SizedBox(height: 12),
            if (showNeedle) ...[
              _InfoCard(
                icon: Icons.circle_outlined,
                title: t.needleInfo,
                rows: [
                  if (myNeedle != null) ...[
                    if (myNeedle.name.isNotEmpty) _InfoRowData(isKorean ? '이름' : 'Name', myNeedle.name),
                    _InfoRowData(t.size, myNeedle.sizeDisplay),
                    if (myNeedle.brandName.isNotEmpty) _InfoRowData(t.brand, myNeedle.brandName),
                  ] else ...[
                    if (swatch.needleSize > 0) _InfoRowData(t.size, swatch.needleSizeDisplay),
                    if (swatch.needleBrandName.isNotEmpty) _InfoRowData(t.brand, swatch.needleBrandName),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (showYarn) ...[
              _InfoCard(
                icon: Icons.texture,
                title: t.yarnInfo,
                rows: [
                  if (myYarn != null) ...[
                    if ((myYarn.name as String).isNotEmpty) _InfoRowData(isKorean ? '이름' : 'Name', myYarn.name as String),
                    if ((myYarn.brandName as String).isNotEmpty) _InfoRowData(t.brand, myYarn.brandName as String),
                    if ((myYarn.color as String).isNotEmpty) _InfoRowData(t.color, myYarn.color as String),
                    if ((myYarn.weight as String).isNotEmpty) _InfoRowData(t.weight, myYarn.weight as String),
                  ] else ...[
                    if (swatch.yarnBrandName.isNotEmpty) _InfoRowData(t.brand, swatch.yarnBrandName),
                    if (swatch.yarnWeight.isNotEmpty) _InfoRowData(t.weight, swatch.yarnWeight),
                    if (swatch.yarnColor.isNotEmpty) _InfoRowData(t.color, swatch.yarnColor),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (swatch.memo.isNotEmpty) ...[
              _MemoCard(title: t.memo, memo: swatch.memo),
              const SizedBox(height: 12),
            ],
            if (swatch.createdAt != null)
              Text(
                t.savedOn(_formatDate(swatch.createdAt!)),
                style: T.caption.copyWith(color: C.mu),
              ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _PhotoHeader extends StatelessWidget {
  final String beforePhotoUrl;
  final String afterPhotoUrl;
  final String swatchId;

  const _PhotoHeader({
    required this.beforePhotoUrl,
    required this.afterPhotoUrl,
    required this.swatchId,
  });

  @override
  Widget build(BuildContext context) {
    final hasBefore = beforePhotoUrl.isNotEmpty;
    final hasAfter = afterPhotoUrl.isNotEmpty;

    if (!hasBefore && !hasAfter) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(18)),
        child: Center(child: Icon(Icons.texture, color: C.lv, size: 48)),
      );
    }

    // 두 사진 모두 있으면 좌우 나란히 표시
    if (hasBefore && hasAfter) {
      return Row(
        children: [
          Expanded(child: _PhotoThumb(photoUrl: beforePhotoUrl, heroTag: 'swatch_before_$swatchId', label: '세탁전')),
          const SizedBox(width: 8),
          Expanded(child: _PhotoThumb(photoUrl: afterPhotoUrl, heroTag: 'swatch_after_$swatchId', label: '세탁후')),
        ],
      );
    }

    // 하나만 있으면 큰 사진으로 표시
    final url = hasBefore ? beforePhotoUrl : afterPhotoUrl;
    final heroTag = hasBefore ? 'swatch_before_$swatchId' : 'swatch_after_$swatchId';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FullScreenImageViewer(imageUrl: url, heroTag: heroTag))),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(height: 220, width: double.infinity, child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String photoUrl;
  final String heroTag;
  final String label;

  const _PhotoThumb({required this.photoUrl, required this.heroTag, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FullScreenImageViewer(imageUrl: photoUrl, heroTag: heroTag))),
      child: Column(
        children: [
          Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(height: 160, width: double.infinity, child: Image.network(photoUrl, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Hero(
                tag: heroTag,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPendingBadge extends StatelessWidget {
  final String label;

  const _SyncPendingBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.og.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 12, color: C.og),
          const SizedBox(width: 4),
          Text(label, style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GaugeCard extends ConsumerWidget {
  final SwatchModel swatch;

  const _GaugeCard({required this.swatch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.gaugeResult, style: T.captionBold.copyWith(color: C.mu)),
          const SizedBox(height: 12),
          _GaugeRow(label: t.beforeAfterLabel(true), stitchCount: swatch.beforeStitchCount, rowCount: swatch.beforeRowCount, color: C.lv),
          if (swatch.hasAfterWash) ...[
            const SizedBox(height: 10),
            _GaugeRow(label: t.beforeAfterLabel(false), stitchCount: swatch.afterStitchCount, rowCount: swatch.afterRowCount, color: C.pk),
            const SizedBox(height: 12),
            MoriChip(label: t.shrinkageLabel(swatch.shrinkageRate), type: ChipType.lime),
          ],
        ],
      ),
    );
  }
}

class _GaugeRow extends ConsumerWidget {
  final String label;
  final int stitchCount;
  final int rowCount;
  final Color color;

  const _GaugeRow({
    required this.label,
    required this.stitchCount,
    required this.rowCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 52, child: Text(label, style: T.caption.copyWith(color: C.mu))),
        Expanded(
          child: Text(
            t.gauge10cm(stitchCount, rowCount),
            style: T.bodyBold.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_InfoRowData> rows;

  const _InfoCard({required this.icon, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: C.mu),
              const SizedBox(width: 6),
              Text(title, style: T.captionBold.copyWith(color: C.mu)),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 70, child: Text(row.label, style: T.caption)),
                  Expanded(child: Text(row.value, style: T.body)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  final String title;
  final String memo;

  const _MemoCard({required this.title, required this.memo});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.captionBold.copyWith(color: C.mu)),
          const SizedBox(height: 8),
          Text(memo, style: T.body),
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

class _PhotoEditTile extends StatelessWidget {
  final String label;
  final String? localPath;
  final String? networkUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoEditTile({
    required this.label,
    required this.onTap,
    required this.onRemove,
    this.localPath,
    this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || networkUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPhoto) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: localPath != null
                    ? Image.file(File(localPath!),
                        height: 160, width: double.infinity, fit: BoxFit.contain)
                    : Image.network(networkUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(
              hasPhoto ? Icons.edit_rounded : Icons.add_photo_alternate_outlined,
              size: 18),
          label: Text(hasPhoto ? label : '+ $label'),
          style: OutlinedButton.styleFrom(
            foregroundColor: C.lv,
            side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

/// 이슈 #630 (B-5) — 스와치 상세에 노출되는 작업시간 요약 카드.
/// ⋮ 메뉴 의존도 낮춤 — 본문에서 즉시 누적시간 확인 + 타이머 진입.
class _SwatchTimerSummaryCard extends ConsumerWidget {
  final SwatchModel swatch;
  final bool isKorean;

  const _SwatchTimerSummaryCard({required this.swatch, required this.isKorean});

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(swatchTimerStreamProvider(swatch.id));

    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        context.push(
          '/swatch/${swatch.id}/timer?name=${Uri.encodeQueryComponent(swatch.swatchName)}',
        );
      },
      child: async.when(
        loading: () => SizedBox(
          height: 48,
          child: Center(
            child: CircularProgressIndicator(color: C.lv, strokeWidth: 2),
          ),
        ),
        error: (e, _) => Text(
          isKorean ? '시간 불러오기 실패' : 'Failed to load time',
          style: T.caption.copyWith(color: C.og),
        ),
        data: (state) {
          final running = state.isRunning;
          int sessionSeconds = 0;
          if (running && state.currentSessionStart != null) {
            sessionSeconds = DateTime.now()
                .difference(state.currentSessionStart!)
                .inSeconds
                .clamp(0, 1 << 30);
          }
          final total = state.totalSeconds + sessionSeconds;
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: running
                      ? C.lv.withValues(alpha: 0.18)
                      : C.lv.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  running ? Icons.timer_rounded : Icons.timer_outlined,
                  color: C.lvD,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean ? '작업 시간' : 'Work Time',
                      style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatHms(total),
                          style: T.h3.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        if (running)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.lv,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isKorean ? '진행 중' : 'RUNNING',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.mu),
            ],
          );
        },
      ),
    );
  }
}
