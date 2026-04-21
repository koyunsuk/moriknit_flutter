import 'dart:math' show acos, pi, max;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class MeasureToolScreen extends StatefulWidget {
  const MeasureToolScreen({super.key});

  @override
  State<MeasureToolScreen> createState() => _MeasureToolScreenState();
}

class _MeasureToolScreenState extends State<MeasureToolScreen> {
  _MeasureMode _mode = _MeasureMode.yarn;
  bool _useInch = false;
  Offset _angleHandle1 = const Offset(80, 200);
  Offset _angleHandle2 = const Offset(260, 200);
  Offset _anglePivot = const Offset(170, 200);
  Offset _circleCenter = const Offset(175, 240);
  double _circleRadius = 80.0;

  void _reset() {
    setState(() {
      _angleHandle1 = const Offset(80, 200);
      _angleHandle2 = const Offset(260, 200);
      _anglePivot = const Offset(170, 200);
      _circleCenter = const Offset(175, 240);
      _circleRadius = 80.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('측정 도구', style: T.h3),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: C.mu),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 배경 — 빈 캔버스 (실물을 화면에 대는 용도)
                Positioned.fill(
                  child: Container(color: isDark ? const Color(0xFF1A1A2E) : Colors.white),
                ),
                // 세로 눈금자 (모든 모드 공통)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _VerticalRulerPainter(isDark: isDark),
                    ),
                  ),
                ),
                // 격자 모드
                if (_mode == _MeasureMode.grid)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GridPainter(useInch: _useInch, isDark: isDark),
                      ),
                    ),
                  ),
                // 각도 모드
                if (_mode == _MeasureMode.angle)
                  Positioned.fill(
                    child: _AngleTool(
                      handle1: _angleHandle1,
                      handle2: _angleHandle2,
                      pivot: _anglePivot,
                      onHandle1: (o) => setState(() => _angleHandle1 = o),
                      onHandle2: (o) => setState(() => _angleHandle2 = o),
                      onPivot: (o) => setState(() => _anglePivot = o),
                    ),
                  ),
                // 원 모드
                if (_mode == _MeasureMode.circle)
                  Positioned.fill(
                    child: _CircleTool(
                      center: _circleCenter,
                      radius: _circleRadius,
                      onCenter: (o) => setState(() => _circleCenter = o),
                      onRadius: (r) => setState(() => _circleRadius = r),
                    ),
                  ),
                // 실·바늘 모드
                if (_mode == _MeasureMode.yarn)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _YarnRulerPainter(isDark: isDark),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _MeasureBar(
            mode: _mode,
            useInch: _useInch,
            isDark: isDark,
            onMode: (m) => setState(() => _mode = m),
            onToggleUnit: () => setState(() => _useInch = !_useInch),
          ),
        ],
      ),
    );
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

enum _MeasureMode { grid, angle, circle, yarn }

const _pxPerCm = 160.0 / 2.54;
const _pxPerIn = 160.0;
const _pxPerMm = _pxPerCm / 10.0;
const _green = Color(0xFF32D74B);

