// lib/features/pattern/presentation/widgets/guide_path_editor_view.dart
//
// 이슈 #668 — 자유 Path 도안 에디터 뷰 (코바늘 왕관/꽃잎/Granny 같은 비정형 모티프).
//
// 구조 (위 → 아래):
//   [툴바]   Grid / Arc / Square / Pen / Cut / Trim + Undo + 단 추가
//   [단 탭]  R1 R2 R3 ... + 추가  (탭하면 해당 단 활성화)
//   [패턴]   현재 단의 심볼 시퀀스 입력 [+] [ch] [dc] [-] [autoRotate 토글]
//   [팔레트] 코바늘/대바늘 토글 + 카테고리 + 심볼 가로 스크롤  (탭하면 패턴 시퀀스에 추가)
//   [캔버스] InteractiveViewer + GestureDetector + GuidePathView
//
// 작동 안정성 원칙
//   - 모든 콜백 try/catch 외피
//   - mounted 체크 (async 시)
//   - Undo 30단계 스냅샷
//   - 빈 chart도 정상 렌더 (rows.isEmpty 허용)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/symbol_svg_widget.dart';
import '../../../../core/widgets/mori_symbol_view.dart';
import '../../../../providers/knit_symbol_provider.dart';
import '../../domain/crochet_symbols.dart';
import '../../domain/guide_path_chart.dart';
import '../../domain/knit_symbols.dart';
import '../../domain/pattern_chart.dart';
import 'guide_path_painter.dart';
import 'round_editor_view.dart' show CraftType;
import 'svg_symbol_cache.dart';

/// 자유 Path 도안 에디터.
///
/// 부모([PatternEditorScreen])가 PatternChart를 보유하고 onChange로 변경 알림을 받는다.
/// 본 위젯은 chart.guidePathData 만 편집한다.
class GuidePathEditorView extends ConsumerStatefulWidget {
  /// 편집 대상 도안 (chartType이 guidePath 여야 함).
  final PatternChart chart;

  /// 변경 시 호출 — 부모에서 setState로 받음.
  final void Function(PatternChart) onChange;

  /// 읽기 전용 (뷰어 모드).
  final bool isReadOnly;

