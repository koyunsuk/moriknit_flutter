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

  // angle
  Offset _angleHandle1 = const Offset(80, 200);
  Offset _angleHandle2 = const Offset(260, 200);
  Offset _anglePivot = const Offset(170, 200);

  // circle
  Offset _circleCenter = const Offset(175, 240);
  double _circleRadius = 80.0;

  // tape (구간 측정)
  Offset _tapePt1 = const Offset(80, 300);
  Offset _tapePt2 = const Offset(260, 300);

  // calibrate (보정)
  Offset _calPt1 = const Offset(60, 300);
  Offset _calPt2 = const Offset(260, 300);
  double _calScale = 1.0;

  // memo (기록)
  final _memos = <String>[];
  final _memoCtrl = TextEditingController();

  // calc (계산기)
  String _calcDisplay = '0';
  double? _calcFirstOp;
  String? _calcOp;
  bool _calcNewInput = true;

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _angleHandle1 = const Offset(80, 200);
      _angleHandle2 = const Offset(260, 200);
      _anglePivot = const Offset(170, 200);
      _circleCenter = const Offset(175, 240);
      _circleRadius = 80.0;
      _tapePt1 = const Offset(80, 300);
      _tapePt2 = const Offset(260, 300);
      _calPt1 = const Offset(60, 300);
      _calPt2 = const Offset(260, 300);
      _calScale = 1.0;
      _calcDisplay = '0';
      _calcFirstOp = null;
      _calcOp = null;
      _calcNewInput = true;
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
                // 배경 — 항상 다크 캔버스
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF1A1A2E)),
                ),
                // 세로 눈금자 (모든 모드 공통)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _VerticalRulerPainter()),
                  ),
                ),
                // 격자 모드
                if (_mode == _MeasureMode.grid)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GridPainter(useInch: _useInch),
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
                  const Positioned.fill(child: _YarnRulerView()),
                // 구간 측정 모드
                if (_mode == _MeasureMode.tape)
                  Positioned.fill(
                    child: _TapeTool(
                      pt1: _tapePt1,
                      pt2: _tapePt2,
                      onPt1: (o) => setState(() => _tapePt1 = o),
                      onPt2: (o) => setState(() => _tapePt2 = o),
                    ),
                  ),
                // 보정 모드
                if (_mode == _MeasureMode.calibrate)
                  Positioned.fill(
                    child: _CalibrateTool(
                      pt1: _calPt1,
                      pt2: _calPt2,
                      scale: _calScale,
                      onPt1: (o) => setState(() => _calPt1 = o),
                      onPt2: (o) => setState(() => _calPt2 = o),
                      onCalibrate: (s) => setState(() => _calScale = s),
                    ),
                  ),
                // 기록 모드
                if (_mode == _MeasureMode.memo)
                  Positioned.fill(
                    child: _MemoOverlay(
                      memos: _memos,
                      ctrl: _memoCtrl,
                      onSave: (s) => setState(() => _memos.insert(0, s)),
                      onDelete: (i) => setState(() => _memos.removeAt(i)),
                    ),
                  ),
                // 계산기 모드
                if (_mode == _MeasureMode.calc)
                  Positioned.fill(
                    child: _CalcOverlay(
                      display: _calcDisplay,
                      firstOp: _calcFirstOp,
                      op: _calcOp,
                      newInput: _calcNewInput,
                      onDisplay: (s) => setState(() => _calcDisplay = s),
                      onFirstOp: (v) => setState(() => _calcFirstOp = v),
                      onOp: (s) => setState(() => _calcOp = s),
                      onNewInput: (b) => setState(() => _calcNewInput = b),
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

enum _MeasureMode { grid, angle, circle, yarn, tape, calibrate, memo, calc }

const _pxPerCm = 160.0 / 2.54;
const _pxPerIn = 160.0;
const _pxPerMm = _pxPerCm / 10.0;

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
  const _GridPainter({required this.useInch});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = useInch ? _pxPerIn : _pxPerCm;
    final thinColor = Colors.white.withValues(alpha: 0.18);
    final boldColor = Colors.white.withValues(alpha: 0.45);
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
  bool shouldRepaint(_GridPainter old) => old.useInch != useInch;
}

// ── Yarn/Needle ruler view ─────────────────────────────────────────────────────

class _YarnRulerView extends StatelessWidget {
  const _YarnRulerView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단: 카드 그리드 (화면 공간 활용)
        Expanded(
          flex: 55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '← 실·바늘을 아래 자에 대세요 →',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                    ),
                    itemCount: _yarnWeights.length,
                    itemBuilder: (_, i) {
                      final (mm, name, color) = _yarnWeights[i];
                      final label = '${mm % 1 == 0 ? mm.toInt() : mm}mm';
                      final circleDia = (mm * 6.0).clamp(10.0, 36.0);
                      return Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(children: [
                          Container(
                            width: circleDia,
                            height: circleDia,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // 하단: mm 눈금자 스트립
        SizedBox(
          height: 72,
          child: CustomPaint(
            size: const Size(double.infinity, 72),
            painter: _YarnStripPainter(),
          ),
        ),
      ],
    );
  }
}

class _YarnStripPainter extends CustomPainter {
  const _YarnStripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const bg = Color(0xFF0D0D1A);
    const stripH = 56.0;
    final top = (size.height - stripH) / 2;

    canvas.drawRect(Rect.fromLTWH(0, top, size.width, stripH), Paint()..color = bg);
    final border = Paint()..color = C.lv.withValues(alpha: 0.8)..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, top), Offset(size.width, top), border);
    canvas.drawLine(Offset(0, top + stripH), Offset(size.width, top + stripH), border);

    final tickP = Paint()..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 0.8;
    final boldP = Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = 1.5;
    int mm = 0;
    for (double x = 48; x <= size.width - 48; x += _pxPerMm, mm++) {
      final isCm = mm % 10 == 0;
      final is5 = mm % 5 == 0;
      final h = isCm ? 20.0 : is5 ? 12.0 : 6.0;
      final p = isCm ? boldP : tickP;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), p);
      canvas.drawLine(Offset(x, top + stripH), Offset(x, top + stripH - h), p);
      if (isCm && mm > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${mm ~/ 10}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, top + 21));
      }
    }

    for (final (weightMm, _, color) in _yarnWeights) {
      final x = 48 + weightMm * _pxPerMm;
      if (x > size.width - 48) break;
      canvas.drawLine(Offset(x, top + 2), Offset(x, top + stripH - 2),
          Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 2.0);
    }
  }

  @override
  bool shouldRepaint(_YarnStripPainter old) => false;
}

