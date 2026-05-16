import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/accessory_provider.dart';
import '../domain/accessory_model.dart';
import 'accessory_detail_screen.dart';
import 'accessory_input_screen.dart';

class AccessoryListScreen extends ConsumerWidget {
  const AccessoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(accessoryListProvider);
    final items = listAsync.valueOrNull ?? const <AccessoryModel>[];
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '나의 악세사리' : 'My Accessories',
                subtitle: isKorean ? '니팅 도구를 관리해요' : 'Manage your knitting tools',
              ),
            ),
            // 요약카드 틀고정
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SummaryCard_Detail(
                headers: [isKorean ? '전체' : 'Total'],
                rows: [
                  LibrarySummaryRowData(
                    badge: isKorean ? '악세사리' : 'Accessories',
                    badgeColor: C.pkD,
                    values: ['${items.length}'],
                    valueColors: [C.tx],
                  ),
                ],
                addLabel: isKorean ? '추가' : 'Add',
                onAdd: () => _showAccessoryStartSheet(context, ref),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  GlassCard(
                    child: listAsync.isLoading
                        ? AsyncLoadingFriendly(
                            isKorean: isKorean,
                            onRetry: () => ref.invalidate(accessoryListProvider),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          )
                        : listAsync.hasError
                            ? AsyncDelayedFriendly(
                                isKorean: isKorean,
                                onRetry: () => ref.invalidate(accessoryListProvider),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                compact: true,
                              )
                        : items.isEmpty
                            ? MoriEmptyState(
                                icon: Icons.build_rounded,
                                iconColor: C.pkD,
                                title: isKorean ? '아직 악세사리가 없어요' : 'No accessories yet',
                                subtitle: isKorean ? '니팅 도구를 추가해 보세요' : 'Add your knitting tools',
                                buttonLabel: isKorean ? '추가하기' : 'Add',
                                onAction: () => _showAccessoryStartSheet(context, ref),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isKorean ? '내 악세사리' : 'My Accessories', style: T.bodyBold),
                                  const SizedBox(height: 8),
                                  ...items.map((item) => _AccessoryCard(
                                    item: item,
                                    isKorean: isKorean,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AccessoryDetailScreen(itemId: item.id),
                                      ),
                                    ),
                                  )),
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

  void _navigateToInput(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccessoryInputScreen()),
    );
  }

  // 이슈 #693 — 신규/복사 시작 시트 (나의 바늘 패턴 통일)
  void _showAccessoryStartSheet(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        maxChildSize: 0.6,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [Text(isKorean ? '악세사리 추가' : 'Add accessory', style: T.h3)]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToInput(context);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '새 악세사리 추가' : 'Add new accessory', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '새 악세사리 정보를 직접 입력해요' : 'Enter accessory info manually', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopyAccessorySheet(context, ref);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.pkD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.pkD)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 악세사리 복사로 시작' : 'Copy existing accessory', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 악세사리를 복사해서 시작해요' : 'Duplicate an existing accessory', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
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

  void _showCopyAccessorySheet(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final items = ref.read(accessoryListProvider).valueOrNull ?? <AccessoryModel>[];
    if (items.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 악세사리가 없어요.' : 'No accessories to copy.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 악세사리 선택' : 'Select accessory to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () {
                        // 이슈 #698 — 즉시 duplicate 호출 금지. 입력화면 진입 + prefill.
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AccessoryInputScreen(copyFrom: item)),
                        );
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.pkD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.build_rounded, color: C.pkD, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.localizedTypeLabel(isKorean), style: T.bodyBold),
                            if (item.brandName.isNotEmpty) Text(item.brandName, style: T.caption.copyWith(color: C.mu)),
                          ])),
                          Icon(Icons.copy_rounded, color: C.mu, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessoryCard extends StatelessWidget {
  final AccessoryModel item;
  final bool isKorean;
  final VoidCallback onTap;

  const _AccessoryCard({required this.item, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: C.glassCard,
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: C.pkL,
                borderRadius: BorderRadius.circular(14),
                image: item.photoUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(item.photoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: item.photoUrl.isEmpty
                  ? Icon(Icons.build_rounded, color: C.pkD, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.localizedTypeLabel(isKorean), style: T.bodyBold),
                      if (item.brandName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(20)),
                          child: Text(item.brandName, style: TextStyle(fontSize: 11, color: C.pkD)),
                        ),
                      ],
                    ],
                  ),
                  if (item.name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.name, style: T.caption.copyWith(color: C.mu)),
                  ],
                  if (item.quantity > 1) ...[
                    const SizedBox(height: 2),
                    Text(isKorean ? '${item.quantity}개' : '×${item.quantity}', style: T.caption.copyWith(color: C.mu)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}
