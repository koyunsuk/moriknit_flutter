import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_pattern_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../blueprint/presentation/step_log_screen.dart';
import '../data/pattern_export_service.dart';
import '../data/pattern_repository.dart';
import '../domain/guide_path_chart.dart';
import '../domain/knit_symbols.dart';
import '../domain/narrative_block.dart';
import '../domain/pattern_chart.dart';
import '../domain/round_chart.dart';
import '../../../features/counter/domain/counter_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import 'widgets/chart_canvas.dart';
import 'widgets/chart_toolbar.dart';
import 'widgets/chart_tracking_overlay.dart';
import 'widgets/grid_size_dialog.dart';
import 'widgets/guide_path_editor_view.dart';
import 'widgets/round_editor_view.dart';
import 'widgets/section_grouper.dart';

class PatternEditorScreen extends ConsumerStatefulWidget {
  final String? patternId;
  final File? referenceImageFile;
  final String? referencePdfPath;
  /// 뷰어 모드 — true일 때 편집 비활성화 (툴바·저장 버튼 숨김)
  final bool readOnly;
  /// 저장/삭제/나가기 후 이동할 경로. null이면 sourceType 기반 기본값 사용.
  final String? returnRoute;
  /// 이슈 #665 — 신규 도안 생성 시 도안 형태 ('rect' / 'roundFull' / 'roundHalf' / 'roundSector').
  /// null이면 'rect' (기존 사각).
  final String? initialChartType;
  const PatternEditorScreen({
    super.key,
    this.patternId,
    this.referenceImageFile,
    this.referencePdfPath,
    this.readOnly = false,
    this.returnRoute,
    this.initialChartType,
  });

