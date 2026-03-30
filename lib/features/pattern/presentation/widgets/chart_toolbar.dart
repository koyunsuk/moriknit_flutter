import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';

class ChartToolbar extends StatefulWidget {
  final ChartMode mode;
  final ChartTool activeTool;
  final Color activeColor;
  final String? activeSymbolId;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<ChartMode> onModeChanged;
  final ValueChanged<ChartTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onSymbolChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExport;

  const ChartToolbar({
    super.key,
    required this.mode,
    required this.activeTool,
    required this.activeColor,
    this.activeSymbolId,
    required this.canUndo,
    required this.canRedo,
    required this.onModeChanged,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onSymbolChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExport,
  });

  @override
  State<ChartToolbar> createState() => _ChartToolbarState();
}

class _ChartToolbarState extends State<ChartToolbar> {
  SymbolCategory _selectedCategory = SymbolCategory.basic;

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
              mode: widget.mode,
              activeTool: widget.activeTool,
              canUndo: widget.canUndo,
              canRedo: widget.canRedo,
              onModeChanged: widget.onModeChanged,
              onToolChanged: widget.onToolChanged,
              onUndo: widget.onUndo,
              onRedo: widget.onRedo,
              onClear: widget.onClear,
              onExport: widget.onExport,
            ),
            const Divider(height: 1),
            if (widget.mode == ChartMode.color)
              _ColorPanel(
                activeColor: widget.activeColor,
                onColorChanged: widget.onColorChanged,
              )
            else
              _SymbolPanel(
                selectedCategory: _selectedCategory,
                activeSymbolId: widget.activeSymbolId,
                onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
                onSymbolChanged: widget.onSymbolChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final ChartMode mode;
  final ChartTool activeTool;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<ChartMode> onModeChanged;
  final ValueChanged<ChartTool> onToolChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExport;

  static const List<({ChartTool tool, IconData icon})> _tools = [
    (tool: ChartTool.draw,  icon: Icons.edit_rounded),
    (tool: ChartTool.erase, icon: Icons.cleaning_services_rounded),
    (tool: ChartTool.fill,  icon: Icons.format_color_fill_rounded),
    (tool: ChartTool.move,  icon: Icons.pan_tool_rounded),
  ];

  const _TopBar({
    required this.mode,
    required this.activeTool,
    required this.canUndo,
    required this.canRedo,
    required this.onModeChanged,
    required this.onToolChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _ModeToggle(mode: mode, onChanged: onModeChanged),
          const SizedBox(width: 6),
          const VerticalDivider(width: 1, indent: 4, endIndent: 4),
          const SizedBox(width: 6),
          for (final t in _tools)
            _ToolBtn(
              icon: t.icon,
              active: activeTool == t.tool,
              onTap: () => onToolChanged(t.tool),
            ),
          const Spacer(),
          _IconBtn(icon: Icons.undo_rounded, enabled: canUndo, onTap: onUndo),
          _IconBtn(icon: Icons.redo_rounded, enabled: canRedo, onTap: onRedo),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.ios_share_rounded, enabled: true, onTap: onExport),
          _IconBtn(icon: Icons.delete_outline_rounded, enabled: true, onTap: onClear, color: Colors.red.shade300),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final ChartMode mode;
  final ValueChanged<ChartMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.lv.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: '컬러',
            active: mode == ChartMode.color,
            onTap: () => onChanged(ChartMode.color),
          ),
          _Tab(
            label: '기호',
            active: mode == ChartMode.symbol,
            onTap: () => onChanged(ChartMode.symbol),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.lv : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : C.tx2,
          ),
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

  const _IconBtn({required this.icon, required this.enabled, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: enabled ? (color ?? C.tx2) : C.mu,
      onPressed: enabled ? onTap : null,
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
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 3),
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
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 3),
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

class _SymbolPanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final symbols = KnitSymbolLibrary.byCategory(selectedCategory);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              for (final sym in symbols)
                _SymbolCell(
                  symbol: sym,
                  active: activeSymbolId == sym.id,
                  onTap: () => onSymbolChanged(sym.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _catLabel(SymbolCategory cat) {
    switch (cat) {
      case SymbolCategory.basic:    return '기본';
      case SymbolCategory.decrease: return '줄이기';
      case SymbolCategory.increase: return '늘리기';
      case SymbolCategory.cable:    return '케이블';
      case SymbolCategory.special:  return '특수';
      case SymbolCategory.lace:     return '레이스';
    }
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

class _SymbolCell extends StatelessWidget {
  final KnitSymbol symbol;
  final bool active;
  final VoidCallback onTap;

  const _SymbolCell({required this.symbol, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${symbol.name} (${symbol.abbr})',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? C.lv : Colors.grey.shade300,
              width: active ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              symbol.unicode,
              style: TextStyle(
                fontSize: 18,
                color: C.tx,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