  const GuidePathEditorView({
    super.key,
    required this.chart,
    required this.onChange,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<GuidePathEditorView> createState() =>
      _GuidePathEditorViewState();
}

class _GuidePathEditorViewState extends ConsumerState<GuidePathEditorView> {
  // ── 편집 상태 ────────────────────────────────────────────────────
  /// 활성 도구.
  PathTool _tool = PathTool.pen;

  /// 활성 단 인덱스.
  int? _activeRowIndex;

  /// 호버 앵커 (Cut/Trim 모드 미리보기).
  ({int rowIndex, int anchorIndex})? _hoveredAnchor;

  /// 가이드 표시.
  final bool _showGuides = true;

  /// 도구 종류 (대바늘/코바늘) — 팔레트 분기.
  CraftType _craftType = CraftType.crochet;

  /// #673 — 단순 필터: null=전체 / increase / decrease / special
  String? _crochetFilter;
  String? _knitFilter;

  /// Arc 도구: 첫 번째 클릭 위치 (두 번째 클릭과 함께 호 생성).
  Offset? _arcFirstPoint;

  /// Square 도구: 드래그 시작 위치.
  Offset? _squareStartPoint;

  /// Square 도구: 드래그 현재 위치 (미리보기).
  Offset? _squareCurrentPoint;

  /// Arc 반지름 (px) — 슬라이더로 조절.
  double _arcRadius = 80;

  /// Grid 도구 — 사각 그리드 자동 생성 시 너비.
  double _gridWidth = 240;

  /// Grid 도구 — 사각 그리드 단 수.
  int _gridRows = 1;

  /// Grid 도구 — 사각 그리드 칸 수.
  int _gridCols = 8;

  /// Undo 스냅샷.
  final List<GuidePathChart> _undoStack = [];
  static const int _kMaxUndo = 30;

  /// 캔버스 크기 (LayoutBuilder에서 받음).
  Size _canvasSize = Size.zero;

  /// #668 정밀도 — 스냅 ON/OFF + 격자 간격 (px).
  bool _snapEnabled = true;
  double _gridSpacing = 16.0;

  /// #668 — 하단 패널 탭 인덱스 (-1 = 접힘, 0 = 도구, 1 = 단탭, 2 = 팔레트, 3 = 옵션).
  /// 탭으로 화면 비율 확보 (그리드 영역 최대화).
  int _bottomTab = 0;

  /// #680 — Square 도구의 corner radius (px). 0이면 직각 사각형.
  double _squareCornerRadius = 0;

  /// #680 — Pen/Line으로 그린 path의 anchor 둥글림 (활성 단 일괄 적용).
  double _pathCornerRadius = 0;

  /// #676 — Line 도구: 첫 클릭 점 (두 번째 클릭과 직선 생성).
  Offset? _lineFirstPoint;

  /// #677 — Arc 정밀 모드 ON 시 3점 입력. 기본 OFF (두 점 + 슬라이더 모드).
  bool _arcThreePointMode = false;
  Offset? _arcSecondPoint; // 3점 모드: 중간 통과점

  /// #679 — 측정 도구 임시 점들.
  final List<Offset> _measurePoints = [];

  /// #689 — 패턴 브러쉬: 현재 드래그 중인 stroke의 raw 샘플 점들.
  /// 드래그 종료 시 다운샘플링해서 RowPath.anchors로 저장.
  final List<Offset> _brushStrokePoints = [];

  /// #689 — 패턴 브러쉬: 현재 선택된 심볼 ID (팔레트에서 탭).
  /// null이면 brush 모드라도 anchor만 추가됨(빈 패턴).
  String? _brushSymbolId;

  /// #689 — 패턴 브러쉬: 심볼 간격(px). 너무 좁으면 겹침, 너무 넓으면 띄엄띄엄.
  double _brushCellWidth = 24;

  /// #689 — 패턴 브러쉬: 자동 회전 (접선 방향에 맞춰 심볼 회전).
  bool _brushAutoRotate = true;

  /// #671 — 핀치줌/팬 컨트롤러 (화면맞춤 버튼용).
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _fitToScreen() {
    _transformCtrl.value = Matrix4.identity();
  }

  // ── getter ──────────────────────────────────────────────────────
  GuidePathChart get _data =>
      widget.chart.guidePathData ?? const GuidePathChart();

  bool get _readOnly => widget.isReadOnly;

  RowPath? get _activeRow {
    if (_activeRowIndex == null) return null;
    return _data.rowByIndex(_activeRowIndex!);
  }

  // ── 변경 처리 ────────────────────────────────────────────────────
  void _pushUndo() {
    _undoStack.add(_data);
    if (_undoStack.length > _kMaxUndo) _undoStack.removeAt(0);
  }

  void _emit(GuidePathChart newData) {
    try {
      widget.onChange(widget.chart.copyWith(guidePathData: newData));
    } catch (e) {
      // ignore: avoid_print
      print('[GuidePathEditor] onChange failed: $e');
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    setState(() {
      _arcFirstPoint = null;
      _squareStartPoint = null;
      _squareCurrentPoint = null;
      _hoveredAnchor = null;
    });
    _emit(prev);
  }

  // ── 단 관리 ─────────────────────────────────────────────────────
  void _addRow() {
    if (_readOnly) return;
    _pushUndo();
    final newData = _data.addRow();
    final newRow = newData.rows.last;
    setState(() {
      _activeRowIndex = newRow.rowIndex;
    });
    _emit(newData);
  }

  void _removeRow(int rowIndex) {
    if (_readOnly) return;
    _pushUndo();
    final newData = _data.removeRow(rowIndex);
    setState(() {
      if (_activeRowIndex == rowIndex) {
        _activeRowIndex = newData.rows.isEmpty ? null : newData.rows.last.rowIndex;
      }
    });
    _emit(newData);
  }

  void _selectRow(int rowIndex) {
    setState(() {
      _activeRowIndex = rowIndex;
      _arcFirstPoint = null;
      _squareStartPoint = null;
      _squareCurrentPoint = null;
    });
  }

  // ── 패턴 시퀀스 편집 ────────────────────────────────────────────
  void _appendPatternSymbol(String symbolId) {
    if (_readOnly) return;
    if (_activeRow == null) {
      // 활성 단이 없으면 자동으로 1단 생성.
      _addRow();
    }
    final row = _activeRow;
    if (row == null) return;
    _pushUndo();
    final newRow = row.copyWith(pattern: [...row.pattern, symbolId]);
    _emit(_data.replaceRow(newRow));
  }

  void _popPatternSymbol() {
    if (_readOnly) return;
    final row = _activeRow;
    if (row == null || row.pattern.isEmpty) return;
    _pushUndo();
    final newPattern = [...row.pattern]..removeLast();
    _emit(_data.replaceRow(row.copyWith(pattern: newPattern)));
  }

  void _toggleAutoRotate() {
    if (_readOnly) return;
    final row = _activeRow;
    if (row == null) return;
    _pushUndo();
    _emit(_data.replaceRow(row.copyWith(autoRotate: !row.autoRotate)));
  }

  void _toggleClosed() {
    if (_readOnly) return;
    final row = _activeRow;
    if (row == null) return;
    _pushUndo();
    _emit(_data.replaceRow(row.copyWith(closed: !row.closed)));
  }

  // ── 캔버스 액션 ─────────────────────────────────────────────────
  /// 활성 단을 반환 (없으면 새로 만들고 활성화).
  RowPath _ensureActiveRow() {
    var row = _activeRow;
    if (row == null) {
      final newData = _data.addRow();
      _activeRowIndex = newData.rows.last.rowIndex;
      _emit(newData);
      row = newData.rows.last;
    }
    return row;
  }

  /// Pen: 클릭 = 직선 앵커 추가.
  void _penAddAnchor(Offset point) {
    if (_readOnly) return;
    _pushUndo();
    final row = _ensureActiveRow();
    final newAnchors = [
      ...row.anchors,
      PathAnchor(position: point, nextEdgeType: AnchorType.line),
    ];
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
  }

  /// Arc: 두 클릭(슬라이더) 또는 3점(시작/중간/끝) 모드 — #677.
  void _arcHandleTap(Offset point) {
    if (_readOnly) return;
    if (_arcThreePointMode) {
      // 3점 모드: 첫 → 둘째(중간) → 셋째(끝).
      if (_arcFirstPoint == null) {
        setState(() => _arcFirstPoint = point);
        return;
      }
      if (_arcSecondPoint == null) {
        setState(() => _arcSecondPoint = point);
        return;
      }
      // 3점으로 외접원 반지름 계산.
      final r = _arcRadiusFrom3Points(
          _arcFirstPoint!, _arcSecondPoint!, point);
      _pushUndo();
      final row = _ensureActiveRow();
      final newAnchors = [
        ...row.anchors,
        PathAnchor(
          position: _arcFirstPoint!,
          nextEdgeType: AnchorType.arc,
          arcRadius: r,
        ),
        PathAnchor(position: point, nextEdgeType: AnchorType.line),
      ];
      setState(() {
        _arcFirstPoint = null;
        _arcSecondPoint = null;
      });
      _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
      return;
    }
    // 기본 두 점 + 슬라이더 모드.
    if (_arcFirstPoint == null) {
      setState(() => _arcFirstPoint = point);
      return;
    }
    _pushUndo();
    final row = _ensureActiveRow();
    final start = _arcFirstPoint!;
    final newAnchors = [
      ...row.anchors,
      PathAnchor(
        position: start,
        nextEdgeType: AnchorType.arc,
        arcRadius: _arcRadius,
      ),
      PathAnchor(position: point, nextEdgeType: AnchorType.line),
    ];
    setState(() => _arcFirstPoint = null);
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
  }

  /// Square: 드래그로 사각형.
  void _squareApply(Offset start, Offset end) {
    if (_readOnly) return;
    _pushUndo();
    final row = _ensureActiveRow();
    // 사각형 4 코너 (시계 방향).
    final tl = Offset(math.min(start.dx, end.dx), math.min(start.dy, end.dy));
    final br = Offset(math.max(start.dx, end.dx), math.max(start.dy, end.dy));
    final tr = Offset(br.dx, tl.dy);
    final bl = Offset(tl.dx, br.dy);
    // #680 — Square corner radius 적용 (4 corner anchor 모두 동일 radius).
    final r = _squareCornerRadius;
    final newAnchors = [
      ...row.anchors,
      PathAnchor(position: tl, nextEdgeType: AnchorType.line, cornerRadius: r),
      PathAnchor(position: tr, nextEdgeType: AnchorType.line, cornerRadius: r),
      PathAnchor(position: br, nextEdgeType: AnchorType.line, cornerRadius: r),
      PathAnchor(position: bl, nextEdgeType: AnchorType.line, cornerRadius: r),
    ];
    _emit(_data.replaceRow(
      row.copyWith(anchors: newAnchors, closed: true),
    ));
  }

  /// #680 — 활성 단의 모든 anchor에 cornerRadius 일괄 적용 (Pen/Line/연속삼각형 둥글림).
  void _applyPathCornerRadius(double r) {
    if (_readOnly) return;
    final row = _activeRow;
    if (row == null || row.anchors.isEmpty) return;
    setState(() => _pathCornerRadius = r);
    _pushUndo();
    final newAnchors = row.anchors
        .map((a) => a.copyWith(cornerRadius: r))
        .toList();
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
  }

  /// Trim: 끝 앵커 클릭 시 삭제.
  void _trimHandleTap(Offset point) {
    if (_readOnly) return;
    final hit = GuidePathPainter.hitTestAnchor(_data, point, 18);
    if (hit == null) return;
    final row = _data.rowByIndex(hit.rowIndex);
    if (row == null || row.anchors.isEmpty) return;
    // 끝 앵커만 허용 (안전).
    if (hit.anchorIndex != row.anchors.length - 1 && hit.anchorIndex != 0) return;
    _pushUndo();
    final newAnchors = [...row.anchors]..removeAt(hit.anchorIndex);
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
  }

  /// Cut: 앵커 클릭 시 분할 (해당 앵커 제거).
  void _cutHandleTap(Offset point) {
    if (_readOnly) return;
    final hit = GuidePathPainter.hitTestAnchor(_data, point, 18);
    if (hit == null) return;
    final row = _data.rowByIndex(hit.rowIndex);
    if (row == null || row.anchors.isEmpty) return;
    _pushUndo();
    final newAnchors = [...row.anchors]..removeAt(hit.anchorIndex);
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
  }

  /// Grid: 사각 그리드 자동 생성 (현재 단을 새 path로 덮어씀).
  void _applyGrid() {
    if (_readOnly) return;
    if (_canvasSize == Size.zero) return;
    _pushUndo();
    // 캔버스 가운데에 배치.
    final cx = _canvasSize.width / 2;
    final cy = _canvasSize.height / 2;
    final w = _gridWidth.clamp(40.0, _canvasSize.width).toDouble();
    final cellW = w / _gridCols;
    final cellH = cellW; // 정사각

    final newData = _data;
    GuidePathChart updated = newData;
    for (int r = 0; r < _gridRows; r++) {
      final y = cy + (r - (_gridRows - 1) / 2) * cellH;
      final left = cx - w / 2;
      final right = cx + w / 2;
      final anchors = [
        PathAnchor(position: Offset(left, y), nextEdgeType: AnchorType.line),
        PathAnchor(position: Offset(right, y), nextEdgeType: AnchorType.line),
      ];
      // 1단부터 자동 생성 — 기존 단 인덱스 다음부터 추가.
      final maxIdx = updated.rows.isEmpty
          ? 0
          : updated.rows.map((r) => r.rowIndex).reduce(math.max);
      updated = updated.addRow(RowPath(
        rowIndex: maxIdx + 1,
        anchors: anchors,
        cellCount: _gridCols,
      ));
    }
    setState(() {
      _activeRowIndex = updated.rows.isEmpty ? null : updated.rows.last.rowIndex;
    });
    _emit(updated);
  }

  // ── #668 — 스냅: 인근 앵커 우선, 그리드 후순위 ───────────────────
  /// 스냅 ON일 때만 적용. 우선순위: (1) 기존 앵커 14px 이내 → 그 위치 / (2) 그리드 16px 격자 / (3) 원본.
  /// Cut/Trim은 앵커 위에서 정확히 동작해야 하므로 호출 측에서 OFF.
  Offset _snap(Offset point) {
    if (!_snapEnabled) return point;
    const anchorRadius = 14.0;
    for (final row in _data.rows) {
      for (final a in row.anchors) {
        if ((a.position - point).distance <= anchorRadius) {
          return a.position;
        }
      }
    }
    return GuidePathPainter.snapToGrid(point, _gridSpacing);
  }

  // ── 통합 캔버스 핸들러 (도구별 분기) ─────────────────────────────
  void _handleCanvasTap(Offset point) {
    try {
      // Cut/Trim은 정확한 클릭이 필요하므로 스냅 미적용.
      final snapped = (_tool == PathTool.cut || _tool == PathTool.trim)
          ? point
          : _snap(point);
      switch (_tool) {
        case PathTool.pen:
          _penAddAnchor(snapped);
          break;
        case PathTool.line:
          _lineHandleTap(snapped);
          break;
        case PathTool.arc:
          _arcHandleTap(snapped);
          break;
        case PathTool.cut:
          _cutHandleTap(snapped);
          break;
        case PathTool.trim:
          _trimHandleTap(snapped);
          break;
        case PathTool.ruler:
        case PathTool.protractor:
          _measureHandleTap(snapped);
          break;
        case PathTool.grid:
        case PathTool.square:
        case PathTool.brush:
          // grid/square/brush는 다른 핸들러에서 처리 (pan 기반).
          break;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[GuidePathEditor] tap handler error: $e');
    }
  }

  // ── #676 — Line 도구: 두 점 직선 ───────────────────────────────────
  void _lineHandleTap(Offset point) {
    if (_lineFirstPoint == null) {
      setState(() => _lineFirstPoint = point);
      return;
    }
    final start = _lineFirstPoint!;
    final end = point;
    if ((start - end).distance < 4) {
      setState(() => _lineFirstPoint = null);
      return;
    }
    if (_activeRow == null) _addRow();
    final row = _activeRow;
    if (row == null) return;
    _pushUndo();
    final newAnchors = [
      ...row.anchors,
      PathAnchor(position: start, nextEdgeType: AnchorType.line),
      PathAnchor(position: end, nextEdgeType: AnchorType.line),
    ];
    _emit(_data.replaceRow(row.copyWith(anchors: newAnchors)));
    setState(() => _lineFirstPoint = null);
  }

  // ── #689 — 패턴 브러쉬 (드래그한 path 위에 심볼 자동 배치) ──────────
  /// 브러쉬 stroke 시작 — 드래그 첫 점 캡처.
  void _brushStart(Offset point) {
    if (_readOnly) return;
    _brushStrokePoints
      ..clear()
      ..add(point);
  }

  /// 브러쉬 stroke 진행 중 — pan update마다 점 추가.
  /// 인접 점이 너무 가까우면(<3px) 스킵해서 메모리 절약 + 노이즈 감소.
  void _brushUpdate(Offset point) {
    if (_readOnly) return;
    if (_brushStrokePoints.isEmpty) {
      _brushStrokePoints.add(point);
      return;
    }
    final last = _brushStrokePoints.last;
    if ((point - last).distance < 3) return;
    _brushStrokePoints.add(point);
    // setState로 미리보기 갱신 (오버레이는 별도 painter로 그림).
    setState(() {});
  }

  /// 브러쉬 stroke 종료 — 캡처한 점들을 다운샘플링해서 RowPath로 저장.
  /// 너무 가까운 점 제거(8px 이하) → 부드러운 path 생성.
  void _brushEnd() {
    if (_readOnly) return;
    if (_brushStrokePoints.length < 2) {
      _brushStrokePoints.clear();
      return;
    }
    // 다운샘플링: 8px 이상 떨어진 점만 유지 (성능 + 부드러움).
    final downsampled = <Offset>[_brushStrokePoints.first];
    const minSpacing = 8.0;
    for (final p in _brushStrokePoints.skip(1)) {
      if ((p - downsampled.last).distance >= minSpacing) {
        downsampled.add(p);
      }
    }
    // 마지막 점이 빠졌으면 추가 (drag end 위치 유지).
    final lastRaw = _brushStrokePoints.last;
    if ((lastRaw - downsampled.last).distance > 1) {
      downsampled.add(lastRaw);
    }
    _brushStrokePoints.clear();

    if (downsampled.length < 2) return;

    _pushUndo();
    final row = _ensureActiveRow();
    // 새 brush stroke로 row의 anchors를 덮어씀 (이전 stroke 누적 X — 한 단=한 stroke).
    //   기존 데이터 보존하려면 새 row를 생성하는 방식도 가능 — 현재는 명확성 우선.
    final anchors = downsampled
        .map((p) => PathAnchor(position: p, nextEdgeType: AnchorType.line))
        .toList();
    // pattern: 선택된 brush 심볼로 채움 (단일 반복 — symbolAt이 modulo로 wrap).
    final pattern = _brushSymbolId != null ? [_brushSymbolId!] : row.pattern;
    final updated = row.copyWith(
      anchors: anchors,
      pattern: pattern,
      cellWidth: _brushCellWidth,
      autoRotate: _brushAutoRotate,
    );
    _emit(_data.replaceRow(updated));
  }

  // ── #679 — 측정 (자/각도기) ────────────────────────────────────────
  void _measureHandleTap(Offset point) {
    final required = _tool == PathTool.protractor ? 3 : 2;
    setState(() {
      if (_measurePoints.length >= required) {
        _measurePoints.clear();
      }
      _measurePoints.add(point);
    });
  }

  // ── #677 — 3점 외접원 반지름 계산 ──────────────────────────────────
  /// 세 점을 지나는 원의 반지름. 동일선상이면 큰 값(직선 근사) 반환.
  double _arcRadiusFrom3Points(Offset a, Offset b, Offset c) {
    final ax = a.dx, ay = a.dy;
    final bx = b.dx, by = b.dy;
    final cx = c.dx, cy = c.dy;
    final d = 2 *
        (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    if (d.abs() < 1e-6) return 1000.0; // 동일선상
    final ux = ((ax * ax + ay * ay) * (by - cy) +
            (bx * bx + by * by) * (cy - ay) +
            (cx * cx + cy * cy) * (ay - by)) /
        d;
    final uy = ((ax * ax + ay * ay) * (cx - bx) +
            (bx * bx + by * by) * (ax - cx) +
            (cx * cx + cy * cy) * (bx - ax)) /
        d;
    final r = math.sqrt((ax - ux) * (ax - ux) + (ay - uy) * (ay - uy));
    return r.clamp(8.0, 2000.0);
  }

  // ── #678 — 회전 복제 (만다라/꽃잎 N등분) ──────────────────────────
  /// 활성 단의 path를 N회 회전 복제. 각 복제는 별도 row로 추가.
  /// 회전 중심 = 캔버스 중심.
  void _rotateClone(int n) {
    if (_readOnly) return;
    final row = _activeRow;
    if (row == null || row.anchors.isEmpty) return;
    if (n < 2 || n > 64) return;
    final cx = _canvasSize.width / 2;
    final cy = _canvasSize.height / 2;
    if (cx <= 0 || cy <= 0) return;

    _pushUndo();
    var newData = _data;
    for (int k = 1; k < n; k++) {
      final angle = 2 * math.pi * k / n;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final rotatedAnchors = row.anchors.map((a) {
        final dx = a.position.dx - cx;
        final dy = a.position.dy - cy;
        final rx = dx * cos - dy * sin + cx;
        final ry = dx * sin + dy * cos + cy;
        return PathAnchor(
          position: Offset(rx, ry),
          nextEdgeType: a.nextEdgeType,
          arcRadius: a.arcRadius,
          handleIn: a.handleIn,
          handleOut: a.handleOut,
        );
      }).toList();
      newData = newData.addRow(
        RowPath(
          rowIndex: 0, // addRow가 자동 설정
          anchors: rotatedAnchors,
          pattern: row.pattern,
          autoRotate: row.autoRotate,
          cellWidth: row.cellWidth,
          cellCount: row.cellCount,
        ),
      );
    }
    _emit(newData);
  }

  // ── #678 — 회전 복제 다이얼로그 ────────────────────────────────────
  Future<void> _showRotateCloneDialog() async {
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회전 복제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('활성 단의 path를 캔버스 중심 기준으로 N등분 회전 복제합니다.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in const [4, 6, 8, 12, 16])
                  ActionChip(
                    label: Text('$n 등분'),
                    onPressed: () => Navigator.pop(ctx, n),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (n != null && mounted) {
      _rotateClone(n);
    }
  }

  // ── 빌드 ────────────────────────────────────────────────────────
  // #668/#673 — 탭 구조로 화면 비율 확보 (캔버스 최대화).
  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(svgSymbolCacheProvider);
    final svgUrls = ref.watch(knitSymbolSvgUrlProvider);
    cache.setSvgUrls(svgUrls);
    return Column(
      children: [
        // 1) 그리드 (메인) — 화면 대부분.
        Expanded(child: _buildCanvas(cache)),
        // 2) 활성 단 패턴 시퀀스 — 항상 표시 (작업 진행 즉시 확인).
        if (!_readOnly && _activeRow != null) _buildPatternRow(),
        // 3) 탭 헤더 — 한 줄.
        if (!_readOnly) _buildBottomTabBar(),
        // 4) 활성 탭 콘텐츠 — 한 영역만 표시.
        if (!_readOnly) _buildBottomTabContent(),
      ],
    );
  }

  Widget _buildBottomTabBar() {
    final tabs = [
      ('도구', Icons.build_outlined),
      ('단', Icons.format_list_numbered),
      ('심볼', Icons.brush_outlined),
      ('옵션', Icons.tune),
    ];
    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(
          top: BorderSide(color: C.bd, width: 1),
          bottom: BorderSide(color: C.bd, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _bottomTab = (_bottomTab == i) ? -1 : i;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _bottomTab == i
                        ? C.lv.withValues(alpha: 0.10)
                        : Colors.transparent,
                    border: _bottomTab == i
                        ? Border(top: BorderSide(color: C.lv, width: 2))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tabs[i].$2,
                          size: 18,
                          color: _bottomTab == i ? C.lvD : C.tx2),
                      const SizedBox(height: 2),
                      Text(tabs[i].$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _bottomTab == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _bottomTab == i ? C.lvD : C.tx2,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomTabContent() {
    switch (_bottomTab) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbar(),
            if (_tool == PathTool.arc) _buildArcControls(),
            if (_tool == PathTool.grid) _buildGridControls(),
          ],
        );
      case 1:
        return _buildRowTabs();
      case 2:
        return _buildPalette();
      case 3:
        return _buildOptionsPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  /// #668 — 옵션 패널: 스냅 ON/OFF + 격자 간격 + 가이드 토글.
  Widget _buildOptionsPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: C.bg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.grid_4x4, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Text('스냅 (앵커 + 그리드)',
                style: T.captionBold.copyWith(color: C.tx)),
            const Spacer(),
            Switch(
              value: _snapEnabled,
              activeThumbColor: C.lv,
              onChanged: (v) => setState(() => _snapEnabled = v),
            ),
          ]),
          if (_snapEnabled) ...[
            const SizedBox(height: 4),
            Row(children: [
              Text('격자 간격', style: T.caption.copyWith(color: C.tx2)),
              Expanded(
                child: Slider(
                  value: _gridSpacing,
                  min: 8,
                  max: 32,
                  divisions: 6,
                  activeColor: C.lv,
                  label: '${_gridSpacing.round()}px',
                  onChanged: (v) => setState(() => _gridSpacing = v),
                ),
              ),
              Text('${_gridSpacing.round()}px',
                  style: T.caption.copyWith(color: C.lvD)),
            ]),
          ],
          const Divider(height: 16),
          // #680 — Square 도구 corner radius (생성 시 적용).
          Row(children: [
            Icon(Icons.crop_square_outlined, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Text('사각 모서리 둥글림',
                style: T.captionBold.copyWith(color: C.tx)),
            const Spacer(),
            Text('${_squareCornerRadius.round()}px',
                style: T.caption.copyWith(color: C.lvD)),
          ]),
          Slider(
            value: _squareCornerRadius,
            min: 0,
            max: 50,
            divisions: 25,
            activeColor: C.lv,
            label: '${_squareCornerRadius.round()}px',
            onChanged: (v) => setState(() => _squareCornerRadius = v),
          ),
          // #680 — 활성 단 path anchor 일괄 둥글림 (연속 삼각형/지그재그 부드럽게).
          Row(children: [
            Icon(Icons.show_chart, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Expanded(
              child: Text('활성 단 꼭짓점 둥글림',
                  style: T.captionBold.copyWith(color: C.tx)),
            ),
            Text('${_pathCornerRadius.round()}px',
                style: T.caption.copyWith(color: C.lvD)),
          ]),
          Slider(
            value: _pathCornerRadius,
            min: 0,
            max: 50,
            divisions: 25,
            activeColor: C.lv,
            label: '${_pathCornerRadius.round()}px',
            onChanged: _activeRow == null ? null : _applyPathCornerRadius,
          ),
          // #689 — 패턴 브러쉬 옵션.
          const Divider(height: 16),
          Row(children: [
            Icon(Icons.brush, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Text('브러쉬 심볼 간격',
                style: T.captionBold.copyWith(color: C.tx)),
            const Spacer(),
            Text('${_brushCellWidth.round()}px',
                style: T.caption.copyWith(color: C.lvD)),
          ]),
          Slider(
            value: _brushCellWidth,
            min: 12,
            max: 80,
            divisions: 17,
            activeColor: C.lv,
            label: '${_brushCellWidth.round()}px',
            onChanged: (v) => setState(() => _brushCellWidth = v),
          ),
          Row(children: [
            Icon(Icons.rotate_right, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Text('브러쉬 자동회전 (접선 방향)',
                style: T.captionBold.copyWith(color: C.tx)),
            const Spacer(),
            Switch(
              value: _brushAutoRotate,
              activeThumbColor: C.lv,
              onChanged: (v) => setState(() => _brushAutoRotate = v),
            ),
          ]),
          if (_tool == PathTool.brush && _brushSymbolId == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '브러쉬 모드: 아래 팔레트에서 심볼을 먼저 선택하세요',
                style: T.caption.copyWith(color: C.og),
              ),
            ),
        ],
      ),
    );
  }

  // ── 1) 툴바 ────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // #689 — 패턴 브러쉬 (드래그한 path 위에 심볼 자동 배치).
            _ToolChip(
              label: '브러쉬',
              icon: Icons.brush,
              selected: _tool == PathTool.brush,
              onTap: () => setState(() {
                _tool = PathTool.brush;
                _arcFirstPoint = null;
                _lineFirstPoint = null;
                _brushStrokePoints.clear();
              }),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '펜',
              icon: Icons.edit_outlined,
              selected: _tool == PathTool.pen,
              onTap: () => setState(() {
                _tool = PathTool.pen;
                _arcFirstPoint = null;
              }),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '호',
              icon: Icons.architecture,
              selected: _tool == PathTool.arc,
              onTap: () => setState(() => _tool = PathTool.arc),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '사각',
              icon: Icons.crop_square_outlined,
              selected: _tool == PathTool.square,
              onTap: () => setState(() => _tool = PathTool.square),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '그리드',
              icon: Icons.grid_on_outlined,
              selected: _tool == PathTool.grid,
              onTap: () => setState(() => _tool = PathTool.grid),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '잘라내기',
              icon: Icons.content_cut,
              selected: _tool == PathTool.cut,
              onTap: () => setState(() => _tool = PathTool.cut),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '끝삭제',
              icon: Icons.backspace_outlined,
              selected: _tool == PathTool.trim,
              onTap: () => setState(() => _tool = PathTool.trim),
            ),
            const SizedBox(width: 6),
            // #676 — Line 도구 (직선 전용)
            _ToolChip(
              label: '직선',
              icon: Icons.show_chart,
              selected: _tool == PathTool.line,
              onTap: () => setState(() {
                _tool = PathTool.line;
                _lineFirstPoint = null;
              }),
            ),
            const SizedBox(width: 6),
            // #679 — 자/각도기
            _ToolChip(
              label: '자',
              icon: Icons.straighten,
              selected: _tool == PathTool.ruler,
              onTap: () => setState(() {
                _tool = PathTool.ruler;
                _measurePoints.clear();
              }),
            ),
            const SizedBox(width: 6),
            _ToolChip(
              label: '각도기',
              icon: Icons.architecture_outlined,
              selected: _tool == PathTool.protractor,
              onTap: () => setState(() {
                _tool = PathTool.protractor;
                _measurePoints.clear();
              }),
            ),
            const SizedBox(width: 12),
            // #678 — 회전 복제 (만다라/꽃잎)
            IconButton(
              tooltip: '회전 복제 (활성 단을 N등분 회전)',
              onPressed: _activeRow == null ? null : _showRotateCloneDialog,
              icon: Icon(Icons.rotate_90_degrees_ccw_outlined,
                  color: _activeRow == null ? C.mu : C.lvD),
              iconSize: 22,
            ),
            IconButton(
              tooltip: '실행 취소',
              onPressed: _undoStack.isEmpty ? null : _undo,
              icon: Icon(Icons.undo,
                  color: _undoStack.isEmpty ? C.mu : C.lvD),
              iconSize: 22,
            ),
            // #671 — 화면맞춤 (transformController 리셋)
            IconButton(
              tooltip: '화면맞춤',
              onPressed: _fitToScreen,
              icon: Icon(Icons.fit_screen_outlined, color: C.lvD),
              iconSize: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── 2) 단 탭 (R1, R2, ... + 추가) ────────────────────────────────
  Widget _buildRowTabs() {
    final sorted = [..._data.rows]
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final row in sorted) ...[
              _RowTab(
                label: 'R${row.rowIndex}',
                selected: _activeRowIndex == row.rowIndex,
                onTap: () => _selectRow(row.rowIndex),
                onDelete: () => _removeRow(row.rowIndex),
              ),
              const SizedBox(width: 6),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _addRow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: C.lvL,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: C.lv.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 14, color: C.lvD),
                  const SizedBox(width: 2),
                  Text('단 추가',
                      style: TextStyle(
                          fontSize: 12,
                          color: C.lvD,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3) Grid 도구 옵션 ──────────────────────────────────────────
  Widget _buildGridControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.lvL,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Row(
        children: [
          Text('단', style: T.caption),
          const SizedBox(width: 4),
          _NumStepper(
            value: _gridRows,
            min: 1,
            max: 5,
            onChanged: (v) => setState(() => _gridRows = v),
          ),
          const SizedBox(width: 12),
          Text('칸', style: T.caption),
          const SizedBox(width: 4),
          _NumStepper(
            value: _gridCols,
            min: 2,
            max: 30,
            onChanged: (v) => setState(() => _gridCols = v),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Text('너비', style: T.caption),
              Expanded(
                child: Slider(
                  value: _gridWidth,
                  min: 80,
                  max: 600,
                  onChanged: (v) => setState(() => _gridWidth = v),
                ),
              ),
            ]),
          ),
          ElevatedButton(
            onPressed: _applyGrid,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  // ── 4) Arc 도구 옵션 ───────────────────────────────────────────
  Widget _buildArcControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.lvL,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // #677 — 3점 모드 토글
          Row(children: [
            Icon(Icons.timeline, size: 16, color: C.lvD),
            const SizedBox(width: 6),
            Text('3점 모드 (시작/중간/끝)', style: T.caption),
            const Spacer(),
            Switch(
              value: _arcThreePointMode,
              activeThumbColor: C.lv,
              onChanged: (v) => setState(() {
                _arcThreePointMode = v;
                _arcFirstPoint = null;
                _arcSecondPoint = null;
              }),
            ),
          ]),
          if (!_arcThreePointMode)
            Row(
              children: [
                Text('호 반지름', style: T.caption),
                Expanded(
                  child: Slider(
                    value: _arcRadius,
                    min: 20,
                    max: 400,
                    activeColor: C.lv,
                    onChanged: (v) => setState(() => _arcRadius = v),
                  ),
                ),
                Text('${_arcRadius.toInt()}px', style: T.caption),
                const SizedBox(width: 8),
                if (_arcFirstPoint != null)
                  Text('두 번째 점 클릭',
                      style: T.caption.copyWith(
                          color: C.lvD, fontWeight: FontWeight.w700)),
              ],
            )
          else
            Row(children: [
              Text(
                _arcFirstPoint == null
                    ? '시작점 클릭'
                    : (_arcSecondPoint == null
                        ? '중간 통과점 클릭'
                        : '끝점 클릭'),
                style: T.caption.copyWith(
                    color: C.lvD, fontWeight: FontWeight.w700),
              ),
            ]),
        ],
      ),
    );
  }

  // ── 5) 활성 단 패턴 시퀀스 입력 ─────────────────────────────────
  Widget _buildPatternRow() {
    final row = _activeRow!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: C.lvL.withValues(alpha: 0.4),
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Row(
        children: [
          Text('R${row.rowIndex} 반복 패턴',
              style: T.caption.copyWith(
                  fontWeight: FontWeight.w700, color: C.lvD)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (row.pattern.isEmpty)
                    Text(
                      '아래 팔레트에서 심볼을 탭해 추가',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  for (final s in row.pattern) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.lv, width: 0.8),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 11,
                              color: C.lvD,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '마지막 심볼 제거',
            onPressed: row.pattern.isEmpty ? null : _popPatternSymbol,
            icon: Icon(Icons.backspace_outlined,
                color: row.pattern.isEmpty ? C.mu : C.og),
            iconSize: 20,
          ),
          // 자동 회전 토글
          IconButton(
            tooltip: '자동 회전',
            onPressed: _toggleAutoRotate,
            icon: Icon(
              row.autoRotate ? Icons.rotate_right : Icons.rotate_left,
              color: row.autoRotate ? C.lv : C.mu,
            ),
            iconSize: 20,
          ),
          // 닫기 토글 (path closed)
          IconButton(
            tooltip: row.closed ? 'path 열기' : 'path 닫기',
            onPressed: _toggleClosed,
            icon: Icon(
              row.closed ? Icons.lock_outline : Icons.lock_open_outlined,
              color: row.closed ? C.lv : C.mu,
            ),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  /// #673 — 단순 필터 (전체/늘리기/줄이기/특수) 적용 심볼 리스트.
  List<dynamic> _filterSymbols(bool isKnit) {
    if (isKnit) {
      final f = _knitFilter;
      if (f == null) return KnitSymbolLibrary.all;
      switch (f) {
        case 'increase':
          return KnitSymbolLibrary.byCategory(SymbolCategory.increase);
        case 'decrease':
          return KnitSymbolLibrary.byCategory(SymbolCategory.decrease);
        case 'special':
          return KnitSymbolLibrary.all
              .where((s) =>
                  s.category == SymbolCategory.basic ||
                  s.category == SymbolCategory.cable ||
                  s.category == SymbolCategory.special ||
                  s.category == SymbolCategory.lace)
              .toList();
      }
      return KnitSymbolLibrary.all;
    }
    final f = _crochetFilter;
    if (f == null) return kCrochetSymbols;
    switch (f) {
      case 'increase':
        return CrochetSymbolLibrary.byCategory(CrochetCategory.increase);
      case 'decrease':
        return CrochetSymbolLibrary.byCategory(CrochetCategory.decrease);
      case 'special':
        return kCrochetSymbols
            .where((c) =>
                c.category == CrochetCategory.basic ||
                c.category == CrochetCategory.special ||
                c.category == CrochetCategory.edge)
            .toList();
    }
    return kCrochetSymbols;
  }

  // ── 6) 심볼 팔레트 (대바늘/코바늘 토글 + 단순 필터 + 심볼 가로 스크롤) ──
  Widget _buildPalette() {
    final isKnit = _craftType == CraftType.knit;
    final List<dynamic> symbols = _filterSymbols(isKnit);

    return Container(
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(
          top: BorderSide(color: C.bd, width: 1),
          bottom: BorderSide(color: C.bd, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1행: 도구 종류 (대바늘 K / 코바늘 C)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(children: [
              _CraftToggleChip(
                label: '대바늘 K',
                selected: _craftType == CraftType.knit,
                onTap: () => setState(() => _craftType = CraftType.knit),
              ),
              const SizedBox(width: 6),
              _CraftToggleChip(
                label: '코바늘 C',
                selected: _craftType == CraftType.crochet,
                onTap: () => setState(() => _craftType = CraftType.crochet),
              ),
            ]),
          ),
          // 2행: 단순 필터 — 전체 / 늘리기 / 줄이기 / 특수
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final entry in const [
                  ['all', '전체'],
                  ['increase', '늘리기'],
                  ['decrease', '줄이기'],
                  ['special', '특수'],
                ]) ...[
                  _CategoryChip(
                    label: entry[1],
                    selected: (isKnit ? _knitFilter : _crochetFilter) ==
                        (entry[0] == 'all' ? null : entry[0]),
                    onTap: () => setState(() {
                      final v = entry[0] == 'all' ? null : entry[0];
                      if (isKnit) {
                        _knitFilter = v;
                      } else {
                        _crochetFilter = v;
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          // 3행: 심볼 가로 스크롤
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              itemCount: symbols.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = symbols[i];
                final id = isKnit
                    ? (s as KnitSymbol).id
                    : (s as CrochetSymbol).id;
                // #689 — 브러쉬 모드일 때는 심볼을 brush 심볼로 설정 (선택 표시).
                //         일반 모드에서는 패턴에 append.
                final isBrushMode = _tool == PathTool.brush;
                return _SymbolPaletteCard(
                  craft: _craftType,
                  symbol: s,
                  selected: isBrushMode && _brushSymbolId == id,
                  onTap: () {
                    if (isBrushMode) {
                      setState(() => _brushSymbolId = id);
                    } else {
                      _appendPatternSymbol(id);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 7) 캔버스 ──────────────────────────────────────────────────
  // #673 — 그리드 흰색 배경 + 섹션 구분 보더.
  Widget _buildCanvas(SvgSymbolCache cache) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 캔버스 크기 추적 (Grid 도구에서 사용).
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _canvasSize) {
            // 다음 프레임에 setState (build 중 setState 회피).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _canvasSize != size) {
                setState(() => _canvasSize = size);
              }
            });
          }
          return InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 4.0,
            // #689 — 브러쉬 모드에서는 InteractiveViewer 팬 비활성화 (드래그 = 브러쉬).
            panEnabled: _tool != PathTool.brush,
            scaleEnabled: _tool != PathTool.brush,
            boundaryMargin: const EdgeInsets.all(80),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _readOnly ? null : (d) => _handleCanvasTap(d.localPosition),
              onPanStart: _readOnly
                  ? null
                  : (d) {
                      // #689 — 브러쉬: 드래그 첫 점 캡처.
                      if (_tool == PathTool.brush) {
                        _brushStart(d.localPosition);
                        return;
                      }
                      if (_tool != PathTool.square) return;
                      // #668 — square 시작점도 스냅.
                      final p = _snap(d.localPosition);
                      setState(() {
                        _squareStartPoint = p;
                        _squareCurrentPoint = p;
                      });
                    },
              onPanUpdate: _readOnly
                  ? null
                  : (d) {
                      // #689 — 브러쉬: 드래그 점 추가 (미리보기).
                      if (_tool == PathTool.brush) {
                        _brushUpdate(d.localPosition);
                        return;
                      }
                      // square 미리보기 — 끝점 스냅.
                      if (_tool == PathTool.square &&
                          _squareStartPoint != null) {
                        setState(() =>
                            _squareCurrentPoint = _snap(d.localPosition));
                        return;
                      }
                      // cut/trim 호버 미리보기
                      if (_tool == PathTool.cut || _tool == PathTool.trim) {
                        final hit = GuidePathPainter.hitTestAnchor(
                            _data, d.localPosition, 18);
                        if (hit != _hoveredAnchor) {
                          setState(() => _hoveredAnchor = hit);
                        }
                      }
                    },
              onPanEnd: _readOnly
                  ? null
                  : (_) {
                      // #689 — 브러쉬: 캡처한 점들을 path로 변환.
                      if (_tool == PathTool.brush) {
                        _brushEnd();
                        return;
                      }
                      if (_tool != PathTool.square) return;
                      final start = _squareStartPoint;
                      final end = _squareCurrentPoint;
                      if (start != null && end != null && (start - end).distance > 4) {
                        _squareApply(start, end);
                      }
                      setState(() {
                        _squareStartPoint = null;
                        _squareCurrentPoint = null;
                      });
                    },
              child: ListenableBuilder(
                listenable: cache,
                builder: (_, _) => Stack(
                  children: [
                    SizedBox.expand(
                      child: GuidePathView(
                        chart: _data,
                        symbolPicture: cache.pictureFor,
                        activeRowIndex: _activeRowIndex,
                        hoveredAnchor: _hoveredAnchor,
                        showGuides: _showGuides,
                        showSnapGrid: _snapEnabled,
                        snapGridSpacing: _gridSpacing,
                      ),
                    ),
                    // square 드래그 미리보기
                    if (_squareStartPoint != null &&
                        _squareCurrentPoint != null)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _SquarePreviewPainter(
                            start: _squareStartPoint!,
                            end: _squareCurrentPoint!,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    // arc / line 첫 점 표시 (대기 상태)
                    if (_arcFirstPoint != null)
                      Positioned(
                        left: _arcFirstPoint!.dx - 6,
                        top: _arcFirstPoint!.dy - 6,
                        child: _waitingPointDot(C.og),
                      ),
                    if (_arcSecondPoint != null)
                      Positioned(
                        left: _arcSecondPoint!.dx - 6,
                        top: _arcSecondPoint!.dy - 6,
                        child: _waitingPointDot(C.lv),
                      ),
                    if (_lineFirstPoint != null)
                      Positioned(
                        left: _lineFirstPoint!.dx - 6,
                        top: _lineFirstPoint!.dy - 6,
                        child: _waitingPointDot(C.pk),
                      ),
                    // #679 — 측정 overlay
                    if (_measurePoints.isNotEmpty)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MeasurementPainter(
                            points: List.of(_measurePoints),
                            isProtractor: _tool == PathTool.protractor,
                            color: C.lvD,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    // #689 — 브러쉬 stroke 미리보기 (드래그 중인 라인 표시).
                    if (_tool == PathTool.brush &&
                        _brushStrokePoints.length >= 2)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _BrushStrokePreviewPainter(
                            points: List.of(_brushStrokePoints),
                            color: C.lv,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _waitingPointDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

// ── #679 — 측정 painter (자/각도기) ─────────────────────────────────
class _MeasurementPainter extends CustomPainter {
  final List<Offset> points;
  final bool isProtractor;
  final Color color;
  _MeasurementPainter({
    required this.points,
    required this.isProtractor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final pointPaint = Paint()..color = color;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 4, pointPaint);
    }
    if (points.length < 2) return;
    if (isProtractor) {
      // 세 점: A-B(중심)-C, 각도 = ∠ABC
      if (points.length >= 2) {
        canvas.drawLine(points[0], points[1], linePaint);
      }
      if (points.length >= 3) {
        canvas.drawLine(points[1], points[2], linePaint);
        final a = points[0], b = points[1], c = points[2];
        final v1 = a - b;
        final v2 = c - b;
        final dot = v1.dx * v2.dx + v1.dy * v2.dy;
        final m1 = v1.distance, m2 = v2.distance;
        if (m1 > 0 && m2 > 0) {
          final cos = (dot / (m1 * m2)).clamp(-1.0, 1.0);
          final degrees = (180 / 3.14159265358979) * _acos(cos);
          _drawLabel(
              canvas, b + const Offset(8, -8), '${degrees.toStringAsFixed(1)}°');
        }
      }
    } else {
      // 자: 두 점 거리
      canvas.drawLine(points[0], points[1], linePaint);
      final dist = (points[1] - points[0]).distance;
      final mid = (points[0] + points[1]) / 2;
      _drawLabel(canvas, mid + const Offset(8, -8),
          '${dist.toStringAsFixed(1)}px');
    }
  }

  double _acos(double x) {
    // dart math import 회피용 간단 acos.
    if (x >= 1) return 0;
    if (x <= -1) return 3.14159265358979;
    return 1.5707963267948966 - _asin(x);
  }

  double _asin(double x) {
    final ax = x.abs();
    final t = 1 - ax;
    final p = 1.5707963050 + ax * (-0.2145988016 + ax * (0.0889789874 + ax * -0.0501743046));
    final res = 1.5707963267948966 - _sqrt(t * 2) * p;
    return x < 0 ? -res : res;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (int i = 0; i < 6; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          backgroundColor: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter old) =>
      old.points.length != points.length ||
      old.isProtractor != isProtractor ||
      old.color != color;
}

// ═══════════════════════════════════════════════════════════════════
// 보조 위젯
// ═══════════════════════════════════════════════════════════════════

/// 도구 칩 (펜/호/사각/그리드/잘라내기/끝삭제).
class _ToolChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToolChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : C.lvD),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : C.lvD,
            ),
          ),
        ]),
      ),
    );
  }
}

/// 단 탭 (R1, R2, ...).
class _RowTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RowTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : C.lvD,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDelete,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }
}

/// 카테고리 칩.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.pk.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? C.pk : C.bd, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? C.pkD : C.tx2,
          ),
        ),
      ),
    );
  }
}

/// 대바늘/코바늘 토글 칩.
class _CraftToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CraftToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : C.lvD,
          ),
        ),
      ),
    );
  }
}

