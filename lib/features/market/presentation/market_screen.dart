import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/template_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../my/data/mori_service.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../project/domain/project_model.dart';
import '../../project/domain/user_template.dart';
import '../domain/market_item.dart';
import '../domain/market_review.dart';
import 'pdf_viewer_screen.dart';
import 'seller_items_screen.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  String _searchQuery = '';
  String _categoryFilter = 'all';
  String _sortMode = 'recommended';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MarketItem> _applyFilters(List<MarketItem> items) {
    var filtered = items;
    if (_categoryFilter != 'all') {
      filtered = filtered.where((i) => i.category == _categoryFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((i) =>
        i.title.toLowerCase().contains(q) ||
        i.description.toLowerCase().contains(q) ||
        i.sellerName.toLowerCase().contains(q) ||
        i.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }
    switch (_sortMode) {
      case 'popular':
        filtered.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      case 'latest':
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case 'free':
        filtered = filtered.where((i) => i.price == 0).toList();
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      default:
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(data: uiCopy, language: language, key: 'market_header_subtitle', fallback: t.marketHeaderSubtitle);
    final itemsAsync = ref.watch(marketItemsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final gates = ref.watch(featureGatesProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final canCreate = user != null && (gates.isStarterOrAbove || isAdmin);
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  maxWidth: isWide ? 1380 : 920,
                  padding: EdgeInsets.zero,
                  child: MoriBrandHeader(subtitle: subtitle),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 1380 : 920),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      _MarketIntroCard(
                          isKorean: isKorean,
                          isAdmin: isAdmin,
                          canCreate: canCreate,
                          onCreate: canCreate ? () => _showCreateItemSheet(context, ref, user.uid, user.displayName ?? user.email ?? '') : null,
                          // 이슈 #713 — Shell 내부 경로로 이동해 하단 탭바 유지.
                          onDashboard: user != null ? () => context.push(Routes.marketDashboard) : null,
                        ),
                      const SizedBox(height: 16),
                      // ── 검색바 ───────────────────────────────────────
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: isKorean ? '상품명, 판매자, 태그 검색' : 'Search items, sellers, tags',
                          prefixIcon: Icon(Icons.search_rounded, color: C.mu, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(icon: Icon(Icons.clear_rounded, size: 18, color: C.mu), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── 카테고리 필터 ────────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in [('all', isKorean ? '전체' : 'All'), ('pattern', isKorean ? '도안' : 'Pattern'), ('yarn', isKorean ? '실' : 'Yarn'), ('tool', isKorean ? '도구' : 'Tool')])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _FilterChip(label: e.$2, selected: _categoryFilter == e.$1, onTap: () => setState(() => _categoryFilter = e.$1)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── 정렬 탭 ─────────────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in [('recommended', isKorean ? '⭐ 추천' : '⭐ Rec'), ('popular', isKorean ? '🔥 인기' : '🔥 Popular'), ('latest', isKorean ? '🆕 최신' : '🆕 Latest'), ('free', isKorean ? '🎁 무료' : '🎁 Free')])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _FilterChip(label: e.$2, selected: _sortMode == e.$1, onTap: () => setState(() => _sortMode = e.$1), small: true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── 이슈 #629 : 무료 도안 섹션 (price == 0) ───────
                      _FreePatternSection(isKorean: isKorean),
                      const SizedBox(height: 16),
                      itemsAsync.when(
                    data: (allItems) {
                      final items = _applyFilters(allItems);
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 72, height: 72, decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.shopping_bag_rounded, color: C.pkD, size: 36)),
                                const SizedBox(height: 16),
                                Text(_searchQuery.isNotEmpty ? (isKorean ? '검색 결과가 없어요' : 'No results') : (isKorean ? '등록된 상품이 없어요' : 'No items yet'), style: T.bodyBold),
                                const SizedBox(height: 6),
                                Text(isKorean ? '다른 검색어나 필터를 사용해보세요.' : 'Try different filters.', style: T.caption.copyWith(color: C.mu)),
                                if (canCreate && _searchQuery.isEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showCreateItemSheet(context, ref, user.uid, user.displayName ?? user.email ?? ''),
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(isKorean ? '상품 추가하기' : 'Add item'),
                                    style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = isWide ? 4 : (constraints.maxWidth > 500 ? 3 : 2);
                          final cardW = (constraints.maxWidth - (cols - 1) * 10) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: items.map((item) => SizedBox(width: cardW, child: _MarketCard(item: item))).toList(),
                          );
                        },
                      );
                    },
                    loading: () => AsyncLoadingFriendly(
                      isKorean: isKorean,
                      onRetry: () => ref.invalidate(marketItemsProvider),
                      padding: const EdgeInsets.all(24),
                    ),
                    error: (e, _) => AsyncDelayedFriendly(
                      isKorean: isKorean,
                      onRetry: () => ref.invalidate(marketItemsProvider),
                      padding: const EdgeInsets.all(24),
                    ),
                      ),
                          ],
                        ),
                      ),
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

  Future<void> _showCreateItemSheet(BuildContext context, WidgetRef ref, String uid, String sellerName) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final gates = ref.read(featureGatesProvider);
    final canUsePro = gates.isProOrAbove;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = 'pattern';
    bool isFree = true;
    // 파일 소스 (기존)
    String? imageFilePath;
    String? pdfFilePath;
    // 내도안 소스
    PatternChart? selectedChart;
    Uint8List? chartMoriBytes;
    // 내템플릿 소스
    UserTemplate? selectedTemplate;
    Uint8List? templateBytes;
    // 소스 타입: 'file'(기존) | 'myPattern' | 'myTemplate'
    String sourceType = 'file';

    final accentHex = ['#FA5BB4', '#B47EEB', '#A3E635', '#F472B6', '#60A5FA', '#34D399', '#FB923C', '#F9A8D4'][Random().nextInt(8)];
    final tagsCtrl = TextEditingController();
    List<String> tags = [];
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isKorean ? '새 상품 추가' : 'Add new item', style: T.h3),
                  const SizedBox(height: 14),
                  // ── 소스 타입 선택 ──────────────────────────────
                  SectionTitle(title: isKorean ? '콘텐츠 소스' : 'Content Source'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SourceChip(
                        label: isKorean ? '파일' : 'File',
                        icon: Icons.upload_file_rounded,
                        selected: sourceType == 'file',
                        onTap: saving ? null : () => setState(() { sourceType = 'file'; selectedChart = null; selectedTemplate = null; chartMoriBytes = null; templateBytes = null; }),
                      ),
                      const SizedBox(width: 6),
                      _SourceChip(
                        label: isKorean ? '내 도안' : 'My Pattern',
                        icon: Icons.grid_on_rounded,
                        selected: sourceType == 'myPattern',
                        isPro: true,
                        onTap: (saving || !canUsePro) ? null : () => setState(() { sourceType = 'myPattern'; imageFilePath = null; pdfFilePath = null; }),
                      ),
                      const SizedBox(width: 6),
                      _SourceChip(
                        label: isKorean ? '내 템플릿' : 'My Template',
                        icon: Icons.list_alt_rounded,
                        selected: sourceType == 'myTemplate',
                        isPro: true,
                        onTap: (saving || !canUsePro) ? null : () => setState(() { sourceType = 'myTemplate'; imageFilePath = null; pdfFilePath = null; }),
                      ),
                    ],
                  ),
                  if (!canUsePro) ...[
                    const SizedBox(height: 6),
                    Text(
                      isKorean ? '⭐ 내 도안/템플릿 등록은 Pro 요금제 이상에서 사용할 수 있어요' : '⭐ My Pattern/Template listing requires Pro plan',
                      style: T.caption.copyWith(color: C.lv),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '상품 이름' : 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: isKorean ? '설명' : 'Description')),
                  const SizedBox(height: 10),
                  // 무료/유료 선택
                  Row(
                    children: [
                      _PriceTypeChip(
                        label: isKorean ? '무료' : 'Free',
                        selected: isFree,
                        enabled: !saving,
                        onTap: () => setState(() { isFree = true; priceCtrl.clear(); }),
                      ),
                      const SizedBox(width: 8),
                      _PriceTypeChip(
                        label: isKorean ? '유료' : 'Paid',
                        selected: !isFree,
                        enabled: !saving,
                        onTap: () => setState(() => isFree = false),
                      ),
                    ],
                  ),
                  if (!isFree) ...[
                    const SizedBox(height: 10),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isKorean ? '가격 (모리)' : 'Price (Mori)', hintText: '0')),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    style: T.body.copyWith(color: C.tx),
                    decoration: InputDecoration(labelText: isKorean ? '카테고리' : 'Category'),
                    items: [
                      DropdownMenuItem(value: 'pattern', child: Text(isKorean ? '도안' : 'Pattern', style: T.body)),
                      DropdownMenuItem(value: 'yarn', child: Text(isKorean ? '실' : 'Yarn', style: T.body)),
                      DropdownMenuItem(value: 'tool', child: Text(isKorean ? '도구' : 'Tool', style: T.body)),
                    ],
                    onChanged: (value) => setState(() => category = value ?? 'pattern'),
                  ),
                  const SizedBox(height: 10),
                  // ── 태그 입력 ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagsCtrl,
                          decoration: InputDecoration(
                            labelText: isKorean ? '태그 (쉼표로 구분)' : 'Tags (comma separated)',
                            hintText: isKorean ? '예: 코바늘, 초보, 강아지' : 'e.g. crochet, beginner',
                          ),
                          onSubmitted: (v) {
                            final newTags = v.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                            setState(() { tags = {...tags, ...newTags}.take(10).toList(); tagsCtrl.clear(); });
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_rounded, color: C.lv),
                        onPressed: () {
                          final newTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                          setState(() { tags = {...tags, ...newTags}.take(10).toList(); tagsCtrl.clear(); });
                        },
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((t) => GestureDetector(
                        onTap: () => setState(() => tags.remove(t)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.lv.withValues(alpha: 0.3))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('#$t', style: T.caption.copyWith(color: C.lvD)),
                            const SizedBox(width: 4),
                            Icon(Icons.close_rounded, size: 12, color: C.mu),
                          ]),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // ── 소스별 파일 선택 UI ─────────────────────────
                  if (sourceType == 'file') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () async {
                          final result = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (result != null) setState(() => imageFilePath = result.files.single.path);
                        },
                        icon: const Icon(Icons.image_rounded, size: 18),
                        label: Text(imageFilePath != null ? (isKorean ? '✓ 이미지 선택됨' : '✓ Image selected') : (isKorean ? '이미지 선택' : 'Select image')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: imageFilePath != null ? C.lmD : C.tx2,
                          side: BorderSide(color: imageFilePath != null ? C.lmD : C.bd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () async {
                          final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                          if (result != null) setState(() => pdfFilePath = result.files.single.path);
                        },
                        icon: const Icon(Icons.description_rounded, size: 18),
                        label: Text(pdfFilePath != null ? (isKorean ? '✓ PDF 선택됨' : '✓ PDF selected') : (isKorean ? 'PDF 선택' : 'Select PDF')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: pdfFilePath != null ? C.lmD : C.tx2,
                          side: BorderSide(color: pdfFilePath != null ? C.lmD : C.bd),
                        ),
                      ),
                    ),
                  ] else if (sourceType == 'myPattern') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () async {
                          final chart = await Navigator.push<PatternChart>(
                            ctx,
                            MaterialPageRoute(builder: (_) => _PatternPickerScreen(isKorean: isKorean)),
                          );
                          if (chart != null) {
                            final bytes = Uint8List.fromList(utf8.encode(
                              const JsonEncoder().convert({'format': 'mori', 'version': 1, 'chart': chart.toJson()}),
                            ));
                            setState(() { selectedChart = chart; chartMoriBytes = bytes; });
                            if (titleCtrl.text.trim().isEmpty) titleCtrl.text = chart.title;
                          }
                        },
                        icon: const Icon(Icons.grid_on_rounded, size: 18),
                        label: Text(selectedChart != null ? '✓ ${selectedChart!.title}' : (isKorean ? '도안 선택' : 'Select pattern')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selectedChart != null ? C.lmD : C.tx2,
                          side: BorderSide(color: selectedChart != null ? C.lmD : C.bd),
                        ),
                      ),
                    ),
                  ] else if (sourceType == 'myTemplate') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () async {
                          final tmpl = await Navigator.push<UserTemplate>(
                            ctx,
                            MaterialPageRoute(builder: (_) => _TemplatePickerScreen(isKorean: isKorean)),
                          );
                          if (tmpl != null) {
                            final bytes = Uint8List.fromList(utf8.encode(
                              const JsonEncoder().convert({'format': 'mori_template', 'version': 1, 'template': tmpl.toMap()}),
                            ));
                            setState(() { selectedTemplate = tmpl; templateBytes = bytes; });
                            if (titleCtrl.text.trim().isEmpty) titleCtrl.text = tmpl.title;
                          }
                        },
                        icon: const Icon(Icons.list_alt_rounded, size: 18),
                        label: Text(selectedTemplate != null ? '✓ ${selectedTemplate!.title}' : (isKorean ? '템플릿 선택' : 'Select template')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selectedTemplate != null ? C.lmD : C.tx2,
                          side: BorderSide(color: selectedTemplate != null ? C.lmD : C.bd),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final price = isFree ? 0 : (int.tryParse(priceCtrl.text.trim()) ?? 0);
                        final missing = <String>[];
                        if (titleCtrl.text.trim().isEmpty) missing.add(isKorean ? '상품 이름' : 'Title');
                        if (!isFree && priceCtrl.text.trim().isEmpty) missing.add(isKorean ? '가격' : 'Price');
                        if (sourceType == 'myPattern' && selectedChart == null) missing.add(isKorean ? '도안' : 'Pattern');
                        if (sourceType == 'myTemplate' && selectedTemplate == null) missing.add(isKorean ? '템플릿' : 'Template');
                        if (missing.isNotEmpty) {
                          showDialog(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(isKorean ? '필수 항목 누락' : 'Required fields missing', style: T.h3),
                              content: Text(
                                isKorean
                                    ? '다음 항목을 입력해 주세요:\n${missing.map((e) => '• $e').join('\n')}'
                                    : 'Please fill in:\n${missing.map((e) => '• $e').join('\n')}',
                                style: T.body,
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(isKorean ? '확인' : 'OK'))],
                            ),
                          );
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          await runWithMoriLoadingDialog<void>(
                            ctx,
                            message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                            task: () async {
                              final item = MarketItem(
                                id: '',
                                sellerUid: uid,
                                sellerName: sellerName,
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                price: price,
                                category: category,
                                accentHex: accentHex,
                                imageType: category,
                                isSoldOut: false,
                                isOfficial: false,
                                imageUrl: '',
                                pdfUrl: '',
                                createdAt: DateTime.now(),
                                status: (!isFree && price > 0) ? 'pending' : 'approved',
                                tags: tags,
                              );
                              // 소스 타입에 따라 업로드
                              if (sourceType == 'myPattern') {
                                final imageUrl = selectedChart?.imageUrl ?? '';
                                await ref.read(marketRepositoryProvider).createItem(
                                  item,
                                  imageBytes: imageUrl.isEmpty ? null : null, // 썸네일 없으면 생략
                                  pdfBytes: chartMoriBytes,
                                  extraData: {'sourceType': 'myPattern', 'patternChartId': selectedChart?.id ?? ''},
                                );
                              } else if (sourceType == 'myTemplate') {
                                await ref.read(marketRepositoryProvider).createItem(
                                  item,
                                  pdfBytes: templateBytes,
                                  extraData: {'sourceType': 'myTemplate', 'templateId': selectedTemplate?.id ?? ''},
                                );
                              } else {
                                await ref.read(marketRepositoryProvider).createItem(item, imageFile: imageFilePath, pdfFile: pdfFilePath);
                              }
                            },
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) showSaveErrorSnackBar(ctx, message: '${isKorean ? "오류: " : "Error: "}$e');
                          if (ctx.mounted) setState(() => saving = false);
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : Text(isKorean ? '상품 등록' : 'Create item'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

}