final _yarnWeights = [
  (1.0,  'Lace',      Color(0xFFAB47BC)),
  (2.0,  'Fingering', Color(0xFF42A5F5)),
  (2.5,  'Sport',     Color(0xFF26C6DA)),
  (3.0,  'DK',        Color(0xFF66BB6A)),
  (4.0,  'Worsted',   Color(0xFFFFCA28)),
  (4.5,  'Aran',      Color(0xFFFFA726)),
  (6.0,  'Bulky',     Color(0xFFEF5350)),
  (9.0,  'S.Bulky',   Color(0xFF8D6E63)),
];

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final bool useInch;
  final bool isDark;
  const _GridPainter({required this.useInch, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = useInch ? _pxPerIn : _pxPerCm;
    final thinColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFF5C6BC0).withValues(alpha: 0.35);
    final boldColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF5C6BC0).withValues(alpha: 0.70);
    final thin = Paint()..color = thinColor..strokeWidth = 0.8;
    final bold = Paint()..color = boldColor..strokeWidth = 1.4;

    int xi = 0;
    for (double x = 0; x <= size.width; x += unit, xi++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), xi % 5 == 0 ? bold : thin);
      if (xi > 0 && xi % 5 == 0) _label(canvas, '$xi${useInch ? '"' : 'cm'}', Offset(x + 2, 3), boldColor);
    }
    int yi = 0;
    for (double y = 0; y <= size.height; y += unit, yi++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), yi % 5 == 0 ? bold : thin);
      if (yi > 0 && yi % 5 == 0) _label(canvas, '$yi${useInch ? '"' : 'cm'}', Offset(3, y + 2), boldColor);
    }
  }

  void _label(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.useInch != useInch || old.isDark != isDark;
}

// ── Yarn/Needle ruler ─────────────────────────────────────────────────────────

class _YarnRulerPainter extends CustomPainter {
  final bool isDark;
  const _YarnRulerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : Colors.black;
    final bg = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85);
    final cy = size.height / 2;
    const stripH = 56.0;
    const legendH = 28.0;
    final legendY = cy + stripH / 2 + 6;

    canvas.drawRect(Rect.fromLTWH(0, cy - stripH / 2, size.width, stripH), Paint()..color = bg);
    final border = Paint()..color = _green.withValues(alpha: 0.8)..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, cy - stripH / 2), Offset(size.width, cy - stripH / 2), border);
    canvas.drawLine(Offset(0, cy + stripH / 2), Offset(size.width, cy + stripH / 2), border);

    final tickPaint = Paint()..color = base.withValues(alpha: 0.5)..strokeWidth = 0.8;
    final boldTick = Paint()..color = base.withValues(alpha: 0.85)..strokeWidth = 1.5;
    int mm = 0;
    for (double x = 0; x <= size.width; x += _pxPerMm, mm++) {
      final isCm = mm % 10 == 0;
      final is5mm = mm % 5 == 0;
      final h = isCm ? 20.0 : is5mm ? 12.0 : 6.0;
      final p = isCm ? boldTick : tickPaint;
      canvas.drawLine(Offset(x, cy - stripH / 2), Offset(x, cy - stripH / 2 + h), p);
      canvas.drawLine(Offset(x, cy + stripH / 2), Offset(x, cy + stripH / 2 - h), p);
      if (isCm && mm > 0) _drawText(canvas, '${mm ~/ 10}', Offset(x + 2, cy - stripH / 2 + 21), base.withValues(alpha: 0.7), 8);
    }

    for (final (weightMm, _, color) in _yarnWeights) {
      final x = weightMm * _pxPerMm;
      if (x > size.width) break;
      canvas.drawLine(Offset(x, cy - stripH / 2 + 2), Offset(x, cy + stripH / 2 - 2),
          Paint()..color = color.withValues(alpha: 0.6)..strokeWidth = 1.5);
    }

    _drawText(canvas, '← 실·바늘을 여기에 대세요 →',
        Offset(size.width / 2 - 100, cy - 9), base.withValues(alpha: 0.55), 10);

    canvas.drawRect(Rect.fromLTWH(0, legendY, size.width, legendH), Paint()..color = bg);
    double lx = 8;
    for (final (weightMm, name, color) in _yarnWeights) {
      const dotR = 4.0;
      canvas.drawCircle(Offset(lx + dotR, legendY + legendH / 2), dotR, Paint()..color = color);
      final label = '${weightMm % 1 == 0 ? weightMm.toInt() : weightMm}mm $name';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: base.withValues(alpha: 0.75), fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx + dotR * 2 + 3, legendY + (legendH - tp.height) / 2));
      lx += dotR * 2 + tp.width + 10;
      if (lx > size.width - 20) break;
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double sz) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: sz, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_YarnRulerPainter old) => old.isDark != isDark;
}

