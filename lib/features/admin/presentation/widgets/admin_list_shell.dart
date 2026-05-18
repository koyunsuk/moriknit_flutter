// 어드민 목록 공통 쉘 (CSS 개념).
// - 테이블 헤더 (컬럼명 sticky)
// - 1줄 row (높이 ≈ 56px)
// - 검색바 + 카운트 + 우상단 액션
// - 빈 상태 placeholder
// - 다중 선택 + 일괄 액션 (이슈 #805)
//
// 모든 어드민 목록은 이 쉘을 사용. 색상/크기/간격은 AdminTableTheme 토큰 참조.

import 'package:flutter/material.dart';

import '../../../../core/theme/admin_table_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

/// 컬럼 정의 (헤더 + flex).
class AdminColumn {
  final String label;
  final int flex;
  final TextAlign align;

  /// 컬럼 너비 고정 (flex 무시). null이면 flex 사용.
  final double? fixedWidth;

  const AdminColumn({
    required this.label,
    this.flex = 1,
    this.align = TextAlign.start,
    this.fixedWidth,
  });
}

/// 한 줄 row 정의.
class AdminRow {
  /// 각 컬럼에 대응하는 셀 위젯. columns 길이와 일치해야 함.
  final List<Widget> cells;

  /// 좌측 accent bar 색 (선택).
  final Color? accent;

  /// 행 전체 클릭 콜백.
  final VoidCallback? onTap;

  /// 선택 상태(하이라이트).
  final bool selected;

  const AdminRow({
    required this.cells,
    this.accent,
    this.onTap,
    this.selected = false,
  });
}

/// 일괄 액션 정의 (다중 선택 시 노출).
class AdminBulkAction<T> {
  final String label;
  final IconData icon;
  final Color? accent;
  final bool requireConfirm;
  final String? confirmMessage;
  final String loadingMessage;
  final Future<void> Function(List<T> selected) onTap;

  const AdminBulkAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent,
    this.requireConfirm = false,
    this.confirmMessage,
    this.loadingMessage = '처리 중입니다.',
  });
}

/// 어드민 목록 공통 쉘.
class AdminListShell<T> extends StatefulWidget {
  /// 좌상단 타이틀 (예: "회원").
  final String title;

  /// 좌상단 아이콘 (선택).
  final IconData? icon;

  /// 컬럼 정의.
  final List<AdminColumn> columns;

  /// 항목 데이터.
  final List<T> items;

  /// 항목 → AdminRow 변환.
  final AdminRow Function(BuildContext context, T item) rowBuilder;

  /// 검색바 hint. null이면 검색바 표시 안 함.
  final String? searchHint;

  /// 검색 변경 콜백.
  final ValueChanged<String>? onSearchChanged;

  /// 우상단 액션 (예: + 새 글 버튼).
  final Widget? trailing;

  /// 빈 상태 메시지.
  final String emptyMessage;

  /// 로딩 상태.
  final bool isLoading;

  /// 에러 메시지 (null 아니면 에러 상태로 표시).
  final String? errorMessage;

  /// 카운트 라벨 포맷 (예: "회원 전체 ({n})"). {n}이 개수로 치환됨.
  /// null이면 "$title 전체 (N)" 자동 생성.
  final String? countFormat;

  // ── 다중 선택 + 일괄 액션 (이슈 #805) ─────────────────────────────────────
  /// 다중 선택 모드 활성화.
  final bool selectable;

  /// 일괄 액션 목록 (selectable=true 일 때만 노출).
  final List<AdminBulkAction<T>>? bulkActions;

  /// 고유 키 추출 함수 (선택 상태 추적용). selectable=true 면 필수.
  final String Function(T item)? itemKey;

  const AdminListShell({
    super.key,
    required this.title,
    this.icon,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.searchHint,
    this.onSearchChanged,
    this.trailing,
    this.emptyMessage = '항목이 없습니다.',
    this.isLoading = false,
    this.errorMessage,
    this.countFormat,
    this.selectable = false,
    this.bulkActions,
    this.itemKey,
  });

  @override
  State<AdminListShell<T>> createState() => _AdminListShellState<T>();
}

class _AdminListShellState<T> extends State<AdminListShell<T>> {
  final Set<String> _selectedKeys = <String>{};

  String _keyOf(T item) {
    final extractor = widget.itemKey;
    if (extractor == null) return identityHashCode(item).toString();
    return extractor(item);
  }

  bool _isSelected(T item) => _selectedKeys.contains(_keyOf(item));

  List<T> _selectedItems() {
    return widget.items.where(_isSelected).toList();
  }