class _FavoriteButton extends ConsumerWidget {
  final String itemId;
  const _FavoriteButton({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const {};
    final isFav = favorites.contains(itemId);
    return GestureDetector(
      onTap: () => ref.read(marketRepositoryProvider).toggleFavorite(user.uid, itemId, isFav),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: isFav ? Colors.red.shade400 : Colors.white,
        ),
      ),
    );
  }
}

class _MarketCard extends ConsumerStatefulWidget {
  final MarketItem item;
  const _MarketCard({required this.item});

  @override
  ConsumerState<_MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends ConsumerState<_MarketCard> {
  bool _buyLoading = false;
  bool _projectLoading = false;

  // 아이템 ID 해시 기반으로 현재 테마 색상에서 일관된 색상 반환
  Color _accentColor(MarketItem item) {
    final palette = [C.pk, C.lv, C.lm, C.lvD, C.pkD, C.lmD, C.og];
    return palette[item.id.hashCode.abs() % palette.length];
  }

  IconData _icon(String type) {
    switch (type) {
      case 'yarn':
        return Icons.blur_circular_rounded;
      case 'tool':
        return Icons.handyman_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  Future<void> _onBuy(bool isKorean, dynamic user) async {
    if (user == null) {
      await showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: Routes.market);
      return;
    }
    if (_buyLoading) return;
    setState(() => _buyLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    bool insufficientMori = false;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '구매하는 중입니다.' : 'Processing purchase...',
        task: () async {
          if (widget.item.price > 0) {
            final success = await MoriService.spend(user.uid, amount: widget.item.price, reason: 'market_purchase:${widget.item.id}');
            if (!success) {
              insufficientMori = true;
              return;
            }
          }
          await ref.read(marketRepositoryProvider).purchaseItem(buyerUid: user.uid, item: widget.item);
        },
      );
      if (insufficientMori) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(isKorean ? '모리가 부족해요' : 'Insufficient Mori'),
              content: Text(isKorean ? '모리가 부족합니다. 저장 활동이나 댓글로 모리를 획득해보세요!' : 'You need more Mori. Earn it by saving or commenting!'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      // 이슈 #791 — "함께 뜨기" 라벨 통일 (Ravelry 인지).
      if (mounted) {
        showSavedSnackBar(
          messenger,
          message: widget.item.price == 0
              ? (isKorean ? '내 도안에 추가됐어요.' : 'Added to your library.')
              : (isKorean ? '구매 완료!' : 'Purchase complete!'),
        );
      }
    } catch (_) {
      if (mounted) showSaveErrorSnackBar(messenger, message: isKorean ? '구매에 실패했습니다.' : 'Purchase failed.');
    } finally {
      if (mounted) setState(() => _buyLoading = false);
    }
  }

  Future<void> _onStartProject(bool isKorean, dynamic user) async {
    if (user == null) {
      await showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: Routes.market);
      return;
    }
    if (_projectLoading) return;
    setState(() => _projectLoading = true);
    try {
      final saved = await runWithMoriLoadingDialog<dynamic>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        task: () async {
          final project = ProjectModel.empty(uid: user.uid).copyWith(
            title: widget.item.title,
            description: widget.item.description,
          );
          return await ref.read(projectRepositoryProvider).createProject(project);
        },
      );
      if (mounted) {
        showSavedSnackBar(context, message: isKorean ? '저장되었습니다.' : 'Saved.');
        context.push('${Routes.projectList}/${saved.id}');
      }
    } catch (_) {
      if (mounted) showSaveErrorSnackBar(context, message: isKorean ? '저장에 실패했습니다.' : 'Save failed.');
    } finally {
      if (mounted) setState(() => _projectLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? HSLColor.fromColor(_accentColor(widget.item))
            .withLightness(
              (HSLColor.fromColor(_accentColor(widget.item)).lightness + 0.18).clamp(0.0, 0.95),
            )
            .toColor()
        : _accentColor(widget.item);

    return GlassCard(
      onTap: () {
        if (kIsWeb && user == null) {
          showLoginRequiredDialog(
            context,
            isKorean: isKorean,
            title: isKorean ? '상품 상세는 로그인 후 볼 수 있어요' : 'Item details require login',
            fromRoute: Routes.market,
          );
          return;
        }
        _showItemDetail(context, widget.item, isKorean, user, accent, isAdmin || user?.uid == widget.item.sellerUid);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 118,
              decoration: BoxDecoration(color: accent.withValues(alpha: isDark ? 0.22 : 0.14), borderRadius: BorderRadius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.item.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      errorWidget: (_, _, _) => Center(child: Icon(_icon(widget.item.imageType), color: accent, size: 42)),
                    )
                  else
                    Center(child: Icon(_icon(widget.item.imageType), color: accent, size: 42)),
                  if (widget.item.isOfficial)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: MoriChip(label: isKorean ? '기본 상품' : 'Official', type: ChipType.white),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _FavoriteButton(itemId: widget.item.id),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.item.title, style: T.bodyBold),
          const SizedBox(height: 4),
          Text(widget.item.description, style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellerItemsScreen(sellerUid: widget.item.sellerUid, sellerName: widget.item.sellerName))),
            child: Text(widget.item.sellerName, style: T.caption.copyWith(color: accent, decoration: TextDecoration.underline)),
          ),
          const SizedBox(height: 4),
          Text(widget.item.price == 0 ? (isKorean ? '무료 도안' : 'Free') : (isKorean ? '${widget.item.price}원' : '${widget.item.price} KRW'), style: T.captionBold.copyWith(color: accent)),
          if (widget.item.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: widget.item.tags.take(3).map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('#$t', style: T.caption.copyWith(color: accent, fontSize: 10)))).toList()),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _buyLoading ? null : () => _onBuy(isKorean, user),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              child: _buyLoading
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  // 이슈 #791 — '함께 뜨기' 라벨 통일 (Ravelry 인지).
                  : Text(widget.item.price == 0
                      ? (isKorean ? '나도 이 도안으로 뜨기' : 'Knit along')
                      : (isKorean ? '구입하기' : 'Buy now')),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _projectLoading ? null : () => _onStartProject(isKorean, user),
              icon: _projectLoading
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accent)))
                  : Icon(Icons.fork_right_rounded, size: 16),
              label: Text(isKorean ? '함께 뜨기로 프로젝트 시작' : 'Start knit-along project'),
              style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent.withValues(alpha: 0.4))),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetail(BuildContext context, MarketItem item, bool isKorean, dynamic user, Color accent, bool isAdmin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ItemDetailSheet(item: item, isKorean: isKorean, user: user, accent: accent, isAdmin: isAdmin),
    );
  }
}