// ── Vertical ruler ────────────────────────────────────────────────────────────

class _VerticalRulerPainter extends CustomPainter {
  final bool isDark;
  const _VerticalRulerPainter({required this.isDark});
  static const _stripW = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : Colors.black;
    final bg = (isDark ? const Color(0xFF1A1A2E) : Colors.white).withValues(alpha: 0.90);
    final border = Paint()..color = _green.withValues(alpha: 0.75)..strokeWidth = 1.2;
    final tickP = Paint()..color = base.withValues(alpha: 0.55)..strokeWidth = 0.9;
    final boldP = Paint()..color = base.withValues(alpha: 0.85)..strokeWidth = 1.4;

    canvas.drawRect(Rect.fromLTWH(0, 0, _stripW, size.height), Paint()..color = bg);
    canvas.drawLine(const Offset(_stripW, 0), Offset(_stripW, size.height), border);
    _txt(canvas, 'cm', const Offset(6, 6), _green, 10, bold: true);

    int ci = 0;
    for (double y = 0; y <= size.height; y += _pxPerCm, ci++) {
      final isMaj = ci % 5 == 0;
      final tw = isMaj ? 18.0 : ci % 2 == 0 ? 10.0 : 6.0;
      canvas.drawLine(Offset(_stripW - tw, y), Offset(_stripW, y), isMaj ? boldP : tickP);
      if (ci > 0) _txt(canvas, '$ci', Offset(2, y - 8), base.withValues(alpha: isMaj ? 0.85 : 0.55), isMaj ? 9.0 : 8.0);
    }

    final rx = size.width - _stripW;
    canvas.drawRect(Rect.fromLTWH(rx, 0, _stripW, size.height), Paint()..color = bg);
    canvas.drawLine(Offset(rx, 0), Offset(rx, size.height), border);
    _txt(canvas, 'in', Offset(rx + 6, 6), _green, 10, bold: true);

    int ii = 0;
    for (double y = 0; y <= size.height; y += _pxPerIn, ii++) {
      final isMaj = ii % 6 == 0;
      final tw = isMaj ? 18.0 : 10.0;
      canvas.drawLine(Offset(rx, y), Offset(rx + tw, y), isMaj ? boldP : tickP);
      if (ii > 0) _txt(canvas, '$ii"', Offset(rx + tw + 2, y - 8), base.withValues(alpha: isMaj ? 0.85 : 0.55), isMaj ? 9.0 : 8.0);
    }
  }

  void _txt(Canvas canvas, String text, Offset pos, Color color, double sz, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: sz, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_VerticalRulerPainter old) => old.isDark != isDark;
}

// ── Angle tool ────────────────────────────────────────────────────────────────

class _AngleTool extends StatelessWidget {
  final Offset handle1, handle2, pivot;
  final ValueChanged<Offset> onHandle1, onHandle2, onPivot;
  const _AngleTool({required this.handle1, required this.handle2, required this.pivot,
      required this.onHandle1, required this.onHandle2, required this.onPivot});

  double get _deg {
    final v1 = handle1 - pivot;
    final v2 = handle2 - pivot;
    if (v1.distance < 1 || v2.distance < 1) return 0;
    return acos(((v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: IgnorePointer(child: CustomPaint(
      painter: _AnglePainter(handle1: handle1, handle2: handle2, pivot: pivot)))),
    _Handle(pos: pivot, isPivot: true, onDrag: onPivot),
    _Handle(pos: handle1, onDrag: onHandle1),
    _Handle(pos: handle2, onDrag: onHandle2),
    Positioned(left: pivot.dx + 12, top: pivot.dy - 30,
        child: _Label(text: '${_deg.toStringAsFixed(1)}°')),
  ]);
}

class _AnglePainter extends CustomPainter {
  final Offset handle1, handle2, pivot;
  const _AnglePainter({required this.handle1, required this.handle2, required this.pivot});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _green.withValues(alpha: 0.8)..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, handle1, p);
    canvas.drawLine(pivot, handle2, p);
  }

  @override
  bool shouldRepaint(_AnglePainter old) => true;
}

