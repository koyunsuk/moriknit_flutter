import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

// ── 데이터 ────────────────────────────────────────────────────────────────────

class _NeedleRow {
  final String metric; // e.g. "2.25 mm"
  final String us;     // e.g. "1" or "" if none
  final String jp;     // e.g. "0"
  const _NeedleRow(this.metric, this.us, this.jp);
}

const _knittingData = [
  _NeedleRow('1.5 mm', '000', '0'),
  _NeedleRow('1.75 mm', '00', '0'),
  _NeedleRow('2.0 mm', '0', '0'),
  _NeedleRow('2.25 mm', '1', '0'),
  _NeedleRow('2.75 mm', '2', '2'),
  _NeedleRow('3.0 mm', '3', '3'),
  _NeedleRow('3.125 mm', '3', '3'),
  _NeedleRow('3.25 mm', '3', '4'),
  _NeedleRow('3.5 mm', '4', '5'),
  _NeedleRow('3.75 mm', '5', '5'),
  _NeedleRow('4.0 mm', '6', '6'),
  _NeedleRow('4.25 mm', '6', '7'),
  _NeedleRow('4.5 mm', '7', '8'),
  _NeedleRow('5.0 mm', '8', '10'),
  _NeedleRow('5.25 mm', '9', '10'),
  _NeedleRow('5.5 mm', '9', '11'),
  _NeedleRow('5.75 mm', '10', '12'),
  _NeedleRow('6.0 mm', '10', '13'),
  _NeedleRow('6.5 mm', '10½', '15'),
  _NeedleRow('7.0 mm', '-', '15'),
  _NeedleRow('8.0 mm', '11', '15'),
  _NeedleRow('9.0 mm', '13', '15'),
  _NeedleRow('10.0 mm', '15', '15'),
  _NeedleRow('12.5 mm', '17', '15'),
  _NeedleRow('12.75 mm', '17', '15'),
  _NeedleRow('15.0 mm', '19', '15'),
  _NeedleRow('19.0 mm', '35', '15'),
  _NeedleRow('25.0 mm', '50', '15'),
  _NeedleRow('35.0 mm', '70', '15'),
];

const _crochetData = [
  _NeedleRow('2.25 mm', 'B-1', '0'),
  _NeedleRow('2.5 mm', '-', '1'),
  _NeedleRow('2.75 mm', 'C-2', '2'),
  _NeedleRow('3.125 mm', 'D', '3'),
  _NeedleRow('3.25 mm', 'D-3', '4'),
  _NeedleRow('3.5 mm', 'E-4', '5'),
  _NeedleRow('3.75 mm', 'F-5', '5'),
  _NeedleRow('4.0 mm', 'G-6', '6'),
  _NeedleRow('4.25 mm', 'G', '7'),
  _NeedleRow('4.5 mm', '7', '8'),
  _NeedleRow('5.0 mm', 'H-8', '10'),
  _NeedleRow('5.25 mm', 'I', '10'),
  _NeedleRow('5.5 mm', 'I-9', '11'),
  _NeedleRow('5.75 mm', 'J', '12'),
  _NeedleRow('6.0 mm', 'J-10', '13'),
  _NeedleRow('6.5 mm', 'K-10½', '15'),
  _NeedleRow('7.0 mm', '-', '15'),
  _NeedleRow('8.0 mm', 'L-11', '15'),
  _NeedleRow('9.0 mm', 'M/N-13', '15'),
  _NeedleRow('10.0 mm', 'N/P-15', '15'),
  _NeedleRow('11.5 mm', 'P-16', '15'),
  _NeedleRow('12.0 mm', '-', '15'),
  _NeedleRow('15.0 mm', 'P/Q', '15'),
  _NeedleRow('15.75 mm', 'Q', '15'),
  _NeedleRow('16.0 mm', 'Q', '15'),
  _NeedleRow('19.0 mm', 'Q', '15'),
  _NeedleRow('25.0 mm', 'S', '15'),
  _NeedleRow('30.0 mm', 'T/U/X', '15'),
];

// ── 화면 ──────────────────────────────────────────────────────────────────────

