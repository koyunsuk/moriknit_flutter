import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/yarn_catalog_provider.dart';

const List<({String id, String nameKo, String nameEn, String colorCode})> _fallbackColors = [
  (id: 'white', nameKo: '화이트', nameEn: 'White', colorCode: '#FFFFFF'),
  (id: 'ivory', nameKo: '아이보리', nameEn: 'Ivory', colorCode: '#FFFFF0'),
  (id: 'cream', nameKo: '크림', nameEn: 'Cream', colorCode: '#FFFDD0'),
  (id: 'beige', nameKo: '베이지', nameEn: 'Beige', colorCode: '#F5F0DC'),
  (id: 'light_gray', nameKo: '라이트그레이', nameEn: 'Light Gray', colorCode: '#D3D3D3'),
  (id: 'gray', nameKo: '그레이', nameEn: 'Gray', colorCode: '#808080'),
  (id: 'charcoal', nameKo: '차콜', nameEn: 'Charcoal', colorCode: '#36454F'),
  (id: 'black', nameKo: '블랙', nameEn: 'Black', colorCode: '#1A1A1A'),
  (id: 'navy', nameKo: '네이비', nameEn: 'Navy', colorCode: '#1B3A6B'),
  (id: 'blue', nameKo: '블루', nameEn: 'Blue', colorCode: '#4A90D9'),
  (id: 'sky_blue', nameKo: '스카이블루', nameEn: 'Sky Blue', colorCode: '#87CEEB'),
  (id: 'teal', nameKo: '틸', nameEn: 'Teal', colorCode: '#008080'),
  (id: 'mint', nameKo: '민트', nameEn: 'Mint', colorCode: '#98D8C8'),
  (id: 'green', nameKo: '그린', nameEn: 'Green', colorCode: '#4CAF50'),
  (id: 'olive', nameKo: '올리브', nameEn: 'Olive', colorCode: '#808000'),
  (id: 'yellow', nameKo: '옐로우', nameEn: 'Yellow', colorCode: '#FFD700'),
  (id: 'mustard', nameKo: '머스타드', nameEn: 'Mustard', colorCode: '#E1AD01'),
  (id: 'orange', nameKo: '오렌지', nameEn: 'Orange', colorCode: '#FF8C00'),
  (id: 'coral', nameKo: '코랄', nameEn: 'Coral', colorCode: '#FF6B6B'),
  (id: 'red', nameKo: '레드', nameEn: 'Red', colorCode: '#E63946'),
  (id: 'burgundy', nameKo: '버건디', nameEn: 'Burgundy', colorCode: '#800020'),
  (id: 'pink', nameKo: '핑크', nameEn: 'Pink', colorCode: '#FFB6C1'),
  (id: 'hot_pink', nameKo: '핫핑크', nameEn: 'Hot Pink', colorCode: '#FF69B4'),
  (id: 'lavender', nameKo: '라벤더', nameEn: 'Lavender', colorCode: '#C8A2C8'),
  (id: 'purple', nameKo: '퍼플', nameEn: 'Purple', colorCode: '#9B59B6'),
  (id: 'brown', nameKo: '브라운', nameEn: 'Brown', colorCode: '#795548'),
  (id: 'camel', nameKo: '카멜', nameEn: 'Camel', colorCode: '#C19A6B'),
  (id: 'multicolor', nameKo: '멀티컬러', nameEn: 'Multicolor', colorCode: '#FF0000'),
];

class YarnColorSheet extends ConsumerWidget {
  final void Function(String id, String nameKo, String colorCode) onSelected;

  const YarnColorSheet({super.key, required this.onSelected});

  static Future<void> show(
    BuildContext context, {
    required void Function(String id, String nameKo, String colorCode) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => YarnColorSheet(onSelected: onSelected),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFCCCCCC);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final colorsAsync = ref.watch(yarnColorsProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Text(isKorean ? '색상 선택' : 'Select Color', style: T.h3)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isKorean ? '닫기' : 'Close'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: colorsAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
              error: (err, st) => _buildGrid(context, isKorean, null),
              data: (items) => _buildGrid(context, isKorean, items.isEmpty ? null : items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool isKorean, dynamic remoteItems) {
    final List<({String id, String nameKo, String colorCode})> displayItems;

    if (remoteItems == null) {
      displayItems = _fallbackColors
          .map((c) => (id: c.id, nameKo: isKorean ? c.nameKo : c.nameEn, colorCode: c.colorCode))
          .toList();
    } else {
      displayItems = (remoteItems as List).map((item) {
        final c = item as dynamic;
        return (
          id: c.id as String,
          nameKo: (isKorean ? c.nameKo : c.nameEn) as String,
          colorCode: c.colorCode as String,
        );
      }).toList();
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.8,
      ),
      itemCount: displayItems.length,
      itemBuilder: (_, index) {
        final item = displayItems[index];
        final color = _parseColor(item.colorCode);
        final isLight = color.computeLuminance() > 0.85;
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            onSelected(item.id, item.nameKo, item.colorCode);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLight ? C.bd : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.nameKo,
                style: T.caption.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