// ── Circle tool ───────────────────────────────────────────────────────────────

class _CircleTool extends StatelessWidget {
  final Offset center;
  final double radius;
  final ValueChanged<Offset> onCenter;
  final ValueChanged<double> onRadius;
  const _CircleTool({required this.center, required this.radius, required this.onCenter, required this.onRadius});

  @override
  Widget build(BuildContext context) {
    final rHandle = Offset(center.dx + radius, center.dy);
    final dCm = (radius * 2) / _pxPerCm;
    return Stack(children: [
      Positioned.fill(child: IgnorePointer(child: CustomPaint(
          painter: _CirclePainter(center: center, radius: radius)))),
      _Handle(pos: center, isPivot: true, onDrag: onCenter),
      _Handle(pos: rHandle, onDrag: (o) => onRadius(max(24.0, (o - center).distance))),
      Positioned(left: center.dx + 8, top: center.dy - 30,
          child: _Label(text: '⌀ ${dCm.toStringAsFixed(1)} cm')),
    ]);
  }
}

class _CirclePainter extends CustomPainter {
  final Offset center;
  final double radius;
  const _CirclePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, radius, Paint()..color = _green.withValues(alpha: 0.7)..strokeWidth = 2.0..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy),
        Paint()..color = _green.withValues(alpha: 0.35)..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(_CirclePainter old) => true;
}

// ── Shared handle & label ─────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  final Offset pos;
  final bool isPivot;
  final ValueChanged<Offset> onDrag;
  const _Handle({required this.pos, this.isPivot = false, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    const sz = 28.0;
    return Positioned(
      left: pos.dx - sz / 2,
      top: pos.dy - sz / 2,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(Offset(pos.dx + d.delta.dx, pos.dy + d.delta.dy)),
        child: Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            color: isPivot ? _green.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: _green, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(isPivot ? Icons.open_with_rounded : Icons.drag_indicator_rounded,
              size: 14, color: isPivot ? Colors.white : _green),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _green, borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

// ── Mode bar ──────────────────────────────────────────────────────────────────

class _MeasureBar extends StatelessWidget {
  final _MeasureMode mode;
  final bool useInch;
  final bool isDark;
  final ValueChanged<_MeasureMode> onMode;
  final VoidCallback onToggleUnit;
  const _MeasureBar({required this.mode, required this.useInch, required this.isDark,
      required this.onMode, required this.onToggleUnit});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A2E) : C.bg;
    final modes = [
      (_MeasureMode.yarn,   Icons.straighten_rounded,           '실·바늘'),
      (_MeasureMode.grid,   Icons.grid_on_rounded,              '격자'),
      (_MeasureMode.angle,  Icons.architecture_rounded,         '각도'),
      (_MeasureMode.circle, Icons.radio_button_unchecked_rounded,'원'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF0F0F1E) : C.gx,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '※ 치수는 기기 화면 특성에 따라 오차가 있을 수 있어 참고용으로만 사용하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : C.mu),
          ),
        ),
        Container(
          height: 56,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final (m, icon, label) in modes) ...[
                GestureDetector(
                  onTap: () => onMode(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: mode == m ? _green.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: mode == m ? _green : Colors.transparent, width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 14, color: mode == m ? _green : (isDark ? Colors.white38 : C.mu)),
                      const SizedBox(width: 3),
                      Text(label, style: TextStyle(
                          fontSize: 11,
                          color: mode == m ? _green : (isDark ? Colors.white38 : C.mu),
                          fontWeight: mode == m ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              if (mode == _MeasureMode.grid)
                GestureDetector(
                  onTap: onToggleUnit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _green, width: 1),
                    ),
                    child: Text(useInch ? 'in' : 'cm',
                        style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
