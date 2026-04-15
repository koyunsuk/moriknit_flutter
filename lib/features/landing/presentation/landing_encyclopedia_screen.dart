import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/encyclopedia_provider.dart';
import '../../encyclopedia/domain/encyclopedia_entry.dart';
import 'feature_detail_screen.dart';
import 'landing_scaffold.dart'; // LandingFeatureScaffold re-exported

const double _kDesktop = 900.0;

// ──────────────────────────────────────────────────────────────────────────────
// 통합 화면: 좌 — 기능설명(히어로 목업 + 설명) / 우 — 뜨개백과사전
// ──────────────────────────────────────────────────────────────────────────────
class LandingEncyclopediaScreen extends ConsumerStatefulWidget {
  const LandingEncyclopediaScreen({super.key});

  @override
  ConsumerState<LandingEncyclopediaScreen> createState() =>
      _LandingEncyclopediaScreenState();
}

class _LandingEncyclopediaScreenState
    extends ConsumerState<LandingEncyclopediaScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _craftTab = 'knitting';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<EncyclopediaEntry> _filter(List<EncyclopediaEntry> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((e) =>
        e.term.toLowerCase().contains(q) ||
        e.termEn.toLowerCase().contains(q) ||
        e.abbreviation.toLowerCase().contains(q) ||
        e.description.toLowerCase().contains(q) ||
        e.descriptionEn.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final encyclopediaAsync = _craftTab == 'knitting'
        ? ref.watch(knittingEncyclopediaProvider)
        : ref.watch(crochetEncyclopediaProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _kDesktop;
    final feature = findFeature('encyclopedia')!;

    return LandingFeatureScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: isDesktop
              ? _DesktopLayout(
                  feature: feature,
                  encyclopediaAsync: encyclopediaAsync,
                  searchCtrl: _searchCtrl,
                  query: _query,
                  craftTab: _craftTab,
                  filteredEntries: encyclopediaAsync.valueOrNull != null
                      ? _filter(encyclopediaAsync.valueOrNull!)
                      : [],
                  onQueryChanged: (v) => setState(() => _query = v.trim()),
                  onQueryCleared: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                  onTabChanged: (t) => setState(() {
                    _craftTab = t;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                )
              : _MobileLayout(
                  feature: feature,
                  encyclopediaAsync: encyclopediaAsync,
                  searchCtrl: _searchCtrl,
                  query: _query,
                  craftTab: _craftTab,
                  filteredEntries: encyclopediaAsync.valueOrNull != null
                      ? _filter(encyclopediaAsync.valueOrNull!)
                      : [],
                  onQueryChanged: (v) => setState(() => _query = v.trim()),
                  onQueryCleared: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                  onTabChanged: (t) => setState(() {
                    _craftTab = t;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
        ),
      ],
    );
  }
}

// ── 데스크탑: 2단 레이아웃 ──────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final FeatureInfo feature;
  final AsyncValue<List<EncyclopediaEntry>> encyclopediaAsync;
  final TextEditingController searchCtrl;
  final String query;
  final String craftTab;
  final List<EncyclopediaEntry> filteredEntries;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onQueryCleared;
  final ValueChanged<String> onTabChanged;

  const _DesktopLayout({
    required this.feature,
    required this.encyclopediaAsync,
    required this.searchCtrl,
    required this.query,
    required this.craftTab,
    required this.filteredEntries,
    required this.onQueryChanged,
    required this.onQueryCleared,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 좌: 기능 설명 ────────────────────────────────────────────
              SizedBox(
                width: 400,
                child: _FeaturePanel(feature: feature),
              ),
              const SizedBox(width: 32),
              // ── 우: 백과사전 ─────────────────────────────────────────────
              Expanded(
                child: _EncyclopediaPanel(
                  encyclopediaAsync: encyclopediaAsync,
                  searchCtrl: searchCtrl,
                  query: query,
                  craftTab: craftTab,
                  filteredEntries: filteredEntries,
                  onQueryChanged: onQueryChanged,
                  onQueryCleared: onQueryCleared,
                  onTabChanged: onTabChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 모바일: 1단 레이아웃 ────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final FeatureInfo feature;
  final AsyncValue<List<EncyclopediaEntry>> encyclopediaAsync;
  final TextEditingController searchCtrl;
  final String query;
  final String craftTab;
  final List<EncyclopediaEntry> filteredEntries;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onQueryCleared;
  final ValueChanged<String> onTabChanged;

  const _MobileLayout({
    required this.feature,
    required this.encyclopediaAsync,
    required this.searchCtrl,
    required this.query,
    required this.craftTab,
    required this.filteredEntries,
    required this.onQueryChanged,
    required this.onQueryCleared,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeaturePanel(feature: feature, compact: true),
          const SizedBox(height: 32),
          _EncyclopediaPanel(
            encyclopediaAsync: encyclopediaAsync,
            searchCtrl: searchCtrl,
            query: query,
            craftTab: craftTab,
            filteredEntries: filteredEntries,
            onQueryChanged: onQueryChanged,
            onQueryCleared: onQueryCleared,
            onTabChanged: onTabChanged,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 좌단: 기능 설명 패널
// ──────────────────────────────────────────────────────────────────────────────
class _FeaturePanel extends StatelessWidget {
  final FeatureInfo feature;
  final bool compact;

  const _FeaturePanel({required this.feature, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ① 히어로 목업
        _PhoneMockup(feature: feature, compact: compact),
        const SizedBox(height: 28),
        // ② 아이콘 + 제목
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: feature.color.withValues(alpha: 0.25)),
              ),
              child: Icon(feature.icon, color: feature.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    feature.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: feature.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ③ 설명
        Text(
          feature.description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.75,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 24),
        // ④ 하이라이트
        ...feature.highlights.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: feature.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, color: feature.color, size: 12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.5),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        // ⑤ 사용 단계
        ...List.generate(feature.steps.length, (i) {
          final (icon, title, desc) = feature.steps[i];
          final isLast = i == feature.steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: feature.color.withValues(alpha: 0.20)),
                      ),
                      child: Icon(icon, color: feature.color, size: 18),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: feature.color.withValues(alpha: 0.18),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: feature.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${i + 1}단계',
                                  style: TextStyle(fontSize: 10, color: feature.color, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(desc,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),
        // ⑥ CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/signup?source=encyclopedia'),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('무료로 시작하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: feature.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 폰 목업 위젯
// ──────────────────────────────────────────────────────────────────────────────
class _PhoneMockup extends StatelessWidget {
  final FeatureInfo feature;
  final bool compact;

  const _PhoneMockup({required this.feature, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final h = compact ? 260.0 : 320.0;

    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            feature.color.withValues(alpha: 0.08),
            feature.color.withValues(alpha: 0.04),
            const Color(0xFFF8F6FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feature.color.withValues(alpha: 0.15)),
      ),
      child: Center(
        child: _MockPhone(feature: feature),
      ),
    );
  }
}

class _MockPhone extends StatelessWidget {
  final FeatureInfo feature;
  const _MockPhone({required this.feature});

  @override
  Widget build(BuildContext context) {
    const phoneW = 180.0;
    const phoneH = 320.0;

    return Container(
      width: phoneW,
      height: phoneH,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: feature.color.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            // 상단 노치
            Container(
              height: 24,
              color: const Color(0xFF111827),
              child: Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // 앱바
            Container(
              height: 38,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 16, color: feature.color),
                  const SizedBox(width: 6),
                  Text(
                    '뜨개백과사전',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            // 검색바
            Container(
              height: 30,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.search_rounded, size: 12, color: feature.color.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      '용어 검색',
                      style: TextStyle(fontSize: 9, color: feature.color.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
            // 목록
            Expanded(
              child: Container(
                color: const Color(0xFFF8F6FF),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _mockEntry('메리야스뜨기', 'Stockinette', 'st', feature.color),
                    _mockEntry('1코 고무단', 'Rib Stitch', 'k1p1', feature.color),
                    _mockEntry('코늘리기', 'Make One', 'M1', feature.color),
                    _mockEntry('코줄이기', 'Decrease', 'k2tog', feature.color),
                    _mockEntry('겉뜨기', 'Knit', 'k', feature.color),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockEntry(String term, String termEn, String abbr, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(Icons.texture_rounded, size: 14, color: color.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(term, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(abbr, style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text(termEn, style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 우단: 백과사전 패널
// ──────────────────────────────────────────────────────────────────────────────
class _EncyclopediaPanel extends StatelessWidget {
  final AsyncValue<List<EncyclopediaEntry>> encyclopediaAsync;
  final TextEditingController searchCtrl;
  final String query;
  final String craftTab;
  final List<EncyclopediaEntry> filteredEntries;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onQueryCleared;
  final ValueChanged<String> onTabChanged;

  const _EncyclopediaPanel({
    required this.encyclopediaAsync,
    required this.searchCtrl,
    required this.query,
    required this.craftTab,
    required this.filteredEntries,
    required this.onQueryChanged,
    required this.onQueryCleared,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // 패널 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFEDE9FE)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 18, color: const Color(0xFFFB923C)),
                const SizedBox(width: 8),
                const Text(
                  '뜨개백과사전',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                encyclopediaAsync.when(
                  data: (entries) => Text(
                    '${entries.length}개 용어',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // 탭 (대바늘 / 코바늘)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                _CraftTabChip(
                  label: '대바늘',
                  selected: craftTab == 'knitting',
                  onTap: () => onTabChanged('knitting'),
                ),
                const SizedBox(width: 8),
                _CraftTabChip(
                  label: '코바늘',
                  selected: craftTab == 'crochet',
                  onTap: () => onTabChanged('crochet'),
                ),
              ],
            ),
          ),
          // 검색바
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: '용어, 약어, 설명으로 검색',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade400),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
                        onPressed: onQueryCleared,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F3FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          // 목록
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 700, minHeight: 200),
            child: encyclopediaAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(
                height: 200,
                child: Center(child: Text('데이터를 불러오지 못했어요.')),
              ),
              data: (_) {
                if (filteredEntries.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('검색 결과가 없어요', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: const Color(0xFFF5F3FF),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      child: Row(
                        children: [
                          Text(
                            '${filteredEntries.length}개',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: filteredEntries.length,
                        itemBuilder: (context, index) =>
                            _EncyclopediaListTile(entry: filteredEntries[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 탭 칩
// ──────────────────────────────────────────────────────────────────────────────
class _CraftTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CraftTabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF7C3AED);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : activeColor.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF5B21B6),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 백과사전 목록 타일
// ──────────────────────────────────────────────────────────────────────────────
class _EncyclopediaListTile extends StatelessWidget {
  final EncyclopediaEntry entry;
  const _EncyclopediaListTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasSvg = entry.referenceUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
            ),
            child: hasSvg
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.network(
                      entry.referenceUrl,
                      placeholderBuilder: (_) => const SizedBox.shrink(),
                    ),
                  )
                : Icon(Icons.texture_rounded, size: 20, color: Colors.grey.shade300),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      entry.term,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (entry.termEn.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(entry.termEn, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                    if (entry.abbreviation.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.abbreviation,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.descriptionEn.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.descriptionEn,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