  void _toggleItem(T item, bool? value) {
    final key = _keyOf(item);
    setState(() {
      if (value == true) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedKeys
          ..clear()
          ..addAll(widget.items.map(_keyOf));
      } else {
        _selectedKeys.clear();
      }
    });
  }

  bool? _allSelectedState() {
    if (widget.items.isEmpty) return false;
    final total = widget.items.length;
    final selected = widget.items.where(_isSelected).length;
    if (selected == 0) return false;
    if (selected == total) return true;
    return null; // tri-state
  }

  @override
  void didUpdateWidget(covariant AdminListShell<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 데이터가 바뀌면 더 이상 존재하지 않는 키는 정리.
    if (widget.selectable) {
      final currentKeys = widget.items.map(_keyOf).toSet();
      final stale = _selectedKeys.difference(currentKeys);
      if (stale.isNotEmpty) {
        _selectedKeys.removeAll(stale);
      }
    }
  }

  Future<void> _runBulkAction(AdminBulkAction<T> action) async {
    final selected = _selectedItems();
    if (selected.isEmpty) return;

    if (action.requireConfirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.label),
          content: Text(
            action.confirmMessage ??
                '${selected.length}개 항목에 대해 "${action.label}"을(를) 실행할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: action.accent),
              child: Text(action.label),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: action.loadingMessage,
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          await action.onTap(selected);
        },
      );
      if (!mounted) return;
      setState(_selectedKeys.clear);
      showSavedSnackBar(
        messenger,
        message: '${selected.length}개 항목 처리 완료',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdminTableTheme.of(context);
    final countLabel = widget.countFormat != null
        ? widget.countFormat!.replaceAll('{n}', widget.items.length.toString())
        : '${widget.title} 전체 (${widget.items.length})';

    final hasSelection = widget.selectable && _selectedKeys.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 툴바: 카운트 + 검색바 + trailing ───────────────────────────────
        Padding(
          padding: theme.toolbarPadding,
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: theme.cellText),
                const SizedBox(width: 8),
              ],
              Text(
                widget.isLoading ? '${widget.title} 로딩 중...' : countLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.cellText,
                ),
              ),
              const Spacer(),
              if (widget.searchHint != null) ...[
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: widget.onSearchChanged,
                  ),
                ),
                if (widget.trailing != null) const SizedBox(width: 8),
              ],
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
        // ── 선택 액션바 (선택된 항목 있을 때만) ─────────────────────────────
        if (hasSelection)
          _AdminBulkActionBar<T>(
            selectedCount: _selectedKeys.length,
            actions: widget.bulkActions ?? const [],
            onClear: () => setState(_selectedKeys.clear),
            onAction: _runBulkAction,
            theme: theme,
          ),
        // ── 헤더 row ──────────────────────────────────────────────────────
        _AdminTableHeader(
          columns: widget.columns,
          theme: theme,
          selectable: widget.selectable,
          checkboxState: _allSelectedState(),
          onCheckboxChanged: _toggleAll,
        ),
        // ── 본문 ──────────────────────────────────────────────────────────
        Expanded(child: _buildBody(context, theme)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AdminTableTheme theme) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '오류: ${widget.errorMessage}',
            style: TextStyle(color: Colors.red.shade400, fontSize: 13),
          ),
        ),
      );
    }
    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.emptyMessage,
            style: TextStyle(color: theme.cellMuted, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: theme.divider),
      itemBuilder: (context, i) {
        final item = widget.items[i];
        final row = widget.rowBuilder(context, item);
        return AdminListRowView(
          columns: widget.columns,
          row: row,
          selectable: widget.selectable,
          isSelected: widget.selectable ? _isSelected(item) : false,
          onSelectedChanged: widget.selectable
              ? (v) => _toggleItem(item, v)
              : null,
        );
      },
    );
  }
}

/// 다중 선택 시 표시되는 액션바.
class _AdminBulkActionBar<T> extends StatelessWidget {
  final int selectedCount;
  final List<AdminBulkAction<T>> actions;
  final VoidCallback onClear;
  final Future<void> Function(AdminBulkAction<T>) onAction;
  final AdminTableTheme theme;