class _ItemDetailSheet extends ConsumerStatefulWidget {
  final MarketItem item;
  final bool isKorean;
  final dynamic user;
  final Color accent;
  final bool isAdmin;

  const _ItemDetailSheet({required this.item, required this.isKorean, required this.user, required this.accent, this.isAdmin = false});

  @override
  ConsumerState<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<_ItemDetailSheet> {
  bool _buyLoading = false;
  bool _projectLoading = false;
  bool _adminActionLoading = false;

  IconData _icon(String type) {
    switch (type) {
      case 'yarn':
        return Icons.blur_circular_rounded;
      case 'tool':
        return Icons.handyman_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  Future<void> _onBuy() async {
    if (_buyLoading) return;
    final isKorean = widget.isKorean;
    if (widget.item.price > 0) {
      final success = await MoriService.spend(widget.user.uid, amount: widget.item.price, reason: 'market_purchase:${widget.item.id}');
      if (!success) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (dCtx) => AlertDialog(
              title: Text(isKorean ? '모리가 부족해요' : 'Insufficient Mori'),
              content: Text(isKorean ? '모리가 부족합니다. 저장 활동이나 댓글로 모리를 획득해보세요!' : 'You need more Mori. Earn it by saving or commenting!'),
              actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _buyLoading = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '구매하는 중입니다.' : 'Processing purchase...',
        task: () async {
          await ref.read(marketRepositoryProvider).purchaseItem(buyerUid: widget.user.uid, item: widget.item);
        },
      );
      if (mounted) Navigator.pop(context);
      if (mounted) showSavedSnackBar(context, message: isKorean ? '구매 완료!' : 'Purchase complete!');
    } catch (_) {
      if (mounted) showSaveErrorSnackBar(context, message: isKorean ? '구매에 실패했습니다.' : 'Purchase failed.');
    } finally {
      if (mounted) setState(() => _buyLoading = false);
    }
  }

  Future<void> _onStartProject() async {
    if (_projectLoading) return;
    setState(() => _projectLoading = true);
    try {
      final saved = await runWithMoriLoadingDialog<dynamic>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        task: () async {
          final project = ProjectModel.empty(uid: widget.user.uid).copyWith(
            title: widget.item.title,
            description: widget.item.description,
          );
          return await ref.read(projectRepositoryProvider).createProject(project);
        },
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showSavedSnackBar(context, message: widget.isKorean ? '저장되었습니다.' : 'Saved.');
        context.push('${Routes.projectList}/${saved.id}');
      }
    } catch (_) {
      if (mounted) showSaveErrorSnackBar(context, message: widget.isKorean ? '저장에 실패했습니다.' : 'Save failed.');
    } finally {
      if (mounted) setState(() => _projectLoading = false);
    }
  }

  Future<void> _onAdminDelete() async {
    final isKorean = widget.isKorean;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '상품 삭제' : 'Delete item', style: T.h3),
        content: Text(
          isKorean ? '이 상품을 삭제하시겠습니까?\n판매 기록이 있으면 삭제할 수 없습니다.' : 'Delete this item?\nCannot delete if sales records exist.',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(isKorean ? '삭제' : 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_adminActionLoading) return;
    if (!mounted) return;
    setState(() => _adminActionLoading = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        task: () async {
          await ref.read(marketRepositoryProvider).deleteItem(widget.item.id);
        },
      );
      if (mounted) Navigator.pop(context);
      if (mounted) showSavedSnackBar(context, message: isKorean ? '삭제되었습니다.' : 'Deleted.');
    } catch (e) {
      final isSold = e.toString().contains('sold');
      if (mounted) showSaveErrorSnackBar(context, message: isSold ? (isKorean ? '판매 기록이 있어 삭제할 수 없습니다.' : 'Cannot delete: has sales records.') : (isKorean ? '삭제에 실패했습니다.' : 'Delete failed.'));
    } finally {
      if (mounted) setState(() => _adminActionLoading = false);
    }
  }

  Future<void> _onAdminEdit() async {
    final isKorean = widget.isKorean;
    final item = widget.item;
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description);
    final priceCtrl = TextEditingController(text: item.price == 0 ? '' : item.price.toString());
    String category = item.category;
    bool isFree = item.price == 0;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '상품 수정' : 'Edit item', style: T.h3),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '상품 이름' : 'Title')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: isKorean ? '설명' : 'Description')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PriceTypeChip(
                      label: isKorean ? '무료' : 'Free',
                      selected: isFree,
                      enabled: !saving,
                      onTap: () => setModalState(() { isFree = true; priceCtrl.clear(); }),
                    ),
                    const SizedBox(width: 8),
                    _PriceTypeChip(
                      label: isKorean ? '유료' : 'Paid',
                      selected: !isFree,
                      enabled: !saving,
                      onTap: () => setModalState(() => isFree = false),
                    ),
                  ],
                ),
                if (!isFree) ...[
                  const SizedBox(height: 10),
                  TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isKorean ? '가격 (원)' : 'Price (KRW)', hintText: '0')),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: isKorean ? '카테고리' : 'Category'),
                  items: [
                    DropdownMenuItem(value: 'pattern', child: Text(isKorean ? '도안' : 'Pattern')),
                    DropdownMenuItem(value: 'yarn', child: Text(isKorean ? '실' : 'Yarn')),
                    DropdownMenuItem(value: 'tool', child: Text(isKorean ? '도구' : 'Tool')),
                  ],
                  onChanged: (value) => setModalState(() => category = value ?? 'pattern'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      setModalState(() => saving = true);
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: isKorean ? '수정하는 중입니다.' : 'Updating...',
                          task: () async {
                            final updated = MarketItem(
                              id: item.id,
                              sellerUid: item.sellerUid,
                              sellerName: item.sellerName,
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              price: isFree ? 0 : (int.tryParse(priceCtrl.text.trim()) ?? 0),
                              category: category,
                              accentHex: item.accentHex,
                              imageType: item.imageType,
                              isSoldOut: item.isSoldOut,
                              isOfficial: item.isOfficial,
                              imageUrl: item.imageUrl,
                              pdfUrl: item.pdfUrl,
                              status: item.status,
                              createdAt: item.createdAt,
                              viewCount: item.viewCount,
                            );
                            await ref.read(marketRepositoryProvider).updateItem(updated);
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) Navigator.pop(context);
                        if (mounted) showSavedSnackBar(context, message: isKorean ? '수정되었습니다.' : 'Updated.');
                      } catch (_) {
                        if (ctx.mounted) showSaveErrorSnackBar(ctx, message: isKorean ? '수정에 실패했습니다.' : 'Update failed.');
                        setModalState(() => saving = false);
                      }
                    },
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : Text(isKorean ? '수정 저장' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final item = widget.item;
    final isKorean = widget.isKorean;
    final accent = widget.accent;
    final isAdmin = widget.isAdmin;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(99))),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Center(child: Icon(_icon(item.imageType), color: accent, size: 64)),
                      )
                    : Center(child: Icon(_icon(item.imageType), color: accent, size: 64)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (item.isOfficial) ...[
                  MoriChip(label: isKorean ? '기본 상품' : 'Official', type: ChipType.white),
                  const SizedBox(width: 8),
                ],
                MoriChip(label: item.category, type: ChipType.lavender),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.title, style: T.h2),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SellerItemsScreen(sellerUid: item.sellerUid, sellerName: item.sellerName))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 13, color: accent),
                  const SizedBox(width: 4),
                  Text(item.sellerName, style: T.caption.copyWith(color: accent, decoration: TextDecoration.underline)),
                ],
              ),
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: item.tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('#$t', style: T.caption.copyWith(color: accent, fontSize: 11)))).toList()),
            ],
            if (item.reviewCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(item.averageRating.toStringAsFixed(1), style: T.captionBold),
                  const SizedBox(width: 4),
                  Text('(${item.reviewCount})', style: T.caption.copyWith(color: C.mu)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(item.description, style: T.body.copyWith(color: C.tx2, height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(isKorean ? '가격' : 'Price', style: T.captionBold.copyWith(color: C.mu)),
                const Spacer(),
                Text(
                  item.price == 0 ? (isKorean ? '무료 도안' : 'Free') : (isKorean ? '${item.price}원' : '${item.price} KRW'),
                  style: T.bodyBold.copyWith(color: accent),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.user == null || _buyLoading ? null : _onBuy,
                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _buyLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Text(isKorean ? '구입하기' : 'Buy now'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.user == null || _projectLoading ? null : _onStartProject,
                icon: _projectLoading
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accent)))
                    : const Icon(Icons.fork_right_rounded, size: 16),
                label: Text(isKorean ? '함께 뜨기로 프로젝트 시작' : 'Start knit-along project'),
                style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            // ── PDF 열기 버튼 (구매 완료 시) ────────────────────
            if (item.pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PdfAccessButton(item: item, isKorean: isKorean, accent: accent),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _adminActionLoading ? null : _onAdminEdit,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(isKorean ? '수정' : 'Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.mu,
                        side: BorderSide(color: C.bd),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _adminActionLoading ? null : _onAdminDelete,
                      icon: _adminActionLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.red)))
                          : const Icon(Icons.delete_rounded, size: 16),
                      label: Text(isKorean ? '삭제' : 'Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // ── 리뷰 섹션 ────────────────────────────────────────
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _ReviewSection(item: item, isKorean: isKorean, accent: accent, user: widget.user),
          ],
        ),
      ),
    );
  }
}

