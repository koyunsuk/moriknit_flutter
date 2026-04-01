import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/yarn_catalog_provider.dart';

const List<String> _fallbackMaterials = [
  '울', '메리노울', '알파카', '캐시미어', '면', '린넨', '실크', '아크릴', '나일론', '혼방',
];

class YarnMaterialSheet extends ConsumerWidget {
  final void Function(String id, String nameKo) onSelected;

  const YarnMaterialSheet({super.key, required this.onSelected});

  static Future<void> show(
    BuildContext context, {
    required void Function(String id, String nameKo) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => YarnMaterialSheet(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final materialsAsync = ref.watch(yarnMaterialsProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
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
                Expanded(child: Text(isKorean ? '소재 선택' : 'Select Material', style: T.h3)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isKorean ? '닫기' : 'Close'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: materialsAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
              error: (err, st) => _buildList(context, isKorean, null),
              data: (items) => _buildList(context, isKorean, items.isEmpty ? null : items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isKorean, dynamic items) {
    final List<({String id, String name})> displayItems;

    if (items == null) {
      displayItems = _fallbackMaterials
          .map((m) => (id: m, name: m))
          .toList();
    } else {
      displayItems = (items as List).map((item) {
        final m = item as dynamic;
        return (id: m.id as String, name: isKorean ? m.nameKo as String : m.nameEn as String);
      }).toList();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: displayItems.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = displayItems[index];
        return Material(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).pop();
              onSelected(item.id, item.name);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(item.name, style: T.bodyBold)),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