  const _AdminBulkActionBar({
    required this.selectedCount,
    required this.actions,
    required this.onClear,
    required this.onAction,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF2FF), // indigo-50
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.indigo.shade400),
          const SizedBox(width: 8),
          Text(
            '$selectedCount개 선택됨',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.cellText,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('선택 해제', style: TextStyle(fontSize: 12)),
          ),
          const Spacer(),
          ...actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ElevatedButton.icon(
                onPressed: () => onAction(a),
                style: ElevatedButton.styleFrom(
                  backgroundColor: a.accent ?? Colors.indigo.shade400,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: Icon(a.icon, size: 14),
                label: Text(a.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 어드민 테이블 헤더 row.
class _AdminTableHeader extends StatelessWidget {
  final List<AdminColumn> columns;
  final AdminTableTheme theme;
  final bool selectable;
  final bool? checkboxState;
  final ValueChanged<bool?>? onCheckboxChanged;

  const _AdminTableHeader({
    required this.columns,
    required this.theme,
    this.selectable = false,
    this.checkboxState,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: theme.headerHeight,
      decoration: BoxDecoration(
        color: theme.headerBg,
        border: Border(
          top: BorderSide(color: theme.divider),
          bottom: BorderSide(color: theme.divider),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: theme.rowPaddingHorizontal),
      child: Row(
        children: [
          if (selectable)
            SizedBox(
              width: 32,
              child: Checkbox(
                value: checkboxState,
                tristate: true,
                onChanged: onCheckboxChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ..._interleaveCells(
            columns: columns,
            theme: theme,
            cellBuilder: (col) => Text(
              col.label,
              textAlign: col.align,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.headerText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 어드민 목록 본문 row (1줄, 높이 = AdminTableTheme.rowHeight).
class AdminListRowView extends StatefulWidget {
  final List<AdminColumn> columns;
  final AdminRow row;
  final bool selectable;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const AdminListRowView({
    super.key,
    required this.columns,
    required this.row,
    this.selectable = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  State<AdminListRowView> createState() => _AdminListRowViewState();
}

class _AdminListRowViewState extends State<AdminListRowView> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdminTableTheme.of(context);
    final r = widget.row;
    final isHighlighted = r.selected || widget.isSelected;
    final bg = isHighlighted
        ? theme.rowSelectedBg
        : (_hovered ? theme.rowHoverBg : theme.rowBg);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: r.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: r.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: theme.rowHeight,
          color: bg,
          child: Row(
            children: [
              // 좌측 accent bar
              Container(
                width: 3,
                height: theme.rowHeight,
                color: r.accent ?? Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.rowPaddingHorizontal,
                  ),
                  child: Row(
                    children: [
                      if (widget.selectable)
                        SizedBox(
                          width: 32,
                          child: Checkbox(
                            value: widget.isSelected,
                            onChanged: widget.onSelectedChanged,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ..._interleaveCells(
                        columns: widget.columns,
                        theme: theme,
                        cellBuilder: null, // 사용 안 함 — externalCells 사용
                        externalCells: r.cells,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 컬럼 정의에 맞춰 셀을 배치 (flex + fixedWidth + gap 처리).
/// cellBuilder가 있으면 헤더용. externalCells가 있으면 본문용.
List<Widget> _interleaveCells({
  required List<AdminColumn> columns,
  required AdminTableTheme theme,
  Widget Function(AdminColumn col)? cellBuilder,
  List<Widget>? externalCells,
}) {
  final widgets = <Widget>[];
  for (var i = 0; i < columns.length; i++) {
    final col = columns[i];
    final cell = cellBuilder != null
        ? cellBuilder(col)
        : (i < (externalCells?.length ?? 0)
            ? externalCells![i]
            : const SizedBox.shrink());
    final wrapped = Align(
      alignment: switch (col.align) {
        TextAlign.center => Alignment.center,
        TextAlign.end => Alignment.centerRight,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: cell,
    );
    if (col.fixedWidth != null) {
      widgets.add(SizedBox(width: col.fixedWidth, child: wrapped));
    } else {
      widgets.add(Expanded(flex: col.flex, child: wrapped));
    }
    if (i < columns.length - 1) {
      widgets.add(SizedBox(width: theme.cellGap));
    }
  }
  return widgets;
}

/// 빈 상태 안내 placeholder (검색 결과 없음 등 인라인 표시용).
class AdminEmptyPlaceholder extends StatelessWidget {
  final String message;
  final IconData? icon;

  const AdminEmptyPlaceholder({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdminTableTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28, color: theme.cellMuted),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: TextStyle(color: theme.cellMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 셀 내부에서 자주 쓰이는 텍스트 도우미.
class AdminCellText extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  final double? fontSize;
  final int maxLines;
  final TextAlign textAlign;

  const AdminCellText(
    this.text, {
    super.key,
    this.bold = false,
    this.muted = false,
    this.fontSize,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdminTableTheme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: muted ? theme.cellMuted : theme.cellText,
        fontSize: fontSize ?? (bold ? 13 : 12.5),
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}

/// 셀 내부에서 자주 쓰이는 라벨/서브라벨 컬럼.
class AdminCellTwoLine extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AdminCellTwoLine({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AdminCellText(title, bold: true),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          AdminCellText(subtitle!, muted: true, fontSize: 11),
        ],
      ],
    );
  }
}

/// 상태/카테고리 배지 (둥근 칩).
class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AdminBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