// ── PDF 접근 버튼 ─────────────────────────────────────────────
class _PdfAccessButton extends ConsumerWidget {
  final MarketItem item;
  final bool isKorean;
  final Color accent;
  const _PdfAccessButton({required this.item, required this.isKorean, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final purchases = ref.watch(myPurchasesProvider).valueOrNull ?? [];
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final owned = isAdmin || item.price == 0 || purchases.any((p) => p.itemId == item.id);
    if (!owned) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(url: item.pdfUrl, title: item.title))),
        icon: Icon(Icons.picture_as_pdf_rounded, size: 16, color: accent),
        label: Text(isKorean ? 'PDF 열기' : 'Open PDF'),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── 리뷰 섹션 ────────────────────────────────────────────────
class _ReviewSection extends ConsumerStatefulWidget {
  final MarketItem item;
  final bool isKorean;
  final Color accent;
  final dynamic user;
  const _ReviewSection({required this.item, required this.isKorean, required this.accent, required this.user});

  @override
  ConsumerState<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<_ReviewSection> {
  double _myRating = 5.0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _showForm = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || widget.user == null) return;
    setState(() => _submitting = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        task: () async {
          final review = MarketReview(
            id: '',
            itemId: widget.item.id,
            reviewerUid: widget.user.uid as String,
            reviewerName: widget.user.displayName as String? ?? widget.user.email as String? ?? '',
            rating: _myRating,
            comment: _commentCtrl.text.trim(),
            createdAt: DateTime.now(),
          );
          await ref.read(marketRepositoryProvider).submitReview(itemId: widget.item.id, review: review);
        },
      );
      if (!mounted) return;
      setState(() { _showForm = false; _commentCtrl.clear(); _myRating = 5.0; });
      showSavedSnackBar(context, message: widget.isKorean ? '리뷰가 등록되었습니다.' : 'Review submitted.');
    } catch (_) {
      if (!mounted) return;
      showSaveErrorSnackBar(context, message: widget.isKorean ? '리뷰 등록에 실패했습니다.' : 'Review failed.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final accent = widget.accent;
    final reviewsAsync = ref.watch(marketReviewsProvider(widget.item.id));
    final purchases = ref.watch(myPurchasesProvider).valueOrNull ?? [];
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final canReview = widget.user != null && (isAdmin || widget.item.price == 0 || purchases.any((p) => p.itemId == widget.item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(isKorean ? '리뷰' : 'Reviews', style: T.bodyBold),
            if (widget.item.reviewCount > 0) ...[
              const SizedBox(width: 6),
              Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 2),
              Text('${widget.item.averageRating.toStringAsFixed(1)} (${widget.item.reviewCount})', style: T.caption.copyWith(color: C.mu)),
            ],
            const Spacer(),
            if (canReview && !_showForm)
              TextButton.icon(
                onPressed: () async {
                  final sm = ScaffoldMessenger.of(context);
                  final already = await ref.read(marketRepositoryProvider).hasUserReviewed(widget.item.id, widget.user.uid as String);
                  if (!mounted) return;
                  if (already) {
                    showSavedSnackBar(sm, message: isKorean ? '이미 리뷰를 작성했어요.' : 'Already reviewed.');
                    return;
                  }
                  setState(() => _showForm = true);
                },
                icon: Icon(Icons.rate_review_rounded, size: 14, color: accent),
                label: Text(isKorean ? '리뷰 작성' : 'Write review', style: T.caption.copyWith(color: accent)),
              ),
          ],
        ),
        if (_showForm) ...[
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '별점' : 'Rating', style: T.captionBold),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) {
                    final star = (i + 1).toDouble();
                    return GestureDetector(
                      onTap: () => setState(() => _myRating = star),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          _myRating >= star ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: isKorean ? '사용 후기를 작성해주세요.' : 'Write your review...',
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => setState(() { _showForm = false; _commentCtrl.clear(); }), child: Text(isKorean ? '취소' : 'Cancel', style: TextStyle(color: C.mu))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      child: Text(isKorean ? '등록' : 'Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(isKorean ? '아직 리뷰가 없어요. 첫 번째 리뷰를 남겨보세요!' : 'No reviews yet. Be the first!', style: T.caption.copyWith(color: C.mu)),
              );
            }
            return Column(
              children: reviews.take(10).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(children: List.generate(5, (i) => Icon((i + 1) <= r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 13, color: Colors.amber))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r.reviewerName, style: T.caption.copyWith(color: C.mu), overflow: TextOverflow.ellipsis)),
                          if (r.createdAt != null)
                            Text('${r.createdAt!.year}.${r.createdAt!.month.toString().padLeft(2, '0')}.${r.createdAt!.day.toString().padLeft(2, '0')}', style: T.caption.copyWith(color: C.mu, fontSize: 10)),
                        ],
                      ),
                      if (r.comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.comment, style: T.body.copyWith(height: 1.5)),
                      ],
                    ],
                  ),
                ),
              )).toList(),
            );
          },
          loading: () => Padding(padding: const EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2))),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 5 : 7),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 12 : 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : C.lvD,
          ),
        ),
      ),
    );
  }
}

