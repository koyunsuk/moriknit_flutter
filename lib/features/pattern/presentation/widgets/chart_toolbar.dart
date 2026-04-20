import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/knit_symbol_entry.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';
import 'chart_canvas.dart' show DrawLayer;
import 'chart_canvas.dart';


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
  SymbolCategory _selectedCategory = SymbolCategory.basic;
  final _topBarScrollCtrl = ScrollController();

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
            ),
            const Divider(height: 1),
            _UnifiedPanel(
              activeLayer: widget.activeLayer,
              activeColor: widget.activeColor,
              activeSymbolId: widget.activeSymbolId,
              selectedCategory: _selectedCategory,
              onLayerChanged: widget.onLayerChanged,
              onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
              onColorChanged: widget.onColorChanged,
              onSymbolChanged: widget.onSymbolChanged,
            ),
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
  final SymbolCategory selectedCategory;
  final String? activeSymbolId;
  final ValueChanged<SymbolCategory> onCategoryChanged;
  final ValueChanged<String> onSymbolChanged;

  const _SymbolPanel({
    required this.selectedCategory,
    required this.activeSymbolId,
    required this.onCategoryChanged,
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
          initialCategory: selectedCategory,
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
        // ── 카테고리 탭 ─────────────────────────────────────
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            children: [
              for (final cat in SymbolCategory.values)
                _CategoryTab(
                  label: _catLabel(cat),
                  active: selectedCategory == cat,
                  onTap: () => onCategoryChanged(cat),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 기호 가로 스크롤 ────────────────────────────────
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

  String _catLabel(SymbolCategory cat) {
    switch (cat) {
      case SymbolCategory.basic:    return '전체';
      case SymbolCategory.decrease: return '줄이기';
      case SymbolCategory.increase: return '늘리기';
      case SymbolCategory.cable:    return '케이블';
      case SymbolCategory.special:  return '특수';
      case SymbolCategory.lace:     return '레이스';
    }
  }
}

// ── 확장 기호 바텀시트 ──────────────────────────────────────────────
class _ExpandedSymbolSheet extends ConsumerStatefulWidget {
  final SymbolCategory initialCategory;
  final String? activeSymbolId;
  final ValueChanged<String> onSymbolChanged;
  final ScrollController scrollController;

  const _ExpandedSymbolSheet({
    required this.initialCategory,
    required this.activeSymbolId,
    required this.onSymbolChanged,
    required this.scrollController,
  });

  @override
  ConsumerState<_ExpandedSymbolSheet> createState() => _ExpandedSymbolSheetState();
}

class _ExpandedSymbolSheetState extends ConsumerState<_ExpandedSymbolSheet> {
  late SymbolCategory _cat;

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  String _catLabel(SymbolCategory cat) {
    switch (cat) {
      case SymbolCategory.basic:    return '전체';
      case SymbolCategory.decrease: return '줄이기';
      case SymbolCategory.increase: return '늘리기';
      case SymbolCategory.cable:    return '케이블';
      case SymbolCategory.special:  return '특수';
      case SymbolCategory.lace:     return '레이스';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(knitSymbolsProvider).valueOrNull ?? [];
    final useStatic = allEntries.isEmpty;

    final firestoreSymbols = useStatic
        ? <KnitSymbolEntry>[]
        : (_cat == SymbolCategory.basic
            ? allEntries
            : allEntries.where((e) => e.symbolCategory == _cat).toList());
    final staticSymbols = !useStatic
        ? <KnitSymbol>[]
        : (_cat == SymbolCategory.basic
            ? KnitSymbolLibrary.all
            : KnitSymbolLibrary.byCategory(_cat));

    final count = useStatic ? staticSymbols.length : firestoreSymbols.length;

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
        // 카테고리 탭
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            children: [
              for (final cat in SymbolCategory.values)
                _CategoryTab(
                  label: _catLabel(cat),
                  active: _cat == cat,
                  onTap: () => setState(() => _cat = cat),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 기호 그리드
        Expanded(
          child: count == 0
              ? Center(
                  child: Text('더 많은 심볼이 계속 추가됩니다.', style: TextStyle(fontSize: 13, color: C.tx2)),
                )
              : GridView.builder(
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
                ),
        ),
      ],
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
  final SymbolCategory selectedCategory;
  final ValueChanged<DrawLayer> onLayerChanged;
  final ValueChanged<SymbolCategory> onCategoryChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onSymbolChanged;

  const _UnifiedPanel({
    required this.activeLayer,
    required this.activeColor,
    required this.activeSymbolId,
    required this.selectedCategory,
    required this.onLayerChanged,
    required this.onCategoryChanged,
    required this.onColorChanged,
    required this.onSymbolChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 색상/기호 탭 삭제 — 색상 팔레트 항상 고정 표시 + 기호 패널 항상 표시
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorPanel(activeColor: activeColor, onColorChanged: onColorChanged),
        const Divider(height: 1),
        _SymbolPanel(
          selectedCategory: selectedCategory,
          activeSymbolId: activeSymbolId,
          onCategoryChanged: onCategoryChanged,
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
              SvgPicture.network(
                entry.svgUrl,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => Text(
                  label.length > 4 ? label.substring(0, 4) : label,
                  style: TextStyle(fontSize: 9, color: C.tx2, fontWeight: FontWeight.w600),
                ),
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
