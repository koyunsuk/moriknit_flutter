import 'package:flutter/material.dart';

import '../../domain/pattern_chart.dart';

enum TrackingDisplayMode { bar, completed, checkbox }

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
  final TransformationController transformationController;

  const ChartTrackingOverlay({
    super.key,
    required this.chart,
    required this.currentRow,
    this.targetRow,
    this.mode = TrackingDisplayMode.bar,
    required this.transformationController,
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

  const _TrackingPainter({
    required this.rows,
    required this.cols,
    required this.currentRow,
    this.targetRow,
    required this.mode,
  });

  static const Color _barColor = Color(0xFFEC4899);    // 핑크 바
  static const Color _doneColor = Color(0x40000000);   // 완료행 마스크
  static const Color _checkColor = Color(0xFF10B981);  // 체크 초록
  static const Color _targetColor = Color(0xFF8B5CF6); // 목표선 보라

  // 뜨개 관례: 1단 = 차트 맨 아래, 위로 올라감
  // currentRow: 1-based 뜨개 단 번호 (1 = 첫 번째 단 = 그리드 맨 아래)
  // gridIndex(knitRow) = rows - knitRow  (0-based, 위에서 아래로)
  int _gridIndex(int knitRow) => rows - knitRow;

  @override
  void paint(Canvas canvas, Size size) {
    const hW = _kHeaderW;
    const hH = _kHeaderH;
    const cW = _kCellW;
    const cH = _kCellH;

    // currentRow: 1단 = 맨 아래, rows단 = 맨 위
    final gi = _gridIndex(currentRow).clamp(0, rows - 1); // 현재 단 그리드 인덱스

    switch (mode) {
      case TrackingDisplayMode.bar:
        // 현재 단 위쪽에 굵은 가로 바 (종이 도안에 자 대는 느낌)
        final barY = hH + gi * cH;
        canvas.drawLine(
          Offset(hW, barY),
          Offset(hW + cols * cW, barY),
          Paint()
            ..color = _barColor
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round,
        );
        // 현재 단 전체 연한 하이라이트
        canvas.drawRect(
          Rect.fromLTWH(hW, barY, cols * cW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.08),
        );
        // 왼쪽 헤더 강조
        canvas.drawRect(
          Rect.fromLTWH(0, barY, hW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.20),
        );

      case TrackingDisplayMode.completed:
        // 완료된 단(1 ~ currentRow-1) = 그리드 아래쪽 rows-(currentRow-1)~rows-1 인덱스
        // 완료된 그리드 범위: gi+1 부터 rows-1 까지 (아래쪽)
        final completedRows = currentRow - 1;
        if (completedRows > 0) {
          final doneTop = hH + (gi + 1) * cH;
          canvas.drawRect(
            Rect.fromLTWH(hW, doneTop, cols * cW, completedRows * cH),
            Paint()..color = _doneColor,
          );
        }
        // 현재 단 상단 가이드 바
        final barY = hH + gi * cH;
        canvas.drawLine(
          Offset(hW, barY),
          Offset(hW + cols * cW, barY),
          Paint()..color = _barColor..strokeWidth = 2.0,
        );

      case TrackingDisplayMode.checkbox:
        // 완료된 단의 왼쪽 헤더에 체크마크
        final checkPaint = Paint()
          ..color = _checkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        // 완료 단: knitRow 1 ~ currentRow-1 → 그리드 아래쪽
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
        // 현재 단 헤더 강조
        canvas.drawRect(
          Rect.fromLTWH(0, hH + gi * cH, hW, cH),
          Paint()..color = _barColor.withValues(alpha: 0.25),
        );
    }

    // 목표 단 보라색 점선 (targetRow 설정 시, 뜨개 기준)
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
      old.rows != rows ||
      old.cols != cols;
}

// 하단 플로팅 컨트롤 바
class TrackingControlBar extends StatelessWidget {
  final int currentRow;
  final int totalRows;
  final TrackingDisplayMode mode;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onLongPressMinus;
  final VoidCallback onLongPressPlus;
  final ValueChanged<TrackingDisplayMode> onModeChange;
  final VoidCallback onClose;

  const TrackingControlBar({
    super.key,
    required this.currentRow,
    required this.totalRows,
    required this.mode,
    required this.onMinus,
    required this.onPlus,
    required this.onLongPressMinus,
    required this.onLongPressPlus,
    required this.onModeChange,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 행 카운터 메인
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 모드 전환 아이콘 버튼들
              Row(
                children: [
                  _ModeBtn(icon: Icons.horizontal_rule_rounded, selected: mode == TrackingDisplayMode.bar,
                    tooltip: '바 모드', onTap: () => onModeChange(TrackingDisplayMode.bar)),
                  const SizedBox(width: 4),
                  _ModeBtn(icon: Icons.layers_rounded, selected: mode == TrackingDisplayMode.completed,
                    tooltip: '완료 모드', onTap: () => onModeChange(TrackingDisplayMode.completed)),
                  const SizedBox(width: 4),
                  _ModeBtn(icon: Icons.check_box_rounded, selected: mode == TrackingDisplayMode.checkbox,
                    tooltip: '체크박스', onTap: () => onModeChange(TrackingDisplayMode.checkbox)),
                ],
              ),

              // 행 증감 컨트롤
              Row(
                children: [
                  GestureDetector(
                    onTap: onMinus,
                    onLongPress: onLongPressMinus,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove_rounded, color: Color(0xFFEC4899), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        '$currentRow단',
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: Color(0xFFEC4899),
                        ),
                      ),
                      Text(
                        '/ $totalRows',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onPlus,
                    onLongPress: onLongPressPlus,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: Color(0xFFEC4899), size: 22),
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
            ),
          ),
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
            color: selected ? const Color(0xFFEC4899) : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16,
            color: selected ? Colors.white : Colors.grey[500]),
        ),
      ),
    );
  }
}
