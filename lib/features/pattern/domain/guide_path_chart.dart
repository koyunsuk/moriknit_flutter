// lib/features/pattern/domain/guide_path_chart.dart
//
// 이슈 #668 — 자유 Path 도안 데이터 모델 (코바늘 왕관/꽃잎/Granny 등 비정형 모티프).
//
// 사각 그리드(PatternChart) / 원형 라운드(RoundChart)와 별개의 형태 — 사용자가 자유롭게
// 그린 path 위에 코바늘 셀을 자동 균등 배치하고, path의 접선에 수직으로 셀을 회전시켜
// 왕관·꽃잎·Granny Square 같이 곡선·다각형 외곽선을 따라가는 코바늘 도안을 표현한다.
//
// 좌표계: 캔버스 정규화 좌표 (0~1) 기준이 아닌 절대 px (편집 시점의 캔버스 크기에 종속).
// 추후 캔버스 리사이즈 시에는 GuidePathEditorView가 좌표를 비례 변환한다.
//
// Phase A (MVP — 본 파일)
//   - 단(row) 여러 개 + 단별 path (앵커 + 변 타입)
//   - 단별 패턴 시퀀스 반복 (`['ch', 'dc', 'ch', 'dc']`)
//   - autoRotate (path 접선 수직)
//   - alignToRowAbove (위 단 cellCount/cellWidth 동기화)
//
// Phase B (후속)
//   - Cubic Bezier 핸들 시각 편집
//   - 셀별 커스텀 회전·색상 오버라이드
//   - PDF 내보내기 (guide_path_pdf_exporter.dart)

import 'dart:math' as math;
import 'dart:ui';

/// 자유 Path 도안 도구 종류 (편집 + 측정).
///
/// - [grid]: 사각 그리드 자동 생성 (1~3단, 너비/단수 입력)
/// - [arc]: 호 생성 (간단=두 점+슬라이더, 정밀=3점)
/// - [square]: 두 점 드래그로 사각형 생성
/// - [pen]: 자유 곡선/베지어 앵커 추가 (클릭=직선, 드래그=Bezier)
/// - [line]: 두 점 직선 전용 (#676)
/// - [cut]: 앵커 사이 선분 클릭 시 분할
/// - [trim]: 끝 앵커 클릭 시 삭제
/// - [ruler]: 두 점 거리 측정 (#679)
/// - [protractor]: 세 점 각도 측정 (#679)
/// - [brush]: #689 — 심볼 패턴 브러쉬. 드래그한 경로 위에 선택된 심볼이 일정 간격으로 자동 배치.
///            (펜처럼 path를 그리되, pattern 시퀀스가 자동으로 [selectedSymbolId] 단일 심볼로 채워짐)
enum PathTool { grid, arc, square, pen, line, cut, trim, ruler, protractor, brush }

/// path 변(edge) 타입.
///
/// 각 [PathAnchor]의 `nextEdgeType`에 저장되며, 다음 앵커까지 그릴 변의 모양을 결정한다.
/// 마지막 앵커(닫히지 않은 path) 또는 wrap-around 직전 앵커에서만 의미를 가진다.
enum AnchorType {
  /// 직선 (lineTo).
  line,

  /// 호 (arcToPoint, [PathAnchor.arcRadius] 사용).
  arc,

  /// 2차 베지어 (quadraticBezierTo, [PathAnchor.handleOut]을 제어점으로).
  quadratic,

  /// 3차 베지어 (cubicTo, [PathAnchor.handleOut] + 다음 앵커의 [PathAnchor.handleIn]).
  cubic,
}

/// path 위의 단일 앵커.
///
/// 위치 + 다음 변(edge) 정보를 함께 보관해서, [RowPath.buildPath] 가
/// 앵커 리스트만 보고 Path 객체를 재구성할 수 있게 한다.
class PathAnchor {
  /// 캔버스 좌표 (px).
  final Offset position;

