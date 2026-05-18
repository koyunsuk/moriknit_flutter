import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ravelry_repository.dart';
import '../domain/ravelry_models.dart';

/// 이슈 #644 Phase 7 — Ravelry yarn DB 검색 시트.
/// 사용자가 검색어를 입력 → Ravelry `/yarns/search.json` 호출 → 결과 리스트 표시 →
/// 항목 선택 시 [RavelryYarnSearchItem]을 반환.
class RavelryYarnSearchSheet extends ConsumerStatefulWidget {
  const RavelryYarnSearchSheet({super.key});

  /// `Navigator.push`로 띄우고 선택된 yarn을 반환.
  static Future<RavelryYarnSearchItem?> show(BuildContext context) {
    return showModalBottomSheet<RavelryYarnSearchItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.92,
        child: RavelryYarnSearchSheet(),
      ),
    );
  }

  @override
  ConsumerState<RavelryYarnSearchSheet> createState() => _RavelryYarnSearchSheetState();
}

class _RavelryYarnSearchSheetState extends ConsumerState<RavelryYarnSearchSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<RavelryYarnSearchItem> _results = const [];
  String? _lastQuery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final repo = ref.read(ravelryRepositoryProvider);
    if (repo == null) {
      setState(() {
        _error = ref.read(appLanguageProvider).isKorean
            ? 'Ravelry 연결이 필요합니다.'
            : 'Ravelry connection required.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final items = await repo.searchYarns(query);
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // 핸들바
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: C.bd2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isKorean ? 'Ravelry yarn 검색' : 'Search Ravelry yarn DB',
                      style: T.h3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: C.tx),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: isKorean
                      ? '브랜드/실 이름으로 검색 (예: Drops Merino)'
                      : 'Search by brand or yarn name',
                  prefixIcon: Icon(Icons.search, color: C.mu),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear, color: C.mu),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = const [];
                              _lastQuery = null;
                            });
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(isKorean ? '검색' : 'Search'),
                  onPressed: _loading ? null : _runSearch,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(isKorean)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isKorean) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: C.lv));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(_error!, style: T.body.copyWith(color: C.og)),
        ),
      );
    }
    if (_lastQuery == null) {
      return _Hint(
        icon: Icons.search,
        text: isKorean
            ? '검색어를 입력하면 Ravelry 글로벌 yarn DB를\n조회합니다 (10만+ 항목).'
            : 'Search Ravelry global yarn DB\n(100k+ entries).',
      );
    }
    if (_results.isEmpty) {
      return _Hint(
        icon: Icons.info_outline,
        text: isKorean
            ? 'Ravelry에 없는 브랜드인가요?\n시트를 닫고 직접 입력하세요.'
            : 'Not found on Ravelry?\nClose and enter manually.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _results[index];
        return _YarnTile(
          item: item,
          isKorean: isKorean,
          onTap: () => Navigator.pop(context, item),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: C.mu, size: 36),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: T.body.copyWith(color: C.mu),
            ),
          ],
        ),
      ),
    );
  }
}

class _YarnTile extends StatelessWidget {
  final RavelryYarnSearchItem item;
  final bool isKorean;
  final VoidCallback onTap;
  const _YarnTile({required this.item, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: item.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: C.lvL,
                          child: Icon(Icons.texture, color: C.lv),
                        ),
                      )
                    : Container(
                        color: C.lvL,
                        child: Icon(Icons.texture, color: C.lv),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.yarnCompanyName != null)
                    Text(
                      item.yarnCompanyName!,
                      style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
                    ),
                  Text(
                    item.name,
                    style: T.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.yarnWeight != null) _Tag(text: item.yarnWeight!),
                      if (item.gaugeStitches != null)
                        _Tag(text: '${item.gaugeStitches!.toStringAsFixed(0)} sts/10cm'),
                      if (item.discontinued)
                        _Tag(
                          text: isKorean ? '단종' : 'Discontinued',
                          color: C.og,
                        ),
                    ],
                  ),
                  if (item.fiberContent != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.fiberContent!,
                      style: T.caption.copyWith(color: C.mu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.mu),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const _Tag({required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? C.lv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: T.caption.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}
