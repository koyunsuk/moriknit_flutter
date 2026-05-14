import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/mori_symbol_view.dart';
import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/crochet_symbols.dart';
import '../../domain/knit_symbol_entry.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';
import 'chart_canvas.dart' show DrawLayer;
import 'chart_canvas.dart';

/// 도안에디터 팔레트 craftType — 대바늘/코바늘 라이브러리 토글
/// (사각 도안의 데이터 모델은 유지: CellData.symbolId는 String, 양쪽 ID 자동 수용)
enum CraftType { knit, crochet }

extension CraftTypeLabel on CraftType {
  String get labelKo => this == CraftType.knit ? '대바늘' : '코바늘';
  String get labelEn => this == CraftType.knit ? 'Knit' : 'Crochet';
  String get badge => this == CraftType.knit ? 'K' : 'C';
}


class ChartToolbar extends StatefulWidget {
  final ChartTool activeTool;
  final Color activeColor;
  final String? activeSymbolId;
  final bool canUndo;
  final bool canRedo;
  final DrawLayer activeLayer;
  final VoidCallback onNarrative;
  final ValueChanged<ChartTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onSymbolChanged;
  final ValueChanged<DrawLayer> onLayerChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback? onFitScreen;
  final VoidCallback? onGridResize;

  const ChartToolbar({
    super.key,
    required this.activeTool,
    required this.activeColor,
    this.activeSymbolId,
    required this.canUndo,
    required this.canRedo,
    required this.activeLayer,
    required this.onNarrative,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onSymbolChanged,
    required this.onLayerChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExport,
    this.onFitScreen,
    this.onGridResize,
  });

  @override
  State<ChartToolbar> createState() => _ChartToolbarState();
}

class _ChartToolbarState extends State<ChartToolbar> {
  // craftType별 카테고리 선택 상태 (전환 시 각자 마지막 선택 기억)
  CraftType _craftType = CraftType.knit;
  SymbolCategory _selectedKnitCategory = SymbolCategory.basic;
  CrochetCategory _selectedCrochetCategory = CrochetCategory.basic;
  final _topBarScrollCtrl = ScrollController();

  /// #680 — 팔레트(색상/심볼) 펼침 토글. 기본 펼침.
  /// 접으면 도구 행만 표시 → 그리드 비율 ↑ (기능은 보존, 사용자가 펼치면 다시 표시).
  bool _panelExpanded = true;

