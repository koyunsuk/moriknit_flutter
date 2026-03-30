import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../../market/domain/market_item.dart';
import '../../market/presentation/pdf_viewer_screen.dart';

class ProjectPatternsScreen extends ConsumerWidget {
  const ProjectPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final purchasedItemsAsync = ref.watch(ownedPurchasedPatternItemsProvider);
    final marketItemsAsync = ref.watch(myMarketItemsProvider);

    final orphanPurchases = ref.watch(orphanPurchasesProvider);

    final listedPatterns = (marketItemsAsync.valueOrNull ?? const <MarketItem>[])
        .where((item) => item.category == 'pattern')
        .toList();
    final purchasedPatterns = purchasedItemsAsync.valueOrNull ?? const <MarketItem>[];
    final merged = <String, MarketItem>{
      for (final item in purchasedPatterns) item.id: item,
      for (final item in listedPatterns) item.id: item,
    };
    final patterns = merged.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final myListedCount = listedPatterns.where((item) => item.sellerUid == user?.uid && item.status != 'library').length;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.projectPatternsTitle,
                subtitle: t.projectPatternsSubtitle,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _PatternSummaryMetric(
                            label: t.patternOwned,
                            value: '${patterns.length}',
                            color: C.pkD,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PatternSummaryMetric(
                            label: t.patternListed,
                            value: '$myListedCount',
                            color: C.lvD,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (purchasedItemsAsync.isLoading || marketItemsAsync.isLoading)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: C.lv),
                            ),
                          )
                        else if (patterns.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: C.lvL,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.noPatternsYet,
                                  style: T.bodyBold.copyWith(color: C.lvD),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.noPatternsDescription,
                                  style: T.caption.copyWith(color: C.lvD, height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => context.push(Routes.toolsPattern),
                                      icon: const Icon(Icons.auto_fix_high_rounded),
                                      label: Text(t.createPattern),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showPatternImportDialog(context, ref, t),
                                      icon: const Icon(Icons.file_open_rounded, size: 18),
                                      label: Text(t.registerPattern),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go(Routes.market),
                                      icon: const Icon(Icons.storefront_rounded, size: 18),
                                      label: Text(t.browsePatternMarket),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(child: Text(t.patternLibrary, style: T.bodyBold)),
                              TextButton.icon(
                                onPressed: () => _showPatternImportDialog(context, ref, t),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: Text(t.registerPattern),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.patternLibraryDescription,
                            style: T.caption.copyWith(color: C.mu),
                          ),
                          const SizedBox(height: 12),
                          ...patterns.map(
                            (item) => _PatternAssetRow(
                              item: item,
                              isKorean: isKorean,
                              ownedLabel: item.status == 'library'
                                  ? (isKorean ? '내가 저장한 도안' : 'Saved by me')
                                  : t.ownedPattern,
                              listedLabel: item.status == 'library'
                                  ? (isKorean ? '내 도안 라이브러리' : 'My pattern library')
                                  : t.listedByMe,
                              freeLabel: isKorean ? '무료' : 'Free',
                              onTap: () => _openPattern(context, item, t.patternFileMissing, t.viewPattern),
                            ),
                          ),
                          // 구매했으나 도안이 삭제된 항목
                          ...orphanPurchases.map(
                            (purchase) => _DeletedPatternRow(
                              title: purchase.title,
                              isKorean: isKorean,
                            ),
                          ),
                        ],
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

  void _openPattern(BuildContext context, MarketItem item, String emptyMessage, String title) {
    // 기본정보 시트 먼저 표시
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isKorean = Localizations.localeOf(ctx).languageCode == 'ko';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(12)),
                    child: Icon(item.pdfUrl.isNotEmpty ? Icons.picture_as_pdf_rounded : Icons.photo_library_outlined, color: C.pkD),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: T.h3),
                    if (item.status.isNotEmpty)
                      Text(item.status == 'library' ? (isKorean ? '내 라이브러리' : 'My library') : item.status, style: T.caption.copyWith(color: C.mu)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 14),
                if (item.description.isNotEmpty) ...[
                  Text(isKorean ? '설명' : 'Description', style: T.captionBold.copyWith(color: C.mu)),
                  const SizedBox(height: 4),
                  Text(item.description, style: T.body.copyWith(height: 1.5)),
                  const SizedBox(height: 14),
                ],
                Row(children: [
                  if (item.price == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: C.lmG, borderRadius: BorderRadius.circular(20)),
                      child: Text(isKorean ? '무료' : 'Free', style: T.captionBold.copyWith(color: C.lmD)),
                    ),
                  const Spacer(),
                  Text(isKorean ? '등록일' : 'Added', style: T.caption.copyWith(color: C.mu)),
                  const SizedBox(width: 6),
                  Text(
                    item.createdAt != null
                        ? '${item.createdAt!.year}.${item.createdAt!.month.toString().padLeft(2,'0')}.${item.createdAt!.day.toString().padLeft(2,'0')}'
                        : '-',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(isKorean ? '닫기' : 'Close'),
                    ),
                  ),
                  if (item.pdfUrl.isNotEmpty || item.imageUrl.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (item.pdfUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(emptyMessage), backgroundColor: C.og, duration: const Duration(milliseconds: 1500)),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(url: item.pdfUrl, title: item.title),
                          ));
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(isKorean ? '도안 보기' : 'View pattern'),
                        style: ElevatedButton.styleFrom(backgroundColor: C.pk, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPatternImportDialog(BuildContext context, WidgetRef ref, AppStrings t) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.loginRequiredFirst), backgroundColor: C.og),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.registerPattern, style: T.h3),
              const SizedBox(height: 8),
              Text(
                t.copyrightNotice,
                style: T.caption.copyWith(color: C.mu, height: 1.5),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.file_present_rounded, color: C.lv),
                title: Text(ref.watch(appLanguageProvider).isKorean ? '파일에서 선택' : 'Choose file'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                    withData: false,
                  );
                  if (result == null || result.files.isEmpty || !context.mounted) return;
                  final picked = result.files.single;
                  final title = await _askPatternTitle(context, t, picked.name.split('.').first);
                  if (title == null || !context.mounted) return;
                  await _saveImportedPattern(
                    context,
                    ref,
                    t,
                    title: title,
                    pdfPath: picked.extension?.toLowerCase() == 'pdf' ? picked.path : null,
                    imagePath: picked.extension?.toLowerCase() == 'pdf' ? null : picked.path,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.photo_library_outlined, color: C.lv),
                title: Text(t.chooseFromGallery),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
                  if (photo == null || !context.mounted) return;
                  final title = await _askPatternTitle(context, t, photo.name.split('.').first);
                  if (title == null || !context.mounted) return;
                  await _saveImportedPattern(
                    context,
                    ref,
                    t,
                    title: title,
                    imagePath: photo.path,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.camera_alt_outlined, color: C.lv),
                title: Text(t.takePhoto),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
                  if (photo == null || !context.mounted) return;
                  final title = await _askPatternTitle(context, t, '');
                  if (title == null || !context.mounted) return;
                  await _saveImportedPattern(
                    context,
                    ref,
                    t,
                    title: title.isEmpty ? (ref.read(appLanguageProvider).isKorean ? '내 도안' : 'My Pattern') : title,
                    imagePath: photo.path,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askPatternTitle(BuildContext context, AppStrings t, String defaultTitle) async {
    final ctrl = TextEditingController(text: defaultTitle);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '도안 이름' : 'Pattern name', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isKorean ? '도안 이름을 입력하세요' : 'Enter pattern name',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : v);
            },
            child: Text(isKorean ? '등록' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _saveImportedPattern(
    BuildContext context,
    WidgetRef ref,
    AppStrings t, {
    required String title,
    String? imagePath,
    String? pdfPath,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    await runWithMoriLoadingDialog<void>(
      context,
      message: '저장하는 중입니다.',
      subtitle: t.copyrightNotice,
      task: () async {
        final item = MarketItem(
          id: '',
          sellerUid: user.uid,
          sellerName: user.displayName ?? user.email ?? '',
          title: title,
          description: '',
          price: 0,
          category: 'pattern',
          accentHex: '#B47EEB',
          imageType: 'pattern',
          isSoldOut: false,
          isOfficial: false,
          imageUrl: '',
          pdfUrl: '',
          status: 'library',
          createdAt: DateTime.now(),
        );
        await ref.read(marketRepositoryProvider).createItem(
          item,
          imageFile: imagePath,
          pdfFile: pdfPath,
          extraData: const {'source': 'manual_upload'},
        );
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.patternSavedToLibrary), backgroundColor: C.lv),
    );
  }
}

