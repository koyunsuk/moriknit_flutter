// lib/features/pattern/presentation/widgets/guide_path_painter.dart
//
// 이슈 #668 — 자유 Path 도안 전용 CustomPainter.
//
// path 위에 코바늘/대바늘 셀을 자동 균등 배치 + path 접선 수직 자동 회전.
// 단(row)별 path를 별도 색상으로 그리며, 단 라벨(R1, R2, ...)을 path 시작점에 표시한다.
//
// 사용:
// ```dart
// final cache = ref.watch(svgSymbolCacheProvider);
// CustomPaint(
//   painter: GuidePathPainter(
//     chart: chart,
//     symbolPicture: cache.pictureFor,
//   ),
// );
// ```

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/guide_path_chart.dart';

/// 자유 Path 도안 painter.
class GuidePathPainter extends CustomPainter {
  /// 도안 데이터.
  final GuidePathChart chart;

  /// SvgSymbolCache.pictureFor() 콜백.
  final ui.Picture? Function(String) symbolPicture;

  /// 현재 편집 중인 단 인덱스 (강조 표시).
  final int? activeRowIndex;

  /// 호버 중인 앵커 (path index, anchor index) — Pen/Cut/Trim 모드 미리보기.
  final ({int rowIndex, int anchorIndex})? hoveredAnchor;

  /// 가이드(path 라인) 표시.
  final bool showGuides;

  /// 단 라벨 (R1, R2) 표시.
  final bool showRowLabels;

  /// #668 정밀도 보강 — 백그라운드 점 격자 표시 (스냅 시각 보조).
  final bool showSnapGrid;

  /// 격자 간격 (px). 스냅 함수와 동일 값 사용.
  final double snapGridSpacing;

  /// 단 색상 사이클 (단별 path 색).
  static const List<Color> _kRowColors = [
    Color(0xFF8B7AB8), // 라벤더
    Color(0xFFE8A0C7), // 핑크
    Color(0xFFF4B942), // 골드
    Color(0xFF7BC4A4), // 민트
    Color(0xFF6FA8DC), // 블루
    Color(0xFFC97A4A), // 브라운
  ];

  /// SVG 뷰박스 (모리니트 심볼 24x24 고정).
  static const double _kSvgViewBox = 24.0;

  /// 셀 기본 크기 (px).
  static const double _kDefaultCellSize = 24.0;

  GuidePathPainter({
    required this.chart,
    required this.symbolPicture,
    this.activeRowIndex,
    this.hoveredAnchor,
    this.showGuides = true,
    this.showRowLabels = true,
    this.showSnapGrid = true,
    this.snapGridSpacing = 16.0,
  });

  /// 좌표를 가장 가까운 격자점으로 스냅 (정적 헬퍼 — 에디터 캔버스에서 호출).
  static Offset snapToGrid(Offset point, double spacing) {
    if (spacing <= 0) return point;
    final sx = (point.dx / spacing).round() * spacing;
    final sy = (point.dy / spacing).round() * spacing;
    return Offset(sx, sy);
  }

  // ── 정적 헬퍼 (외부 hit-test/스냅용) ─────────────────────────────

  /// path 위 t (0~1) 위치의 좌표.
  ///
  /// 빈 path 또는 metrics 실패 시 [Offset.zero] 반환.
  static Offset positionAt(Path path, double t) {
    try {
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return Offset.zero;
      final totalLength = metrics.fold<double>(0, (a, m) => a + m.length);
      if (totalLength <= 0) return Offset.zero;
      final tan = _tangentAcrossMetrics(metrics, totalLength * t.clamp(0.0, 1.0));
      return tan?.position ?? Offset.zero;
    } catch (_) {
      return Offset.zero;
    }
  }