  @override
  void dispose() {
    _topBarScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(top: BorderSide(color: C.bd, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopBar(
              activeTool: widget.activeTool,
              canUndo: widget.canUndo,
              canRedo: widget.canRedo,
              onNarrative: widget.onNarrative,
              onToolChanged: widget.onToolChanged,
              onUndo: widget.onUndo,
              onRedo: widget.onRedo,
              onClear: widget.onClear,
              onExport: widget.onExport,
              onFitScreen: widget.onFitScreen,
              onGridResize: widget.onGridResize,
              scrollController: _topBarScrollCtrl,
              // #680 — 팔레트 토글 (그리드 영역 확보).
              panelExpanded: _panelExpanded,
              onTogglePanel: () =>
                  setState(() => _panelExpanded = !_panelExpanded),
            ),
            // #680 — 팔레트는 토글 ON 시에만 표시 (기능 보존, 비율만 조정).
            if (_panelExpanded) ...[
              const Divider(height: 1),
              _UnifiedPanel(
                activeLayer: widget.activeLayer,
                activeColor: widget.activeColor,
                activeSymbolId: widget.activeSymbolId,
                craftType: _craftType,
                selectedKnitCategory: _selectedKnitCategory,
                selectedCrochetCategory: _selectedCrochetCategory,
                onLayerChanged: widget.onLayerChanged,
                onCraftTypeChanged: (c) => setState(() => _craftType = c),
                onKnitCategoryChanged: (cat) =>
                    setState(() => _selectedKnitCategory = cat),
                onCrochetCategoryChanged: (cat) =>
                    setState(() => _selectedCrochetCategory = cat),
                onColorChanged: widget.onColorChanged,
                onSymbolChanged: widget.onSymbolChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final ChartTool activeTool;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onNarrative;
  final ValueChanged<ChartTool> onToolChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback? onFitScreen;
  final VoidCallback? onGridResize;
  final ScrollController? scrollController;
  // #680 — 팔레트 토글 (그리드 영역 확보).
  final bool panelExpanded;
  final VoidCallback? onTogglePanel;

  const _TopBar({
    required this.activeTool,
    required this.canUndo,
    required this.canRedo,
    required this.onNarrative,
    required this.onToolChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExport,
    this.onFitScreen,
    this.onGridResize,
    this.scrollController,
    this.panelExpanded = true,
    this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) {
    // 1단: 그리기 도구 + 액션 버튼 통합
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolBtn(icon: Icons.edit_rounded, active: activeTool == ChartTool.draw, onTap: () => onToolChanged(ChartTool.draw)),
          _ToolBtn(icon: Icons.brush_rounded, active: activeTool == ChartTool.brush, onTap: () => onToolChanged(ChartTool.brush)),
          _ToolBtn(icon: Icons.format_color_fill_rounded, active: activeTool == ChartTool.fill, onTap: () => onToolChanged(ChartTool.fill)),
          _ToolBtn(icon: Icons.cleaning_services_rounded, active: activeTool == ChartTool.erase, onTap: () => onToolChanged(ChartTool.erase)),
          _ToolBtn(icon: Icons.pan_tool_rounded, active: activeTool == ChartTool.move, onTap: () => onToolChanged(ChartTool.move)),
          const VerticalDivider(width: 14, thickness: 1, indent: 6, endIndent: 6),
          _IconBtn(
            icon: Icons.article_outlined,
            enabled: true,
            onTap: onNarrative,
            tooltip: '서술형 도안',
          ),
          if (onFitScreen != null)
            _IconBtn(icon: Icons.fit_screen_rounded, enabled: true, onTap: onFitScreen!),
          if (onGridResize != null)
            _IconBtn(icon: Icons.grid_on_rounded, enabled: true, onTap: onGridResize!, tooltip: '그리드 크기'),
          _IconBtn(icon: Icons.undo_rounded, enabled: canUndo, onTap: onUndo),
          _IconBtn(icon: Icons.redo_rounded, enabled: canRedo, onTap: onRedo),
          _IconBtn(icon: Icons.ios_share_rounded, enabled: true, onTap: onExport),
          _IconBtn(icon: Icons.delete_outline_rounded, enabled: true, onTap: onClear, color: Colors.red.shade300),
          // #680 — 팔레트 펼치기/접기 토글 (그리드 영역 확보).
          if (onTogglePanel != null)
            _IconBtn(
              icon: panelExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              enabled: true,
              onTap: onTogglePanel!,
              tooltip: panelExpanded ? '팔레트 접기' : '팔레트 펼치기',
            ),
        ],
      ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? C.lv.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: C.lv.withValues(alpha: 0.5)) : null,
        ),
        child: Icon(icon, size: 18, color: active ? C.lvD : C.tx2),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  const _IconBtn({required this.icon, required this.enabled, required this.onTap, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: enabled ? (color ?? C.tx2) : C.mu,
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
    );
  }
}

class _ColorPanel extends StatelessWidget {
  final Color activeColor;
  final ValueChanged<Color> onColorChanged;

  static const List<Color> _defaultColors = [
    Colors.white,
    Colors.black,
    Color(0xFFE53935),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF9E9E9E),
  ];

  const _ColorPanel({required this.activeColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          for (final color in _defaultColors)
            _ColorSwatch(
              color: color,
              active: activeColor.toARGB32() == color.toARGB32(),
              onTap: () => onColorChanged(color),
            ),
          const SizedBox(width: 6),
          _CustomColorBtn(onColorChanged: onColorChanged),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ColorSwatch({required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? C.lv : Colors.grey.shade300,
            width: active ? 2.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: C.lv.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }
}

class _CustomColorBtn extends StatelessWidget {
  final ValueChanged<Color> onColorChanged;

  const _CustomColorBtn({required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.add, size: 16, color: Colors.white),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color pickedColor = Colors.purple;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('색상 선택'),
        content: SizedBox(
          width: 280,
          child: _SimpleColorPicker(
            initialColor: pickedColor,
            onColorChanged: (c) => pickedColor = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.pop(ctx);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
}

class _SimpleColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _SimpleColorPicker({required this.initialColor, required this.onColorChanged});

  @override
  State<_SimpleColorPicker> createState() => _SimpleColorPickerState();
}

class _SimpleColorPickerState extends State<_SimpleColorPicker> {
  late double _hue;
  late double _sat;
  late double _val;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: _currentColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 12),
        _label('색조 (Hue)'),
        Slider(
          value: _hue,
          min: 0,
          max: 360,
          onChanged: (v) {
            setState(() => _hue = v);
            widget.onColorChanged(_currentColor);
          },
        ),
        _label('채도 (Saturation)'),
        Slider(
          value: _sat,
          onChanged: (v) {
            setState(() => _sat = v);
            widget.onColorChanged(_currentColor);
          },
        ),
        _label('명도 (Value)'),
        Slider(
          value: _val,
          onChanged: (v) {
            setState(() => _val = v);
            widget.onColorChanged(_currentColor);
          },
        ),
      ],
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      );
}

class _SymbolPanel extends ConsumerWidget {
  final CraftType craftType;
  final SymbolCategory selectedKnitCategory;
  final CrochetCategory selectedCrochetCategory;
  final String? activeSymbolId;
  final ValueChanged<CraftType> onCraftTypeChanged;
  final ValueChanged<SymbolCategory> onKnitCategoryChanged;
  final ValueChanged<CrochetCategory> onCrochetCategoryChanged;
  final ValueChanged<String> onSymbolChanged;

  const _SymbolPanel({
    required this.craftType,
    required this.selectedKnitCategory,
    required this.selectedCrochetCategory,
    required this.activeSymbolId,
    required this.onCraftTypeChanged,
    required this.onKnitCategoryChanged,
    required this.onCrochetCategoryChanged,
    required this.onSymbolChanged,
  });

  void _openExpanded(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.gx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        snap: true,
        snapSizes: const [0.55, 0.92],
        builder: (_, scrollCtrl) => _ExpandedSymbolSheet(
          initialCraftType: craftType,
          initialKnitCategory: selectedKnitCategory,
          initialCrochetCategory: selectedCrochetCategory,
          activeSymbolId: activeSymbolId,
          onSymbolChanged: (id) {
            onSymbolChanged(id);
            Navigator.pop(ctx);
          },
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 드래그 핸들 ──────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openExpanded(context),
          onVerticalDragUpdate: (d) {
            if (d.delta.dy < -4) _openExpanded(context);
          },
          child: SizedBox(
            height: 40,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: C.bd2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        // ── craftType 토글 (대바늘/코바늘) ──────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              _CraftTypeChip(
                craft: CraftType.knit,
                active: craftType == CraftType.knit,
                onTap: () => onCraftTypeChanged(CraftType.knit),
              ),
              const SizedBox(width: 6),
              _CraftTypeChip(
                craft: CraftType.crochet,
                active: craftType == CraftType.crochet,
                onTap: () => onCraftTypeChanged(CraftType.crochet),
              ),
            ],
          ),
        ),
        // ── 카테고리 탭 + 심볼 가로 스크롤 ──────────────────
        if (craftType == CraftType.knit)
          _KnitSymbolRow(
            selectedCategory: selectedKnitCategory,
            activeSymbolId: activeSymbolId,
            onCategoryChanged: onKnitCategoryChanged,
            onSymbolChanged: onSymbolChanged,
          )
        else
          _CrochetSymbolRow(
            selectedCategory: selectedCrochetCategory,
            activeSymbolId: activeSymbolId,
            onCategoryChanged: onCrochetCategoryChanged,
            onSymbolChanged: onSymbolChanged,
          ),
      ],
    );
  }
}

/// 대바늘 카테고리 탭 + 심볼 가로 스크롤 (기존 동작 그대로 — Firestore/정적 폴백 유지)
class _KnitSymbolRow extends ConsumerWidget {
  final SymbolCategory selectedCategory;
  final String? activeSymbolId;
  final ValueChanged<SymbolCategory> onCategoryChanged;
  final ValueChanged<String> onSymbolChanged;