class _PatternSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PatternSummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 4),
          Text(value, style: T.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _DeletedPatternRow extends StatelessWidget {
  final String title;
  final bool isKorean;
  const _DeletedPatternRow({required this.title, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : (isKorean ? '(제목 없음)' : '(No title)'),
                  style: T.bodyBold.copyWith(color: Colors.grey.shade500, decoration: TextDecoration.lineThrough),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isKorean ? '도안이 삭제되었습니다' : 'Pattern has been removed',
                  style: T.caption.copyWith(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 18),
        ],
      ),
    );
  }
}

class _PatternAssetRow extends StatelessWidget {
  final MarketItem item;
  final bool isKorean;
  final String ownedLabel;
  final String listedLabel;
  final String freeLabel;
  final VoidCallback onTap;

  const _PatternAssetRow({
    required this.item,
    required this.isKorean,
    required this.ownedLabel,
    required this.listedLabel,
    required this.freeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = item.status == 'library' ? listedLabel : (item.sellerUid.isNotEmpty ? listedLabel : ownedLabel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: C.pk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.pdfUrl.isNotEmpty ? Icons.picture_as_pdf_rounded : Icons.photo_library_outlined, color: C.pkD),
        ),
        title: Text(item.title, style: T.bodyBold),
        subtitle: Text(
          label,
          style: T.caption.copyWith(color: C.mu),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.price == 0)
              MoriChip(label: freeLabel, type: ChipType.lime),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: C.mu),
          ],
        ),
      ),
    );
  }
}