  /// path 위 t (0~1)에서의 접선 각도 (라디안).
  ///
  /// 빈 path 시 0 반환.
  static double angleAt(Path path, double t) {
    try {
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return 0;
      final totalLength = metrics.fold<double>(0, (a, m) => a + m.length);
      if (totalLength <= 0) return 0;
      final tan = _tangentAcrossMetrics(metrics, totalLength * t.clamp(0.0, 1.0));
      return tan?.angle ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 캔버스 좌표 → 가장 가까운 (rowIndex, anchorIndex) 반환.
  ///
  /// [threshold] (px) 이내 앵커가 없으면 null. Pen/Cut/Trim 모드에서 사용.
  static ({int rowIndex, int anchorIndex})? hitTestAnchor(
    GuidePathChart chart,
    Offset point,
    double threshold,
  ) {
    double bestDist = threshold;
    ({int rowIndex, int anchorIndex})? best;
    for (final row in chart.rows) {
      for (int i = 0; i < row.anchors.length; i++) {
        final a = row.anchors[i].position;
        final d = (a - point).distance;
        if (d < bestDist) {
          bestDist = d;
          best = (rowIndex: row.rowIndex, anchorIndex: i);
        }
      }
    }
    return best;
  }

  /// metrics 배열에서 누적 거리 [distance] 위치의 Tangent 반환.
  static ui.Tangent? _tangentAcrossMetrics(
    List<ui.PathMetric> metrics,
    double distance,
  ) {
    double remaining = distance;
    for (final m in metrics) {
      if (m.length <= 0) continue;
      if (remaining <= m.length) {
        return m.getTangentForOffset(remaining);
      }
      remaining -= m.length;
    }
    // 끝을 넘었으면 마지막 metric 끝점 반환.
    if (metrics.isEmpty) return null;
    return metrics.last.getTangentForOffset(metrics.last.length);
  }

  // ── paint ────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    // #668 — 백그라운드 점 격자 (스냅 시각 보조).
    if (showSnapGrid) {
      _drawSnapGrid(canvas, size);
    }

    // #673 — 빈 chart일 때 샘플 왕관 path 가이드 표시 (사용자에게 예시 제공).
    if (chart.rows.isEmpty) {
      _drawSampleCrown(canvas, size);
    }

    // 단을 rowIndex 순으로 정렬 (Painter 안 정렬 — 데이터 순서 보존).
    final sorted = [...chart.rows]
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));

    for (final row in sorted) {
      final color = _colorForRow(row.rowIndex);
      _drawRow(canvas, row, color);
    }

    // 라벨은 모든 path 위에 그리기.
    if (showRowLabels) {
      for (final row in sorted) {
        _drawRowLabel(canvas, row, _colorForRow(row.rowIndex));
      }
    }