  const _KnitSymbolRow({
    required this.selectedCategory,
    required this.activeSymbolId,
    required this.onCategoryChanged,
    required this.onSymbolChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntries = ref.watch(knitSymbolsProvider).valueOrNull ?? [];
    // Firestore 심볼이 없으면 정적 라이브러리 폴백
    final useStatic = allEntries.isEmpty;

    // basic(전체) 탭: 모든 심볼, 나머지: 카테고리 필터
    final firestoreSymbols = useStatic
        ? <KnitSymbolEntry>[]
        : (selectedCategory == SymbolCategory.basic
            ? allEntries
            : allEntries.where((e) => e.symbolCategory == selectedCategory).toList());
    final staticSymbols = !useStatic
        ? <KnitSymbol>[]
        : (selectedCategory == SymbolCategory.basic
            ? KnitSymbolLibrary.all
            : KnitSymbolLibrary.byCategory(selectedCategory));

    final hasSymbols = useStatic ? staticSymbols.isNotEmpty : firestoreSymbols.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            children: [
              for (final cat in SymbolCategory.values)
                _CategoryTab(
                  label: _knitCatLabel(cat),
                  active: selectedCategory == cat,
                  onTap: () => onCategoryChanged(cat),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 68,
          child: !hasSymbols
              ? Center(
                  child: Text('더 많은 심볼이 계속 추가됩니다.', style: TextStyle(fontSize: 11, color: C.tx2)),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: useStatic
                      ? [
                          for (final s in staticSymbols)
                            _StaticSymbolCell(
                              symbol: s,
                              active: activeSymbolId == s.id,
                              onTap: () => onSymbolChanged(s.id),
                            ),
                        ]
                      : [
                          for (final e in firestoreSymbols)
                            _SymbolCell(
                              entry: e,
                              active: activeSymbolId == e.symbolId,
                              onTap: () => onSymbolChanged(e.symbolId),
                            ),
                        ],
                ),
        ),
      ],
    );
  }
}

/// 코바늘 카테고리 탭 + 심볼 가로 스크롤 (CrochetSymbolLibrary 직접 사용)
class _CrochetSymbolRow extends StatelessWidget {
  final CrochetCategory selectedCategory;
  final String? activeSymbolId;
  final ValueChanged<CrochetCategory> onCategoryChanged;
  final ValueChanged<String> onSymbolChanged;

