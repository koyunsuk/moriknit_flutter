import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../my/data/mori_service.dart';
import '../../project/domain/project_model.dart';
import '../domain/market_item.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  child: MoriBrandHeader(
                    subtitle: subtitle,
                  ),
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
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _MarketIntroCard(
                                isKorean: isKorean,
                                isAdmin: isAdmin,
                                canCreate: canCreate,
                                onCreate: canCreate ? () => _showCreateItemSheet(context, ref, user.uid, user.displayName ?? user.email ?? '') : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _MarketGuestCard(
                                isKorean: isKorean,
                                isGuest: user == null,
                                onStart: () => showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: Routes.market),
                              ),
                            ),
                          ],
                        )
                      else
                        _MarketIntroCard(
                          isKorean: isKorean,
                          isAdmin: isAdmin,
                          canCreate: canCreate,
                          onCreate: canCreate ? () => _showCreateItemSheet(context, ref, user.uid, user.displayName ?? user.email ?? '') : null,
                        ),
                      const SizedBox(height: 16),
                      SectionTitle(title: isKorean ? '추천 상품' : 'Recommended items'),
                      const SizedBox(height: 10),
                      itemsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 72, height: 72, decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.shopping_bag_rounded, color: C.pkD, size: 36)),
                                const SizedBox(height: 16),
                                Text(isKorean ? '등록된 상품이 없어요' : 'No items yet', style: T.bodyBold),
                                const SizedBox(height: 6),
                                Text(isKorean ? '첫 번째 상품을 등록해보세요.' : 'Be the first to add an item.', style: T.caption.copyWith(color: C.mu)),
                                if (canCreate) ...[
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
                    loading: () => Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: C.lv))),
                    error: (e, _) => Text('${isKorean ? '마켓을 불러오지 못했어요: ' : 'Market load failed: '}$e', style: T.body.copyWith(color: C.og)),
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
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = 'pattern';
    bool isFree = false;
    String? imageFilePath;
    String? pdfFilePath;
    final accentHex = ['#FA5BB4', '#B47EEB', '#A3E635', '#F472B6', '#60A5FA', '#34D399', '#FB923C', '#F9A8D4'][Random().nextInt(8)];

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
                  const SizedBox(height: 12),
                  TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '상품 이름' : 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: isKorean ? '설명' : 'Description')),
                  const SizedBox(height: 10),
                  // 무료 도안 토글
                  GestureDetector(
                    onTap: saving ? null : () => setState(() { isFree = !isFree; if (isFree) priceCtrl.clear(); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isFree ? C.lmD.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isFree ? C.lmD : C.bd),
                      ),
                      child: Row(
                        children: [
                          Icon(isFree ? Icons.check_circle_rounded : Icons.circle_outlined, color: isFree ? C.lmD : C.mu, size: 20),
                          const SizedBox(width: 10),
                          Text(isKorean ? '무료 도안 (가격 없음)' : 'Free pattern (no price)', style: T.body.copyWith(color: isFree ? C.lmD : C.tx2)),
                        ],
                      ),
                    ),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (result != null) setState(() => imageFilePath = result.files.single.path);
                      },
                      icon: Icon(Icons.image_rounded, size: 18),
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
                      icon: Icon(Icons.description_rounded, size: 18),
                      label: Text(pdfFilePath != null ? (isKorean ? '✓ PDF 선택됨' : '✓ PDF selected') : (isKorean ? 'PDF 선택' : 'Select PDF')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pdfFilePath != null ? C.lmD : C.tx2,
                        side: BorderSide(color: pdfFilePath != null ? C.lmD : C.bd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final price = isFree ? 0 : (int.tryParse(priceCtrl.text.trim()) ?? 0);
                        // 필수항목 검증
                        final missing = <String>[];
                        if (titleCtrl.text.trim().isEmpty) missing.add(isKorean ? '상품 이름' : 'Title');
                        if (!isFree && priceCtrl.text.trim().isEmpty) missing.add(isKorean ? '가격' : 'Price');
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
                              );
                              await ref.read(marketRepositoryProvider).createItem(item, imageFile: imageFilePath, pdfFile: pdfFilePath);
                            },
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) showSaveErrorSnackBar(ctx, message: isKorean ? '상품 등록에 실패했습니다.' : 'Failed to create item.');
                          if (ctx.mounted) setState(() => saving = false);
                        }
                      },
                      child: saving
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
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
    final overlay = showSavingOverlay(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.item.price > 0) {
        final success = await MoriService.spend(user.uid, amount: widget.item.price, reason: 'market_purchase:${widget.item.id}');
        if (!success) {
          overlay.close();
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
      }
      await ref.read(marketRepositoryProvider).purchaseItem(buyerUid: user.uid, item: widget.item);
      overlay.close();
      if (mounted) showSavedSnackBar(messenger, message: isKorean ? '구매 완료!' : 'Purchase complete!');
    } catch (_) {
      overlay.close();
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
    final overlay = showSavingOverlay(context);
    try {
      final project = ProjectModel.empty(uid: user.uid).copyWith(
        title: widget.item.title,
        description: widget.item.description,
      );
      final saved = await ref.read(projectRepositoryProvider).createProject(project);
      overlay.close();
      if (mounted) {
        showSavedSnackBar(context, message: isKorean ? '저장되었습니다.' : 'Saved.');
        context.push('${Routes.projectList}/${saved.id}');
      }
    } catch (_) {
      overlay.close();
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
    final accent = _accentColor(widget.item);

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
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.imageUrl.isNotEmpty)
                    Image.network(
                      widget.item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(child: Icon(_icon(widget.item.imageType), color: accent, size: 42)),
                    )
                  else
                    Center(child: Icon(_icon(widget.item.imageType), color: accent, size: 42)),
                  if (widget.item.isOfficial)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: MoriChip(label: isKorean ? '기본 상품' : 'Official', type: ChipType.white),
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
          Text(widget.item.sellerName, style: T.caption.copyWith(color: accent)),
          const SizedBox(height: 4),
          Text(widget.item.price == 0 ? (isKorean ? '무료 도안' : 'Free') : (isKorean ? '${widget.item.price}원' : '${widget.item.price} KRW'), style: T.captionBold.copyWith(color: accent)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _buyLoading ? null : () => _onBuy(isKorean, user),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              child: _buyLoading
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Text(isKorean ? '구입하기' : 'Buy now'),
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
              label: Text(isKorean ? '이걸로 프로젝트 시작' : 'Start project from this'),
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
    final overlay = showSavingOverlay(context);
    try {
      await ref.read(marketRepositoryProvider).purchaseItem(buyerUid: widget.user.uid, item: widget.item);
      overlay.close();
      if (mounted) Navigator.pop(context);
      if (mounted) showSavedSnackBar(context, message: isKorean ? '구매 완료!' : 'Purchase complete!');
    } catch (_) {
      overlay.close();
      if (mounted) showSaveErrorSnackBar(context, message: isKorean ? '구매에 실패했습니다.' : 'Purchase failed.');
    } finally {
      if (mounted) setState(() => _buyLoading = false);
    }
  }

  Future<void> _onStartProject() async {
    if (_projectLoading) return;
    setState(() => _projectLoading = true);
    final overlay = showSavingOverlay(context);
    try {
      final project = ProjectModel.empty(uid: widget.user.uid).copyWith(
        title: widget.item.title,
        description: widget.item.description,
      );
      final saved = await ref.read(projectRepositoryProvider).createProject(project);
      overlay.close();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showSavedSnackBar(context, message: widget.isKorean ? '저장되었습니다.' : 'Saved.');
        context.push('${Routes.projectList}/${saved.id}');
      }
    } catch (_) {
      overlay.close();
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
    final overlay = showSavingOverlay(context, message: isKorean ? '삭제하는 중입니다.' : 'Deleting...');
    try {
      await ref.read(marketRepositoryProvider).deleteItem(widget.item.id);
      overlay.close();
      if (mounted) Navigator.pop(context);
      if (mounted) showSavedSnackBar(context, message: isKorean ? '삭제되었습니다.' : 'Deleted.');
    } catch (e) {
      overlay.close();
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
                GestureDetector(
                  onTap: saving ? null : () => setModalState(() { isFree = !isFree; if (isFree) priceCtrl.clear(); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFree ? C.lmD.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isFree ? C.lmD : C.bd),
                    ),
                    child: Row(
                      children: [
                        Icon(isFree ? Icons.check_circle_rounded : Icons.circle_outlined, color: isFree ? C.lmD : C.mu, size: 20),
                        const SizedBox(width: 10),
                        Text(isKorean ? '무료 도안 (가격 없음)' : 'Free pattern (no price)', style: T.body.copyWith(color: isFree ? C.lmD : C.tx2)),
                      ],
                    ),
                  ),
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
                      final overlay = showSavingOverlay(ctx);
                      try {
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
                        overlay.close();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) Navigator.pop(context);
                        if (mounted) showSavedSnackBar(context, message: isKorean ? '수정되었습니다.' : 'Updated.');
                      } catch (_) {
                        overlay.close();
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
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(child: Icon(_icon(item.imageType), color: accent, size: 64)),
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
            Text(item.sellerName, style: T.caption.copyWith(color: accent)),
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
                label: Text(isKorean ? '이걸로 프로젝트 시작' : 'Start project from this'),
                style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
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
          ],
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
  const _MarketIntroCard({required this.isKorean, required this.isAdmin, required this.canCreate, this.onCreate});

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
          SizedBox(
            width: double.infinity,
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
        ],
      ),
    );
  }
}

class _MarketGuestCard extends StatelessWidget {
  final bool isKorean;
  final bool isGuest;
  final VoidCallback onStart;
  const _MarketGuestCard({required this.isKorean, required this.isGuest, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '웹에서 먼저 둘러보세요' : 'Browse first on web', style: T.bodyBold),
          const SizedBox(height: 10),
          Text(
            isGuest
                ? (isKorean ? '상품 목록은 둘러볼 수 있고, 상세와 구매는 로그인 후 바로 이어집니다.' : 'You can browse the listing now, then log in to open full details and buy.')
                : (isKorean ? '로그인된 상태라서 상세와 구매를 바로 진행할 수 있어요.' : 'You are signed in, so details and purchase are ready.'),
            style: T.caption.copyWith(color: C.mu, height: 1.6),
          ),
          const SizedBox(height: 14),
          if (isGuest)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                child: Text(isKorean ? '무료로 시작하기' : 'Start free'),
              ),
            ),
        ],
      ),
    );
  }
}