  /// 이 앵커에서 다음 앵커까지의 변(edge) 타입.
  final AnchorType nextEdgeType;

  /// arc 변일 때 반지름 (px). 없으면 50.
  final double? arcRadius;

  /// cubic 변에서 이 앵커로 들어오는 핸들 위치 (캔버스 좌표).
  final Offset? handleIn;

  /// quadratic 또는 cubic 변에서 이 앵커에서 나가는 핸들 위치 (캔버스 좌표).
  final Offset? handleOut;

  /// #680 — 모서리 둥글림(fillet) 반지름 (px). 0이면 날카로운 모서리(기본).
  /// 인접 두 line 변의 끝/시작을 잘라 arc로 부드럽게 연결.
  final double cornerRadius;

  const PathAnchor({
    required this.position,
    this.nextEdgeType = AnchorType.line,
    this.arcRadius,
    this.handleIn,
    this.handleOut,
    this.cornerRadius = 0,
  });

  PathAnchor copyWith({
    Offset? position,
    AnchorType? nextEdgeType,
    Object? arcRadius = _sentinel,
    Object? handleIn = _sentinel,
    Object? handleOut = _sentinel,
    double? cornerRadius,
  }) {
    return PathAnchor(
      position: position ?? this.position,
      nextEdgeType: nextEdgeType ?? this.nextEdgeType,
      arcRadius: identical(arcRadius, _sentinel)
          ? this.arcRadius
          : arcRadius as double?,
      handleIn: identical(handleIn, _sentinel)
          ? this.handleIn
          : handleIn as Offset?,
      handleOut: identical(handleOut, _sentinel)
          ? this.handleOut
          : handleOut as Offset?,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'edge': nextEdgeType.name,
        if (arcRadius != null) 'r': arcRadius,
        if (handleIn != null) 'hix': handleIn!.dx,
        if (handleIn != null) 'hiy': handleIn!.dy,
        if (handleOut != null) 'hox': handleOut!.dx,
        if (handleOut != null) 'hoy': handleOut!.dy,
        if (cornerRadius > 0) 'cr': cornerRadius,
      };

  factory PathAnchor.fromJson(Map<String, dynamic> json) {
    final hix = (json['hix'] as num?)?.toDouble();
    final hiy = (json['hiy'] as num?)?.toDouble();
    final hox = (json['hox'] as num?)?.toDouble();
    final hoy = (json['hoy'] as num?)?.toDouble();
    return PathAnchor(
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      nextEdgeType: _edgeFromName(json['edge'] as String?),
      arcRadius: (json['r'] as num?)?.toDouble(),
      handleIn: (hix != null && hiy != null) ? Offset(hix, hiy) : null,
      handleOut: (hox != null && hoy != null) ? Offset(hox, hoy) : null,
      cornerRadius: (json['cr'] as num?)?.toDouble() ?? 0,
    );
  }

  static AnchorType _edgeFromName(String? name) {
    switch (name) {
      case 'arc':
        return AnchorType.arc;
      case 'quadratic':
        return AnchorType.quadratic;
      case 'cubic':
        return AnchorType.cubic;
      case 'line':
      default:
        return AnchorType.line;
    }
  }
}

/// 한 단(row)의 path + 패턴 + 옵션.
///
/// path는 [anchors] 리스트로 정의되며, [closed]가 true면 마지막 앵커에서 첫 앵커로 닫힌다.
/// 셀은 path 길이를 [cellCount]로 균등 분할한 위치에 배치되고, [pattern]을 반복해서 심볼이
/// 채워진다.
class RowPath {
  /// 단 인덱스 (1-base — UI 라벨용).
  final int rowIndex;

  /// path 앵커 리스트.
  final List<PathAnchor> anchors;

  /// 닫힌 path 여부 (왕관·Granny Square 같은 폐곡선).
  final bool closed;

