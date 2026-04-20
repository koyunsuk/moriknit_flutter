import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/pattern_chart.dart';

/// 그리드 크기 설정 다이얼로그
/// 반환값: GridSizeResult(rows, cols, mode) 또는 null (취소)
class GridSizeResult {
  final int rows;
  final int cols;
  final ChartMode mode;
  const GridSizeResult({
    required this.rows,
    required this.cols,
    this.mode = ChartMode.symbol,
  });
}

/// 그리드 크기 설정 다이얼로그
/// [initialMode]: 신규 생성 시 기본 모드. null이면 ChartMode.symbol.
/// 편집 모드(isEdit=true)에서는 모드 선택 UI를 숨기고 기존 모드를 유지함.
Future<GridSizeResult?> showGridSizeDialog(
  BuildContext context, {
  required int initialRows,
  required int initialCols,
  bool isEdit = false,
  ChartMode? initialMode,
}) {
  return showDialog<GridSizeResult>(
    context: context,
    barrierDismissible: !isEdit ? false : true,
    builder: (_) => _GridSizeDialog(
      initialRows: initialRows,
      initialCols: initialCols,
      isEdit: isEdit,
      initialMode: initialMode ?? ChartMode.symbol,
    ),
  );
}

class _GridSizeDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  final bool isEdit;
  final ChartMode initialMode;

  const _GridSizeDialog({
    required this.initialRows,
    required this.initialCols,
    required this.isEdit,
    required this.initialMode,
  });

  @override
  State<_GridSizeDialog> createState() => _GridSizeDialogState();
}

class _GridSizeDialogState extends State<_GridSizeDialog> {
  late TextEditingController _rowsCtrl;
  late TextEditingController _colsCtrl;
  late ChartMode _mode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rowsCtrl = TextEditingController(text: '${widget.initialRows}');
    _colsCtrl = TextEditingController(text: '${widget.initialCols}');
    // 새로만들기 시 모드 선택 기본값: 기호(symbol) — 이전 동작 유지
    // colorChart 모드를 지원하기 위해 최상단 칩으로 노출
    _mode = widget.initialMode == ChartMode.colorChart
        ? ChartMode.colorChart
        : ChartMode.symbol;
  }

  @override
  void dispose() {
    _rowsCtrl.dispose();
    _colsCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final rows = int.tryParse(_rowsCtrl.text.trim());
    final cols = int.tryParse(_colsCtrl.text.trim());
    if (rows == null || cols == null || rows < 1 || cols < 1) {
      setState(() => _error = '코 수와 단 수를 올바르게 입력해 주세요.');
      return;
    }
    if (rows > 200 || cols > 200) {
      setState(() => _error = '최대 200 x 200까지 설정할 수 있어요.');
      return;
    }
    Navigator.of(context).pop(
      GridSizeResult(rows: rows, cols: cols, mode: _mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: C.bg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEdit ? '그리드 크기 변경' : '도안 크기 설정',
              style: T.h2,
            ),
            const SizedBox(height: 6),
            Text(
              '코 수(가로)와 단 수(세로)를 입력하세요.\n셀 비율은 뜨개 코 실제 비율(4:6)로 표시됩니다.',
              style: T.caption.copyWith(color: C.tx2),
            ),
            if (!widget.isEdit) ...[
              const SizedBox(height: 16),
              Text(
                '도안 종류',
                style: T.caption.copyWith(
                  color: C.tx2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ModeChip(
                    label: '기호 도안',
                    active: _mode == ChartMode.symbol,
                    onTap: () => setState(() => _mode = ChartMode.symbol),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    label: '컬러차트',
                    active: _mode == ChartMode.colorChart,
                    onTap: () => setState(() => _mode = ChartMode.colorChart),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SizeField(
                    controller: _colsCtrl,
                    label: '코 수 (가로)',
                    hint: '20',
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SizeField(
                    controller: _rowsCtrl,
                    label: '단 수 (세로)',
                    hint: '30',
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GridPreview(
              rowsCtrl: _rowsCtrl,
              colsCtrl: _colsCtrl,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: T.caption.copyWith(color: const Color(0xFFDC2626)),
              ),
            ],
            const SizedBox(height: 20),
            if (widget.isEdit)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: C.bd2),
                        foregroundColor: C.tx2,
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _ConfirmButton(onTap: _confirm)),
                ],
              )
            else
              _ConfirmButton(onTap: _confirm, label: '시작하기'),
          ],
        ),
      ),
      ),
    );
  }
}

class _SizeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  const _SizeField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.caption.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onSubmitted: onSubmitted,
          style: T.h2,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: C.gx,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// 그리드 미리보기 — 입력 값 변경 시 실시간 업데이트
class _GridPreview extends StatefulWidget {
  final TextEditingController rowsCtrl;
  final TextEditingController colsCtrl;

  const _GridPreview({required this.rowsCtrl, required this.colsCtrl});

  @override
  State<_GridPreview> createState() => _GridPreviewState();
}

class _GridPreviewState extends State<_GridPreview> {
  @override
  void initState() {
    super.initState();
    widget.rowsCtrl.addListener(_rebuild);
    widget.colsCtrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.rowsCtrl.removeListener(_rebuild);
    widget.colsCtrl.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final rows = int.tryParse(widget.rowsCtrl.text) ?? 0;
    final cols = int.tryParse(widget.colsCtrl.text) ?? 0;

    if (rows <= 0 || cols <= 0) return const SizedBox.shrink();

    // 미리보기 박스 최대 120×80
    const previewW = 180.0;
    const previewH = 80.0;
    // 4:6 셀 비율 유지하면서 전체를 previewW×previewH 안에 맞춤
    final cellW = (previewW / cols).clamp(1.0, 12.0);
    final cellH = cellW * (6 / 4);
    final totalW = cellW * cols;
    final totalH = cellH * rows;

    final scale = (totalW > previewW || totalH > previewH)
        ? (totalW / previewW).clamp(1.0, double.infinity)
        : 1.0;

    return Center(
      child: Column(
        children: [
          Container(
            width: previewW,
            height: previewH,
            decoration: BoxDecoration(
              border: Border.all(color: C.bd2),
              borderRadius: BorderRadius.circular(8),
              color: C.gx,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                size: const Size(previewW, previewH),
                painter: _PreviewPainter(
                  rows: rows,
                  cols: cols,
                  scale: scale,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$cols코 × $rows단',
            style: T.caption.copyWith(color: C.tx2),
          ),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double scale;

  const _PreviewPainter({required this.rows, required this.cols, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = (size.width / cols).clamp(0.5, size.width);
    final cellH = cellW * (6 / 4);
    final totalH = cellH * rows;
    final offsetY = ((size.height - totalH) / 2).clamp(0.0, size.height);

    final linePaint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 0.5;

    for (int c = 0; c <= cols; c++) {
      final x = c * cellW;
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, offsetY + totalH.clamp(0.0, size.height - offsetY)),
        linePaint,
      );
    }
    for (int r = 0; r <= rows; r++) {
      final y = offsetY + r * cellH;
      if (y > size.height) break;
      canvas.drawLine(Offset(0, y), Offset(cols * cellW, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.rows != rows || old.cols != cols || old.scale != scale;
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _ConfirmButton({required this.onTap, this.label = '확인'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: C.lv,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// 모드 선택 칩 — CLAUDE.md 칩 스타일 준수
/// 선택: color C.lv, text white, fontWeight w700
/// 미선택: color C.lvL, border C.lv.withValues(alpha:0.20), text C.lvD
class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? C.lv : C.lv.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : C.lvD,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