  const _CrochetSymbolRow({
    required this.selectedCategory,
    required this.activeSymbolId,
    required this.onCategoryChanged,
    required this.onSymbolChanged,
  });

  @override
  Widget build(BuildContext context) {
    final symbols = CrochetSymbolLibrary.byCategory(selectedCategory);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            children: [
              for (final cat in CrochetCategory.values)
                _CategoryTab(
                  label: CrochetSymbolLibrary.categoryLabelKo(cat),
                  active: selectedCategory == cat,
                  onTap: () => onCategoryChanged(cat),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 68,
          child: symbols.isEmpty
              ? Center(
                  child: Text('해당 카테고리에 심볼이 없습니다.', style: TextStyle(fontSize: 11, color: C.tx2)),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: [
                    for (final s in symbols)
                      _CrochetSymbolCell(
                        symbol: s,
                        active: activeSymbolId == s.id,
                        onTap: () => onSymbolChanged(s.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _knitCatLabel(SymbolCategory cat) {
  switch (cat) {
    case SymbolCategory.basic:    return '전체';
    case SymbolCategory.decrease: return '줄이기';
    case SymbolCategory.increase: return '늘리기';
    case SymbolCategory.cable:    return '케이블';
    case SymbolCategory.special:  return '특수';
    case SymbolCategory.lace:     return '레이스';
  }
}

/// 대바늘/코바늘 토글 칩 — 표준 칩 스타일
class _CraftTypeChip extends StatelessWidget {
  final CraftType craft;
  final bool active;
  final VoidCallback onTap;

  const _CraftTypeChip({required this.craft, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: 0.22) : C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                craft.badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : C.lvD,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              craft.labelKo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : C.lvD,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 코바늘 심볼 셀 — Firebase Storage SVG (network) 또는 약어 텍스트 폴백
class _CrochetSymbolCell extends StatelessWidget {
  final CrochetSymbol symbol;
  final bool active;
  final VoidCallback onTap;

  const _CrochetSymbolCell({required this.symbol, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = symbol.abbreviation;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${symbol.labelKo} ($label)',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? C.lv : Colors.grey.shade300,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 코바늘은 직접 firebaseUrl 사용 — Firestore 매핑 충돌 회피.
              if (symbol.hasSvg)
                SvgPicture.network(
                  symbol.firebaseUrl,
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => Text(
                    label.length > 4 ? label.substring(0, 4) : label,
                    style: TextStyle(fontSize: 9, color: C.tx2, fontWeight: FontWeight.w600),
                  ),
                )
              else
                Text(
                  label.length > 5 ? label.substring(0, 5) : label,
                  style: TextStyle(fontSize: 11, color: C.tx, fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 3),
              Text(
                label.length > 6 ? label.substring(0, 6) : label,
                style: TextStyle(fontSize: 8, color: C.tx2, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 확장 기호 바텀시트 ──────────────────────────────────────────────
class _ExpandedSymbolSheet extends ConsumerStatefulWidget {
  final CraftType initialCraftType;
  final SymbolCategory initialKnitCategory;
  final CrochetCategory initialCrochetCategory;
  final String? activeSymbolId;
  final ValueChanged<String> onSymbolChanged;
  final ScrollController scrollController;

  const _ExpandedSymbolSheet({
    required this.initialCraftType,
    required this.initialKnitCategory,
    required this.initialCrochetCategory,
    required this.activeSymbolId,
    required this.onSymbolChanged,
    required this.scrollController,
  });

  @override
  ConsumerState<_ExpandedSymbolSheet> createState() => _ExpandedSymbolSheetState();
}

class _ExpandedSymbolSheetState extends ConsumerState<_ExpandedSymbolSheet> {
  late CraftType _craft;
  late SymbolCategory _knitCat;
  late CrochetCategory _crochetCat;

  @override
  void initState() {
    super.initState();
    _craft = widget.initialCraftType;
    _knitCat = widget.initialKnitCategory;
    _crochetCat = widget.initialCrochetCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 드래그 인디케이터
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: C.bd2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // craftType 토글
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              _CraftTypeChip(
                craft: CraftType.knit,
                active: _craft == CraftType.knit,
                onTap: () => setState(() => _craft = CraftType.knit),
              ),
              const SizedBox(width: 6),
              _CraftTypeChip(
                craft: CraftType.crochet,
                active: _craft == CraftType.crochet,
                onTap: () => setState(() => _craft = CraftType.crochet),
              ),
            ],
          ),
        ),
        // 카테고리 탭
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            children: _craft == CraftType.knit
                ? [
                    for (final cat in SymbolCategory.values)
                      _CategoryTab(
                        label: _knitCatLabel(cat),
                        active: _knitCat == cat,
                        onTap: () => setState(() => _knitCat = cat),
                      ),
                  ]
                : [
                    for (final cat in CrochetCategory.values)
                      _CategoryTab(
                        label: CrochetSymbolLibrary.categoryLabelKo(cat),
                        active: _crochetCat == cat,
                        onTap: () => setState(() => _crochetCat = cat),
                      ),
                  ],
          ),
        ),
        const Divider(height: 1),
        // 기호 그리드
        Expanded(
          child: _craft == CraftType.knit
              ? _buildKnitGrid()
              : _buildCrochetGrid(),
        ),
      ],
    );
  }

  Widget _buildKnitGrid() {
    final allEntries = ref.watch(knitSymbolsProvider).valueOrNull ?? [];
    final useStatic = allEntries.isEmpty;

    final firestoreSymbols = useStatic
        ? <KnitSymbolEntry>[]
        : (_knitCat == SymbolCategory.basic
            ? allEntries
            : allEntries.where((e) => e.symbolCategory == _knitCat).toList());
    final staticSymbols = !useStatic
        ? <KnitSymbol>[]
        : (_knitCat == SymbolCategory.basic
            ? KnitSymbolLibrary.all
            : KnitSymbolLibrary.byCategory(_knitCat));

    final count = useStatic ? staticSymbols.length : firestoreSymbols.length;

    if (count == 0) {
      return Center(
        child: Text('더 많은 심볼이 계속 추가됩니다.', style: TextStyle(fontSize: 13, color: C.tx2)),
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (_, i) {
        if (useStatic) {
          final s = staticSymbols[i];
          return _StaticSymbolCell(
            symbol: s,
            active: widget.activeSymbolId == s.id,
            onTap: () => widget.onSymbolChanged(s.id),
          );
        }
        final e = firestoreSymbols[i];
        return _SymbolCell(
          entry: e,
          active: widget.activeSymbolId == e.symbolId,
          onTap: () => widget.onSymbolChanged(e.symbolId),
        );
      },
    );
  }

  Widget _buildCrochetGrid() {
    final symbols = CrochetSymbolLibrary.byCategory(_crochetCat);

    if (symbols.isEmpty) {
      return Center(
        child: Text('해당 카테고리에 심볼이 없습니다.', style: TextStyle(fontSize: 13, color: C.tx2)),
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: symbols.length,
      itemBuilder: (_, i) {
        final s = symbols[i];
        return _CrochetSymbolCell(
          symbol: s,
          active: widget.activeSymbolId == s.id,
          onTap: () => widget.onSymbolChanged(s.id),
        );
      },
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : C.tx2,
          ),
        ),
      ),
    );
  }
}

// ── 통합 패널 (도안 모드 — 색상+기호 레이어 서브토글) ─────────────────────────
class _UnifiedPanel extends StatelessWidget {
  final DrawLayer activeLayer;
  final Color activeColor;
  final String? activeSymbolId;
  final CraftType craftType;
  final SymbolCategory selectedKnitCategory;
  final CrochetCategory selectedCrochetCategory;
  final ValueChanged<DrawLayer> onLayerChanged;
  final ValueChanged<CraftType> onCraftTypeChanged;
  final ValueChanged<SymbolCategory> onKnitCategoryChanged;
  final ValueChanged<CrochetCategory> onCrochetCategoryChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onSymbolChanged;

  const _UnifiedPanel({
    required this.activeLayer,
    required this.activeColor,
    required this.activeSymbolId,
    required this.craftType,
    required this.selectedKnitCategory,
    required this.selectedCrochetCategory,
    required this.onLayerChanged,
    required this.onCraftTypeChanged,
    required this.onKnitCategoryChanged,
    required this.onCrochetCategoryChanged,
    required this.onColorChanged,
    required this.onSymbolChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 색상/기호 탭 삭제 — 색상 팔레트 항상 고정 표시 + 기호 패널 항상 표시
    // craftType 토글 (대바늘/코바늘) → 카테고리 탭 → 심볼 가로 스크롤
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorPanel(activeColor: activeColor, onColorChanged: onColorChanged),
        const Divider(height: 1),
        _SymbolPanel(
          craftType: craftType,
          selectedKnitCategory: selectedKnitCategory,
          selectedCrochetCategory: selectedCrochetCategory,
          activeSymbolId: activeSymbolId,
          onCraftTypeChanged: onCraftTypeChanged,
          onKnitCategoryChanged: onKnitCategoryChanged,
          onCrochetCategoryChanged: onCrochetCategoryChanged,
          onSymbolChanged: onSymbolChanged,
        ),
      ],
    );
  }
}

/// 정적 라이브러리 기반 심볼 셀 — Firestore 없을 때 폴백 (유니코드 표시)
class _StaticSymbolCell extends StatelessWidget {
  final KnitSymbol symbol;
  final bool active;
  final VoidCallback onTap;

  const _StaticSymbolCell({required this.symbol, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${symbol.name} (${symbol.abbr})',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? C.lv : Colors.grey.shade300,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(symbol.unicode, style: TextStyle(fontSize: 16, color: C.tx, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                symbol.abbr.length > 6 ? symbol.abbr.substring(0, 6) : symbol.abbr,
                style: TextStyle(fontSize: 8, color: C.tx2, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// knit_symbols 컬렉션 기반 심볼 셀 — Firebase Storage SVG 표시
class _SymbolCell extends StatelessWidget {
  final KnitSymbolEntry entry;
  final bool active;
  final VoidCallback onTap;

  const _SymbolCell({
    required this.entry,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = entry.abbreviation.isNotEmpty ? entry.abbreviation : entry.name;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${entry.name} ($label)',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? C.lv : Colors.grey.shade300,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // #672 — 단일 소스 (MoriSymbolView)
              MoriSymbolView(
                symbolId: entry.symbolId,
                size: 22,
                fallbackText: label,
              ),
              const SizedBox(height: 3),
              Text(
                label.length > 6 ? label.substring(0, 6) : label,
                style: TextStyle(fontSize: 8, color: C.tx2, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
