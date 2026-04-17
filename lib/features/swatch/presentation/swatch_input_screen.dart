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
import '../../../providers/accessory_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/needle_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../my/data/mori_service.dart';
import '../../my/domain/accessory_model.dart';
import '../../my/domain/needle_model.dart';
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
  String? _linkedNeedleName;
  String? _linkedYarnName;
  String? _linkedAccessoryName;

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
                _TopPhotoDualCard(
                  yarnPhotoUrl: swatch.myYarnPhotoUrl,
                  swatchPhotoUrl: swatch.beforePhotoUrl,
                  onYarnPhotoSelected: notifier.updateMyYarnPhotoUrl,
                  onSwatchPhotoSelected: notifier.updateBeforePhotoUrl,
                  t: t,
                ),
                const SizedBox(height: 14),
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
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectNeedleFromMyNeedles(isKorean),
                        icon: Icon(Icons.settings_outlined, size: 16, color: C.lv),
                        label: Text(isKorean ? '나의 바늘에서 선택' : 'Select from My Needles', style: T.body.copyWith(color: C.lv)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      if (_linkedNeedleName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lv.withValues(alpha: 0.30))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_outline, color: C.lv, size: 14),
                            const SizedBox(width: 6),
                            Text(isKorean ? '연동됨: $_linkedNeedleName' : 'Linked: $_linkedNeedleName', style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectYarnFromMyYarns(isKorean),
                        icon: Icon(Icons.color_lens_outlined, size: 16, color: C.lv),
                        label: Text(isKorean ? '나의 실에서 선택' : 'Select from My Yarns', style: T.body.copyWith(color: C.lv)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      if (_linkedYarnName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lv.withValues(alpha: 0.30))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_outline, color: C.lv, size: 14),
                            const SizedBox(width: 6),
                            Text(isKorean ? '연동됨: $_linkedYarnName' : 'Linked: $_linkedYarnName', style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 10),
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
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '나의 악세사리 연결' : 'My Accessories'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectAccessoryFromMyAccessories(isKorean),
                        icon: Icon(Icons.diamond_outlined, size: 16, color: C.lv),
                        label: Text(isKorean ? '나의 악세사리에서 선택' : 'Select from My Accessories', style: T.body.copyWith(color: C.lv)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      if (_linkedAccessoryName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lv.withValues(alpha: 0.30))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_outline, color: C.lv, size: 14),
                            const SizedBox(width: 6),
                            Text(isKorean ? '연동됨: $_linkedAccessoryName' : 'Linked: $_linkedAccessoryName', style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(isKorean ? '연결된 악세사리 없음' : 'No accessory linked', style: T.caption.copyWith(color: C.mu)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(title: isKorean ? '최종 완성 콧수 / 단수' : 'Final Stitch / Row Count'),
                      const SizedBox(height: 6),
                      Text(
                        isKorean ? '10×10 게이지와 별개로, 작품 완성 후 실제 콧수와 단수를 기록해요.' : 'Record actual stitch & row counts of finished piece (separate from 10×10 gauge).',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GaugeInput(
                              label: isKorean ? '최종 콧수' : 'Final sts',
                              value: swatch.finalStitchCount,
                              color: C.lv,
                              onMinus: () => notifier.updateFinalStitchCount((swatch.finalStitchCount - 1).clamp(0, 9999)),
                              onPlus: () => notifier.updateFinalStitchCount((swatch.finalStitchCount + 1).clamp(0, 9999)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GaugeInput(
                              label: isKorean ? '최종 단수' : 'Final rows',
                              value: swatch.finalRowCount,
                              color: C.lv,
                              onMinus: () => notifier.updateFinalRowCount((swatch.finalRowCount - 1).clamp(0, 9999)),
                              onPlus: () => notifier.updateFinalRowCount((swatch.finalRowCount + 1).clamp(0, 9999)),
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
                      SectionTitle(title: isKorean ? '시작 날짜' : 'Start Date'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: swatch.startedAt ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) notifier.updateStartedAt(picked);
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
                              Icon(Icons.calendar_today_outlined, color: C.mu, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  swatch.startedAt != null
                                      ? '${swatch.startedAt!.year}.${swatch.startedAt!.month.toString().padLeft(2, '0')}.${swatch.startedAt!.day.toString().padLeft(2, '0')}'
                                      : (isKorean ? '날짜 선택 (선택사항)' : 'Select date (optional)'),
                                  style: swatch.startedAt != null ? T.body : T.body.copyWith(color: C.mu),
                                ),
                              ),
                              if (swatch.startedAt != null)
                                GestureDetector(
                                  onTap: () => notifier.updateStartedAt(null),
                                  child: Icon(Icons.close, color: C.mu, size: 18),
                                ),
                            ],
                          ),
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

  void _selectNeedleFromMyNeedles(bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(isKorean ? '나의 바늘에서 선택' : 'Select from My Needles', style: T.h3),
                ),
                if (needles.isEmpty)
                  Expanded(child: Center(child: Text(isKorean ? '등록된 바늘이 없어요.' : 'No needles found.', style: T.body.copyWith(color: C.mu))))
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
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.settings_outlined, color: C.lvD, size: 20),
                          ),
                          title: Text(needle.name.isNotEmpty ? needle.name : needle.sizeDisplay, style: T.bodyBold),
                          subtitle: Text('${needle.sizeDisplay} · ${needle.brandName.isNotEmpty ? needle.brandName : (isKorean ? "브랜드 없음" : "No brand")}', style: T.caption.copyWith(color: C.mu)),
                          onTap: () {
                            notifier.updateNeedleSize(needle.size);
                            notifier.updateMyNeedleId(needle.id);
                            notifier.updateMyNeedlePhotoUrl(needle.photoUrl);
                            if (needle.brandName.isNotEmpty) notifier.updateNeedleBrand('', needle.brandName);
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

  void _selectYarnFromMyYarns(bool isKorean) {
    final notifier = ref.read(swatchInputProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
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
                  ? Center(child: Text(isKorean ? '등록된 실이 없어요' : 'No yarns found', style: T.body.copyWith(color: C.mu)))
                  : ListView.builder(
                      controller: controller,
                      itemCount: yarns.length,
                      itemBuilder: (ctx, i) {
                        final yarn = yarns[i];
                        return ListTile(
                          leading: yarn.photoUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(yarn.photoUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.color_lens_outlined, color: C.lvD, size: 20))))
                              : Container(width: 44, height: 44, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.color_lens_outlined, color: C.lvD, size: 20)),
                          title: Text(yarn.name.isNotEmpty ? yarn.name : yarn.brandName, style: T.bodyBold),
                          subtitle: Text('${yarn.brandName.isNotEmpty ? yarn.brandName : (isKorean ? "브랜드 없음" : "No brand")}${yarn.color.isNotEmpty ? " · ${yarn.color}" : ""}', style: T.caption.copyWith(color: C.mu)),
                          onTap: () {
                            notifier.updateMyYarnId(yarn.id);
                            notifier.updateMyYarnPhotoUrl(yarn.photoUrl);
                            if (yarn.brandName.isNotEmpty) notifier.updateYarnBrand('', yarn.brandName);
                            setState(() => _linkedYarnName = yarn.name.isNotEmpty ? yarn.name : yarn.brandName);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  void _selectAccessoryFromMyAccessories(bool isKorean) {
    final notifier = ref.read(swatchInputProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Consumer(
          builder: (context, ref, _) {
            final accessoriesAsync = ref.watch(accessoryListProvider);
            return accessoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (accessories) => accessories.isEmpty
                  ? Center(child: Text(isKorean ? '등록된 악세사리가 없어요' : 'No accessories found', style: T.body.copyWith(color: C.mu)))
                  : ListView.builder(
                      controller: controller,
                      itemCount: accessories.length,
                      itemBuilder: (ctx, i) {
                        final acc = accessories[i];
                        return ListTile(
                          leading: acc.photoUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(acc.photoUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.diamond_outlined, color: C.lvD, size: 20))))
                              : Container(width: 44, height: 44, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.diamond_outlined, color: C.lvD, size: 20)),
                          title: Text(acc.name.isNotEmpty ? acc.name : acc.localizedTypeLabel(isKorean), style: T.bodyBold),
                          subtitle: Text(acc.localizedTypeLabel(isKorean), style: T.caption.copyWith(color: C.mu)),
                          onTap: () {
                            notifier.updateMyAccessoryId(acc.id);
                            notifier.updateMyAccessoryName(acc.name.isNotEmpty ? acc.name : acc.localizedTypeLabel(isKorean));
                            setState(() => _linkedAccessoryName = acc.name.isNotEmpty ? acc.name : acc.localizedTypeLabel(isKorean));
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            );
          },
        ),
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

// ──────────────────────────────────────────────
// 최상단 2패널 사진 카드 (좌: 실사진 / 우: 스와치사진)
// ──────────────────────────────────────────────
class _TopPhotoDualCard extends StatefulWidget {
  final String yarnPhotoUrl;
  final String swatchPhotoUrl;
  final ValueChanged<String> onYarnPhotoSelected;
  final ValueChanged<String> onSwatchPhotoSelected;
  final AppStrings t;

  const _TopPhotoDualCard({
    required this.yarnPhotoUrl,
    required this.swatchPhotoUrl,
    required this.onYarnPhotoSelected,
    required this.onSwatchPhotoSelected,
    required this.t,
  });

  @override
  State<_TopPhotoDualCard> createState() => _TopPhotoDualCardState();
}

class _TopPhotoDualCardState extends State<_TopPhotoDualCard> {
  bool _uploadingYarn = false;
  bool _uploadingSwatch = false;
  String? _yarnLocalPath;
  String? _swatchLocalPath;

  Future<void> _pickAndUpload({
    required ImageSource source,
    required bool isYarn,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      if (isYarn) {
        _yarnLocalPath = picked.path;
        _uploadingYarn = true;
      } else {
        _swatchLocalPath = picked.path;
        _uploadingSwatch = true;
      }
    });

    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('swatches/${DateTime.now().millisecondsSinceEpoch}_${isYarn ? 'yarn' : 'swatch'}.jpg');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      if (isYarn) {
        widget.onYarnPhotoSelected(url);
      } else {
        widget.onSwatchPhotoSelected(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.t.failedToUploadImage(e.toString())), backgroundColor: C.og),
      );
    } finally {
      if (mounted) setState(() => isYarn ? _uploadingYarn = false : _uploadingSwatch = false);
    }
  }

  void _showPickerMenu({required bool isYarn}) {
    final photoUrl = isYarn ? widget.yarnPhotoUrl : widget.swatchPhotoUrl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(widget.t.chooseFromGallery),
              onTap: () { Navigator.pop(ctx); _pickAndUpload(source: ImageSource.gallery, isYarn: isYarn); },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(widget.t.takePhoto),
              onTap: () { Navigator.pop(ctx); _pickAndUpload(source: ImageSource.camera, isYarn: isYarn); },
            ),
            if (photoUrl.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline, color: C.og),
                title: Text(widget.t.removePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => isYarn ? _yarnLocalPath = null : _swatchLocalPath = null);
                  if (isYarn) { widget.onYarnPhotoSelected(''); } else { widget.onSwatchPhotoSelected(''); }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: isKorean ? '사진' : 'Photos'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _PhotoPanel(
                label: isKorean ? '실 사진' : 'Yarn',
                localPath: _yarnLocalPath,
                photoUrl: widget.yarnPhotoUrl,
                uploading: _uploadingYarn,
                onTap: () => _showPickerMenu(isYarn: true),
              )),
              const SizedBox(width: 10),
              Expanded(child: _PhotoPanel(
                label: isKorean ? '스와치 사진' : 'Swatch',
                localPath: _swatchLocalPath,
                photoUrl: widget.swatchPhotoUrl,
                uploading: _uploadingSwatch,
                onTap: () => _showPickerMenu(isYarn: false),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPanel extends StatelessWidget {
  final String label;
  final String? localPath;
  final String photoUrl;
  final bool uploading;
  final VoidCallback onTap;

  const _PhotoPanel({
    required this.label,
    required this.localPath,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localPath != null || photoUrl.isNotEmpty;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd2),
            ),
            child: uploading
                ? Center(child: CircularProgressIndicator(color: C.lv, strokeWidth: 2))
                : hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: localPath != null
                            ? Image.file(File(localPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                            : Image.network(photoUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 30),
                          const SizedBox(height: 4),
                          Text(label, style: T.caption.copyWith(color: C.mu)),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ──────────────────────────────────────────────

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
                              ? Image.file(File(_localPath!), fit: BoxFit.contain, width: double.infinity)
                              : Image.network(widget.photoUrl, fit: BoxFit.contain, width: double.infinity),
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
