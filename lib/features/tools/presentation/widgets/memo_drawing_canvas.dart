import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// 메모용 그리기 캔버스 풀스크린 모달.
///
/// - 펜 / 지우개 / 색상 5종 / 두께 3단계
/// - 클리어 + 1단계 undo
/// - 저장 시 PNG `Uint8List` 반환 (pop)
class MemoDrawingCanvas extends StatefulWidget {
  const MemoDrawingCanvas({super.key});

  @override
  State<MemoDrawingCanvas> createState() => _MemoDrawingCanvasState();
}

enum _DrawTool { pen, eraser }

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  _Stroke({
    required this.points,
    required this.color,
    required this.width,
    required this.isEraser,
  });
}

class _MemoDrawingCanvasState extends State<MemoDrawingCanvas> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  // 1단계 undo 스냅샷 (마지막 stroke 추가/클리어 이전 상태)
  List<_Stroke>? _undoSnapshot;
  _Stroke? _current;

  _DrawTool _tool = _DrawTool.pen;
  late Color _color;
  double _width = 4;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _color = C.tx;
  }

  List<Color> get _palette => [C.tx, C.lv, C.og, C.lmD, C.pkD];

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = _Stroke(
        points: [d.localPosition],
        color: _color,
        width: _tool == _DrawTool.eraser ? _width * 4 : _width,
        isEraser: _tool == _DrawTool.eraser,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_current == null) return;
    setState(() {
      _current!.points.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_current == null) return;
    setState(() {
      // 새 stroke 추가 직전 상태를 undo 스냅샷으로 보관 (1단계 undo)
      _undoSnapshot = List.of(_strokes);
      _strokes.add(_current!);
      _current = null;
    });
  }

  void _undo() {
    if (_undoSnapshot == null) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(_undoSnapshot!);
      _undoSnapshot = null;
    });
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() {
      _undoSnapshot = List.of(_strokes);
      _strokes.clear();
    });
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _capturePng();
      if (!mounted) return;
      Navigator.pop<Uint8List>(context, bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('그림 저장에 실패했어요. $e')),
      );
    }
  }

  Future<Uint8List> _capturePng() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('PNG 인코딩 실패');
    }
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('그리기', style: T.h3),
        actions: [
          IconButton(
            icon: Icon(Icons.undo_rounded, color: C.tx),
            tooltip: '되돌리기',
            onPressed: _undoSnapshot == null ? null : _undo,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: C.og),
            tooltip: '전체 지우기',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  color: Colors.white,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _StrokePainter(
                          strokes: _strokes,
                          current: _current,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Toolbar(
              tool: _tool,
              color: _color,
              width: _width,
              palette: _palette,
              onToolChanged: (t) => setState(() => _tool = t),
              onColorChanged: (c) => setState(() {
                _color = c;
                _tool = _DrawTool.pen;
              }),
              onWidthChanged: (w) => setState(() => _width = w),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final _DrawTool tool;
  final Color color;
  final double width;
  final List<Color> palette;
  final ValueChanged<_DrawTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  const _Toolbar({
    required this.tool,
    required this.color,
    required this.width,
    required this.palette,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(top: BorderSide(color: C.bd)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 도구
            _ToolIcon(
              icon: Icons.edit_rounded,
              selected: tool == _DrawTool.pen,
              tooltip: '펜',
              onTap: () => onToolChanged(_DrawTool.pen),
            ),
            const SizedBox(width: 6),
            _ToolIcon(
              icon: Icons.cleaning_services_rounded,
              selected: tool == _DrawTool.eraser,
              tooltip: '지우개',
              onTap: () => onToolChanged(_DrawTool.eraser),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 28, color: C.bd),
            const SizedBox(width: 12),
            // 색상
            for (final c in palette) ...[
              _ColorSwatch(
                color: c,
                selected: tool == _DrawTool.pen && color.toARGB32() == c.toARGB32(),
                onTap: () => onColorChanged(c),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 6),
            Container(width: 1, height: 28, color: C.bd),
            const SizedBox(width: 12),
            // 두께 3단계
            for (final w in const [2.0, 4.0, 8.0]) ...[
              _WidthDot(
                width: w,
                selected: width == w,
                onTap: () => onWidthChanged(w),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? C.lv : C.lvL,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : C.lvD,
            size: 20,
          ),
        ),
      ),
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? C.tx : C.bd,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _WidthDot({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? C.lvL : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? C.lv : C.bd,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width * 2,
          height: width * 2,
          decoration: BoxDecoration(
            color: C.tx,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;

  _StrokePainter({required this.strokes, required this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _paintStroke(canvas, s);
    }
    if (current != null) {
      _paintStroke(canvas, current!);
    }
  }

  void _paintStroke(Canvas canvas, _Stroke s) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..color = s.isEraser ? Colors.white : s.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s.width
      ..style = PaintingStyle.stroke
      ..blendMode = s.isEraser ? BlendMode.srcOver : BlendMode.srcOver;

    if (s.points.length == 1) {
      canvas.drawCircle(s.points.first, s.width / 2, Paint()..color = s.isEraser ? Colors.white : s.color);
      return;
    }
    final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
    for (var i = 1; i < s.points.length; i++) {
      path.lineTo(s.points[i].dx, s.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.strokes != strokes || old.current != current;
}
