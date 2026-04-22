import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/pattern_chart.dart';

/// 그리드 크기 설정 다이얼로그
/// 반환값: GridSizeResult(rows, cols, mode) 또는 null (취소)
class GridSizeResult {
  final int rows;
  final int cols;
  final ChartMode mode;
  final String title;
  final bool mirrorMode;
  final String? category;
  final DateTime createdAt;
  final String? coverImagePath;

  const GridSizeResult({
    required this.rows,
    required this.cols,
    this.mode = ChartMode.symbol,
    this.title = '',
    this.mirrorMode = false,
    this.category,
    required this.createdAt,
    this.coverImagePath,
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
  late TextEditingController _titleCtrl;
  late ChartMode _mode;
  String? _error;

  // 새 도안 전용 추가 필드
  bool _mirrorMode = false;
  String? _category;
  DateTime _createdAt = DateTime.now();
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    _rowsCtrl = TextEditingController(text: '${widget.initialRows}');
    _colsCtrl = TextEditingController(text: '${widget.initialCols}');
    _titleCtrl = TextEditingController();
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
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover(ImageSource source) async {
    if (kIsWeb) return; // 웹: dart:io File 사용 불가, 모바일 전용
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 800);
    if (picked != null) setState(() => _coverImagePath = picked.path);
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
    // 새 도안 모드: 제목 필수 검사
    if (!widget.isEdit) {
      final titleText = _titleCtrl.text.trim();
      if (titleText.isEmpty) {
        setState(() => _error = '도안 제목을 입력해 주세요.');
        return;
      }
    }
    Navigator.of(context).pop(
      GridSizeResult(
        rows: rows,
        cols: cols,
        mode: _mode,
        title: widget.isEdit ? '' : _titleCtrl.text.trim(),
        mirrorMode: widget.isEdit ? false : _mirrorMode,
        category: widget.isEdit ? null : _category,
        createdAt: widget.isEdit ? DateTime.now() : _createdAt,
        coverImagePath: widget.isEdit ? null : _coverImagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEdit) {
      return _buildNewPatternDialog(context);
    }
    return _buildEditDialog(context);
  }

  /// 기존 그리드 크기 변경 다이얼로그 (isEdit=true) — 기존 UI 그대로 유지
  Widget _buildEditDialog(BuildContext context) {
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
              Text('그리드 크기 변경', style: T.h2),
              const SizedBox(height: 6),
              Text(
                '코 수(가로)와 단 수(세로)를 입력하세요.\n셀 비율은 뜨개 코 실제 비율(4:6)로 표시됩니다.',
                style: T.caption.copyWith(color: C.tx2),
              ),
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
              _GridPreview(rowsCtrl: _rowsCtrl, colsCtrl: _colsCtrl),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: T.caption.copyWith(color: const Color(0xFFDC2626))),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: C.bd2),
                        foregroundColor: C.tx2,
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _ConfirmButton(onTap: _confirm)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 새 도안 만들기 다이얼로그 (isEdit=false) — 7단계 폼
  Widget _buildNewPatternDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: C.bg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Expanded(child: Text('새 도안 만들기', style: T.h2)),
                  IconButton(
                    icon: Icon(Icons.close, color: C.tx2, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                '도안 기본 정보를 입력하고 시작하세요.',
                style: T.caption.copyWith(color: C.tx2),
              ),
            ),
            const SizedBox(height: 16),
            // 폼 스크롤 영역
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildNewPatternForm(),
              ),
            ),
            // 에러 메시지
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(_error!, style: T.caption.copyWith(color: const Color(0xFFDC2626))),
              ),
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: _ConfirmButton(onTap: _confirm, label: '시작하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPatternForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 도안 제목
        _FormSection(
          number: 1,
          title: '도안 제목',
          isRequired: true,
          helpText: '이 도안을 구분하는 이름이에요.\n나중에 수정할 수 있어요.',
          child: TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: '예: 케이블 카디건 앞판',
              filled: true,
              fillColor: C.gx,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 2. 도안 종류
        _FormSection(
          number: 2,
          title: '도안 종류',
          isRequired: true,
          helpText: '기호차트: 겉뜨기·안뜨기 등 뜨개 기호로 표현\n컬러차트: 색상 블록으로 표현하는 도안',
          child: Row(
            children: [
              _ModeChip(
                label: '기호차트',
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
        ),
        const SizedBox(height: 16),
        // 3. 그리드 크기
        _FormSection(
          number: 3,
          title: '그리드 크기',
          isRequired: true,
          helpText: '가로 코 수와 세로 단 수를 입력하세요.\n나중에 크기 변경도 가능해요.',
          child: Column(
            children: [
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
              const SizedBox(height: 8),
              _GridPreview(rowsCtrl: _rowsCtrl, colsCtrl: _colsCtrl),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 4. 대칭 모드
        _FormSection(
          number: 4,
          title: '대칭 모드',
          isRequired: true,
          helpText: '왼쪽 절반만 그리면 오른쪽이 자동으로\n거울처럼 채워져요.\n스웨터·숄 등 좌우 대칭 도안에 유용해요.',
          child: Row(
            children: [
              _ModeChip(
                label: '대칭 사용',
                active: _mirrorMode,
                onTap: () => setState(() => _mirrorMode = true),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: '일반 모드',
                active: !_mirrorMode,
                onTap: () => setState(() => _mirrorMode = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 5. 커버 이미지
        _FormSection(
          number: 5,
          title: '커버 이미지',
          isRequired: false,
          helpText: '도안 목록에서 표지로 보일 사진이에요.\n없어도 괜찮아요.',
          child: _coverImagePath != null
              ? Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_coverImagePath!),
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _coverImagePath = null),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _ImagePickButton(
                      icon: Icons.camera_alt_rounded,
                      label: '촬영',
                      onTap: () => _pickCover(ImageSource.camera),
                    ),
                    const SizedBox(width: 8),
                    _ImagePickButton(
                      icon: Icons.photo_library_rounded,
                      label: '갤러리',
                      onTap: () => _pickCover(ImageSource.gallery),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        // 6. 작성일
        _FormSection(
          number: 6,
          title: '작성일',
          isRequired: false,
          badge: '자동',
          helpText: '도안 작성 날짜예요.\n오늘 날짜가 자동으로 입력되지만 바꿀 수 있어요.',
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _createdAt,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _createdAt = picked);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.bd),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_createdAt.year}년 ${_createdAt.month}월 ${_createdAt.day}일',
                      style: T.body,
                    ),
                  ),
                  Icon(Icons.calendar_today_rounded, size: 18, color: C.mu),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 7. 카테고리
        _FormSection(
          number: 7,
          title: '카테고리',
          isRequired: false,
          helpText: '도안을 분류하는 태그예요.\n나중에 필터링에 사용돼요.',
          child: Row(
            children: [
              _ModeChip(
                label: '의상',
                active: _category == '의상',
                onTap: () => setState(() => _category = _category == '의상' ? null : '의상'),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: '소품',
                active: _category == '소품',
                onTap: () => setState(() => _category = _category == '소품' ? null : '소품'),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: '기타',
                active: _category == '기타',
                onTap: () => setState(() => _category = _category == '기타' ? null : '기타'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
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

/// 새 도안 폼 섹션 래퍼 — 번호 원 + 제목 + 필수/선택 뱃지 + ? 도움말 버튼
class _FormSection extends StatelessWidget {
  final int number;
  final String title;
  final bool isRequired;
  final String? badge; // 커스텀 뱃지 텍스트 (예: '자동')
  final String helpText;
  final Widget child;

  const _FormSection({
    required this.number,
    required this.title,
    required this.isRequired,
    required this.helpText,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = badge ?? (isRequired ? '필수' : '선택');
    final badgeColor = badge != null
        ? C.mu
        : isRequired
            ? C.lv
            : C.mu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // 번호 원
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: C.lv,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 제목
            Expanded(
              child: Text(
                title,
                style: T.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // ? 도움말 버튼
            GestureDetector(
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(title, style: T.h3),
                    content: Text(helpText, style: T.body),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(Icons.help_outline_rounded, size: 18, color: C.mu),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// 커버 이미지 선택 버튼 (카메라 / 갤러리)
class _ImagePickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: C.tx2),
            const SizedBox(width: 6),
            Text(label, style: T.caption.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