  /// 셀 심볼 시퀀스 — 길이만큼 반복 적용.
  ///
  /// 예: `['ch', 'dc', 'ch', 'dc']` → 6셀이면 `[ch, dc, ch, dc, ch, dc]`.
  /// 비어 있으면 셀은 그리지 않고 path 가이드만 표시.
  final List<String> pattern;

  /// 셀 개수 (수동 지정). null이면 [cellWidth] 또는 path 길이 기반 자동 계산.
  final int? cellCount;

  /// 위 단 인덱스 (1-base) — 지정 시 해당 단의 cellCount/cellWidth와 동기화.
  final int? alignToRowAbove;

  /// 셀이 path 접선에 수직으로 자동 회전.
  final bool autoRotate;

  /// 셀 한 칸의 너비 (px). 없으면 path 길이 / cellCount.
  final double? cellWidth;

  const RowPath({
    required this.rowIndex,
    this.anchors = const [],
    this.closed = false,
    this.pattern = const [],
    this.cellCount,
    this.alignToRowAbove,
    this.autoRotate = true,
    this.cellWidth,
  });

  RowPath copyWith({
    int? rowIndex,
    List<PathAnchor>? anchors,
    bool? closed,
    List<String>? pattern,
    Object? cellCount = _sentinel,
    Object? alignToRowAbove = _sentinel,
    bool? autoRotate,
    Object? cellWidth = _sentinel,
  }) {
    return RowPath(
      rowIndex: rowIndex ?? this.rowIndex,
      anchors: anchors ?? this.anchors,
      closed: closed ?? this.closed,
      pattern: pattern ?? this.pattern,
      cellCount: identical(cellCount, _sentinel)
          ? this.cellCount
          : cellCount as int?,
      alignToRowAbove: identical(alignToRowAbove, _sentinel)
          ? this.alignToRowAbove
          : alignToRowAbove as int?,
      autoRotate: autoRotate ?? this.autoRotate,
      cellWidth: identical(cellWidth, _sentinel)
          ? this.cellWidth
          : cellWidth as double?,
    );
  }

  static const Object _sentinel = Object();

