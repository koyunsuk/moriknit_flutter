import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/encyclopedia_provider.dart';
import '../domain/encyclopedia_entry.dart';
import '../domain/personal_encyclopedia_entry.dart';

const _encyclopediaCategories = ['all', 'term', 'symbol'];

class EncyclopediaScreen extends ConsumerStatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  ConsumerState<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends ConsumerState<EncyclopediaScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              MoriPageHeaderShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoriWideHeader(
                      title: t.myEncyclopedia,
                      subtitle: t.myEncyclopediaDescription,
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      labelStyle: T.captionBold,
                      unselectedLabelStyle: T.caption,
                      labelColor: C.pkD,
                      unselectedLabelColor: C.mu,
                      indicatorColor: C.pkD,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(text: isKorean ? '대바늘' : 'Knitting'),
                        Tab(text: isKorean ? '코바늘' : 'Crochet'),
                        Tab(text: t.encyclopediaTabPersonal),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                  decoration: InputDecoration(
                    hintText: isKorean ? '검색...' : 'Search...',
                    hintStyle: T.body.copyWith(color: C.mu),
                    prefixIcon: Icon(Icons.search_rounded, color: C.mu, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.pkD, width: 1.5),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.clear_rounded, color: C.mu, size: 18),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _CraftTab(
                      isKorean: isKorean,
                      uid: uid,
                      searchQuery: _searchQuery,
                      craftType: 'knitting',
                    ),
                    _CraftTab(
                      isKorean: isKorean,
                      uid: uid,
                      searchQuery: _searchQuery,
                      craftType: 'crochet',
                    ),
                    _PersonalTab(isKorean: isKorean, uid: uid, searchQuery: _searchQuery),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Craft Tab (대바늘 / 코바늘)
// ---------------------------------------------------------------------------
class _CraftTab extends ConsumerWidget {
  final bool isKorean;
  final String? uid;
  final String searchQuery;
  final String craftType;

  const _CraftTab({
    required this.isKorean,
    required this.uid,
    required this.searchQuery,
    required this.craftType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final entriesAsync = craftType == 'crochet'
        ? ref.watch(crochetEncyclopediaProvider)
        : ref.watch(knittingEncyclopediaProvider);
    final selectedCategory = ref.watch(selectedEncyclopediaCategoryProvider);
    final bookmarkedIds = uid != null ? ref.watch(bookmarkedIdsProvider(uid!)) : <String>{};

    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemCount: _encyclopediaCategories.length,
            itemBuilder: (_, index) {
              final key = _encyclopediaCategories[index];
              final selected = key == selectedCategory;
              return GestureDetector(
                onTap: () => ref.read(selectedEncyclopediaCategoryProvider.notifier).state = key,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? C.pkD : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: selected ? C.pkD : C.bd),
                  ),
                  child: Text(
                    _labelForCategory(key, isKorean),
                    style: T.sm.copyWith(
                      color: selected ? Colors.white : C.tx2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entriesAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
            error: (error, _) => Center(child: Text('$error', style: T.body)),
            data: (entries) {
              var filtered = selectedCategory == 'all'
                  ? entries
                  : entries.where((e) => _matchesCategory(e.category, selectedCategory)).toList();

              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                filtered = filtered
                    .where((e) =>
                        e.term.toLowerCase().contains(q) ||
                        e.termEn.toLowerCase().contains(q) ||
                        e.description.toLowerCase().contains(q) ||
                        e.descriptionEn.toLowerCase().contains(q))
                    .toList();
              }

              if (filtered.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    GlassCard(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: C.pkL,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: C.pkD, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isNotEmpty
                                ? (isKorean ? '검색 결과가 없어요.' : 'No results found.')
                                : t.encyclopediaNoOfficialEntries,
                            style: T.bodyBold,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemCount: filtered.length,
                itemBuilder: (_, index) => _OfficialEntryCard(
                  entry: filtered[index],
                  isKorean: isKorean,
                  isBookmarked: bookmarkedIds.contains(filtered[index].id),
                  uid: uid,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _matchesCategory(String raw, String selected) {
    switch (selected) {
      case 'term':
        return {'term', 'terms', '용어', 'abbreviation'}.contains(raw);
case 'symbol':
        return {'symbol', 'symbols', '기호'}.contains(raw);
      default:
        return true;
    }
  }

  String _labelForCategory(String key, bool isKorean) {
    switch (key) {
      case 'all':
        return isKorean ? '전체' : 'All';
      case 'term':
        return isKorean ? '용어' : 'Terms';
case 'symbol':
        return isKorean ? '기호' : 'Symbols';
      default:
        return key;
    }
  }
}

// ---------------------------------------------------------------------------
// Personal Tab
// ---------------------------------------------------------------------------
class _PersonalTab extends ConsumerWidget {
  final bool isKorean;
  final String? uid;
  final String searchQuery;

  const _PersonalTab({required this.isKorean, required this.uid, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);

    if (uid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: C.mu),
              const SizedBox(height: 16),
              Text(t.loginRequiredFirst, style: T.bodyBold, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final entriesAsync = ref.watch(personalEncyclopediaProvider(uid!));

    return Stack(
      children: [
        entriesAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
          error: (error, _) => Center(child: Text('$error', style: T.body)),
          data: (entries) {
            var filtered = entries.toList();

            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              filtered = filtered
                  .where((e) =>
                      e.term.toLowerCase().contains(q) ||
                      e.definition.toLowerCase().contains(q) ||
                      e.example.toLowerCase().contains(q))
                  .toList();
            }

            if (filtered.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  GlassCard(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: C.pkL,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.bookmark_border_rounded, color: C.pkD, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? (isKorean ? '검색 결과가 없어요.' : 'No results found.')
                              : t.encyclopediaNoPersonalEntries,
                          style: T.body.copyWith(color: C.tx2, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemCount: filtered.length,
              itemBuilder: (_, index) => _PersonalEntryCard(
                entry: filtered[index],
                uid: uid!,
              ),
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 20,
          child: FloatingActionButton.extended(
            backgroundColor: C.pkD,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text(t.encyclopediaAddTerm, style: T.captionBold.copyWith(color: Colors.white)),
            onPressed: () => _showAddDialog(context, ref, uid!),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref, String uid) async {
    final t = ref.read(appStringsProvider);
    final termCtrl = TextEditingController();
    final definitionCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.encyclopediaAddTerm, style: T.h3),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: termCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: t.encyclopediaTermLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: definitionCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: t.encyclopediaDefinitionLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: exampleCtrl,
                decoration: InputDecoration(labelText: t.encyclopediaExampleLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel, style: T.body.copyWith(color: C.mu)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.pkD, foregroundColor: Colors.white),
            onPressed: () async {
              final term = termCtrl.text.trim();
              final definition = definitionCtrl.text.trim();
              if (term.isEmpty || definition.isEmpty) return;

              final repo = ref.read(personalEncyclopediaRepositoryProvider);
              await repo.addEntry(
                uid,
                PersonalEncyclopediaEntry(
                  id: '',
                  term: term,
                  definition: definition,
                  example: exampleCtrl.text.trim(),
                  sourceId: '',
                  isBookmark: false,
                  createdAt: DateTime.now(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Official Entry Card — 컴팩트 2단 구조
// ---------------------------------------------------------------------------
class _OfficialEntryCard extends ConsumerStatefulWidget {
  final EncyclopediaEntry entry;
  final bool isKorean;
  final bool isBookmarked;
  final String? uid;

  const _OfficialEntryCard({
    required this.entry,
    required this.isKorean,
    required this.isBookmarked,
    required this.uid,
  });

  @override
  ConsumerState<_OfficialEntryCard> createState() => _OfficialEntryCardState();
}

class _OfficialEntryCardState extends ConsumerState<_OfficialEntryCard> {
  bool _expanded = false;

  EncyclopediaEntry get e => widget.entry;
  bool get isKorean => widget.isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final hasSvg = e.referenceUrl.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 좌: 썸네일 ──
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 0),
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.bd2),
              ),
              child: hasSvg
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.network(
                        e.referenceUrl,
                        placeholderBuilder: (_) => Icon(Icons.texture_rounded, size: 18, color: C.mu),
                      ),
                    )
                  : Icon(Icons.menu_book_rounded, size: 20, color: C.mu),
            ),
            // ── 세로 구분선 ──
            Container(
              width: 1,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: C.bd,
            ),
            // ── 우: 2단 내용 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1단: 약어 + 영문 설명
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (e.abbreviation.isNotEmpty) ...[
                        Text(
                          e.abbreviation,
                          style: T.captionBold.copyWith(color: C.lvD),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          e.termEn.isNotEmpty ? e.termEn : e.term,
                          style: T.caption.copyWith(color: C.mu),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 별표(즐겨찾기)
                      GestureDetector(
                        onTap: () => _handleBookmark(context, ref, t),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            widget.isBookmarked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: widget.isBookmarked ? const Color(0xFFE11D48) : C.mu,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // 2단: 한글 명칭 + 한글 설명
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.term.isNotEmpty) ...[
                        Text(
                          e.term,
                          style: T.captionBold.copyWith(color: C.tx),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          e.description,
                          style: T.caption.copyWith(color: C.tx2),
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // 탭 시 영문 설명 확장
                  if (_expanded && e.descriptionEn.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: C.lvL,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.bd2),
                      ),
                      child: Text(
                        e.descriptionEn,
                        style: T.caption.copyWith(color: C.lvD, height: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBookmark(BuildContext context, WidgetRef ref, dynamic t) async {
    if (widget.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.loginRequiredFirst)),
      );
      return;
    }
    final wasBookmarked = widget.isBookmarked;
    final repo = ref.read(personalEncyclopediaRepositoryProvider);
    await toggleBookmark(
      repo: repo,
      uid: widget.uid!,
      entry: widget.entry,
      isCurrentlyBookmarked: wasBookmarked,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasBookmarked ? t.encyclopediaBookmarkRemoved : t.encyclopediaBookmarkAdded),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Personal Entry Card
// ---------------------------------------------------------------------------
class _PersonalEntryCard extends ConsumerWidget {
  final PersonalEncyclopediaEntry entry;
  final String uid;

  const _PersonalEntryCard({required this.entry, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.isBookmark)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.favorite_rounded, size: 14, color: const Color(0xFFE11D48)),
                      ),
                    Expanded(child: Text(entry.term, style: T.bodyBold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.definition,
                  style: T.body.copyWith(color: C.tx2, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.example.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.example,
                    style: T.caption.copyWith(color: C.mu, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline_rounded, size: 20, color: C.mu),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(entry.isBookmark ? '북마크 제거' : '항목 삭제', style: T.h3),
        content: Text(
          entry.isBookmark
              ? '나만의 사전에서 이 북마크를 제거할까요?'
              : '이 항목을 삭제할까요? 되돌릴 수 없어요.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(personalEncyclopediaRepositoryProvider);
      await repo.deleteEntry(uid, entry.id);
    }
  }
}
