import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/pattern_chart.dart';

enum TrackingDisplayMode { bar, completed, checkbox }

/// 바 방향: bottomUp = 아래서 위로(기본), topDown = 위에서 아래로
/// topDown 시 현재 단 아래(이전 단)가 가려지지 않아 전단 확인 가능
enum TrackingBarDirection { bottomUp, topDown }

// chart_canvas.dart 와 동일한 상수 (수정 금지 영역이므로 재선언)
const double _kCellW = 24.0;
const double _kCellH = 24.0;
const double _kHeaderW = 20.0;
const double _kHeaderH = 20.0;

// 현재 행 하이라이트 오버레이 — chart_canvas.dart 수정 0줄
class ChartTrackingOverlay extends StatelessWidget {
  final PatternChart chart;
  final int currentRow;
  final int? targetRow;
  final TrackingDisplayMode mode;
  final TrackingBarDirection direction;
  final TransformationController transformationController;
  // 세로 포인터 (null = 비활성)
  final int? currentCol;
  // 교차점 마커 너비 (셀 단위, 1.0 ~ 7.0)
  final double markerWidth;

  const ChartTrackingOverlay({
    super.key,
    required this.chart,
    required this.currentRow,
    this.targetRow,
    this.mode = TrackingDisplayMode.bar,
    this.direction = TrackingBarDirection.bottomUp,
    required this.transformationController,
    this.currentCol,
    this.markerWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final canvasW = _kHeaderW + chart.cols * _kCellW;
    final canvasH = _kHeaderH + chart.rows * _kCellH;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: transformationController,
        builder: (context, _) {
          return Transform(
            transform: transformationController.value,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: canvasW,
              height: canvasH,
              child: CustomPaint(
                painter: _TrackingPainter(
                  rows: chart.rows,
                  cols: chart.cols,
                  currentRow: currentRow,
                  targetRow: targetRow,
                  mode: mode,
                  direction: direction,
                  currentCol: currentCol,
                  markerWidth: markerWidth,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrackingPainter extends CustomPainter {
  final int rows;
  final int cols;
  final int currentRow;
  final int? targetRow;
  final TrackingDisplayMode mode;
  final TrackingBarDirection direction;
  final int? currentCol;
  final double markerWidth;

  const _TrackingPainter({
    required this.rows,
    required this.cols,
    required this.currentRow,
    this.targetRow,
    required this.mode,
    this.direction = TrackingBarDirection.bottomUp,
    this.currentCol,
    this.markerWidth = 2.0,
  });

  static Color get _barColor => C.lv;
  static const Color _doneColor = Color(0x40000000);
  static const Color _checkColor = Color(0xFF10B981);
  static const Color _targetColor = Color(0xFF8B5CF6);
  // 세로 포인터 색상 — 주황/앰버 (실물 트래커 클립 색상)
  static const Color _colColor = Color(0xFFF59E0B);

  // 뜨개 관례: 1단 = 차트 맨 아래, 위로 올라감
  int _gridIndex(int knitRow) => rows - knitRow;

  @override
  void paint(Canvas canvas, Size size) {
    const hW = _kHeaderW;
    const hH = _kHeaderH;
    const cW = _kCellW;
    const cH = _kCellH;

    final gi = _gridIndex(currentRow).clamp(0, rows - 1);
    final isTopDown = direction == TrackingBarDirection.topDown;

    // ── 가로 트래킹 바 ──────────────────────────────────────────
    switch (mode) {
      case TrackingDisplayMode.bar:
        // bottomUp: 바 = 현재 단 상단 / topDown: 바 = 현재 단 하단
        final barY = isTopDown ? hH + (gi + 1) * cH : hH + gi * cH;
        canvas.drawLine(
          Offset(hW, barY),
          Offset(hW + cols * cW, barY),
          Paint()
            ..color = _barColor
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawRect(
          Rect.fromLTWH(hW, hH + gi * cH, cols * cW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.08),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, hH + gi * cH, hW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.20),
        );

      case TrackingDisplayMode.completed:
        if (isTopDown) {
          // 미래 단(현재 단 위) 을 회색으로 → 이전 단이 가려지지 않음
          if (gi > 0) {
            canvas.drawRect(
              Rect.fromLTWH(hW, hH, cols * cW, gi * cH),
              Paint()..color = _doneColor,
            );
          }
          // 바 = 현재 단 하단
          final barY = hH + (gi + 1) * cH;
          canvas.drawLine(
            Offset(hW, barY),
            Offset(hW + cols * cW, barY),
            Paint()..color = _barColor..strokeWidth = 2.0,
          );
        } else {
          // 완료 단(현재 단 아래) 을 회색으로
          final completedRows = currentRow - 1;
          if (completedRows > 0) {
            final doneTop = hH + (gi + 1) * cH;
            canvas.drawRect(
              Rect.fromLTWH(hW, doneTop, cols * cW, completedRows * cH),
              Paint()..color = _doneColor,
            );
          }
          // 바 = 현재 단 상단
          final barY = hH + gi * cH;
          canvas.drawLine(
            Offset(hW, barY),
            Offset(hW + cols * cW, barY),
            Paint()..color = _barColor..strokeWidth = 2.0,
          );
        }

      case TrackingDisplayMode.checkbox:
        final checkPaint = Paint()
          ..color = _checkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (isTopDown) {
          // 미래 단(현재 단 위)에 체크 표시
          for (int kr = currentRow + 1; kr <= rows; kr++) {
            final futGi = _gridIndex(kr);
            final cx = hW / 2;
            final cy = hH + futGi * cH + cH / 2;
            final path = Path()
              ..moveTo(cx - 3.5, cy)
              ..lineTo(cx - 0.5, cy + 3)
              ..lineTo(cx + 4, cy - 3.5);
            canvas.drawPath(path, checkPaint);
          }
        } else {
          // 완료 단(현재 단 아래)에 체크 표시
          for (int kr = 1; kr < currentRow && kr <= rows; kr++) {
            final doneGi = _gridIndex(kr);
            final cx = hW / 2;
            final cy = hH + doneGi * cH + cH / 2;
            final path = Path()
              ..moveTo(cx - 3.5, cy)
              ..lineTo(cx - 0.5, cy + 3)
              ..lineTo(cx + 4, cy - 3.5);
            canvas.drawPath(path, checkPaint);
          }
        }
        canvas.drawRect(
          Rect.fromLTWH(0, hH + gi * cH, hW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.25),
        );
    }

    // ── 세로 포인터 (크로스헤어) ────────────────────────────────
    if (currentCol != null) {
      final col = currentCol!.clamp(1, cols);
      final ci = col - 1; // 0-based
      final lineX = hW + ci * cW + cW / 2; // 열 중앙
      final halfW = (markerWidth * cW) / 2.0;
      final stripLeft = (lineX - halfW).clamp(hW, hW + cols * cW);
      final stripRight = (lineX + halfW).clamp(hW, hW + cols * cW);
      final stripW = stripRight - stripLeft;

      // 세로 반투명 스트립 (전체 높이)
      canvas.drawRect(
        Rect.fromLTWH(stripLeft, hH, stripW, rows * cH),
        Paint()..color = _colColor.withValues(alpha: 0.10),
      );

      // 세로 중심선
      canvas.drawLine(
        Offset(lineX, hH),
        Offset(lineX, hH + rows * cH),
        Paint()
          ..color = _colColor.withValues(alpha: 0.55)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );

      // 교차점 강조 마커 (가로 바 × 세로 바)
      canvas.drawRect(
        Rect.fromLTWH(stripLeft, hH + gi * cH, stripW, cH),
        Paint()..color = _colColor.withValues(alpha: 0.40),
      );
    }

    // ── 목표 단 보라색 점선 ─────────────────────────────────────
    if (targetRow != null && targetRow! >= 1 && targetRow! <= rows) {
      final tgi = _gridIndex(targetRow!);
      final y = hH + tgi * cH;
      final dashPaint = Paint()
        ..color = _targetColor
        ..strokeWidth = 1.5;
      const dashW = 6.0;
      const gapW = 4.0;
      double x = hW;
      final endX = hW + cols * cW;
      while (x < endX) {
        canvas.drawLine(Offset(x, y), Offset((x + dashW).clamp(x, endX), y), dashPaint);
        x += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(_TrackingPainter old) =>
      old.currentRow != currentRow ||
      old.targetRow != targetRow ||
      old.mode != mode ||
      old.direction != direction ||
      old.rows != rows ||
      old.cols != cols ||
      old.currentCol != currentCol ||
      old.markerWidth != markerWidth;
}

// ── 하단 플로팅 컨트롤 바 ──────────────────────────────────────────
class TrackingControlBar extends StatelessWidget {
  final int currentRow;
  final int totalRows;
  final TrackingDisplayMode mode;
  final TrackingBarDirection direction;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onLongPressMinus;
  final VoidCallback onLongPressPlus;
  final ValueChanged<TrackingDisplayMode> onModeChange;
  final ValueChanged<TrackingBarDirection> onDirectionChange;
  final VoidCallback onClose;

  // 세로 포인터
  final int? currentCol;
  final int totalCols;
  final double markerWidth;
  final VoidCallback onColToggle;
  final VoidCallback onColMinus;
  final VoidCallback onColPlus;
  final VoidCallback onColLongPressMinus;
  final VoidCallback onColLongPressPlus;
  final ValueChanged<double> onMarkerWidthChange;

  const TrackingControlBar({
    super.key,
    required this.currentRow,
    required this.totalRows,
    required this.mode,
    this.direction = TrackingBarDirection.bottomUp,
    required this.onMinus,
    required this.onPlus,
    required this.onLongPressMinus,
    required this.onLongPressPlus,
    required this.onModeChange,
    required this.onDirectionChange,
    required this.onClose,
    this.currentCol,
    this.totalCols = 1,
    this.markerWidth = 2.0,
    required this.onColToggle,
    required this.onColMinus,
    required this.onColPlus,
    required this.onColLongPressMinus,
    required this.onColLongPressPlus,
    required this.onMarkerWidthChange,
  });

  @override
  Widget build(BuildContext context) {
    final colEnabled = currentCol != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: C.lv.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 메인 행: 모드 | 방향·크로스헤어 | 단 증감 | 닫기 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 가로 모드 버튼 + 방향 + 크로스헤어
              Row(
                children: [
                  _ModeBtn(
                    icon: Icons.horizontal_rule_rounded,
                    selected: mode == TrackingDisplayMode.bar,
                    tooltip: '바 모드',
                    onTap: () => onModeChange(TrackingDisplayMode.bar),
                  ),
                  const SizedBox(width: 4),
                  _ModeBtn(
                    icon: Icons.layers_rounded,
                    selected: mode == TrackingDisplayMode.completed,
                    tooltip: '완료 모드',
                    onTap: () => onModeChange(TrackingDisplayMode.completed),
                  ),
                  const SizedBox(width: 4),
                  _ModeBtn(
                    icon: Icons.check_box_rounded,
                    selected: mode == TrackingDisplayMode.checkbox,
                    tooltip: '체크박스',
                    onTap: () => onModeChange(TrackingDisplayMode.checkbox),
                  ),
                  const SizedBox(width: 8),
                  // 방향 토글: 아래→위 / 위→아래
                  Tooltip(
                    message: direction == TrackingBarDirection.bottomUp ? '위에서 아래로 전환' : '아래에서 위로 전환',
                    child: GestureDetector(
                      onTap: () => onDirectionChange(
                        direction == TrackingBarDirection.bottomUp
                            ? TrackingBarDirection.topDown
                            : TrackingBarDirection.bottomUp,
                      ),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: direction == TrackingBarDirection.topDown
                              ? C.lv.withValues(alpha: 0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: direction == TrackingBarDirection.topDown
                                ? C.lv.withValues(alpha: 0.50)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          direction == TrackingBarDirection.topDown
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 15,
                          color: direction == TrackingBarDirection.topDown ? C.lv : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 세로 포인터 (크로스헤어) 토글
                  Tooltip(
                    message: colEnabled ? '세로 포인터 끄기' : '세로 포인터 켜기',
                    child: GestureDetector(
                      onTap: onColToggle,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: colEnabled
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colEnabled
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.60)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded, // 십자(+) 아이콘 = 크로스헤어
                          size: 16,
                          color: colEnabled ? const Color(0xFFF59E0B) : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 단 증감 컨트롤
              Row(
                children: [
                  GestureDetector(
                    onTap: onMinus,
                    onLongPress: onLongPressMinus,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove_rounded, color: C.lv, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        '$currentRow단',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.lv),
                      ),
                      Text('/ $totalRows', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onPlus,
                    onLongPress: onLongPressPlus,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: C.lv, size: 22),
                    ),
                  ),
                ],
              ),

              // 닫기
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close_rounded, color: Colors.grey[400], size: 20),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalRows > 0 ? currentRow / totalRows : 0,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(C.lv),
            ),
          ),

          // ── 세로 포인터 컨트롤 (활성 시만 표시) ──
          if (colEnabled) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                // 코 증감
                GestureDetector(
                  onTap: onColMinus,
                  onLongPress: onColLongPressMinus,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_left_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      '$currentCol코',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    Text('/ $totalCols', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onColPlus,
                  onLongPress: onColLongPressPlus,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                ),

                const SizedBox(width: 12),
                // 마커 너비 슬라이더
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '마커 너비 ${markerWidth.toStringAsFixed(1)}칸',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xFFF59E0B),
                          inactiveTrackColor: Colors.grey[200],
                          thumbColor: const Color(0xFFF59E0B),
                          overlayColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: markerWidth.clamp(0.5, 7.0),
                          min: 0.5,
                          max: 7.0,
                          divisions: 13,
                          onChanged: onMarkerWidthChange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ModeBtn({required this.icon, required this.selected, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: selected ? C.lv : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[500]),
        ),
      ),
    );
  }
}
