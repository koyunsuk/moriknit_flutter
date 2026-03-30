import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';
import 'widgets/chart_canvas.dart';
import 'widgets/chart_toolbar.dart';

class PatternEditorScreen extends ConsumerStatefulWidget {
  final String? patternId;
  const PatternEditorScreen({super.key, this.patternId});

  @override
  ConsumerState<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends ConsumerState<PatternEditorScreen> {
  PatternChart _chart = PatternChart.empty(rows: 30, cols: 20, mode: ChartMode.color);
  bool _loading = true;

  ChartTool _tool = ChartTool.draw;
  Color _activeColor = Colors.black;
  String? _activeSymbolId;

  final List<PatternChart> _undoStack = [];
  final List<PatternChart> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.patternId != null && widget.patternId!.isNotEmpty) {
      final repo = ref.read(patternRepositoryProvider);
      final loaded = await repo.get(widget.patternId!);
      if (loaded != null && mounted) {
        setState(() {
          _chart = loaded;
          _loading = false;
        });
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onChartChanged(PatternChart next) {
    setState(() {
      _undoStack.add(_chart);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
      _chart = next;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_chart);
      _chart = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_chart);
      _chart = _redoStack.removeLast();
    });
  }

  void _clear() {
    _onChartChanged(PatternChart.empty(
      id: _chart.id,
      title: _chart.title,
      rows: _chart.rows,
      cols: _chart.cols,
      mode: _chart.mode,
    ));
  }

  void _onModeChanged(ChartMode mode) {
    setState(() {
      _chart = PatternChart(
        id: _chart.id,
        title: _chart.title,
        rows: _chart.rows,
        cols: _chart.cols,
        mode: mode,
        grid: _chart.grid,
      );
    });
  }

  Future<void> _save() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          final saved = await ref.read(patternRepositoryProvider).save(_chart);
          if (mounted) setState(() => _chart = saved);
        },
      );
      if (mounted) showSavedSnackBar(context, message: isKorean ? '저장되었습니다.' : 'Saved.');
    } catch (_) {
      if (mounted) showSaveErrorSnackBar(context, message: isKorean ? '저장에 실패했습니다.' : 'Failed to save.');
    }
  }

  Future<void> _editTitle() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final ctrl = TextEditingController(text: _chart.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '도안 제목' : 'Pattern title', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isKorean ? '제목을 입력하세요' : 'Enter title'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isKorean ? '확인' : 'OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() {
        _chart = PatternChart(
          id: _chart.id,
          title: result,
          rows: _chart.rows,
          cols: _chart.cols,
          mode: _chart.mode,
          grid: _chart.grid,
        );
      });
    }
  }

  Future<void> _editGridSize() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    int rows = _chart.rows;
    int cols = _chart.cols;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isKorean ? '그리드 크기' : 'Grid size', style: T.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isKorean ? '* 기존 내용은 유지됩니다.' : '* Existing cells are preserved.', style: T.caption.copyWith(color: C.mu)),
              const SizedBox(height: 16),
              Row(children: [
                Text(isKorean ? '행 (Row):' : 'Rows:', style: T.body),
                const Spacer(),
                IconButton(icon: const Icon(Icons.remove), onPressed: rows > 5 ? () => setS(() => rows--) : null),
                SizedBox(width: 40, child: Text('$rows', textAlign: TextAlign.center, style: T.bodyBold)),
                IconButton(icon: const Icon(Icons.add), onPressed: rows < 100 ? () => setS(() => rows++) : null),
              ]),
              Row(children: [
                Text(isKorean ? '열 (Col):' : 'Cols:', style: T.body),
                const Spacer(),
                IconButton(icon: const Icon(Icons.remove), onPressed: cols > 5 ? () => setS(() => cols--) : null),
                SizedBox(width: 40, child: Text('$cols', textAlign: TextAlign.center, style: T.bodyBold)),
                IconButton(icon: const Icon(Icons.add), onPressed: cols < 100 ? () => setS(() => cols++) : null),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _onChartChanged(_chart.resize(rows, cols));
              },
              child: Text(isKorean ? '적용' : 'Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    if (_loading) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.lv)),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _editTitle,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _chart.title,
                              style: T.h2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_rounded, size: 16, color: C.mu),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isKorean ? '그리드 크기' : 'Grid size',
                    icon: Icon(Icons.grid_on_rounded, color: C.mu),
                    onPressed: _editGridSize,
                  ),
                  IconButton(
                    tooltip: isKorean ? '저장' : 'Save',
                    icon: Icon(Icons.save_rounded, color: C.lvD),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: ChartCanvas(
                  chart: _chart,
                  tool: _tool,
                  activeColor: _activeColor,
                  activeSymbolId: _activeSymbolId,
                  onChartChanged: _onChartChanged,
                ),
              ),
            ),
            ChartToolbar(
              mode: _chart.mode,
              activeTool: _tool,
              activeColor: _activeColor,
              activeSymbolId: _activeSymbolId,
              canUndo: _undoStack.isNotEmpty,
              canRedo: _redoStack.isNotEmpty,
              onModeChanged: _onModeChanged,
              onToolChanged: (t) => setState(() => _tool = t),
              onColorChanged: (c) => setState(() => _activeColor = c),
              onSymbolChanged: (id) => setState(() => _activeSymbolId = id),
              onUndo: _undo,
              onRedo: _redo,
              onClear: _clear,
              onExport: _save,
            ),
          ],
        ),
      ),
    );
  }
}