  /// 앵커 리스트로부터 [Path] 객체를 생성.
  ///
  /// 앵커가 0개면 빈 Path 반환. 변 타입별로 분기:
  /// - [AnchorType.line]: lineTo
  /// - [AnchorType.arc]: arcToPoint(radius=arcRadius ?? 50)
  /// - [AnchorType.quadratic]: quadraticBezierTo(handleOut)
  /// - [AnchorType.cubic]: cubicTo(handleOut → next.handleIn)
  ///
  /// 안전성: 모든 핸들 fallback 처리 (handle이 null이면 두 점 중간을 사용).
  Path buildPath() {
    final p = Path();
    if (anchors.isEmpty) return p;
    final n = anchors.length;
    final lastIdx = closed ? n : n - 1;

    // #680 — fillet(둥글림) 시작점 계산: 첫 앵커가 둥글림이면 시작 위치 조정.
    final firstAnchor = anchors[0];
    final firstStart = closed && firstAnchor.cornerRadius > 0
        ? _filletEnter(anchors[(n - 1) % n], firstAnchor,
            firstAnchor.cornerRadius)
        : firstAnchor.position;
    p.moveTo(firstStart.dx, firstStart.dy);

    for (int i = 0; i < lastIdx; i++) {
      final cur = anchors[i];
      final next = anchors[(i + 1) % n];
      switch (cur.nextEdgeType) {
        case AnchorType.line:
          // #680 fillet — next anchor가 line+line 교차 + cornerRadius>0 이면
          //  next까지 선을 짧게(filletEnter) 그리고 arc로 next 다음 변 시작점까지 이음.
          final canFillet = next.cornerRadius > 0 &&
              ((i + 1) < lastIdx || closed) &&
              next.nextEdgeType == AnchorType.line;
          if (canFillet) {
            final nextNext = anchors[(i + 2) % n];
            final r = _clampFilletRadius(
                cur.position, next.position, nextNext.position,
                next.cornerRadius);
            if (r > 0.5) {
              final enter = _filletEnter(cur, next, r);
              final exit = _filletExit(next, nextNext, r);
              p.lineTo(enter.dx, enter.dy);
              p.arcToPoint(exit, radius: Radius.circular(r));
              continue;
            }
          }
          p.lineTo(next.position.dx, next.position.dy);
          break;
        case AnchorType.arc:
          // arcToPoint는 음수 반경/0 반경에서 NaN 발생 가능 → 안전 fallback.
          final r = (cur.arcRadius ?? 50).abs().clamp(1.0, 99999.0);
          try {
            p.arcToPoint(
              next.position,
              radius: Radius.circular(r),
              clockwise: true,
            );
          } catch (_) {
            // arc 파라미터 부적합 → 직선으로 폴백.
            p.lineTo(next.position.dx, next.position.dy);
          }
          break;
        case AnchorType.quadratic:
          final ctrl = cur.handleOut ??
              Offset(
                (cur.position.dx + next.position.dx) / 2,
                (cur.position.dy + next.position.dy) / 2,
              );
          p.quadraticBezierTo(
            ctrl.dx,
            ctrl.dy,
            next.position.dx,
            next.position.dy,
          );
          break;
        case AnchorType.cubic:
          final c1 = cur.handleOut ??
              Offset(
                cur.position.dx + (next.position.dx - cur.position.dx) / 3,
                cur.position.dy + (next.position.dy - cur.position.dy) / 3,
              );
          final c2 = next.handleIn ??
              Offset(
                cur.position.dx + 2 * (next.position.dx - cur.position.dx) / 3,
                cur.position.dy + 2 * (next.position.dy - cur.position.dy) / 3,
              );
          p.cubicTo(
            c1.dx,
            c1.dy,
            c2.dx,
            c2.dy,
            next.position.dx,
            next.position.dy,
          );
          break;
      }
    }
    if (closed) p.close();
    return p;
  }

  // #680 — fillet 헬퍼 (꼭짓점 둥글림).
  /// next anchor에서 prev→next 방향으로 r 만큼 떨어진 진입점.
  static Offset _filletEnter(PathAnchor prev, PathAnchor next, double r) {
    final dx = next.position.dx - prev.position.dx;
    final dy = next.position.dy - prev.position.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) return next.position;
    final t = (len - r).clamp(0.0, len) / len;
    return Offset(
      prev.position.dx + dx * t,
      prev.position.dy + dy * t,
    );
  }

