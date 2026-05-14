// lib/features/pattern/presentation/widgets/round_editor_view.dart
//
// 이슈 #665 Phase 3+4 — 원형(코바늘 라운드) 도안 에디터 뷰.
//
// 사각 그리드(chart_canvas.dart)와 별개로 chartType이 round*인 도안에서 사용.
// PatternChart.roundData (RoundChart) 를 편집해서 onChange 콜백으로 전달.
//
// 주요 기능
//   - 코바늘 심볼 30종 카테고리 탭 팔레트 (basic/decrease/increase/special/edge)
//   - 셀 배치/지우기/선택/색상 변경 (place/erase/select/color 모드)
//   - 라운드 추가/삭제 (+단/-단 — autoIncreasePerRound 자동 적용)
//   - 셀 색상 8종 + 자동회전 토글 + 가이드 토글
//   - InteractiveViewer 줌·팬 + 드래그 호버 스냅
//   - Undo (최대 30단계 스냅샷)
//
// 참고 위젯
//   - RoundChartView / RoundChartPainter (그리기)
//   - SvgSymbolCache (심볼 SVG 캐시)
//   - CrochetSymbolLibrary (30종 심볼 메타)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mori_symbol_view.dart';
import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/crochet_symbols.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';
import '../../domain/round_chart.dart';
import 'round_chart_painter.dart';
import 'svg_symbol_cache.dart';

/// 편집 모드 — 캔버스 탭 액션 분기.
enum _EditMode {
  /// 심볼 배치.
  place,

  /// 셀 제거.
  erase,

  /// 셀 선택 (편집 패널 표시).
  select,

  /// 셀 배경색만 변경.
  color,
}

/// 도구 종류 — 원형 도안 팔레트에서 대바늘/코바늘 심볼 그룹 전환.
///
/// 원형 도안은 코바늘 사용이 일반적이라 [crochet]가 기본값이지만,
/// 이슈 #665 옵션 1.5에 따라 한 도안에 대바늘 심볼도 혼용 가능.
/// RoundCell.symbolId는 String이라 양쪽 ID 모두 그대로 저장됨.
enum CraftType {
  /// 대바늘 (KnitSymbolLibrary 60종 — 카테고리 6종)
  knit,

  /// 코바늘 (CrochetSymbolLibrary 30종 — 카테고리 5종)
  crochet,
}

/// 원형 도안 에디터 뷰.
///
/// 부모(에디터 화면)에서 [PatternChart] 보유 + 저장. 본 위젯은
/// roundData 편집만 책임지고, 변경 즉시 [onChange] 콜백으로 새 PatternChart 전달.
class RoundEditorView extends ConsumerStatefulWidget {
  /// 편집 대상 도안 (chartType이 round* 여야 함).
  final PatternChart chart;

  /// 변경 시 호출되는 콜백 (저장은 부모 책임).
  final void Function(PatternChart) onChange;

  /// 읽기 전용 (뷰어 모드).
  final bool isReadOnly;