class _MarketIntroCard extends StatelessWidget {
  final bool isKorean;
  final bool isAdmin;
  final bool canCreate;
  final VoidCallback? onCreate;
  final VoidCallback? onDashboard;
  const _MarketIntroCard({required this.isKorean, required this.isAdmin, required this.canCreate, this.onCreate, this.onDashboard});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.storefront_rounded, color: C.lvD, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: T.sm.copyWith(height: 1.6),
                    children: isKorean
                        ? [
                            TextSpan(text: 'Pro', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                            const TextSpan(text: '·'),
                            TextSpan(text: 'Business', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                            const TextSpan(text: ' 회원은 상품을 등록할 수 있습니다.\n일반 회원은 구매만 가능합니다.'),
                          ]
                        : [
                            TextSpan(text: 'Pro', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                            const TextSpan(text: '·'),
                            TextSpan(text: 'Business', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                            const TextSpan(text: ' members can list items.\nOthers can purchase only.'),
                          ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_business_rounded),
                  label: Text(isKorean ? '상품 추가' : 'Add item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCreate ? C.lv : C.bd,
                    foregroundColor: canCreate ? Colors.white : C.mu,
                  ),
                ),
              ),
              if (onDashboard != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDashboard,
                  icon: const Icon(Icons.bar_chart_rounded, size: 16),
                  label: Text(isKorean ? '내 마켓' : 'My Market'),
                  style: OutlinedButton.styleFrom(foregroundColor: C.lv, side: BorderSide(color: C.lv.withValues(alpha: 0.4))),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PriceTypeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : C.lvD,
          ),
        ),
      ),
    );
  }
}