  @override
  ConsumerState<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends ConsumerState<PatternEditorScreen> {
  late PatternChart _chart;
  final List<PatternChart> _undoStack = [];
  final List<PatternChart> _redoStack = [];

  ChartTool _activeTool = ChartTool.draw;
  // 도구별 색상 — 각 도구 독립 색상 관리
  Color _penColor = Colors.black;
  Color _brushColor = Colors.red;
  Color _painterColor = Colors.blue;
  String? _activeSymbolId;
  DrawLayer _activeLayer = DrawLayer.symbol;

  Color get _activeColor {
    switch (_activeTool) {
      case ChartTool.draw:
        return _penColor;
      case ChartTool.brush:
        return _brushColor;
      case ChartTool.fill:
        return _painterColor;
      default:
        return _penColor;
    }
  }
  bool _isSaving = false;
  bool _isDirty = false;
  bool _showReference = false;
  bool _isEditingTitle = false;
  late TextEditingController _narrativeController;
  late TextEditingController _titleController;
  File? _referenceImageFile;

  final GlobalKey _chartKey = GlobalKey();

  // 이슈 #98: 전체 조망 — ValueNotifier로 ChartCanvas에 크기 전달
  final ValueNotifier<Size?> _fitToScreenNotifier = ValueNotifier(null);

  // 트래킹 오버레이 상태
  final TransformationController _trackingCtrl = TransformationController();
  bool _trackingEnabled = true;
  int _trackingCurrentRow = 1; // 1단 = 맨 아래부터 시작 (뜨개 관례)
  TrackingDisplayMode _trackingMode = TrackingDisplayMode.bar;
  TrackingBarDirection _trackingDirection = TrackingBarDirection.bottomUp;
  int? _trackingCurrentCol = 1; // 기본 활성 (1코)
  double _trackingMarkerWidth = 1.0;

  @override
  void initState() {
    super.initState();
    // 이슈 #665 — initialChartType이 round*면 빈 RoundChart 부착.
    final chartShape = _chartShapeFromString(widget.initialChartType);
    _chart = PatternChart.empty(
      id: widget.patternId ?? '',
      title: 'Untitled',
    ).copyWith(
      chartType: chartShape,
      // 이슈 #665 — round*: RoundChart 부착. 이슈 #668 — guidePath: GuidePathChart 부착.
      roundData: (chartShape == ChartShape.roundFull ||
              chartShape == ChartShape.roundHalf ||
              chartShape == ChartShape.roundSector)
          ? const RoundChart()
          : null,
      guidePathData:
          chartShape == ChartShape.guidePath ? const GuidePathChart() : null,
    );
    _narrativeController = TextEditingController(text: _chart.narrativeText);
    _titleController = TextEditingController(text: _chart.title);
    _referenceImageFile = widget.referenceImageFile;
    if (widget.patternId != null && widget.patternId!.isNotEmpty) {
      _loadChart(widget.patternId!);
    }
    // #680 — 새 도안은 즉시 작업 가능 (워드/엑셀 패턴).
    //   기본 20코×30단으로 시작. 사이즈 변경은 정보바/툴바에서 가능.
    if (widget.referenceImageFile != null || widget.referencePdfPath != null) {
      _showReference = true;
    }
    // 첫 번째 기호 기본 선택
    final firstSymbol = KnitSymbolLibrary.byCategory(SymbolCategory.basic).firstOrNull;
    _activeSymbolId = firstSymbol?.id;
  }

  /// 이슈 #665/#668 — 라우터 query 파싱
  /// ('roundFull'/'roundHalf'/'roundSector'/'guidePath'/'rect').
  ChartShape _chartShapeFromString(String? name) {
    switch (name) {
      case 'roundFull':
        return ChartShape.roundFull;
      case 'roundHalf':
        return ChartShape.roundHalf;
      case 'roundSector':
        return ChartShape.roundSector;
      case 'guidePath':
        return ChartShape.guidePath;
      case 'rect':
      default:
        return ChartShape.rect;
    }
  }

  @override
  void dispose() {
    _narrativeController.dispose();
    _titleController.dispose();
    _fitToScreenNotifier.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  // #680 — _showGridSizeDialogForNew 제거 (즉시 시작 패턴 적용).

  /// #680 — 정보바: 그리드 사이즈/대칭/미저장 표시 (다이얼로그 대체).
  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Row(
        children: [
          // 그리드 사이즈 — 클릭으로 변경.
          InkWell(
            onTap: _showGridSizeDialogForEdit,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.grid_on_rounded, size: 14, color: C.lvD),
                const SizedBox(width: 4),
                Text('${_chart.cols}코 × ${_chart.rows}단',
                    style: T.caption.copyWith(
                        color: C.tx, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          if (_chart.mirrorMode) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flip, size: 12, color: C.lvD),
                const SizedBox(width: 3),
                Text('대칭',
                    style: T.caption.copyWith(
                        fontSize: 10, color: C.lvD,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          const Spacer(),
          // 미저장 표시 — 닷.
          if (_isDirty)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: C.og,
                shape: BoxShape.circle,
              ),
            ),
          if (_isDirty) const SizedBox(width: 4),
          Text(
            _isDirty ? '편집중' : '저장됨',
            style: T.caption.copyWith(
                color: _isDirty ? C.og : C.mu, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _showGridSizeDialogForEdit() async {
    if (!mounted) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final result = await showGridSizeDialog(
      context,
      initialRows: _chart.rows,
      initialCols: _chart.cols,
      isEdit: true,
    );
    if (!mounted || result == null) return;

    // 축소 시 잘리는 영역에 데이터가 있는지 확인
    if (result.rows < _chart.rows || result.cols < _chart.cols) {
      bool hasDataInCutoff = false;
      for (int r = 0; r < _chart.rows && !hasDataInCutoff; r++) {
        for (int c = 0; c < _chart.cols && !hasDataInCutoff; c++) {
          if (r >= result.rows || c >= result.cols) {
            final cell = _chart.grid[r][c];
            if (cell.color != null || cell.symbolId != null) hasDataInCutoff = true;
          }
        }
      }
      if (hasDataInCutoff) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isKorean ? '데이터 손실 경고' : 'Data Loss Warning', style: T.h3),
            content: Text(
              isKorean
                  ? '크기를 줄이면 잘리는 영역의 그림/기호가 삭제됩니다.\n계속할까요?'
                  : 'Shrinking the grid will delete content outside the new bounds.\nContinue?',
              style: T.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isKorean ? '취소' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isKorean ? '삭제하고 변경' : 'Trim & Resize'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }
    _pushUndo(_chart);
    setState(() => _chart = _chart.resize(result.rows, result.cols));
  }

  Future<void> _loadChart(String id) async {
    final repo = ref.read(patternRepositoryProvider);
    final loaded = await repo.get(id);
    if (loaded != null && mounted) {
      setState(() => _chart = loaded);
      _narrativeController.text = loaded.narrativeText;
      _titleController.text = loaded.title;
    }
  }

  void _pushUndo(PatternChart prev) {
    _undoStack.add(prev);
    _redoStack.clear();
  }

  void _onChartChanged(PatternChart next) {
    _pushUndo(_chart);
    setState(() {
      _chart = next;
      _isDirty = true;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_chart);
    setState(() => _chart = _undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_chart);
    setState(() => _chart = _redoStack.removeLast());
  }

  void _clearChart() {
    _pushUndo(_chart);
    setState(() {
      _chart = PatternChart.empty(
        id: _chart.id,
        title: _chart.title,
        rows: _chart.rows,
        cols: _chart.cols,
        mode: _chart.mode,
      );
    });
    _narrativeController.clear();
  }

  void _openNarrativeSheet() {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    // 탭 상태: 0 = 서술형 편집(기존), 1 = 섹션 나누기(신규)
    // showModalBottomSheet builder 스코프 closure 변수로 세션 내 유지.
    int tab = 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.85, 0.95],
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx2, setSheetState) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
              ),
              _GenerateFromGridBar(
                chart: _chart,
                isKorean: isKorean,
                onGenerate: () async {
                  await _generateNarrativeFromGrid();
                  setSheetState(() {});
                },
              ),
              // 컬러차트 모드 — 색상 범례 패널
              if (_chart.mode == ChartMode.colorChart)
                _ColorLegendPanel(chart: _chart, isKorean: isKorean),
              // 탭 토글 (신규 — 기존 UI는 탭 0에 그대로 유지)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _NarrativeTabBtn(
                        label: isKorean ? '서술형 편집' : 'Narrative',
                        icon: Icons.edit_note_rounded,
                        active: tab == 0,
                        onTap: () => setSheetState(() => tab = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NarrativeTabBtn(
                        label: isKorean ? '섹션 나누기' : 'Sections',
                        icon: Icons.segment_rounded,
                        active: tab == 1,
                        onTap: () => setSheetState(() => tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tab == 0
                    ? (_chart.mode == ChartMode.colorChart
                        ? _NarrativeWithPreview(
                            chart: _chart,
                            controller: _narrativeController,
                            onChanged: (text) {
                              _pushUndo(_chart);
                              setState(() {
                                _chart = _chart.copyWith(
                                  narrativeText: text,
                                  narrativeBlocks: NarrativeBlock.reconcile(
                                    text,
                                    _chart.narrativeBlocks,
                                  ),
                                );
                              });
                              setSheetState(() {});
                            },
                          )
                        : _NarrativeEditor(
                            controller: _narrativeController,
                            onChanged: (text) {
                              _pushUndo(_chart);
                              setState(() {
                                _chart = _chart.copyWith(
                                  narrativeText: text,
                                  narrativeBlocks: NarrativeBlock.reconcile(
                                    text,
                                    _chart.narrativeBlocks,
                                  ),
                                );
                              });
                              setSheetState(() {});
                            },
                          ))
                    : SectionGrouper(
                        chart: _chart,
                        isKorean: isKorean,
                        onChanged: (updated) {
                          _pushUndo(_chart);
                          setState(() {
                            _chart = updated;
                            // 서술형 컨트롤러 텍스트도 블록 기준으로 동기화
                            if (_narrativeController.text != updated.narrativeText) {
                              _narrativeController.text = updated.narrativeText;
                            }
                          });
                          setSheetState(() {});
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isKorean ? '닫기' : 'Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 이슈 #96: 저장 진입점 — 제목 확인 후 _runSave 호출
  Future<void> _save() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;

    // 제목 미입력 시 다이얼로그 (await 발생)
    if (_chart.title.isEmpty || _chart.title == 'Untitled') {
      final newTitle = await _askTitle(isKorean);
      if (!mounted) return;
      if (newTitle == null || newTitle.trim().isEmpty) return;
      setState(() {
        _chart = PatternChart(
          id: _chart.id,
          title: newTitle.trim(),
          rows: _chart.rows,
          cols: _chart.cols,
          mode: _chart.mode,
          grid: _chart.grid,
          narrativeText: _chart.narrativeText,
        );
      });
    }

    // mounted 체크 직후 동기적으로 context를 전달 — async gap 없음
    if (!mounted) return;
    await _runSave(context, isKorean);
  }

  void _navigateAfterAction() {
    if (widget.returnRoute != null) {
      // Navigator.push로 열린 경우 — pop으로 복귀 (context.go는 Navigator 스택 미제거)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go(widget.returnRoute!);
      }
    } else if (_chart.sourceType == PatternSourceType.aiConverted) {
      context.go(Routes.toolsMyParsedPatterns);
    } else {
      context.go(Routes.toolsPatternGate);
    }
  }

  // 실제 저장 수행 — BuildContext를 파라미터로 받아 async gap 경고 방지
  Future<void> _runSave(BuildContext ctx, bool isKorean) async {
    final messenger = ScaffoldMessenger.of(ctx);
    setState(() => _isSaving = true);
    try {
      await runWithMoriLoadingDialog<void>(
        ctx,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(patternRepositoryProvider);
          final saved = await repo.save(_chart);
          if (mounted) setState(() => _chart = saved);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '저장됐어요.' : 'Saved.');
      if (mounted) {
        setState(() => _isDirty = false);
        _navigateAfterAction();
      }
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _askTitle(bool isKorean) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '도안 이름' : 'Pattern title', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isKorean ? '도안 이름을 입력해 주세요.' : 'Enter a title',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isKorean ? '확인' : 'OK'),
          ),
        ],
      ),
    );
  }

  // 이슈 #96: PDF 내보내기 — Starter 플랜 권한 체크 + 안내 다이얼로그
  Future<void> _showPdfDialog() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final gates = ref.read(featureGatesProvider);

    if (!gates.canExportPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? 'PDF 내보내기는 Starter 플랜 이상에서 사용할 수 있어요.'
              : 'PDF export is available on the Starter plan or above.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: C.og,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? 'PDF 내보내기' : 'Export PDF', style: T.h3),
        content: Text(
          isKorean
              ? '저작권 보호를 위해 모리니트 워터마크와 제작자 이름이 표시됩니다.'
              : 'A MoriKnit watermark and creator name will be shown for copyright protection.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '닫기' : 'Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportPdf(isKorean);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isKorean ? '확인' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeReferenceImage() async {
    if (kIsWeb) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: C.lv),
              title: Text(isKorean ? '카메라로 찍기' : 'Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await ImagePicker().pickImage(source: ImageSource.camera);
                if (p != null && mounted) setState(() => _referenceImageFile = File(p.path));
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (p != null && mounted) setState(() => _referenceImageFile = File(p.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(bool isKorean) async {
    try {
      // 캔버스 캡처 (선택적 — 없으면 테이블로 대체)
      Uint8List? imageBytes;
      final boundary =
          _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        imageBytes = byteData?.buffer.asUint8List();
      }
      if (!mounted) return;

      final user = ref.read(authStateProvider).valueOrNull;
      final creatorName = user?.displayName ?? user?.email ?? 'MoriKnit';

      final pdfBytes = await PatternExportService.buildMagazinePdf(
        chart: _chart,
        chartImageBytes: imageBytes,
        creatorName: creatorName,
      );

      if (!mounted) return;
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${_chart.title}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// 이미지(PNG) 내보내기
  Future<void> _exportImage(bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '이미지 내보내는 중입니다.' : 'Exporting image...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          await PatternExportService.exportImage(
            boundaryKey: _chartKey,
            title: _chart.title,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// .mori 파일 내보내기
  Future<void> _exportMoriFile(bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '파일 내보내는 중입니다.' : 'Exporting file...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          await PatternExportService.exportMoriFile(chart: _chart);
        },
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _copyChart() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    // 미저장 변경사항 있으면 저장 여부 확인
    if (_isDirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isKorean ? '저장하지 않은 변경사항' : 'Unsaved changes', style: T.h3),
          content: Text(isKorean ? '복사 전 변경사항을 저장할까요?' : 'Save changes before copying?', style: T.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(isKorean ? '저장 안 함' : 'Don\'t save')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(isKorean ? '저장' : 'Save')),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'save') {
        await _runSave(context, isKorean);
        if (!mounted || _isDirty) return; // 저장 실패 시 중단
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final copied = await runWithMoriLoadingDialog<PatternChart>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Copying...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternRepositoryProvider).duplicate(_chart),
      );
      if (!mounted) return;
      // 복사된 도안 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatternEditorScreen(patternId: copied.id, readOnly: false),
        ),
      );
    } catch (e) {
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  Future<void> _deleteChart() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '도안 삭제' : 'Delete Pattern', style: T.h3),
        content: Text(isKorean ? '\'${_chart.title}\' 도안을 삭제할까요?\n삭제 후 복구할 수 없어요.' : 'Delete \'${_chart.title}\'?\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternRepositoryProvider).delete(_chart.id),
      );
      if (!mounted) return;
      _navigateAfterAction();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  // ── 게이지 설정 다이얼로그 ──────────────────────────────────────────────────────
  void _showGaugeDialog(bool isKorean) {
    final stitchCtrl = TextEditingController(
        text: _chart.gauge != null ? _chart.gauge!.stitchesPer10cm.toString() : '');
    final rowCtrl = TextEditingController(
        text: _chart.gauge != null ? _chart.gauge!.rowsPer10cm.toString() : '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(isKorean ? '게이지 설정 (10cm 기준)' : 'Gauge (per 10cm)', style: T.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stitchCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isKorean ? '코 수 (stitches)' : 'Stitches',
                hintText: '예: 22',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rowCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isKorean ? '단 수 (rows)' : 'Rows',
                hintText: '예: 30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _chart = _chart.copyWith(gauge: _sentinelGauge));
              Navigator.pop(ctx);
            },
            child: Text(isKorean ? '게이지 삭제' : 'Clear', style: TextStyle(color: C.og)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          FilledButton(
            onPressed: () {
              final s = double.tryParse(stitchCtrl.text.trim());
              final r = double.tryParse(rowCtrl.text.trim());
              if (s != null && r != null && s > 0 && r > 0) {
                setState(() => _chart = _chart.copyWith(gauge: GaugeInfo(stitchesPer10cm: s, rowsPer10cm: r)));
                _isDirty = true;
              }
              Navigator.pop(ctx);
            },
            child: Text(isKorean ? '적용' : 'Apply'),
          ),
        ],
      ),
    );
  }

  // sentinel — gauge를 null로 지우기 위한 copyWith용
  static const _sentinelGauge = Object();

  // ── 뜨기 방향 토글 ──────────────────────────────────────────────────────────
  void _toggleKnittingDirection() {
    setState(() {
      _chart = _chart.copyWith(
        knittingDirection: _chart.knittingDirection == KnittingDirection.flatRows
            ? KnittingDirection.inTheRound
            : KnittingDirection.flatRows,
      );
      _isDirty = true;
    });
  }

  // ── 반복 구간 지정 다이얼로그 ──────────────────────────────────────────────────
  void _showRepeatRegionDialog(bool isKorean) {
    final startRowCtrl = TextEditingController();
    final endRowCtrl = TextEditingController();
    final startColCtrl = TextEditingController();
    final endColCtrl = TextEditingController();
    final repeatCountCtrl = TextEditingController(text: '1');
    // 이슈 #625 커밋 3 — 반복구간 레이블 (서술형 블록과의 연결 식별)
    final labelKoCtrl = TextEditingController();
    final labelEnCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(isKorean ? '반복 구간 지정' : 'Set Repeat Region', style: T.h3),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isKorean ? '단 범위 (1단 = 맨 아래)' : 'Row range (Row 1 = bottom)', style: T.caption.copyWith(color: C.mu)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: startRowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isKorean ? '시작단' : 'Start row'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: endRowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isKorean ? '끝단' : 'End row'),
                )),
              ]),
              const SizedBox(height: 8),
              Text(isKorean ? '코 범위 (1코 = 맨 오른쪽)' : 'Col range (Col 1 = right)', style: T.caption.copyWith(color: C.mu)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: startColCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isKorean ? '시작코' : 'Start col'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: endColCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isKorean ? '끝코' : 'End col'),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: repeatCountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: isKorean ? '반복 횟수' : 'Repeat count'),
              ),
              const SizedBox(height: 8),
              // 반복구간 레이블 (서술형 블록과의 연결용)
              TextField(
                controller: labelKoCtrl,
                decoration: InputDecoration(
                  labelText: isKorean ? '반복구간 이름 (한글, 선택)' : 'Label (Korean, optional)',
                  hintText: isKorean ? '예: 소매 반복, 케이블 무늬' : '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: labelEnCtrl,
                decoration: InputDecoration(
                  labelText: isKorean ? '반복구간 이름 (영문, 선택)' : 'Label (English, optional)',
                  hintText: 'e.g. Sleeve repeat',
                ),
              ),
              const SizedBox(height: 12),
              if (_chart.repeatRegions.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _chart = _chart.copyWith(repeatRegions: []));
                    _isDirty = true;
                    Navigator.pop(ctx);
                  },
                  icon: Icon(Icons.clear_all, color: C.og, size: 16),
                  label: Text(isKorean ? '모든 반복 구간 삭제' : 'Clear all regions', style: TextStyle(color: C.og)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          FilledButton(
            onPressed: () {
              final sr = int.tryParse(startRowCtrl.text.trim());
              final er = int.tryParse(endRowCtrl.text.trim());
              final sc = int.tryParse(startColCtrl.text.trim());
              final ec = int.tryParse(endColCtrl.text.trim());
              final rc = int.tryParse(repeatCountCtrl.text.trim()) ?? 1;
              if (sr != null && er != null && sc != null && ec != null) {
                // 사용자 입력은 1-based (뜨개 관례), 내부는 0-based index
                // row: 1단=맨아래 → grid index = rows - rowLabel
                final r0 = (_chart.rows - er).clamp(0, _chart.rows - 1);
                final r1 = (_chart.rows - sr).clamp(0, _chart.rows - 1);
                // col: 1코=맨오른쪽 → grid index = cols - colLabel
                final c0 = (_chart.cols - ec).clamp(0, _chart.cols - 1);
                final c1 = (_chart.cols - sc).clamp(0, _chart.cols - 1);
                final ko = labelKoCtrl.text.trim();
                final en = labelEnCtrl.text.trim();
                // id 자동 부여 — 서술형 블록과의 연결 기반
                final region = RepeatRegion.create(
                  startRow: r0, endRow: r1,
                  startCol: c0, endCol: c1,
                  repeatCount: rc,
                  label: en.isEmpty ? null : en,
                  labelKo: ko.isEmpty ? null : ko,
                );
                setState(() => _chart = _chart.copyWith(
                  repeatRegions: [..._chart.repeatRegions, region],
                ));
                _isDirty = true;
              }
              Navigator.pop(ctx);
            },
            child: Text(isKorean ? '추가' : 'Add'),
          ),
        ],
      ),
    );
  }

  /// 이슈 #687 (Phase D2) — 도안에디터에서 단계로그(StepLogScreen) 진입.
  /// 저장되지 않은 도안(id 비어있음)은 먼저 저장 안내.
  void _openStepLog(bool isKorean) {
    if (_chart.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '먼저 도안을 저장한 뒤 단계로그를 열어 주세요.'
              : 'Please save the pattern before opening the step log.'),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StepLogScreen(blueprintId: _chart.id),
      ),
    );
  }

  void _showProjectLinkSheet() {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allProjects = cRef.watch(projectListProvider).valueOrNull ?? [];
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (_, scrollCtrl) => Column(children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(isKorean ? '프로젝트에 연결' : 'Link to Project', style: T.bodyBold),
              ),
              if (_chart.linkedProjectId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    Icon(Icons.link_off_rounded, size: 16, color: C.og),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(patternRepositoryProvider).linkToProject(_chart.id, null);
                        if (mounted) setState(() => _chart = _chart.copyWith(linkedProjectId: null));
                      },
                      child: Text(isKorean ? '연결 해제' : 'Unlink', style: T.caption.copyWith(color: C.og)),
                    ),
                  ]),
                ),
              if (allProjects.isEmpty)
                Expanded(child: Center(child: Text(isKorean ? '등록된 프로젝트가 없어요.' : 'No projects.', style: T.body.copyWith(color: C.mu))))
              else
                Expanded(child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: allProjects.length,
                  itemBuilder: (_, i) {
                    final project = allProjects[i];
                    final linked = project.id == _chart.linkedProjectId;
                    return ListTile(
                      leading: project.coverPhotoUrl.isNotEmpty
                          ? CachedPatternImage(
                              url: project.coverPhotoUrl,
                              patternId: 'project_${project.id}',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(6),
                              placeholderIcon: Icons.folder_rounded,
                            )
                          : Container(width: 40, height: 40, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.folder_rounded, color: C.lv)),
                      title: Text(project.title, style: T.bodyBold),
                      trailing: linked ? Icon(Icons.check_circle_rounded, color: C.lv, size: 20) : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await runWithMoriLoadingDialog<void>(context,
                            message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                            task: () => ref.read(patternRepositoryProvider).linkToProject(_chart.id, project.id),
                          );
                          if (!mounted) return;
                          setState(() => _chart = _chart.copyWith(linkedProjectId: project.id));
                          showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '프로젝트에 연결됐어요.' : 'Linked to project.');
                        } catch (e) {
                          if (!mounted) return;
                          showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                    );
                  },
                )),
            ]),
          );
        },
      ),
    );
  }

  // 이슈 #98: 전체 조망 — 현재 가용 화면 크기를 notifier에 전달
  void _triggerFitToScreen() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final screenSize = renderBox.size;
    // 툴바 높이(약 120) + 앱바(약 56) 제외한 캔버스 가용 영역
    final availH = screenSize.height - 56 - 120;
    final availW = screenSize.width;
    _fitToScreenNotifier.value = Size(availW, availH.clamp(100.0, double.infinity));
  }

  /// 이슈 #347: 기호 그리드 → 서술형 도안 변환 (RLE)
  /// 이슈 #564: 컬러차트 모드 지원 — 빈 칸=겉뜨기, 색상은 MC/CC 라벨로 변환
  Future<void> _generateNarrativeFromGrid() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    // 기호 데이터 또는 색상 데이터가 있는지 확인 (컬러차트 모드 지원)
    final hasSymbols = _chart.grid.any(
      (row) => row.any((cell) => cell.symbolId != null),
    );
    final hasColors = _chart.grid.any(
      (row) => row.any((cell) => cell.color != null),
    );
    if (!hasSymbols && !hasColors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '그리드에 먼저 기호나 색상을 그려주세요.'
              : 'Draw symbols or colors in the grid first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // 기존 내용이 있으면 확인 다이얼로그
    if (_narrativeController.text.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isKorean ? '서술형 도안 생성' : 'Generate Narrative'),
          content: Text(isKorean
              ? '기존 서술형 도안이 그리드 기반으로 덮어쓰여집니다. 계속할까요?'
              : 'Existing narrative will be replaced with grid-based content. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isKorean ? '취소' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
              ),
              child: Text(isKorean ? '생성' : 'Generate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final narrative = _chart.toNarrative(korean: isKorean);
    _pushUndo(_chart);
    setState(() {
      _narrativeController.text = narrative;
      _chart = PatternChart(
        id: _chart.id,
        title: _chart.title,
        rows: _chart.rows,
        cols: _chart.cols,
        mode: _chart.mode,
        grid: _chart.grid,
        narrativeText: narrative,
        type: _chart.type,
        imageUrl: _chart.imageUrl,
        pdfUrl: _chart.pdfUrl,
        forkCount: _chart.forkCount,
        sourcePatternId: _chart.sourcePatternId,
        sourceOwnerName: _chart.sourceOwnerName,
        sourceType: _chart.sourceType,
        aiSections: _chart.aiSections,
        // 사용자 보고 버그 (#625) — 그리드에서 불러오기 후 섹션 나누기 탭 진입 시
        // 블록이 비어있다는 안내가 뜨는 문제. narrativeBlocks를 함께 동기화해서 해결.
        narrativeBlocks: NarrativeBlock.reconcile(narrative, _chart.narrativeBlocks),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    // 이슈 #668 — 자유 Path 도안이면 GuidePathEditorView로 분기 (사각/원형 코드 무손상).
    if (_chart.chartType == ChartShape.guidePath) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _chart.title.isEmpty
                ? (isKorean ? '자유 Path 도안' : 'Free Path Chart')
                : _chart.title,
            style: T.h3,
          ),
          backgroundColor: C.bg,
          elevation: 0,
          actions: widget.readOnly
              ? [
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded, color: C.lv),
                    tooltip: isKorean ? '단계로그 보기' : 'Step Log',
                    onPressed: () => _openStepLog(isKorean),
                  ),
                ]
              : [
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded, color: C.lv),
                    tooltip: isKorean ? '단계로그 보기' : 'Step Log',
                    onPressed: () => _openStepLog(isKorean),
                  ),
                  IconButton(
                    icon: Icon(Icons.save_rounded, color: C.lv),
                    tooltip: isKorean ? '저장' : 'Save',
                    onPressed: _save,
                  ),
                ],
        ),
        body: GuidePathEditorView(
          chart: _chart.guidePathData == null
              ? _chart.copyWith(guidePathData: const GuidePathChart())
              : _chart,
          onChange: (updated) {
            setState(() {
              _chart = updated;
              _isDirty = true;
            });
          },
          isReadOnly: widget.readOnly,
        ),
      );
    }

    // 이슈 #665 — 원형 도안이면 RoundEditorView로 분기 (사각 코드 무손상).
    if (_chart.chartType != ChartShape.rect && _chart.roundData != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_chart.title.isEmpty ? (isKorean ? '원형 도안' : 'Round Chart') : _chart.title, style: T.h3),
          backgroundColor: C.bg,
          elevation: 0,
          actions: widget.readOnly
              ? [
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded, color: C.lv),
                    tooltip: isKorean ? '단계로그 보기' : 'Step Log',
                    onPressed: () => _openStepLog(isKorean),
                  ),
                ]
              : [
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded, color: C.lv),
                    tooltip: isKorean ? '단계로그 보기' : 'Step Log',
                    onPressed: () => _openStepLog(isKorean),
                  ),
                  IconButton(
                    icon: Icon(Icons.save_rounded, color: C.lv),
                    tooltip: isKorean ? '저장' : 'Save',
                    onPressed: _save,
                  ),
                ],
        ),
        body: RoundEditorView(
          chart: _chart,
          onChange: (updated) {
            setState(() {
              _chart = updated;
              _isDirty = true;
            });
          },
          isReadOnly: widget.readOnly,
        ),
      );
    }

    return PopScope(
      canPop: !_isDirty || widget.readOnly,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isKorean ? '저장하지 않고 나가기' : 'Leave without saving?', style: T.h3),
            content: Text(
              isKorean
                  ? '변경 사항이 저장되지 않았습니다.\n그래도 나가시겠어요?'
                  : 'Changes have not been saved.\nLeave anyway?',
              style: T.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isKorean ? '계속 편집' : 'Keep editing'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.og,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isKorean ? '나가기' : 'Leave'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          setState(() => _isDirty = false);
          _navigateAfterAction();
        }
      },
      child: Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditingTitle)
              SizedBox(
                height: 32,
                child: TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: T.h3,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    final name = v.trim();
                    if (name.isNotEmpty) setState(() => _chart = _chart.copyWith(title: name));
                    setState(() => _isEditingTitle = false);
                  },
                  onTapOutside: (_) {
                    final name = _titleController.text.trim();
                    if (name.isNotEmpty) setState(() => _chart = _chart.copyWith(title: name));
                    setState(() => _isEditingTitle = false);
                  },
                ),
              )
            else
              GestureDetector(
                onTap: widget.readOnly ? null : () {
                  _titleController.text = _chart.title;
                  setState(() => _isEditingTitle = true);
                },
                child: Text(_chart.title, style: T.h3),
              ),
            if (_chart.sourcePatternId != null &&
                _chart.sourceOwnerName != null &&
                _chart.sourceOwnerName!.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fork_right_rounded, size: 12, color: C.pkD),
                  const SizedBox(width: 3),
                  Text(
                    isKorean
                        ? '원본: ${_chart.sourceOwnerName}'
                        : 'Forked from: ${_chart.sourceOwnerName}',
                    style: T.caption.copyWith(color: C.pkD, fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          // 참조 이미지/PDF 토글 버튼
          if (widget.referenceImageFile != null || widget.referencePdfPath != null)
            IconButton(
              icon: Icon(_showReference ? Icons.image_rounded : Icons.image_outlined),
              tooltip: isKorean ? '참조 이미지' : 'Reference',
              onPressed: () => setState(() => _showReference = !_showReference),
            ),
          // 뷰어 모드 배지
          if (widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.lv.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 14, color: C.lvD),
                      const SizedBox(width: 4),
                      Text(
                        isKorean ? '뷰어' : 'Viewer',
                        style: TextStyle(
                          fontSize: 11,
                          color: C.lvD,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 통합 햄버거 메뉴 (편집/뷰어 모드 공통)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: isKorean ? '메뉴' : 'Menu',
            onSelected: (v) {
              switch (v) {
                case 'save':
                  if (!_isSaving) _save();
                case 'grid':
                  _showGridSizeDialogForEdit();
                case 'gauge':
                  _showGaugeDialog(isKorean);
                case 'direction':
                  _toggleKnittingDirection();
                case 'repeat':
                  _showRepeatRegionDialog(isKorean);
                case 'pdf':
                  _showPdfDialog();
                case 'image':
                  _exportImage(isKorean);
                case 'mori':
                  _exportMoriFile(isKorean);
                case 'edit':
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatternEditorScreen(
                        patternId: _chart.id,
                        readOnly: false,
                      ),
                    ),
                  );
                case 'copy':
                  _copyChart();
                case 'link_project':
                  _showProjectLinkSheet();
                case 'step_log':
                  _openStepLog(isKorean);
                case 'delete':
                  _deleteChart();
              }
            },
            itemBuilder: (_) => widget.readOnly
                ? [
                    // 뷰어 모드 메뉴
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '수정하기' : 'Edit')])),
                    PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')])),
                    PopupMenuItem(value: 'link_project', child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '프로젝트에 연결' : 'Link to project')])),
                    PopupMenuItem(value: 'step_log', child: Row(children: [Icon(Icons.list_alt_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '단계로그 보기' : 'Step Log')])),
                    PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? 'PDF로 내보내기' : 'Export as PDF')])),
                    PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '이미지로 내보내기' : 'Export as image')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
                  ]
                : [
                    // 편집 모드 메뉴
                    PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.save_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '저장' : 'Save')])),
                    PopupMenuItem(value: 'gauge', child: Row(children: [Icon(Icons.straighten_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '게이지 설정' : 'Set Gauge')])),
                    PopupMenuItem(value: 'direction', child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(_chart.knittingDirection == KnittingDirection.flatRows ? (isKorean ? '뜨기 방향: 평면 → 원통' : 'Direction: Flat → Round') : (isKorean ? '뜨기 방향: 원통 → 평면' : 'Direction: Round → Flat'))])),
                    PopupMenuItem(value: 'repeat', child: Row(children: [Icon(Icons.repeat_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '반복 구간 지정' : 'Set Repeat Region')])),
                    PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')])),
                    PopupMenuItem(value: 'link_project', child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '프로젝트에 연결' : 'Link to project')])),
                    PopupMenuItem(value: 'step_log', child: Row(children: [Icon(Icons.list_alt_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '단계로그 보기' : 'Step Log')])),
                    PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? 'PDF로 내보내기' : 'Export as PDF')])),
                    PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '이미지로 내보내기' : 'Export as image')])),
                    PopupMenuItem(value: 'mori', child: Row(children: [Icon(Icons.download_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '.mori 파일로 내보내기' : 'Export as .mori')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
                  ],
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          Positioned.fill(
            child: Column(
              children: [
                // 게이지 치수 배지
                if (_chart.gauge != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: C.lv.withValues(alpha: 0.08),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.straighten_rounded, size: 13, color: C.lv),
                        const SizedBox(width: 4),
                        Text(
                          '${_chart.gauge!.widthCm(_chart.cols).toStringAsFixed(1)} × ${_chart.gauge!.heightCm(_chart.rows).toStringAsFixed(1)} cm'
                          '  (${_chart.gauge!.stitchesPer10cm.toStringAsFixed(0)}코/${_chart.gauge!.rowsPer10cm.toStringAsFixed(0)}단 / 10cm)',
                          style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                // 참조 이미지 패널 (최대 200px로 제한)
                if (_showReference && _referenceImageFile != null)
                  Stack(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SizedBox(
                          width: double.infinity,
                          child: Image.file(_referenceImageFile!, fit: BoxFit.contain),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: _changeReferenceImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: C.lv.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_showReference && widget.referencePdfPath != null && !kIsWeb)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: PDFView(filePath: widget.referencePdfPath!),
                  ),
                // #680 — 정보바: 그리드 사이즈 + 대칭 모드 + 미저장 표시.
                if (!widget.readOnly) _buildInfoBar(),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          key: _chartKey,
                          child: ChartCanvas(
                            chart: _chart,
                            tool: _activeTool,
                            activeColor: _activeColor,
                            activeSymbolId: _activeSymbolId,
                            activeLayer: _activeLayer,
                            onChartChanged: _onChartChanged,
                            fitToScreenNotifier: _fitToScreenNotifier,
                            readOnly: widget.readOnly,
                            transformationController: _trackingCtrl,
                          ),
                        ),
                        // #680 — 대칭 모드 시 분할선 (시각 가이드)
                        if (_chart.mirrorMode)
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _MirrorAxisPainter(color: C.lv),
                            ),
                          ),
                        // 행 트래킹 — 그리드 위 시각 오버레이만 (컨트롤바 분리)
                        if (_trackingEnabled)
                          _TrackingOverlay(
                            chart: _chart,
                            trackingCtrl: _trackingCtrl,
                            chartId: _chart.id,
                            localRow: _trackingCurrentRow,
                            mode: _trackingMode,
                            direction: _trackingDirection,
                            currentCol: _trackingCurrentCol,
                            markerWidth: _trackingMarkerWidth,
                          ),
                        // 트래킹 시작 버튼 (트래킹 비활성 시)
                        if (!_trackingEnabled)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              heroTag: 'trackingFab',
                              backgroundColor: C.lv,
                              onPressed: () => setState(() {
                                _trackingEnabled = true;
                                _trackingCurrentCol ??= 1;
                              }),
                              tooltip: '행 트래킹 시작',
                              child: const Icon(Icons.track_changes_rounded, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 트래킹 컨트롤 바 — 그리드 하단 별도 블록
                if (_trackingEnabled)
                  _TrackingControlBlock(
                    chart: _chart,
                    chartId: _chart.id,
                    localRow: _trackingCurrentRow,
                    mode: _trackingMode,
                    direction: _trackingDirection,
                    currentCol: _trackingCurrentCol,
                    markerWidth: _trackingMarkerWidth,
                    onLocalRowChange: (r) => setState(() => _trackingCurrentRow = r),
                    onModeChange: (m) => setState(() => _trackingMode = m),
                    onDirectionChange: (d) => setState(() => _trackingDirection = d),
                    onColToggle: () => setState(() {
                      _trackingCurrentCol = _trackingCurrentCol == null ? 1 : null;
                    }),
                    onLocalColChange: (c) => setState(() => _trackingCurrentCol = c),
                    onMarkerWidthChange: (w) => setState(() => _trackingMarkerWidth = w),
                    onClose: () => setState(() => _trackingEnabled = false),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : ChartToolbar(
              activeTool: _activeTool,
              activeColor: _activeColor,
              activeSymbolId: _activeSymbolId,
              canUndo: _undoStack.isNotEmpty,
              canRedo: _redoStack.isNotEmpty,
              activeLayer: _activeLayer,
              onLayerChanged: (layer) => setState(() => _activeLayer = layer),
              onNarrative: _openNarrativeSheet,
              onToolChanged: (tool) => setState(() => _activeTool = tool),
              onColorChanged: (color) => setState(() {
                switch (_activeTool) {
                  case ChartTool.draw: _penColor = color;
                  case ChartTool.brush: _brushColor = color;
                  case ChartTool.fill: _painterColor = color;
                  default: _penColor = color;
                }
              }),
              onSymbolChanged: (id) => setState(() => _activeSymbolId = id),
              onUndo: _undo,
              onRedo: _redo,
              onClear: _clearChart,
              onExport: _showPdfDialog,
              onFitScreen: _triggerFitToScreen,
              onGridResize: _showGridSizeDialogForEdit,
            ),
      ),
    );
  }
}

/// 이슈 #347: 그리드 → 서술형 변환 버튼 바
class _GenerateFromGridBar extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  final VoidCallback onGenerate;

  const _GenerateFromGridBar({
    required this.chart,
    required this.isKorean,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final hasSymbols = chart.grid.any(
      (row) => row.any((cell) => cell.symbolId != null),
    );
    final hasColors = chart.grid.any(
      (row) => row.any((cell) => cell.color != null),
    );
    final canGenerate = hasSymbols || hasColors;
    final isColorChart = chart.mode == ChartMode.colorChart;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: C.lvL,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: C.lvD),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isColorChart
                      ? (isKorean
                          ? '컬러차트를 서술형 도안으로 변환합니다.'
                          : 'Convert color chart to narrative pattern.')
                      : (isKorean
                          ? '기호 그리드를 서술형 도안으로 변환합니다.'
                          : 'Convert symbol grid to narrative pattern.'),
                  style: TextStyle(fontSize: 12, color: C.tx2),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canGenerate ? onGenerate : null,
                icon: const Icon(Icons.text_snippet_rounded, size: 15),
                label: Text(
                  isKorean ? '그리드에서 생성' : 'Generate',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: C.bd,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          // 안내칩 — 빈 칸 겉뜨기 처리 안내
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 13, color: C.lvD),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isKorean
                        ? '겉뜨기는 빈 칸으로 생략할 수 있어요.'
                        : 'Empty cells are treated as knit stitches.',
                    style: TextStyle(fontSize: 11, color: C.tx2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 그리드 위 시각 오버레이만 — Firestore 구독으로 currentRow 반영
class _TrackingOverlay extends ConsumerWidget {
  final PatternChart chart;
  final TransformationController trackingCtrl;
  final String chartId;
  final int localRow;
  final TrackingDisplayMode mode;
  final TrackingBarDirection direction;
  final int? currentCol;
  final double markerWidth;

  const _TrackingOverlay({
    required this.chart,
    required this.trackingCtrl,
    required this.chartId,
    required this.localRow,
    required this.mode,
    this.direction = TrackingBarDirection.bottomUp,
    this.currentCol,
    this.markerWidth = 2.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterByChartIdProvider(chartId)).valueOrNull;
    final currentRow = counter != null ? counter.rowCount.clamp(1, chart.rows) : localRow;
    return ChartTrackingOverlay(
      chart: chart,
      currentRow: currentRow,
      mode: mode,
      direction: direction,
      currentCol: currentCol,
      markerWidth: markerWidth,
      transformationController: trackingCtrl,
    );
  }
}

// 그리드 하단 별도 컨트롤 블록 — 그리드를 가리지 않음
class _TrackingControlBlock extends ConsumerWidget {
  final PatternChart chart;
  final String chartId;
  final int localRow;
  final TrackingDisplayMode mode;
  final TrackingBarDirection direction;
  final int? currentCol;
  final double markerWidth;
  final ValueChanged<int> onLocalRowChange;
  final ValueChanged<TrackingDisplayMode> onModeChange;
  final ValueChanged<TrackingBarDirection> onDirectionChange;
  final VoidCallback onColToggle;
  final ValueChanged<int> onLocalColChange;
  final ValueChanged<double> onMarkerWidthChange;
  final VoidCallback onClose;

  const _TrackingControlBlock({
    required this.chart,
    required this.chartId,
    required this.localRow,
    required this.mode,
    this.direction = TrackingBarDirection.bottomUp,
    this.currentCol,
    this.markerWidth = 2.0,
    required this.onLocalRowChange,
    required this.onModeChange,
    required this.onDirectionChange,
    required this.onColToggle,
    required this.onLocalColChange,
    required this.onMarkerWidthChange,
    required this.onClose,
  });

  Future<void> _increment(BuildContext context, WidgetRef ref, String? counterId, int delta) async {
    if (counterId != null && counterId.isNotEmpty) {
      await ref.read(counterRepositoryProvider).incrementRow(counterId, delta);
    } else {
      onLocalRowChange((localRow + delta).clamp(1, chart.rows));
    }
  }

  Future<void> _ensureCounter(BuildContext context, WidgetRef ref) async {
    if (chartId.isEmpty) return;
    final existing = ref.read(counterByChartIdProvider(chartId)).valueOrNull;
    if (existing != null) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    await ref.read(counterRepositoryProvider).createCounter(CounterModel(
      id: '',
      uid: uid,
      name: chart.title.isNotEmpty ? chart.title : '도안 트래커',
      patternChartId: chartId,
      targetRowCount: chart.rows,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterAsync = ref.watch(counterByChartIdProvider(chartId));
    final counter = counterAsync.valueOrNull;
    final currentRow = counter != null ? counter.rowCount.clamp(1, chart.rows) : localRow;
    final counterId = counter?.id;

    if (counterAsync is AsyncData && counter == null && chartId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCounter(context, ref));
    }

    return Container(
      color: C.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: TrackingControlBar(
          currentRow: currentRow,
          totalRows: chart.rows,
          mode: mode,
          direction: direction,
          currentCol: currentCol,
          totalCols: chart.cols,
          markerWidth: markerWidth,
          onMinus: () => _increment(context, ref, counterId, -1),
          onPlus: () => _increment(context, ref, counterId, 1),
          onLongPressMinus: () => _increment(context, ref, counterId, -5),
          onLongPressPlus: () => _increment(context, ref, counterId, 5),
          onModeChange: onModeChange,
          onDirectionChange: onDirectionChange,
          onColToggle: onColToggle,
          onColMinus: () => onLocalColChange(((currentCol ?? 1) - 1).clamp(1, chart.cols)),
          onColPlus: () => onLocalColChange(((currentCol ?? 1) + 1).clamp(1, chart.cols)),
          onColLongPressMinus: () => onLocalColChange(((currentCol ?? 1) - 5).clamp(1, chart.cols)),
          onColLongPressPlus: () => onLocalColChange(((currentCol ?? 1) + 5).clamp(1, chart.cols)),
          onMarkerWidthChange: onMarkerWidthChange,
          onClose: onClose,
          onJumpToLastRow: () => _increment(context, ref, counterId, chart.rows - currentRow),
          onJumpToFirstRow: () => _increment(context, ref, counterId, 1 - currentRow),
        ),
      ),
    );
  }
}

/// 서술형 시트 상단 탭 버튼 (이슈 #625 — 서술형 편집 / 섹션 나누기 토글)
class _NarrativeTabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NarrativeTabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? C.lv : C.lv.withValues(alpha: 0.2),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : C.lvD,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: T.caption.copyWith(
                color: active ? Colors.white : C.lvD,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NarrativeEditor({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontSize: 14, height: 1.8),
          decoration: InputDecoration(
            hintText: '1단: 겉뜨기 20코\n2단: 안뜨기 20코\n3단: ...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
}

/// 이슈 #564: 컬러차트 서술형 — 편집(위) + 색상 프리뷰(아래) 분할 뷰
class _NarrativeWithPreview extends StatelessWidget {
  final PatternChart chart;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NarrativeWithPreview({
    required this.chart,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = PatternChart.buildColorLabels(chart.grid);
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: _NarrativeEditor(controller: controller, onChanged: onChanged),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 14, color: C.lvD),
                    const SizedBox(width: 4),
                    Text(
                      '프리뷰',
                      style: T.caption.copyWith(
                        color: C.tx2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => _NarrativeRichText(
                        text: controller.text,
                        labels: labels,
                      ),
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

/// 이슈 #568: 서술형 프리뷰 — A(단별 카드) + B(색상 사용량) + C(배지 개선)
class _NarrativeRichText extends StatelessWidget {
  final String text;
  final Map<int, String> labels; // argb → label

  const _NarrativeRichText({required this.text, required this.labels});

  Map<String, int> get _argbByLabel =>
      {for (final e in labels.entries) e.value: e.key};

  // B안: 색상별 코수 집계 — `겉뜨기 3[MC]` → MC: 3
  Map<String, int> _countByLabel() {
    final counts = <String, int>{};
    final regex = RegExp(r'(\d+)?\[(MC|CC\d+)\]');
    for (final m in regex.allMatches(text)) {
      final count = int.tryParse(m.group(1) ?? '') ?? 1;
      final label = m.group(2)!;
      counts[label] = (counts[label] ?? 0) + count;
    }
    return counts;
  }

  // A안: 줄 파싱 → (단 라벨, 내용) 리스트
  List<({String rowLabel, String content})> _parseRows() {
    final result = <({String rowLabel, String content})>[];
    final rowRegex = RegExp(r'^(\d+단|Row \d+):\s*(.+)$');
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final m = rowRegex.firstMatch(trimmed);
      if (m != null) {
        result.add((rowLabel: m.group(1)!, content: m.group(2)!));
      } else {
        result.add((rowLabel: '', content: trimmed));
      }
    }
    return result;
  }

  // C안: 배지 — 색상 원 + 라벨 (HEX 제거)
  InlineSpan _colorBadge(String label, int argb) {
    final color = Color(argb);
    final isLight = color.computeLuminance() > 0.6;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
        decoration: BoxDecoration(
          color: isLight ? color.withValues(alpha: 0.15) : color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLight ? color.withValues(alpha: 0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isLight ? color : Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isLight ? C.tx : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildLineSpans(String line, Map<String, int> byLabel) {
    final regex = RegExp(r'\[(MC|CC\d+)\]');
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in regex.allMatches(line)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, m.start)));
      }
      final label = m.group(1)!;
      final argb = byLabel[label];
      spans.add(argb != null ? _colorBadge(label, argb) : TextSpan(text: m.group(0)));
      cursor = m.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text(
        '그리드에서 생성 버튼을 눌러 서술형 도안을 만들어 보세요.',
        style: T.caption.copyWith(color: C.tx2),
      );
    }

    final byLabel = _argbByLabel;
    final counts = _countByLabel();
    final total = counts.values.fold(0, (a, b) => a + b);
    final rows = _parseRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // B안: 색상 사용량 요약 바
        if (counts.isNotEmpty && total > 0) ...[
          _ColorUsageSummary(counts: counts, byLabel: byLabel, total: total),
          const SizedBox(height: 8),
          Divider(height: 1, color: C.bd),
          const SizedBox(height: 6),
        ],
        // A안: 단별 카드
        ...rows.asMap().entries.map((e) {
          final spans = _buildLineSpans(e.value.content, byLabel);
          return _NarrativeRowCard(
            rowLabel: e.value.rowLabel,
            spans: spans,
            isEven: e.key.isEven,
          );
        }),
      ],
    );
  }
}

/// B안: 색상별 코수 사용량 바
class _ColorUsageSummary extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, int> byLabel; // label → argb
  final int total;

  const _ColorUsageSummary({
    required this.counts,
    required this.byLabel,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final sortedLabels = counts.keys.toList()
      ..sort((a, b) {
        if (a == 'MC') return -1;
        if (b == 'MC') return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: sortedLabels.map((label) {
        final count = counts[label]!;
        final argb = byLabel[label] ?? 0xFFCCCCCC;
        final color = Color(argb);
        final ratio = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: C.tx,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: C.bd,
                    color: color,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '$count코',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: C.tx2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// A안: 단별 카드 — 단 번호 배지 + 내용 인라인 스팬
class _NarrativeRowCard extends StatelessWidget {
  final String rowLabel;
  final List<InlineSpan> spans;
  final bool isEven;

  const _NarrativeRowCard({
    required this.rowLabel,
    required this.spans,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isEven ? C.gx : C.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rowLabel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.lv,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rowLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, height: 1.6, color: C.tx),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이슈 #564: 컬러차트 색상 범례 — MC/CC1/CC2... 색상 칩 + HEX 코드
class _ColorLegendPanel extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;

  const _ColorLegendPanel({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final labels = PatternChart.buildColorLabels(chart.grid);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.bd, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: C.lvD),
              const SizedBox(width: 4),
              Text(
                isKorean ? '색상 범례' : 'Color Legend',
                style: T.caption.copyWith(
                  color: C.tx2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final entry in labels.entries)
                _LegendChip(argb: entry.key, label: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final int argb;
  final String label;

  const _LegendChip({required this.argb, required this.label});

  String get _hex {
    final v = argb & 0xFFFFFF;
    return '#${v.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(argb);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: C.bd2, width: 0.8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: C.tx,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _hex,
            style: TextStyle(
              fontSize: 10,
              color: C.tx2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// #680 — 대칭 모드 시 캔버스 정중앙에 점선 분할선 그림 (시각 가이드).
class _MirrorAxisPainter extends CustomPainter {
  final Color color;
  _MirrorAxisPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    // 점선 (8px 그리고 6px 띄우고 반복).
    const dash = 8.0;
    const gap = 6.0;
    double y = 0;
    while (y < size.height) {
      final next = (y + dash).clamp(0, size.height).toDouble();
      canvas.drawLine(Offset(cx, y), Offset(cx, next), paint);
      y = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MirrorAxisPainter old) => old.color != color;
}
