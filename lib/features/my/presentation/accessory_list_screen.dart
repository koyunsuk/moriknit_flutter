import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  WorkspaceSummaryBar(
                    stats: [
                      WorkStat('${items.length}', isKorean ? '전체' : 'Total', color: C.pkD),
                    ],
                    addLabel: isKorean ? '추가' : 'Add',
                    onAdd: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccessoryInputScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: listAsync.isLoading
                        ? Center(child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(color: C.lv),
                          ))
                        : items.isEmpty
                            ? MoriEmptyState(
                                icon: Icons.build_rounded,
                                iconColor: C.pkD,
                                title: isKorean ? '아직 악세사리가 없어요' : 'No accessories yet',
                                subtitle: isKorean ? '니팅 도구를 추가해 보세요' : 'Add your knitting tools',
                                buttonLabel: isKorean ? '추가하기' : 'Add',
                                onAction: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AccessoryInputScreen()),
                                ),
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