/// 심볼 카드 (탭 시 패턴에 추가).
/// #689 — selected 플래그 추가 (브러쉬 모드에서 현재 brush 심볼 강조).
class _SymbolPaletteCard extends ConsumerWidget {
  final CraftType craft;
  final dynamic symbol;
  final VoidCallback onTap;
  final bool selected;
  const _SymbolPaletteCard({
    required this.craft,
    required this.symbol,
    required this.onTap,
    this.selected = false,
  });

  String get _label {
    if (craft == CraftType.knit) return (symbol as KnitSymbol).abbr;
    return (symbol as CrochetSymbol).abbreviation;
  }

  String get _tooltipKo {
    if (craft == CraftType.knit) return (symbol as KnitSymbol).name;
    return (symbol as CrochetSymbol).labelKo;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #672/#673 — 사각 그리드 _StaticSymbolCell 과 완전 동일한 사이즈/정렬.
    final label = _label;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '$_tooltipKo ($label)',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? C.lvL : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? C.lv : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _preview(),
              const SizedBox(height: 3),
              Text(
                label.length > 6 ? label.substring(0, 6) : label,
                style: TextStyle(
                    fontSize: 8, color: C.tx2, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    // #672 — 사각 그리드와 동일한 SVG 사이즈/소스.
    if (craft == CraftType.knit) {
      final k = symbol as KnitSymbol;
      return MoriSymbolView(
        symbolId: k.id,
        size: 22,
        fallbackText: k.abbr,
      );
    }
    // 코바늘: 직접 firebaseUrl 사용 — Firestore 매핑 충돌 회피.
    final c = symbol as CrochetSymbol;
    if (c.hasSvg) {
      return SymbolSvgWidget(
        symbolId: c.id,
        svgUrl: c.firebaseUrl,
        size: 22,
        fit: BoxFit.contain,
        fallback: Text(
          c.abbreviation.length > 4
              ? c.abbreviation.substring(0, 4)
              : c.abbreviation,
          style: TextStyle(
              fontSize: 9, color: C.tx2, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Text(
      c.abbreviation.length > 5
          ? c.abbreviation.substring(0, 5)
          : c.abbreviation,
      style: TextStyle(fontSize: 11, color: C.tx, fontWeight: FontWeight.w700),
    );
  }
}

/// 숫자 +/- 스테퍼.
class _NumStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _NumStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: value > min ? () => onChanged(value - 1) : null,
        child: Icon(Icons.remove_circle_outline,
            size: 18, color: value > min ? C.lvD : C.mu),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('$value',
            style: TextStyle(fontWeight: FontWeight.w700, color: C.tx)),
      ),
      InkWell(
        onTap: value < max ? () => onChanged(value + 1) : null,
        child: Icon(Icons.add_circle_outline,
            size: 18, color: value < max ? C.lvD : C.mu),
      ),
    ]);
  }
}

/// #689 — 브러쉬 stroke 드래그 미리보기 painter.
/// 사용자가 드래그하는 동안 캡처된 raw 점들을 라인으로 연결해서 보여줌.
class _BrushStrokePreviewPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _BrushStrokePreviewPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePreviewPainter old) =>
      old.points.length != points.length || old.color != color;
}

/// Square 도구 드래그 미리보기 painter.
class _SquarePreviewPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  _SquarePreviewPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.lv.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SquarePreviewPainter old) =>
      old.start != start || old.end != end;
}