// ── Vertical ruler ────────────────────────────────────────────────────────────

class _VerticalRulerPainter extends CustomPainter {
  const _VerticalRulerPainter();
  static const _stripW = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    const base = Colors.white;
    const bg = Color(0xFF1A1A2E);
    final border = Paint()..color = C.lv.withValues(alpha: 0.75)..strokeWidth = 1.2;
    final tickP = Paint()..color = base.withValues(alpha: 0.55)..strokeWidth = 0.9;
    final boldP = Paint()..color = base.withValues(alpha: 0.85)..strokeWidth = 1.4;

    canvas.drawRect(Rect.fromLTWH(0, 0, _stripW, size.height), Paint()..color = bg);
    canvas.drawLine(const Offset(_stripW, 0), Offset(_stripW, size.height), border);
    _txt(canvas, '센티', const Offset(4, 6), C.lv, 9, bold: true);

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
    _txt(canvas, '인치', Offset(rx + 4, 6), C.lv, 9, bold: true);

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
  bool shouldRepaint(_VerticalRulerPainter old) => false;
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
    final p = Paint()..color = C.lv.withValues(alpha: 0.8)..strokeWidth = 2.0..strokeCap = StrokeCap.round;
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
    canvas.drawCircle(center, radius, Paint()..color = C.lv.withValues(alpha: 0.7)..strokeWidth = 2.0..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy),
        Paint()..color = C.lv.withValues(alpha: 0.35)..strokeWidth = 1.0);
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
            color: isPivot ? C.lv.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: C.lv, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(isPivot ? Icons.open_with_rounded : Icons.drag_indicator_rounded,
              size: 14, color: isPivot ? Colors.white : C.lv),
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
      color: C.lv, borderRadius: BorderRadius.circular(12),
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
    final inactive = isDark ? Colors.white38 : C.mu;
    final modes = [
      (_MeasureMode.yarn,      Icons.straighten_rounded,             '실·바늘'),
      (_MeasureMode.grid,      Icons.grid_on_rounded,                '격자'),
      (_MeasureMode.angle,     Icons.architecture_rounded,           '각도'),
      (_MeasureMode.circle,    Icons.radio_button_unchecked_rounded,  '원'),
      (_MeasureMode.tape,      Icons.linear_scale_rounded,           '구간'),
      (_MeasureMode.calibrate, Icons.tune_rounded,                   '보정'),
      (_MeasureMode.memo,      Icons.bookmark_border_rounded,        '기록'),
      (_MeasureMode.calc,      Icons.calculate_outlined,             '계산기'),
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
        SizedBox(
          height: 56,
          child: ColoredBox(
            color: bg,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final (m, icon, label) in modes) ...[
                  GestureDetector(
                    onTap: () => onMode(m),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: mode == m ? C.lv.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: mode == m ? C.lv : Colors.transparent, width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 14, color: mode == m ? C.lv : inactive),
                        const SizedBox(width: 3),
                        Text(label, style: TextStyle(
                            fontSize: 11,
                            color: mode == m ? C.lv : inactive,
                            fontWeight: mode == m ? FontWeight.w700 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                ],
                if (mode == _MeasureMode.grid)
                  GestureDetector(
                    onTap: onToggleUnit,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.lv, width: 1),
                      ),
                      child: Text(
                        useInch ? 'in' : 'cm',
                        style: TextStyle(color: C.lv, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 구간 측정 ─────────────────────────────────────────────────────────────────

class _TapeTool extends StatelessWidget {
  final Offset pt1, pt2;
  final ValueChanged<Offset> onPt1, onPt2;
  const _TapeTool({required this.pt1, required this.pt2, required this.onPt1, required this.onPt2});

  double get _cm => (pt2 - pt1).distance / _pxPerCm;

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: IgnorePointer(child: CustomPaint(
      painter: _TapePainter(pt1: pt1, pt2: pt2)))),
    _Handle(pos: pt1, onDrag: onPt1),
    _Handle(pos: pt2, onDrag: onPt2),
    Positioned(
      left: (pt1.dx + pt2.dx) / 2 - 30,
      top: (pt1.dy + pt2.dy) / 2 - 26,
      child: _Label(text: '${_cm.toStringAsFixed(1)} cm'),
    ),
  ]);
}

class _TapePainter extends CustomPainter {
  final Offset pt1, pt2;
  const _TapePainter({required this.pt1, required this.pt2});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = C.lv.withValues(alpha: 0.85)..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    canvas.drawLine(pt1, pt2, p);
    // 끝단 수직선
    final dir = (pt2 - pt1);
    if (dir.distance < 1) return;
    final norm = Offset(-dir.dy, dir.dx) / dir.distance * 10;
    final endP = Paint()..color = C.lv..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    canvas.drawLine(pt1 - norm, pt1 + norm, endP);
    canvas.drawLine(pt2 - norm, pt2 + norm, endP);
  }

  @override
  bool shouldRepaint(_TapePainter old) => true;
}

// ── 보정 ──────────────────────────────────────────────────────────────────────

class _CalibrateTool extends StatelessWidget {
  final Offset pt1, pt2;
  final double scale;
  final ValueChanged<Offset> onPt1, onPt2;
  final ValueChanged<double> onCalibrate;
  const _CalibrateTool({required this.pt1, required this.pt2, required this.scale,
      required this.onPt1, required this.onPt2, required this.onCalibrate});

  static const _cardWidthMm = 85.6;

  double get _measuredMm => (pt2 - pt1).distance / (_pxPerMm * scale);

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: IgnorePointer(child: CustomPaint(
        painter: _TapePainter(pt1: pt1, pt2: pt2)))),
      _Handle(pos: pt1, onDrag: onPt1),
      _Handle(pos: pt2, onDrag: onPt2),
      Positioned(
        left: 0, right: 0,
        top: 24,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: const Color(0xCC1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.lv.withValues(alpha: 0.4)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '신용카드(85.6mm) 너비에 맞춰 끝점을 조정하세요',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '현재 측정값: ${_measuredMm.toStringAsFixed(1)} mm',
                style: TextStyle(color: C.lv, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  final dist = (pt2 - pt1).distance;
                  if (dist > 10) onCalibrate(dist / (_pxPerMm * _cardWidthMm));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.lv,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('85.6mm로 보정', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              if (scale != 1.0) ...[
                const SizedBox(height: 6),
                Text('보정 배율: ${scale.toStringAsFixed(3)}×', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── 기록 ──────────────────────────────────────────────────────────────────────

class _MemoOverlay extends StatelessWidget {
  final List<String> memos;
  final TextEditingController ctrl;
  final ValueChanged<String> onSave;
  final ValueChanged<int> onDelete;
  const _MemoOverlay({required this.memos, required this.ctrl,
      required this.onSave, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 12, 48, 12),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '측정값 메모 (예: 소매 둘레 38cm)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF2A2A3E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) { onSave(t); ctrl.clear(); }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.lv, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: memos.isEmpty
              ? Center(child: Text('저장된 기록이 없어요.\n측정 후 메모해 두세요.', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)))
              : ListView.separated(
                  itemCount: memos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.bookmark, size: 14, color: C.lv),
                      const SizedBox(width: 8),
                      Expanded(child: Text(memos[i], style: const TextStyle(color: Colors.white, fontSize: 13))),
                      GestureDetector(
                        onTap: () => onDelete(i),
                        child: const Icon(Icons.close, size: 16, color: Colors.white38),
                      ),
                    ]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ── 계산기 ────────────────────────────────────────────────────────────────────

class _CalcOverlay extends StatelessWidget {
  final String display;
  final double? firstOp;
  final String? op;
  final bool newInput;
  final ValueChanged<String> onDisplay;
  final ValueChanged<double?> onFirstOp;
  final ValueChanged<String?> onOp;
  final ValueChanged<bool> onNewInput;
  const _CalcOverlay({required this.display, required this.firstOp, required this.op,
      required this.newInput, required this.onDisplay, required this.onFirstOp,
      required this.onOp, required this.onNewInput});

  void _tap(String key) {
    if (key == 'C') {
      onDisplay('0'); onFirstOp(null); onOp(null); onNewInput(true);
    } else if (key == '±') {
      final v = double.tryParse(display) ?? 0;
      onDisplay(_fmt(-v));
    } else if (key == '%') {
      final v = double.tryParse(display) ?? 0;
      onDisplay(_fmt(v / 100));
    } else if (['+', '−', '×', '÷'].contains(key)) {
      onFirstOp(double.tryParse(display));
      onOp(key);
      onNewInput(true);
    } else if (key == '=') {
      if (firstOp == null || op == null) return;
      final b = double.tryParse(display) ?? 0;
      double result;
      switch (op) {
        case '+': result = firstOp! + b;
        case '−': result = firstOp! - b;
        case '×': result = firstOp! * b;
        case '÷': result = b == 0 ? double.nan : firstOp! / b;
        default: result = b;
      }
      onDisplay(_fmt(result)); onFirstOp(null); onOp(null); onNewInput(true);
    } else if (key == '.') {
      final cur = newInput ? '0' : display;
      if (!cur.contains('.')) { onDisplay('$cur.'); onNewInput(false); }
    } else {
      final cur = (newInput || display == '0') ? key : display + key;
      onDisplay(cur); onNewInput(false);
    }
  }

  String _fmt(double v) {
    if (v.isNaN) return 'Error';
    if (v == v.truncateToDouble() && v.abs() < 1e10) return v.toInt().toString();
    return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['C', '±', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['0', '.', '='],
    ];
    bool isOp(String k) => ['+', '−', '×', '÷', '='].contains(k);
    return Center(
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xEE1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.lv.withValues(alpha: 0.3)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (op != null) Text('${firstOp ?? ''} $op', style: TextStyle(color: C.lv.withValues(alpha: 0.6), fontSize: 12)),
              Text(display, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300)),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                for (final k in row) ...[
                  Expanded(
                    flex: k == '0' ? 2 : 1,
                    child: GestureDetector(
                      onTap: () => _tap(k),
                      child: Container(
                        height: 52,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isOp(k)
                              ? (k == op ? C.lv : C.lv.withValues(alpha: 0.2))
                              : k == 'C' || k == '±' || k == '%'
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(k,
                            style: TextStyle(
                              color: isOp(k) ? Colors.white : Colors.white.withValues(alpha: 0.9),
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            )),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