// ── 소스 타입 선택 칩 ─────────────────────────────────────────
class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isPro;
  final VoidCallback? onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.isPro = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? C.lv : (disabled ? C.gx : C.lvL),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: disabled ? 0.1 : 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : (disabled ? C.mu : C.lvD)),
            const SizedBox(width: 5),
            Text(label, style: T.caption.copyWith(
              color: selected ? Colors.white : (disabled ? C.mu : C.lvD),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            )),
            if (isPro) ...[
              const SizedBox(width: 4),
              Text('Pro', style: TextStyle(
                color: selected ? Colors.white.withValues(alpha: 0.8) : C.lv,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 내 도안 선택 화면 ─────────────────────────────────────────
class _PatternPickerScreen extends ConsumerWidget {
  final bool isKorean;

  const _PatternPickerScreen({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(patternListProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '도안 선택' : 'Select Pattern', style: T.h3),
      ),
      body: patternsAsync.when(
        data: (patterns) {
          if (patterns.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_off_rounded, color: C.mu, size: 40),
                  const SizedBox(height: 12),
                  Text(isKorean ? '도안이 없어요' : 'No patterns yet', style: T.body.copyWith(color: C.mu)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: patterns.length,
            itemBuilder: (_, i) {
              final chart = patterns[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => Navigator.pop(context, chart),
                  child: Row(
                    children: [
                      chart.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(imageUrl: chart.imageUrl, width: 48, height: 48, fit: BoxFit.cover, memCacheWidth: 96, memCacheHeight: 96,
                                  errorWidget: (_, _, _) => Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.grid_on_rounded, color: C.lv))),
                            )
                          : Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.grid_on_rounded, color: C.lv)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chart.title.isEmpty ? (isKorean ? '제목 없음' : 'Untitled') : chart.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${chart.rows} × ${chart.cols}', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => AsyncLoadingFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(patternListProvider),
        ),
        error: (e, _) => AsyncDelayedFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(patternListProvider),
        ),
      ),
    );
  }
}

// ── 내 템플릿 선택 화면 ───────────────────────────────────────
class _TemplatePickerScreen extends ConsumerWidget {
  final bool isKorean;

  const _TemplatePickerScreen({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userTemplateListProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '템플릿 선택' : 'Select Template', style: T.h3),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt_rounded, color: C.mu, size: 40),
                  const SizedBox(height: 12),
                  Text(isKorean ? '템플릿이 없어요' : 'No templates yet', style: T.body.copyWith(color: C.mu)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: templates.length,
            itemBuilder: (_, i) {
              final tmpl = templates[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => Navigator.pop(context, tmpl),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.list_alt_rounded, color: C.lv),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tmpl.title.isEmpty ? (isKorean ? '제목 없음' : 'Untitled') : tmpl.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (tmpl.description.isNotEmpty)
                              Text(tmpl.description, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(isKorean ? '${tmpl.stepTitles.length}단계' : '${tmpl.stepTitles.length} steps', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => AsyncLoadingFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(userTemplateListProvider),
        ),
        error: (e, _) => AsyncDelayedFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(userTemplateListProvider),
        ),
      ),
    );
  }
}

// ── 이슈 #629 : 무료 도안 섹션 ─────────────────────────────────────────────
//
// 마켓 상단에 무료 도안(price == 0)만 모은 가로 스크롤 섹션.
// freePatternItemsProvider 사용. 비어 있을 때는 플레이스홀더 표시 (CLAUDE.md 원칙).
class _FreePatternSection extends ConsumerWidget {
  final bool isKorean;
  const _FreePatternSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freeAsync = ref.watch(freePatternItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: C.lv, size: 18),
            const SizedBox(width: 6),
            Text(
              isKorean ? '무료 도안' : 'Free Patterns',
              style: T.bodyBold,
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.lv.withValues(alpha: 0.30)),
              ),
              child: Text(
                isKorean ? '0원' : 'Free',
                style: T.caption.copyWith(
                  color: C.lvD,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 168,
          child: freeAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return _FreePatternPlaceholder(isKorean: isKorean);
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(
                  width: 150,
                  child: _FreePatternMiniCard(item: items[i]),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => _FreePatternPlaceholder(isKorean: isKorean),
          ),
        ),
      ],
    );
  }
}