  const RoundEditorView({
    super.key,
    required this.chart,
    required this.onChange,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<RoundEditorView> createState() => _RoundEditorViewState();
}

class _RoundEditorViewState extends ConsumerState<RoundEditorView> {
  // ── 편집 상태 ────────────────────────────────────────────────────
  /// 현재 선택된 심볼 ID (palette 탭).
  String? _selectedSymbolId;

  /// 호버 중인 셀 (드래그 시 미리보기).
  RoundCellKey? _hoveredCell;

  /// 선택된 셀 (편집 패널 표시).
  RoundCellKey? _selectedCell;

  /// 편집 모드.
  _EditMode _mode = _EditMode.place;

  /// 셀 배경색 (다음 배치 시 적용).
  Color _selectedColor = const Color(0xFF8B7AB8);

  /// 가이드(점선 동심원·방사선) 표시.
  bool _showGuides = true;

  /// 자동 회전 (셀 배치 시 기본값).
  /// #680 일관성 — 기본 OFF. 회전 없이 SVG 원본 방향(위가 위) 유지.
  /// 사용자가 vertical bar를 외곽 향하게 하고 싶으면 옵션에서 ON.
  bool _autoRotate = false;

  /// 현재 표시 중인 도구 종류 (대바늘/코바늘).
  ///
  /// 원형 도안은 코바늘이 일반적이므로 기본값은 [CraftType.crochet].
  CraftType _craftType = CraftType.crochet;

  /// 코바늘 단순 필터 (#673) — 전체 / 늘리기 / 줄이기 / 특수.
  /// null = 전체. 'increase' / 'decrease' / 'special' 중 하나.
  String? _crochetFilter; // null = 전체

  /// 대바늘 단순 필터 (일관성) — 전체 / 늘리기 / 줄이기 / 특수.
  String? _knitFilter; // null = 전체

  /// Undo 스냅샷 (최대 30개).
  final List<RoundChart> _undoStack = [];
  static const int _kMaxUndo = 30;

  /// #680/#675 — 하단 탭: -1 접힘, 0 도구, 1 단(라운드 가감 + 옵션), 2 심볼.
  int _bottomTab = 0;

  /// #671 — InteractiveViewer 핀치줌/팬 컨트롤러 (화면맞춤 버튼용).
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  /// 화면맞춤 — 변환 행렬 리셋 (스케일 1.0, 팬 0).
  void _fitToScreen() {
    _transformCtrl.value = Matrix4.identity();
  }

  /// 셀 배경 8색 팔레트.
  static const List<Color> _kCellColors = [
    Color(0xFF8B7AB8), // 라벤더
    Color(0xFFE8A0C7), // 핑크
    Color(0xFFF4B942), // 골드
    Color(0xFF7BC4A4), // 민트
    Color(0xFF6FA8DC), // 블루
    Color(0xFFC97A4A), // 브라운
    Color(0xFFE57373), // 코랄레드
    Color(0xFFEEEEEE), // 라이트그레이
  ];

  // ── 편의 getter ────────────────────────────────────────────────
  /// 유효한 RoundChart (없으면 기본 6단 매직링).
  RoundChart get _roundData =>
      widget.chart.roundData ??
      const RoundChart(rounds: 6, baseStitchCount: 6);

  bool get _readOnly => widget.isReadOnly;

  // ── 변경 처리 ────────────────────────────────────────────────────
  /// 변경 직전 스냅샷 push (Undo).
  void _pushUndo() {
    _undoStack.add(_roundData);
    if (_undoStack.length > _kMaxUndo) {
      _undoStack.removeAt(0);
    }
  }

  /// roundData 변경을 부모에게 전달.
  void _emit(RoundChart newRoundData) {
    final newChart = widget.chart.copyWith(roundData: newRoundData);
    widget.onChange(newChart);
  }

  /// Undo 실행.
  void _undo() {
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    setState(() {
      _selectedCell = null;
      _hoveredCell = null;
    });
    _emit(prev);
  }

  // ── 셀 액션 ────────────────────────────────────────────────────
  /// 심볼 배치 (#680 — 터치 위치로 align 자동).
  void _placeCell(RoundCellKey key, {bool? isLineTouch}) {
    if (_readOnly) return;
    if (_mode == _EditMode.erase) {
      _eraseCell(key);
      return;
    }
    if (_mode == _EditMode.select) {
      setState(() => _selectedCell = key);
      return;
    }
    if (_mode == _EditMode.color) {
      _recolorCell(key);
      return;
    }
    if (_selectedSymbolId == null) return;
    _pushUndo();
    final existing = _roundData.cells[key] ?? const RoundCell();
    // #680 — 터치 위치가 라인 부근이면 onLine, 셀 중앙이면 cellArea.
    final align = isLineTouch == true ? CellAlign.onLine : CellAlign.cellArea;
    final cell = existing.copyWith(
      symbolId: _selectedSymbolId,
      autoRotate: _autoRotate,
      align: align,
    );
    _emit(_roundData.withCell(key, cell));
  }

  /// 셀 제거.
  void _eraseCell(RoundCellKey key) {
    if (_readOnly) return;
    if (!_roundData.cells.containsKey(key)) return;
    _pushUndo();
    _emit(_roundData.withoutCell(key));
    if (_selectedCell == key) {
      setState(() => _selectedCell = null);
    }
  }

  /// 셀 배경색만 변경.
  void _recolorCell(RoundCellKey key) {
    if (_readOnly) return;
    final existing = _roundData.cells[key];
    _pushUndo();
    final cell = (existing ?? const RoundCell()).copyWith(color: _selectedColor);
    _emit(_roundData.withCell(key, cell));
  }

  // ── #680 자동 배치 — 라운드에 N개 균일 채우기 ─────────────────────
  Future<void> _autoFillRound() async {
    if (_readOnly || _selectedSymbolId == null) return;
    final result = await _showAutoFillDialog();
    if (result == null || !mounted) return;
    final segCount = _roundData.stitchCounts.isNotEmpty &&
            result.round - 1 < _roundData.stitchCounts.length
        ? _roundData.stitchCounts[result.round - 1]
        : (_roundData.autoIncreasePerRound
            ? _roundData.baseStitchCount * result.round
            : _roundData.baseStitchCount);
    final n = result.count.clamp(1, segCount);
    _pushUndo();
    var data = _roundData;
    for (int s = 0; s < n; s++) {
      final segIdx = (s * segCount / n).floor();
      final key = RoundCellKey(round: result.round, segment: segIdx);
      final existing = data.cells[key] ?? const RoundCell();
      data = data.withCell(
        key,
        existing.copyWith(
          symbolId: _selectedSymbolId,
          autoRotate: _autoRotate,
          align: result.align,
        ),
      );
    }
    _emit(data);
  }

  /// 자동 배치 다이얼로그 — round/count/align 반환.
  Future<({int round, int count, CellAlign align})?>
      _showAutoFillDialog() async {
    int round = 1;
    int n = 6;
    CellAlign align = CellAlign.onLine; // 기본 = 라인 위 (자연스러움)
    return showDialog<({int round, int count, CellAlign align})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('라운드에 자동 배치'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('선택 심볼을 라운드에 균일 배치합니다.'),
              const SizedBox(height: 12),
              Row(children: [
                const Text('라운드'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: round.toDouble(),
                    min: 1,
                    max: _roundData.rounds.toDouble(),
                    divisions: math.max(1, _roundData.rounds - 1),
                    label: 'R$round',
                    onChanged: (v) => setLocal(() => round = v.round()),
                  ),
                ),
                Text('R$round'),
              ]),
              Row(children: [
                const Text('개수'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: n.toDouble(),
                    min: 1,
                    max: 36,
                    divisions: 35,
                    label: '$n',
                    onChanged: (v) => setLocal(() => n = v.round()),
                  ),
                ),
                Text('$n개'),
              ]),
              const SizedBox(height: 8),
              const Text('정렬', style: TextStyle(fontWeight: FontWeight.w700)),
              RadioListTile<CellAlign>(
                value: CellAlign.onLine,
                groupValue: align,
                onChanged: (v) => setLocal(() => align = v!),
                title: const Text('라인 위 (baseline)'),
                subtitle: const Text('심볼 밑면이 라인에 닿고 외곽으로 솟음'),
                dense: true,
              ),
              RadioListTile<CellAlign>(
                value: CellAlign.cellArea,
                groupValue: align,
                onChanged: (v) => setLocal(() => align = v!),
                title: const Text('셀 안 (contain)'),
                subtitle: const Text('사각 그리드처럼 셀 사각 영역에 맞춤'),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx, (round: round, count: n, align: align)),
              child: const Text('배치'),
            ),
          ],
        ),
      ),
    );
  }

  /// 라운드 1단 추가.
  void _addRound() {
    if (_readOnly) return;
    _pushUndo();
    _emit(_roundData.copyWith(rounds: _roundData.rounds + 1));
  }

  /// 마지막 라운드 제거 (해당 셀 모두 삭제).
  void _removeRound() {
    if (_readOnly) return;
    if (_roundData.rounds <= 1) return;
    _pushUndo();
    final lastRound = _roundData.rounds;
    final newCells = Map<RoundCellKey, RoundCell>.from(_roundData.cells);
    newCells.removeWhere((k, _) => k.round == lastRound);
    _emit(_roundData.copyWith(
      rounds: _roundData.rounds - 1,
      cells: newCells,
    ));
    if (_selectedCell != null && _selectedCell!.round == lastRound) {
      setState(() => _selectedCell = null);
    }
  }

  /// 선택 셀 회전 토글.
  void _toggleSelectedRotation() {
    if (_readOnly) return;
    final key = _selectedCell;
    if (key == null) return;
    final cell = _roundData.cells[key];
    if (cell == null) return;
    _pushUndo();
    _emit(_roundData.withCell(key, cell.copyWith(autoRotate: !cell.autoRotate)));
  }

  // ── 빌드 ────────────────────────────────────────────────────────
  // #680/#675 — 탭 구조로 그리드 영역 최대화 (자유 path와 동일).
  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(svgSymbolCacheProvider);
    final svgUrls = ref.watch(knitSymbolSvgUrlProvider);
    cache.setSvgUrls(svgUrls);
    return Column(
      children: [
        // 1) 그리드 (메인) — 화면 대부분
        Expanded(child: _buildCanvas(cache)),
        // 2) 셀 인스펙터 (선택 시 — 항상 표시)
        if (_selectedCell != null && !_readOnly) _buildCellInspector(),
        // 3) 탭바 — 한 줄
        if (!_readOnly) _buildBottomTabBar(),
        // 4) 활성 탭 콘텐츠 — 한 영역만
        if (!_readOnly) _buildBottomTabContent(),
      ],
    );
  }

  Widget _buildBottomTabBar() {
    final tabs = [
      ('도구', Icons.build_outlined),
      ('단/옵션', Icons.tune),
      ('심볼', Icons.brush_outlined),
    ];
    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(
          top: BorderSide(color: C.bd, width: 1),
          bottom: BorderSide(color: C.bd, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _bottomTab = (_bottomTab == i) ? -1 : i;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _bottomTab == i
                        ? C.lv.withValues(alpha: 0.10)
                        : Colors.transparent,
                    border: _bottomTab == i
                        ? Border(top: BorderSide(color: C.lv, width: 2))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tabs[i].$2,
                          size: 18,
                          color: _bottomTab == i ? C.lvD : C.tx2),
                      const SizedBox(height: 2),
                      Text(tabs[i].$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _bottomTab == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _bottomTab == i ? C.lvD : C.tx2,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomTabContent() {
    switch (_bottomTab) {
      case 0:
        return _buildToolbar();
      case 1:
        return _buildOptionsRow();
      case 2:
        return _buildPalette();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── 1) 툴바 ────────────────────────────────────────────────────
  // #666/#671 — 가로 스크롤로 픽셀 오버플로우 방지 + 화면맞춤 버튼 추가.
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarChip(
              label: '심볼',
              icon: Icons.brush_outlined,
              selected: _mode == _EditMode.place,
              onTap: () => setState(() => _mode = _EditMode.place),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '지우개',
              icon: Icons.cleaning_services_outlined,
              selected: _mode == _EditMode.erase,
              onTap: () => setState(() => _mode = _EditMode.erase),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '선택',
              icon: Icons.touch_app_outlined,
              selected: _mode == _EditMode.select,
              onTap: () => setState(() => _mode = _EditMode.select),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '색칠',
              icon: Icons.format_color_fill,
              selected: _mode == _EditMode.color,
              onTap: () => setState(() => _mode = _EditMode.color),
            ),
            const SizedBox(width: 12),
            // #680 자동 배치 — 라운드에 N개 균일.
            IconButton(
              tooltip: '자동 배치 (라운드에 N개)',
              onPressed: _selectedSymbolId == null ? null : _autoFillRound,
              icon: Icon(Icons.auto_awesome_motion,
                  color: _selectedSymbolId == null ? C.mu : C.lvD),
              iconSize: 22,
            ),
            IconButton(
              tooltip: '실행 취소',
              onPressed: _undoStack.isEmpty ? null : _undo,
              icon: Icon(Icons.undo, color: _undoStack.isEmpty ? C.mu : C.lvD),
              iconSize: 22,
            ),
            IconButton(
              tooltip: '화면맞춤',
              onPressed: _fitToScreen,
              icon: Icon(Icons.fit_screen_outlined, color: C.lvD),
              iconSize: 22,
            ),
            IconButton(
              tooltip: '단 추가',
              onPressed: _addRound,
              icon: Icon(Icons.add_circle_outline, color: C.lv),
              iconSize: 22,
            ),
            IconButton(
              tooltip: '단 삭제',
              onPressed: _roundData.rounds <= 1 ? null : _removeRound,
              icon: Icon(
                Icons.remove_circle_outline,
                color: _roundData.rounds <= 1 ? C.mu : C.og,
              ),
              iconSize: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── 2) 옵션 행 (색상 + 토글) ──────────────────────────────────
  Widget _buildOptionsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Row(
        children: [
          // 색상 8개
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in _kCellColors) ...[
                    _ColorSwatch(
                      color: c,
                      selected: c.toARGB32() == _selectedColor.toARGB32(),
                      onTap: () => setState(() => _selectedColor = c),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 자동회전
          _OptionToggle(
            label: '자동회전',
            value: _autoRotate,
            onChanged: (v) => setState(() => _autoRotate = v),
          ),
          const SizedBox(width: 8),
          // 가이드
          _OptionToggle(
            label: '가이드',
            value: _showGuides,
            onChanged: (v) => setState(() => _showGuides = v),
          ),
        ],
      ),
    );
  }

  // ── 3) 심볼 팔레트 (대바늘/코바늘 토글 + 카테고리 + 심볼 가로 스크롤) ──
  /// #673 — 단순 필터(전체/늘리기/줄이기/특수)에 따른 심볼 리스트.
  /// 'special' 필터는 basic + special + edge(코바늘) / cable + special + lace(대바늘) 모두 포함.
  List<dynamic> _filterSymbols(bool isKnit) {
    if (isKnit) {
      final filter = _knitFilter;
      if (filter == null) return KnitSymbolLibrary.all;
      switch (filter) {
        case 'increase':
          return KnitSymbolLibrary.byCategory(SymbolCategory.increase);
        case 'decrease':
          return KnitSymbolLibrary.byCategory(SymbolCategory.decrease);
        case 'special':
          return KnitSymbolLibrary.all
              .where((s) =>
                  s.category == SymbolCategory.basic ||
                  s.category == SymbolCategory.cable ||
                  s.category == SymbolCategory.special ||
                  s.category == SymbolCategory.lace)
              .toList();
      }
      return KnitSymbolLibrary.all;
    }
    final filter = _crochetFilter;
    if (filter == null) return kCrochetSymbols;
    switch (filter) {
      case 'increase':
        return CrochetSymbolLibrary.byCategory(CrochetCategory.increase);
      case 'decrease':
        return CrochetSymbolLibrary.byCategory(CrochetCategory.decrease);
      case 'special':
        return kCrochetSymbols
            .where((c) =>
                c.category == CrochetCategory.basic ||
                c.category == CrochetCategory.special ||
                c.category == CrochetCategory.edge)
            .toList();
    }
    return kCrochetSymbols;
  }

  Widget _buildPalette() {
    // #673 — 단순화된 필터: 전체 / 늘리기 / 줄이기 / 특수.
    final isKnit = _craftType == CraftType.knit;
    final List<dynamic> symbols = _filterSymbols(isKnit);

    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        // 섹션 구분 — 위/아래 모두 라인.
        border: Border(
          top: BorderSide(color: C.bd, width: 1),
          bottom: BorderSide(color: C.bd, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1행: 도구 종류 토글 (대바늘 K / 코바늘 C)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                _CraftToggle(
                  label: '대바늘 K',
                  selected: _craftType == CraftType.knit,
                  onTap: () => setState(() {
                    _craftType = CraftType.knit;
                    _selectedSymbolId = null;
                  }),
                ),
                const SizedBox(width: 6),
                _CraftToggle(
                  label: '코바늘 C',
                  selected: _craftType == CraftType.crochet,
                  onTap: () => setState(() {
                    _craftType = CraftType.crochet;
                    _selectedSymbolId = null;
                  }),
                ),
              ],
            ),
          ),
          // 2행: 단순 필터 탭 — 전체 / 늘리기 / 줄이기 / 특수
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final entry in const [
                  ['all', '전체'],
                  ['increase', '늘리기'],
                  ['decrease', '줄이기'],
                  ['special', '특수'],
                ]) ...[
                  _CategoryTab(
                    label: entry[1],
                    selected: (isKnit ? _knitFilter : _crochetFilter) ==
                        (entry[0] == 'all' ? null : entry[0]),
                    onTap: () => setState(() {
                      final v = entry[0] == 'all' ? null : entry[0];
                      if (isKnit) {
                        _knitFilter = v;
                      } else {
                        _crochetFilter = v;
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          // 3행: 심볼 가로 스크롤
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              itemCount: symbols.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = symbols[i];
                final id = isKnit
                    ? (s as KnitSymbol).id
                    : (s as CrochetSymbol).id;
                final selected = _selectedSymbolId == id;
                return _SymbolCard(
                  craft: _craftType,
                  symbol: s,
                  selected: selected,
                  onTap: () => setState(() {
                    _selectedSymbolId = id;
                    _mode = _EditMode.place;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 4) 선택 셀 인스펙터 (#680 — align/angle/symbol/색 분리 편집) ──
  Widget _buildCellInspector() {
    final key = _selectedCell!;
    final cell = _roundData.cells[key];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: C.lvL,
        border: Border(bottom: BorderSide(color: C.lv.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.adjust, size: 16, color: C.lvD),
              const SizedBox(width: 6),
              Text('R${key.round} · S${key.segment}', style: T.bodyBold),
              const SizedBox(width: 12),
              if (cell?.symbolId != null) ...[
                Expanded(
                  child: Text(
                    CrochetSymbolLibrary.byId(cell!.symbolId!)?.labelKo ??
                        KnitSymbolLibrary.byId(cell.symbolId!)?.name ??
                        cell.symbolId!,
                    style: T.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (cell != null) ...[
                IconButton(
                  tooltip: '심볼 제거',
                  onPressed: () {
                    if (cell.symbolId == null) return;
                    _pushUndo();
                    _emit(_roundData.withCell(key, cell.withoutSymbol()));
                  },
                  icon: Icon(Icons.cleaning_services_outlined,
                      color: cell.symbolId == null ? C.mu : C.lvD),
                  iconSize: 18,
                ),
                IconButton(
                  tooltip: '색칠 제거',
                  onPressed: () {
                    if (cell.color == null) return;
                    _pushUndo();
                    _emit(_roundData.withCell(key, cell.withoutColor()));
                  },
                  icon: Icon(Icons.format_color_reset,
                      color: cell.color == null ? C.mu : C.lvD),
                  iconSize: 18,
                ),
                IconButton(
                  tooltip: '셀 완전 삭제',
                  onPressed: () => _eraseCell(key),
                  icon: Icon(Icons.delete_outline, color: C.og),
                  iconSize: 18,
                ),
              ],
              IconButton(
                tooltip: '닫기',
                onPressed: () => setState(() => _selectedCell = null),
                icon: Icon(Icons.close, color: C.tx2),
                iconSize: 18,
              ),
            ],
          ),
          if (cell != null) ...[
            // align 토글 — 셀안 / 라인 위
            Row(children: [
              Text('정렬', style: T.caption.copyWith(color: C.tx2)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('셀 안', style: TextStyle(fontSize: 11)),
                selected: cell.align == CellAlign.cellArea,
                selectedColor: C.lv,
                onSelected: (_) {
                  _pushUndo();
                  _emit(_roundData.withCell(
                      key, cell.copyWith(align: CellAlign.cellArea)));
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('라인 위', style: TextStyle(fontSize: 11)),
                selected: cell.align == CellAlign.onLine,
                selectedColor: C.lv,
                onSelected: (_) {
                  _pushUndo();
                  _emit(_roundData.withCell(
                      key, cell.copyWith(align: CellAlign.onLine)));
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: '자동 회전',
                onPressed: _toggleSelectedRotation,
                icon: Icon(
                  cell.autoRotate
                      ? Icons.rotate_right
                      : Icons.rotate_left,
                  color: cell.autoRotate ? C.lv : C.mu,
                ),
                iconSize: 18,
              ),
            ]),
            // angle 슬라이더 — 미세 회전 (-π/4 ~ π/4)
            Row(children: [
              Text('각도', style: T.caption.copyWith(color: C.tx2)),
              Expanded(
                child: Slider(
                  value: cell.rotationDelta.clamp(-math.pi / 4, math.pi / 4),
                  min: -math.pi / 4,
                  max: math.pi / 4,
                  divisions: 36,
                  activeColor: C.lv,
                  label:
                      '${(cell.rotationDelta * 180 / math.pi).toStringAsFixed(0)}°',
                  onChanged: (v) {
                    _emit(_roundData.withCell(
                        key, cell.copyWith(rotationDelta: v)));
                  },
                  onChangeStart: (_) => _pushUndo(),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(cell.rotationDelta * 180 / math.pi).toStringAsFixed(0)}°',
                  style: T.caption.copyWith(color: C.lvD),
                  textAlign: TextAlign.right,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── 5) 캔버스 ──────────────────────────────────────────────────
  Widget _buildCanvas(SvgSymbolCache cache) {
    // #673 — 그리드 배경 흰색 + 섹션 구분 (하단 보더).
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 4.0,
            // #680 — 좌표 기준 명확화. boundaryMargin 제거로 hit test/그리기 size 일치.
            constrained: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _readOnly
                  ? null
                  : (d) {
                      // #680 — 터치 위치로 align 자동 결정.
                      final hint = RoundChartPainter.snapToCellWithHint(
                        _roundData,
                        d.localPosition,
                        size,
                      );
                      if (hint != null) {
                        _placeCell(hint.key, isLineTouch: hint.isLineTouch);
                      }
                    },
              onPanUpdate: _readOnly
                  ? null
                  : (d) {
                      final key = RoundChartPainter.snapToCell(
                        _roundData,
                        d.localPosition,
                        size,
                      );
                      if (key != _hoveredCell) {
                        setState(() => _hoveredCell = key);
                      }
                    },
              onPanEnd: _readOnly
                  ? null
                  : (d) {
                      final key = _hoveredCell;
                      if (key != null) {
                        // PanEnd에서도 마지막 위치 hint 사용.
                        final hint = RoundChartPainter.snapToCellWithHint(
                          _roundData,
                          d.localPosition,
                          size,
                        );
                        _placeCell(key,
                            isLineTouch: hint?.isLineTouch ?? false);
                      }
                      setState(() => _hoveredCell = null);
                    },
              child: ListenableBuilder(
                listenable: cache,
                builder: (_, _) => SizedBox.expand(
                  child: RoundChartView(
                    chart: _roundData,
                    hoveredCell: _hoveredCell,
                    selectedCell: _selectedCell,
                    showGuides: _showGuides,
                    symbolPicture: cache.pictureFor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 보조 위젯들
// ═══════════════════════════════════════════════════════════════════

/// 툴바 모드 칩 (심볼/지우개/선택/색칠).
class _ToolbarChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : C.lvD,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : C.lvD,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카테고리 탭 (기초/줄임/늘림/특수/가장자리).
class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.pk.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? C.pk : C.bd,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? C.pkD : C.tx2,
          ),
        ),
      ),
    );
  }
}

/// 심볼 한 칸 (SVG 미리보기 + 한글 라벨).
///
/// 대바늘([KnitSymbol])과 코바늘([CrochetSymbol]) 모두 표시 가능.
/// craftType에 따라 미리보기 렌더링 방식이 달라짐:
/// - 대바늘: 인라인 SVG 문자열 (kKnitSymbolSvgData) → SvgPicture.string
/// - 코바늘: Firebase Storage URL → SvgPicture.network
class _SymbolCard extends ConsumerWidget {
  final CraftType craft;
  final dynamic symbol; // KnitSymbol or CrochetSymbol
  final bool selected;
  final VoidCallback onTap;

  const _SymbolCard({
    required this.craft,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  /// 약어 라벨 (사각 그리드와 동일).
  String get _label {
    if (craft == CraftType.knit) return (symbol as KnitSymbol).abbr;
    return (symbol as CrochetSymbol).abbreviation;
  }

  /// Tooltip 한글 라벨.
  String get _tooltipKo {
    if (craft == CraftType.knit) return (symbol as KnitSymbol).name;
    return (symbol as CrochetSymbol).labelKo;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #672 — 사각 그리드 _StaticSymbolCell 과 완전 동일한 사이즈/정렬.
    final label = _label;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '$_tooltipKo ($label)',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? C.lv : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPreview(),
              const SizedBox(height: 3),
              Text(
                label.length > 6 ? label.substring(0, 6) : label,
                style: TextStyle(
                    fontSize: 8, color: C.tx2, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // #672 — 사각 그리드와 동일한 SVG 사이즈/소스.
    if (craft == CraftType.knit) {
      final k = symbol as KnitSymbol;
      // 대바늘: Firestore knit_symbols (MoriSymbolView)
      return MoriSymbolView(
        symbolId: k.id,
        size: 22,
        fallbackText: k.abbr,
      );
    }
    // 코바늘: 직접 firebaseUrl 사용 — Firestore 매핑 충돌 회피 (사각 그리드와 동일).
    final c = symbol as CrochetSymbol;
    if (c.hasSvg) {
      return SvgPicture.network(
        c.firebaseUrl,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Text(
          c.abbreviation.length > 4
              ? c.abbreviation.substring(0, 4)
              : c.abbreviation,
          style: TextStyle(
              fontSize: 9, color: C.tx2, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Text(
      c.abbreviation.length > 5
          ? c.abbreviation.substring(0, 5)
          : c.abbreviation,
      style: TextStyle(fontSize: 11, color: C.tx, fontWeight: FontWeight.w700),
    );
  }
}

/// 도구 종류 토글 (대바늘 K / 코바늘 C).
///
/// 모리니트 칩 스타일을 따름 — 선택 시 C.lv 강조, 미선택 시 C.lvL.
class _CraftToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CraftToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : C.lvD,
          ),
        ),
      ),
    );
  }
}

/// 색상 8칸 중 하나.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? C.tx : C.bd,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// 토글 (자동회전/가이드).
class _OptionToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? C.lvL : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? C.lv : C.bd,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: value ? C.lv : C.mu,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value ? C.lvD : C.tx2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