  /// 현재 anchor에서 next 방향으로 r 만큼 진행한 출구점.
  static Offset _filletExit(PathAnchor cur, PathAnchor next, double r) {
    final dx = next.position.dx - cur.position.dx;
    final dy = next.position.dy - cur.position.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) return cur.position;
    final t = r.clamp(0.0, len) / len;
    return Offset(
      cur.position.dx + dx * t,
      cur.position.dy + dy * t,
    );
  }

  /// 두 변 길이의 절반을 넘지 않도록 fillet radius 클램프.
  static double _clampFilletRadius(
      Offset prev, Offset corner, Offset next, double requested) {
    final l1 = (corner - prev).distance;
    final l2 = (next - corner).distance;
    final maxR = math.min(l1, l2) * 0.5;
    return requested.clamp(0.0, maxR).toDouble();
  }

  /// path의 총 길이 계산 (PathMetric 기반).
  ///
  /// 빈 path는 0을 반환하고, computeMetrics 실패 시에도 0으로 폴백.
  double computeLength() {
    try {
      final path = buildPath();
      double total = 0;
      for (final m in path.computeMetrics()) {
        total += m.length;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 패턴 시퀀스에서 i번째 셀의 심볼 ID.
  ///
  /// pattern이 비었으면 null. 인덱스가 범위를 벗어나면 modulo로 wrap.
  String? symbolAt(int i) {
    if (pattern.isEmpty) return null;
    return pattern[i % pattern.length];
  }

  Map<String, dynamic> toJson() => {
        'rowIndex': rowIndex,
        'anchors': anchors.map((a) => a.toJson()).toList(),
        if (closed) 'closed': true,
        if (pattern.isNotEmpty) 'pattern': pattern,
        if (cellCount != null) 'cellCount': cellCount,
        if (alignToRowAbove != null) 'alignToRowAbove': alignToRowAbove,
        if (!autoRotate) 'autoRotate': false,
        if (cellWidth != null) 'cellWidth': cellWidth,
      };

  factory RowPath.fromJson(Map<String, dynamic> json) {
    final rawAnchors = (json['anchors'] as List<dynamic>?) ?? const [];
    return RowPath(
      rowIndex: (json['rowIndex'] as num).toInt(),
      anchors: rawAnchors
          .map((e) => PathAnchor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      closed: json['closed'] as bool? ?? false,
      pattern: ((json['pattern'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      cellCount: (json['cellCount'] as num?)?.toInt(),
      alignToRowAbove: (json['alignToRowAbove'] as num?)?.toInt(),
      autoRotate: json['autoRotate'] as bool? ?? true,
      cellWidth: (json['cellWidth'] as num?)?.toDouble(),
    );
  }
}

/// 자유 Path 도안.
///
/// [PatternChart.guidePathData]에 보관되며, [PatternChart.chartType]가 [ChartShape.guidePath]인
/// 도안에서만 의미를 가진다. 단([RowPath])이 0개여도 유효 (편집 직후 빈 상태).
class GuidePathChart {
  /// 단 리스트 (rowIndex로 정렬되지 않을 수 있음 — UI에서 정렬).
  final List<RowPath> rows;

  /// 캔버스 기준 너비 (path 좌표 정규화 기준 — 추후 리사이즈 시 비례 변환용).
  final double canvasWidth;

  /// 캔버스 기준 높이.
  final double canvasHeight;

  const GuidePathChart({
    this.rows = const [],
    this.canvasWidth = 600,
    this.canvasHeight = 600,
  });

  GuidePathChart copyWith({
    List<RowPath>? rows,
    double? canvasWidth,
    double? canvasHeight,
  }) =>
      GuidePathChart(
        rows: rows ?? this.rows,
        canvasWidth: canvasWidth ?? this.canvasWidth,
        canvasHeight: canvasHeight ?? this.canvasHeight,
      );

  /// 단 추가 (rowIndex 자동 = 현재 max + 1).
  GuidePathChart addRow([RowPath? row]) {
    final nextIdx = rows.isEmpty
        ? 1
        : rows.map((r) => r.rowIndex).reduce(math.max) + 1;
    final newRow = row ?? RowPath(rowIndex: nextIdx);
    return copyWith(rows: [...rows, newRow]);
  }

  /// 단 교체 (같은 rowIndex 매칭).
  GuidePathChart replaceRow(RowPath row) {
    final idx = rows.indexWhere((r) => r.rowIndex == row.rowIndex);
    if (idx < 0) return addRow(row);
    final newRows = List<RowPath>.from(rows);
    newRows[idx] = row;
    return copyWith(rows: newRows);
  }

  /// 단 제거.
  GuidePathChart removeRow(int rowIndex) {
    return copyWith(
      rows: rows.where((r) => r.rowIndex != rowIndex).toList(),
    );
  }

  /// rowIndex로 단 조회.
  RowPath? rowByIndex(int rowIndex) {
    for (final r in rows) {
      if (r.rowIndex == rowIndex) return r;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'rows': rows.map((r) => r.toJson()).toList(),
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
      };

  factory GuidePathChart.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List<dynamic>?) ?? const [];
    return GuidePathChart(
      rows: rawRows
          .map((e) => RowPath.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 600,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 600,
    );
  }
}
