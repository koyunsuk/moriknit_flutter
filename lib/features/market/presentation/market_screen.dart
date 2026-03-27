import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../domain/market_item.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final itemsAsync = ref.watch(marketItemsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final gates = ref.watch(featureGatesProvider);
    final isDeveloper = _isDeveloper(user?.email);
    final canCreate = user != null && (gates.isStarterOrAbove || isDeveloper);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoriBrandHeader(
                    logoSize: 86,
                    titleSize: 26,
                    subtitle: isKorean ? '도안, 실, 뜨개 도구를 기록 흐름과 함께 연결하는 모리니트 마켓이에요.' : 'A market that connects patterns, yarn, and tools to your MoriKnit records.',
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: C.lvD),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDeveloper
                                    ? (isKorean ? '개발자 계정으로 상품 등록이 열려 있어요. 기본 상품과 함께 직접 판매 흐름을 테스트할 수 있어요.' : 'Developer access is enabled for seller testing.')
                                    : (isKorean ? '기본 MoriKnit 상품은 바로 구입할 수 있고, 유료 구독자는 직접 상품을 등록할 수 있어요.' : 'Official items are ready to buy, and paid members can add listings.'),
                                style: T.body,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const MoriChip(label: 'MoriKnit Picks', type: ChipType.pink),
                            if (isDeveloper) MoriChip(label: isKorean ? '개발자 판매 가능' : 'Developer seller', type: ChipType.lime),
                            MoriChip(label: canCreate ? (isKorean ? '상품 추가 가능' : 'Can create listing') : (isKorean ? '기본 상품 구매 가능' : 'Official items ready'), type: ChipType.white),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canCreate ? () => _showCreateItemSheet(context, ref, user.uid, user.displayName ?? user.email ?? '') : null,
                            icon: const Icon(Icons.add_business_rounded),
                            label: Text(isKorean ? '상품 추가' : 'Add item'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(title: isKorean ? '추천 상품' : 'Recommended items'),
                  const SizedBox(height: 10),
                  itemsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return GlassCard(
                          child: Column(
                            children: [
                              Container(width: 84, height: 84, decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.shopping_bag_rounded, color: C.pkD, size: 38)),
                              const SizedBox(height: 14),
                              Text(isKorean ? '등록된 상품이 아직 없어요' : 'No items listed yet', style: T.bodyBold),
                              const SizedBox(height: 6),
                              Text(isKorean ? '기본 상품을 먼저 준비해두고, 이후 셀러 상품이 함께 쌓이도록 구성했어요.' : 'Official items appear first, then seller listings join in.', style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: items.map((item) => SizedBox(width: (MediaQuery.of(context).size.width - 42) / 2, child: _MarketCard(item: item))).toList(),
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: C.lv))),
                    error: (e, _) => Text('${isKorean ? '마켓을 불러오지 못했어요: ' : 'Market load failed: '}$e', style: T.body.copyWith(color: C.og)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDeveloper(String? email) {
    final value = (email ?? '').toLowerCase();
    return value == 'koyunsuk@gmail.com' || value.endsWith('@moriknit.com');
  }

  Future<void> _showCreateItemSheet(BuildContext context, WidgetRef ref, String uid, String sellerName) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = 'pattern';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isKorean ? '새 상품 추가' : 'Add new item', style: T.h3),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '상품 이름' : 'Title')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: isKorean ? '설명' : 'Description')),
                const SizedBox(height: 10),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isKorean ? '가격' : 'Price')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: isKorean ? '카테고리' : 'Category'),
                  items: [
                    DropdownMenuItem(value: 'pattern', child: Text(isKorean ? '도안' : 'Pattern')),
                    DropdownMenuItem(value: 'yarn', child: Text(isKorean ? '실' : 'Yarn')),
                    DropdownMenuItem(value: 'tool', child: Text(isKorean ? '도구' : 'Tool')),
                  ],
                  onChanged: (value) => setState(() => category = value ?? 'pattern'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      if (titleCtrl.text.trim().isEmpty || price <= 0) return;
                      final item = MarketItem(
                        id: '',
                        sellerUid: uid,
                        sellerName: sellerName,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        price: price,
                        category: category,
                        accentHex: _accentHex(category),
                        imageType: category,
                        isSoldOut: false,
                        isOfficial: false,
                        createdAt: DateTime.now(),
                      );
                      await ref.read(marketRepositoryProvider).createItem(item);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(isKorean ? '상품 등록' : 'Create item'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _accentHex(String category) {
    switch (category) {
      case 'yarn':
        return '#A3E635';
      case 'tool':
        return '#C084FC';
      default:
        return '#F472B6';
    }
  }
}

class _MarketCard extends ConsumerWidget {
  final MarketItem item;
  const _MarketCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final accent = _parseColor(item.accentHex);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 118,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                Center(child: Icon(_icon(item.imageType), color: accent, size: 42)),
                if (item.isOfficial)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: MoriChip(label: isKorean ? '기본 상품' : 'Official', type: ChipType.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(item.title, style: T.bodyBold),
          const SizedBox(height: 4),
          Text(item.description, style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(item.sellerName, style: T.caption.copyWith(color: accent)),
          const SizedBox(height: 4),
          Text(isKorean ? '${item.price}원' : '${item.price} KRW', style: T.captionBold.copyWith(color: accent)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: user == null ? null : () async {
                await ref.read(marketRepositoryProvider).purchaseItem(buyerUid: user.uid, item: item);
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              child: Text(isKorean ? '구입하기' : 'Buy now'),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
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
}