class _FreePatternPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _FreePatternPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: C.gx,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.lv.withValues(alpha: 0.12)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: C.lv.withValues(alpha: 0.32),
                  size: 28,
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FreePatternMiniCard extends ConsumerWidget {
  final MarketItem item;
  const _FreePatternMiniCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentPalette = [C.pk, C.lv, C.lm, C.lvD, C.pkD, C.lmD, C.og];
    final accent = accentPalette[item.id.hashCode.abs() % accentPalette.length];
    return GlassCard(
      padding: const EdgeInsets.all(8),
      onTap: () {
        final user = ref.read(authStateProvider).valueOrNull;
        final isKorean = ref.read(appLanguageProvider).isKorean;
        if (kIsWeb && user == null) {
          showLoginRequiredDialog(
            context,
            isKorean: isKorean,
            title: isKorean ? '상품 상세는 로그인 후 볼 수 있어요' : 'Item details require login',
            fromRoute: Routes.market,
          );
          return;
        }
        final isAdmin =
            ref.read(isAdminProvider).valueOrNull == true;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: C.bg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => _ItemDetailSheet(
            item: item,
            isKorean: isKorean,
            user: user,
            accent: accent,
            isAdmin: isAdmin || user?.uid == item.sellerUid,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 78,
              width: double.infinity,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 240,
                      errorWidget: (_, _, _) => Center(
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: accent,
                          size: 28,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: accent,
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: T.captionBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.sellerName,
            style: T.caption.copyWith(color: C.mu, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Free',
            style: T.caption
                .copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

