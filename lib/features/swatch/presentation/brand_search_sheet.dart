import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

enum BrandType { yarn, needle }

class BrandSearchSheet extends ConsumerStatefulWidget {
  final BrandType brandType;
  final void Function(String id, String name) onSelected;

  const BrandSearchSheet({
    super.key,
    required this.brandType,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required BrandType brandType,
    required void Function(String id, String name) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => BrandSearchSheet(
        brandType: brandType,
        onSelected: onSelected,
      ),
    );
  }

  @override
  ConsumerState<BrandSearchSheet> createState() => _BrandSearchSheetState();
}

class _BrandSearchSheetState extends ConsumerState<BrandSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<_BrandItem> _results = const [];
  bool _loading = false;
  int _searchToken = 0;

  String get _collectionName => widget.brandType == BrandType.yarn ? 'yarnBrands' : 'needleBrands';

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final currentToken = ++_searchToken;
    setState(() => _loading = true);

    try {
      final lower = query.trim().toLowerCase();
      Query<Map<String, dynamic>> request = FirebaseFirestore.instance.collection(_collectionName);

      if (lower.isEmpty) {
        request = request.orderBy('nameLower').limit(50);
      } else {
        request = request.orderBy('nameLower').startAt([lower]).endAt(['$lower\uf8ff']).limit(50);
      }

      final snapshot = await request.get();
      if (!mounted || currentToken != _searchToken) return;

      final remote = snapshot.docs
          .where((doc) {
            // isActive 필드가 없거나 true인 항목만 표시
            final data = doc.data();
            final isActive = data['isActive'];
            return isActive == null || isActive == true;
          })
          .map((doc) => _BrandItem(
                id: doc.id,
                name: (doc.data()['name'] as String?)?.trim().isNotEmpty == true ? (doc.data()['name'] as String).trim() : doc.id,
              ))
          .toList();

      setState(() {
        _results = remote;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[BrandSearch] 검색 오류 ($_collectionName): $e');
      if (!mounted || currentToken != _searchToken) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _selectBrand(_BrandItem item) {
    Navigator.of(context).pop();
    widget.onSelected(item.id, item.name);
  }

  void _selectCustom() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop();
    widget.onSelected('custom_${name.toLowerCase().replaceAll(' ', '_')}', name);
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final query = _controller.text.trim();
    final title = widget.brandType == BrandType.yarn
        ? (isKorean ? '실 브랜드 검색' : 'Search yarn brand')
        : (isKorean ? '바늘 브랜드 검색' : 'Search needle brand');
    final hint = isKorean ? '브랜드 이름으로 검색' : 'Search by brand name';
    final emptyMessage = isKorean ? '검색 결과가 없어요.' : 'No brands found.';
    final customLabel = isKorean ? '직접 입력' : 'Use custom name';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
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
                  Expanded(child: Text(title, style: T.h3)),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(isKorean ? '닫기' : 'Close')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(Icons.search_rounded, color: C.mu),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                          icon: Icon(Icons.close_rounded, color: C.mu),
                        ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: C.lv))
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emptyMessage, style: T.body.copyWith(color: C.mu)),
                                const SizedBox(height: 10),
                                if (query.isNotEmpty)
                                  ElevatedButton(
                                    onPressed: _selectCustom,
                                    child: Text('"$query" ${isKorean ? '직접 입력' : 'use as custom'}'),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final brand = _results[index];
                            return Material(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _selectBrand(brand),
                                  child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(brand.name, style: T.bodyBold)),
                                      Icon(Icons.chevron_right_rounded, color: C.mu),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: query.isEmpty ? null : _selectCustom,
                  child: Text(query.isEmpty ? customLabel : '"$query" $customLabel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandItem {
  final String id;
  final String name;

  const _BrandItem({required this.id, required this.name});
}