    // 호버 앵커 강조.
    if (hoveredAnchor != null) {
      final row = chart.rowByIndex(hoveredAnchor!.rowIndex);
      if (row != null &&
          hoveredAnchor!.anchorIndex >= 0 &&
          hoveredAnchor!.anchorIndex < row.anchors.length) {
        final p = row.anchors[hoveredAnchor!.anchorIndex].position;
        final paint = Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(p, 8, paint);
      }
    }
  }

  /// 단 한 개 그리기 (가이드 path + 셀).
  void _drawRow(Canvas canvas, RowPath row, Color color) {
    if (row.anchors.isEmpty) return;
    final path = row.buildPath();

    // 1) 가이드 path 라인
    if (showGuides) {
      final isActive = activeRowIndex == row.rowIndex;
      final paint = Paint()
        ..color = color.withValues(alpha: isActive ? 0.6 : 0.3)
        ..strokeWidth = isActive ? 1.5 : 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);

      // 앵커 점 표시 (활성 단만)
      if (isActive) {
        final anchorPaint = Paint()..color = color.withValues(alpha: 0.85);
        for (final a in row.anchors) {
          canvas.drawCircle(a.position, 3.5, anchorPaint);
        }
      }
    }

    // 2) 셀 자동 배치
    if (row.pattern.isNotEmpty) {
      _drawCells(canvas, row, path);
    }
  }

  /// path 위에 셀(심볼) 균등 배치 + 자동 회전.
  void _drawCells(Canvas canvas, RowPath row, Path path) {
    final List<ui.PathMetric> metrics;
    try {
      metrics = path.computeMetrics().toList();
    } catch (_) {
      return;
    }
    if (metrics.isEmpty) return;
    final totalLength = metrics.fold<double>(0, (a, m) => a + m.length);
    if (totalLength <= 0) return;

    // 셀 너비/개수 결정 (안전 폴백 다층).
    final double cellW = (row.cellWidth ?? _kDefaultCellSize)
        .clamp(8.0, 200.0)
        .toDouble();
    int n;
    if (row.cellCount != null && row.cellCount! > 0) {
      n = row.cellCount!;
    } else {
      n = math.max(1, (totalLength / cellW).floor());
    }
    if (n <= 0) return;

    // F2 — 심볼 크기는 cellW 고정 (path 길이/셀 수에 따라 변동 X).
    //       비율 일정 보장. 사용자가 row.cellWidth로 직접 제어.
    final symbolPx = cellW * 0.90;
    if (symbolPx <= 0) return;
    // F4 — 법선 방향 오프셋: 심볼이 path 라인을 가리지 않도록 살짝 위로 이동.
    final normalOffset = symbolPx * 0.10;

    for (int i = 0; i < n; i++) {
      // 셀 중심 = i + 0.5 위치 (path 길이 균등 분할).
      final t = (i + 0.5) / n;
      final tan = _tangentAcrossMetrics(metrics, totalLength * t);
      if (tan == null) continue;

      final symId = row.symbolAt(i);
      if (symId == null) continue;

      final picture = symbolPicture(symId);
      if (picture == null) {
        // 로드 중 — 자리만 점으로 표시.
        final placeholder = Paint()..color = C.mu.withValues(alpha: 0.4);
        canvas.drawCircle(tan.position, symbolPx * 0.18, placeholder);
        continue;
      }

      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      // F3 — autoRotate 기본 true 가정. 접선 방향 + π/2 보정 (심볼의 "위"가 path 바깥).
      if (row.autoRotate) {
        canvas.rotate(tan.angle + math.pi / 2);
      }
      // F1 — anchor = bottom-center: 심볼의 밑면이 path 위에 닿음 (라인을 baseline으로).
      // F4 — normalOffset만큼 위(바깥)로 이동: 라인이 심볼에 가려지지 않음.
      canvas.translate(-symbolPx / 2, -symbolPx - normalOffset);
      canvas.scale(symbolPx / _kSvgViewBox, symbolPx / _kSvgViewBox);
      canvas.drawPicture(picture);
      canvas.restore();
    }
  }

  /// 단 라벨 (R1, R2, ...) 그리기 — path 첫 앵커 옆.
  void _drawRowLabel(Canvas canvas, RowPath row, Color color) {
    if (row.anchors.isEmpty) return;
    final pos = row.anchors.first.position;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: 11),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: ui.FontWeight.w700,
      ))
      ..addText('R${row.rowIndex}');
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 60));
    canvas.drawParagraph(p, pos + const Offset(8, -16));
  }

  /// rowIndex → 색상 (cycle).
  Color _colorForRow(int rowIndex) {
    if (rowIndex <= 0) return _kRowColors[0];
    return _kRowColors[(rowIndex - 1) % _kRowColors.length];
  }

  // ── #668 — 백그라운드 라인 격자 (모눈종이 스타일) ─────────────────
  void _drawSnapGrid(Canvas canvas, Size size) {
    if (snapGridSpacing <= 0 || size.width <= 0 || size.height <= 0) return;
    final minor = Paint()
      ..color = C.bd.withValues(alpha: 0.30)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final major = Paint()
      ..color = C.bd.withValues(alpha: 0.65)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final cols = (size.width / snapGridSpacing).ceil();
    final rows = (size.height / snapGridSpacing).ceil();
    // 세로선
    for (int c = 0; c <= cols; c++) {
      final x = c * snapGridSpacing;
      final isMajor = c % 4 == 0;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), isMajor ? major : minor);
    }
    // 가로선
    for (int r = 0; r <= rows; r++) {
      final y = r * snapGridSpacing;
      final isMajor = r % 4 == 0;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), isMajor ? major : minor);
    }
  }

  // ── #673 — 빈 chart 일 때 샘플 왕관 path 가이드 ──────────────────
  void _drawSampleCrown(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 캔버스 중앙 기준, 화면 60% 폭 사용.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.6;
    final h = w * 0.5;

    // 5뿔 왕관 path: 좌하 → (좌하 → 좌피크 → 좌골 → 중피크 → 우골 → 우피크 → 우상하강) → 우하 → 닫힘
    final crown = Path()
      ..moveTo(cx - w / 2, cy + h / 2)
      ..lineTo(cx - w / 2, cy - h / 4)
      ..lineTo(cx - w * 0.30, cy - h * 0.55)
      ..lineTo(cx - w * 0.18, cy - h / 4)
      ..lineTo(cx, cy - h * 0.7)
      ..lineTo(cx + w * 0.18, cy - h / 4)
      ..lineTo(cx + w * 0.30, cy - h * 0.55)
      ..lineTo(cx + w / 2, cy - h / 4)
      ..lineTo(cx + w / 2, cy + h / 2)
      ..close();

    // 점선 효과 — path를 작은 조각으로 분할해서 alternating draw.
    final paint = Paint()
      ..color = C.mu.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, crown, paint, dashLen: 6, gapLen: 4);

    // 안내 텍스트 — 왕관 아래.
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 12,
    ))
      ..pushStyle(ui.TextStyle(
        color: C.mu,
        fontSize: 12,
        fontWeight: ui.FontWeight.w500,
      ))
      ..addText('샘플: 왕관 모티프\n펜/호/사각/그리드 도구로 직접 그려보세요');
    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: size.width - 32));
    canvas.drawParagraph(
      paragraph,
      Offset(16, cy + h / 2 + 16),
    );
  }

  /// 점선 path 렌더링 (dash/gap 픽셀 단위).
  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dashLen,
    required double gapLen,
  }) {
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final next =
            (distance + (draw ? dashLen : gapLen)).clamp(0, metric.length);
        if (draw) {
          final segment = metric.extractPath(distance, next.toDouble());
          canvas.drawPath(segment, paint);
        }
        distance = next.toDouble();
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidePathPainter old) {
    return old.chart != chart ||
        old.activeRowIndex != activeRowIndex ||
        old.hoveredAnchor != hoveredAnchor ||
        old.showGuides != showGuides ||
        old.showRowLabels != showRowLabels ||
        old.showSnapGrid != showSnapGrid ||
        old.snapGridSpacing != snapGridSpacing ||
        !identical(old.symbolPicture, symbolPicture);
  }
}

/// 자유 Path 도안 표시용 StatelessWidget 래퍼.
class GuidePathView extends StatelessWidget {
  final GuidePathChart chart;
  final ui.Picture? Function(String) symbolPicture;
  final int? activeRowIndex;
  final ({int rowIndex, int anchorIndex})? hoveredAnchor;
  final bool showGuides;
  final bool showRowLabels;
  final bool showSnapGrid;
  final double snapGridSpacing;

  const GuidePathView({
    super.key,
    required this.chart,
    required this.symbolPicture,
    this.activeRowIndex,
    this.hoveredAnchor,
    this.showGuides = true,
    this.showRowLabels = true,
    this.showSnapGrid = true,
    this.snapGridSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePathPainter(
        chart: chart,
        symbolPicture: symbolPicture,
        activeRowIndex: activeRowIndex,
        hoveredAnchor: hoveredAnchor,
        showGuides: showGuides,
        showRowLabels: showRowLabels,
        showSnapGrid: showSnapGrid,
        snapGridSpacing: snapGridSpacing,
      ),
    );
  }
}
