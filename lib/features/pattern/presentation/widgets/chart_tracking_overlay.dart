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
class TrackingControlBar extends StatefulWidget {
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

  // 단 이동 — 마지막단/첫단 점프
  final VoidCallback? onJumpToLastRow;
  final VoidCallback? onJumpToFirstRow;

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
    this.onJumpToLastRow,
    this.onJumpToFirstRow,
  });

  @override
  State<TrackingControlBar> createState() => _TrackingControlBarState();
}

class _TrackingControlBarState extends State<TrackingControlBar> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('트래킹바 버튼 안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpRow(icon: Icons.horizontal_rule_rounded, label: '━ 바 모드', desc: '현재 단 위치에 선 표시'),
              _HelpRow(icon: Icons.layers_rounded, label: '▓ 완료 모드', desc: '완료된 단을 어둡게 표시'),
              _HelpRow(icon: Icons.check_box_rounded, label: '☑ 체크 모드', desc: '완료 단에 체크 표시'),
              _HelpRow(icon: Icons.swap_vert_rounded, label: '↕ 방향', desc: '아래→위 / 위→아래 전환'),
              _HelpRow(icon: Icons.add_rounded, label: '⊕ 세로 포인터', desc: '코 위치 세로선 표시/숨김'),
              _HelpRow(icon: Icons.skip_previous_rounded, label: '⏮ 1단↓', desc: '첫 번째 단으로 이동'),
              _HelpRow(icon: Icons.skip_next_rounded, label: '⏭ 마지막단↑', desc: '마지막 단으로 이동'),
              _HelpRow(icon: Icons.remove_rounded, label: '[-] / [+]', desc: '단 증감 (길게 누르면 10단씩)'),
              _HelpRow(icon: Icons.chevron_left_rounded, label: '← →', desc: '코 위치 이동'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colEnabled = widget.currentCol != null;
    final progress = widget.totalRows > 0 ? widget.currentRow / widget.totalRows : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // ── 확장 패널 (위로 펼침) ──
          if (_expanded) ...[
            // 모드 + 방향 + 크로스헤어 + 점프버튼 행
            Row(
              children: [
                _ModeBtn(
                  icon: Icons.horizontal_rule_rounded,
                  selected: widget.mode == TrackingDisplayMode.bar,
                  tooltip: '바 모드',
                  onTap: () => widget.onModeChange(TrackingDisplayMode.bar),
                ),
                const SizedBox(width: 4),
                _ModeBtn(
                  icon: Icons.layers_rounded,
                  selected: widget.mode == TrackingDisplayMode.completed,
                  tooltip: '완료 모드',
                  onTap: () => widget.onModeChange(TrackingDisplayMode.completed),
                ),
                const SizedBox(width: 4),
                _ModeBtn(
                  icon: Icons.check_box_rounded,
                  selected: widget.mode == TrackingDisplayMode.checkbox,
                  tooltip: '체크박스',
                  onTap: () => widget.onModeChange(TrackingDisplayMode.checkbox),
                ),
                const SizedBox(width: 8),
                // 방향 토글
                Tooltip(
                  message: widget.direction == TrackingBarDirection.bottomUp ? '위에서 아래로 전환' : '아래에서 위로 전환',
                  child: GestureDetector(
                    onTap: () => widget.onDirectionChange(
                      widget.direction == TrackingBarDirection.bottomUp
                          ? TrackingBarDirection.topDown
                          : TrackingBarDirection.bottomUp,
                    ),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: widget.direction == TrackingBarDirection.topDown
                            ? C.lv.withValues(alpha: 0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.direction == TrackingBarDirection.topDown
                              ? C.lv.withValues(alpha: 0.50)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        widget.direction == TrackingBarDirection.topDown
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 15,
                        color: widget.direction == TrackingBarDirection.topDown ? C.lv : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 크로스헤어 토글
                Tooltip(
                  message: colEnabled ? '세로 포인터 끄기' : '세로 포인터 켜기',
                  child: GestureDetector(
                    onTap: widget.onColToggle,
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
                        Icons.add_rounded,
                        size: 16,
                        color: colEnabled ? const Color(0xFFF59E0B) : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // 점프 버튼
                if (widget.onJumpToFirstRow != null)
                  _JumpBtn(label: '1단↓', onTap: widget.onJumpToFirstRow!),
                if (widget.onJumpToFirstRow != null && widget.onJumpToLastRow != null)
                  const SizedBox(width: 6),
                if (widget.onJumpToLastRow != null)
                  _JumpBtn(label: '마지막단↑', onTap: widget.onJumpToLastRow!),
              ],
            ),

            // 크로스헤어 활성 시: 코증감 + 마커너비 슬라이더 행
            if (colEnabled) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  // 코 증감
                  GestureDetector(
                    onTap: widget.onColMinus,
                    onLongPress: widget.onColLongPressMinus,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Color(0xFFF59E0B), size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    children: [
                      Text(
                        '${widget.currentCol}코',
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      Text('/ ${widget.totalCols}', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onColPlus,
                    onLongPress: widget.onColLongPressPlus,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 마커 너비 슬라이더
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '마커 너비 ${widget.markerWidth.toStringAsFixed(1)}칸',
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
                            value: widget.markerWidth.clamp(0.5, 7.0),
                            min: 0.5,
                            max: 7.0,
                            divisions: 13,
                            onChanged: widget.onMarkerWidthChange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 4),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 4),
          ],

          // ── 슬림 메인 행: [-] 진행률바+단수 [+] [?] [≡/✕] ──
          Row(
            children: [
              // [-] 버튼
              GestureDetector(
                onTap: widget.onMinus,
                onLongPress: widget.onLongPressMinus,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove_rounded, color: C.lv, size: 18),
                ),
              ),
              const SizedBox(width: 8),

              // 진행률바 + 단수 텍스트 (중앙 확장)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 단수 텍스트
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.currentRow}단',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: C.lv,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${widget.totalRows}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // 진행률바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(C.lv),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // [+] 버튼
              GestureDetector(
                onTap: widget.onPlus,
                onLongPress: widget.onLongPressPlus,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: C.lv, size: 18),
                ),
              ),
              const SizedBox(width: 6),

              // [?] 도움말 버튼
              GestureDetector(
                onTap: _showHelpDialog,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_outline_rounded, size: 15, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(width: 4),

              // [≡/✕] 확장 토글 버튼
              GestureDetector(
                onTap: _toggleExpanded,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _expanded ? C.lv.withValues(alpha: 0.12) : Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _expanded ? C.lv.withValues(alpha: 0.40) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    _expanded ? Icons.close_rounded : Icons.menu_rounded,
                    size: 15,
                    color: _expanded ? C.lv : Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 도움말 다이얼로그 내부 행 위젯
class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;

  const _HelpRow({required this.icon, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JumpBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: C.lv.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.lv.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.lv),
        ),
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
