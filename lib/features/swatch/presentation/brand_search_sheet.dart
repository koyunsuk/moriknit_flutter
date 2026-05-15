import 'dart:async';

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

  // #650 정정 — 실제 컬렉션 이름은 snake_case (어드민 코드와 일치)
  String get _collectionName => widget.brandType == BrandType.yarn ? 'yarn_brands' : 'needle_brands';

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

  /// #695 — 캐시 우선 + 짧은 서버 timeout + 빈 폴백 (#685 패턴 적용)
  /// 이전: 단순 `.get()` 호출이 오프라인·네트워크 지연 시 무한 대기 → 사용자에게 "DB 로딩 안 됨"으로 보임.
  Future<QuerySnapshot<Map<String, dynamic>>?> _fetchSnapshot() async {
    final col = FirebaseFirestore.instance.collection(_collectionName).limit(500);

    // 1) Source.cache 우선 (Firestore SDK 영속 캐시 — #685)
    try {
      final cached = await col.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) {
        debugPrint('[BrandSearch] HIT cache $_collectionName (${cached.docs.length}개)');
        // 백그라운드로 서버 갱신 trigger
        unawaited(_refreshFromServer());
        return cached;
      }
    } catch (_) {
      // 캐시 없음 — server 폴백
    }

    // 2) 서버 fetch — 5초 timeout, 실패 시 null (빈 폴백)
    try {
      return await col
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[BrandSearch] TIMEOUT 5s → 빈 폴백 ($_collectionName)');
      return null;
    } catch (e) {
      debugPrint('[BrandSearch] 서버 fetch 실패 ($_collectionName): $e');
      return null;
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .limit(500)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // 백그라운드 실패 무음
    }
  }

  Future<void> _search(String query) async {
    final currentToken = ++_searchToken;
    setState(() => _loading = true);

    // #650 — 모든 문서 조회 후 클라이언트에서 정렬·필터.
    // 이전: orderBy('name')은 name 필드가 없는 문서를 자동 제외해서 결과 0건 발생.
    final lower = query.trim().toLowerCase();
    final snapshot = await _fetchSnapshot();

    if (!mounted || currentToken != _searchToken) return;

    if (snapshot == null) {
      // 캐시·서버 모두 실패 → 빈 결과 (UI에 직접 입력 옵션 노출됨)
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    debugPrint('[BrandSearch] $_collectionName 문서 ${snapshot.docs.length}개 로드됨');

    final all = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final isActive = data['isActive'];
          return isActive == null || isActive == true;
        })
        .map((doc) {
          final data = doc.data();
          final n = (data['name'] as String?)?.trim() ?? '';
          // name 없으면 nameKo, nameEn, brandName 등 다른 필드 폴백
          final fallback = (data['nameKo'] as String?)?.trim()
              ?? (data['nameEn'] as String?)?.trim()
              ?? (data['brandName'] as String?)?.trim()
              ?? '';
          return _BrandItem(
            id: doc.id,
            name: n.isNotEmpty ? n : (fallback.isNotEmpty ? fallback : doc.id),
          );
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // 검색어 있으면 클라이언트 contains 필터 (대소문자 무관)
    final remote = lower.isEmpty
        ? all
        : all.where((b) => b.name.toLowerCase().contains(lower)).toList();

    setState(() {
      _results = remote;
      _loading = false;
    });
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