class NeedleSizeConverterScreen extends ConsumerStatefulWidget {
  const NeedleSizeConverterScreen({super.key});

  @override
  ConsumerState<NeedleSizeConverterScreen> createState() =>
      _NeedleSizeConverterScreenState();
}

class _NeedleSizeConverterScreenState
    extends ConsumerState<NeedleSizeConverterScreen> {
  bool _isCrochet = false;
  final _searchCtrl = TextEditingController();
  int? _highlightIndex;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_NeedleRow> get _data => _isCrochet ? _crochetData : _knittingData;

  List<({_NeedleRow row, int index})> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final data = _data;
    if (q.isEmpty) {
      return List.generate(data.length, (i) => (row: data[i], index: i));
    }
    return data
        .asMap()
        .entries
        .where((e) =>
            e.value.metric.toLowerCase().contains(q) ||
            e.value.us.toLowerCase().contains(q) ||
            e.value.jp.toLowerCase().contains(q))
        .map((e) => (row: e.value, index: e.key))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '바늘 크기 변환기' : 'Needle Size Converter',
                    subtitle: isKorean
                        ? '대바늘·코바늘 호수 환산'
                        : 'Knit / crochet size lookup',
                  ),
                ),
                // ── 탭 (대바늘 / 코바늘) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _TabChip(
                        label: isKorean ? '대바늘' : 'Knitting',
                        selected: !_isCrochet,
                        onTap: () => setState(() {
                          _isCrochet = false;
                          _searchCtrl.clear();
                          _highlightIndex = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        label: isKorean ? '코바늘' : 'Crochet',
                        selected: _isCrochet,
                        onTap: () => setState(() {
                          _isCrochet = true;
                          _searchCtrl.clear();
                          _highlightIndex = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── 검색 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() => _highlightIndex = null),
                    decoration: InputDecoration(
                      hintText: isKorean
                          ? 'mm, US, JP 번호로 검색'
                          : 'Search by mm, US or JP',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _highlightIndex = null;
                              }),
                            )
                          : null,
                      fillColor: C.gx,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── 헤더 행 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Metric (mm)',
                            style: T.captionBold.copyWith(color: C.lvD),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'US',
                            textAlign: TextAlign.center,
                            style: T.captionBold.copyWith(color: C.lvD),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'JP',
                            textAlign: TextAlign.center,
                            style: T.captionBold.copyWith(color: C.lvD),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // ── 목록 ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final item = _filtered[i];
                      final isHighlighted = _highlightIndex == item.index;
                      return _NeedleRowTile(
                        row: item.row,
                        highlighted: isHighlighted,
                        onTap: () => setState(() {
                          _highlightIndex =
                              isHighlighted ? null : item.index;
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 탭 칩 ────────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : C.lvD,
          ),
        ),
      ),
    );
  }
}

// ── 행 타일 ──────────────────────────────────────────────────────────────────

class _NeedleRowTile extends StatelessWidget {
  final _NeedleRow row;
  final bool highlighted;
  final VoidCallback onTap;
  const _NeedleRowTile(
      {required this.row, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted
              ? C.lv.withValues(alpha: 0.15)
              : C.gx.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted
                ? C.lv.withValues(alpha: 0.6)
                : Colors.transparent,
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.metric,
                style: T.body.copyWith(
                  fontWeight:
                      highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: highlighted ? C.lvD : C.tx,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.us.isEmpty || row.us == '-' ? '—' : row.us,
                textAlign: TextAlign.center,
                style: T.body.copyWith(
                  fontWeight:
                      highlighted ? FontWeight.w700 : FontWeight.w400,
                  color: highlighted
                      ? C.lvD
                      : (row.us.isEmpty || row.us == '-'
                          ? C.mu
                          : C.tx),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.jp,
                textAlign: TextAlign.center,
                style: T.body.copyWith(
                  fontWeight:
                      highlighted ? FontWeight.w700 : FontWeight.w400,
                  color: highlighted ? C.lvD : C.tx,
                ),
              ),
            ),
            if (highlighted)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: C.lv),
              ),
          ],
        ),
      ),
    );
  }
}
