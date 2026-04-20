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
import '../../../core/widgets/common_widgets.dart';
import '../data/pattern_export_service.dart';
import '../data/pattern_repository.dart';
import '../domain/knit_symbols.dart';
import '../domain/pattern_chart.dart';
import '../../../features/counter/domain/counter_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import 'widgets/chart_canvas.dart';
import 'widgets/chart_toolbar.dart';
import 'widgets/chart_tracking_overlay.dart';
import 'widgets/grid_size_dialog.dart';

class PatternEditorScreen extends ConsumerStatefulWidget {
  final String? patternId;
  final File? referenceImageFile;
  final String? referencePdfPath;
  /// 뷰어 모드 — true일 때 편집 비활성화 (툴바·저장 버튼 숨김)
  final bool readOnly;
  /// 저장/삭제/나가기 후 이동할 경로. null이면 sourceType 기반 기본값 사용.
  final String? returnRoute;
  const PatternEditorScreen({
    super.key,
    this.patternId,
    this.referenceImageFile,
    this.referencePdfPath,
    this.readOnly = false,
    this.returnRoute,
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
  bool _trackingEnabled = false;
  int _trackingCurrentRow = 1; // 1단 = 맨 아래부터 시작 (뜨개 관례)
  TrackingDisplayMode _trackingMode = TrackingDisplayMode.bar;

  @override
  void initState() {
    super.initState();
    _chart = PatternChart.empty(
      id: widget.patternId ?? '',
      title: 'Untitled',
    );
    _narrativeController = TextEditingController(text: _chart.narrativeText);
    _titleController = TextEditingController(text: _chart.title);
    _referenceImageFile = widget.referenceImageFile;
    if (widget.patternId != null && widget.patternId!.isNotEmpty) {
      _loadChart(widget.patternId!);
    } else if (!widget.readOnly) {
      // 새 도안: 첫 프레임 후 그리드 크기 설정 다이얼로그 표시 (뷰어 모드에서는 제외)
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGridSizeDialogForNew());
    }
    if (widget.referenceImageFile != null || widget.referencePdfPath != null) {
      _showReference = true;
    }
    // 첫 번째 기호 기본 선택
    final firstSymbol = KnitSymbolLibrary.byCategory(SymbolCategory.basic).firstOrNull;
    _activeSymbolId = firstSymbol?.id;
  }

  @override
  void dispose() {
    _narrativeController.dispose();
    _titleController.dispose();
    _fitToScreenNotifier.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  Future<void> _showGridSizeDialogForNew() async {
    if (!mounted) return;
    final result = await showGridSizeDialog(
      context,
      initialRows: 30,
      initialCols: 20,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _chart = PatternChart.empty(
          id: _chart.id,
          title: _chart.title,
          rows: result.rows,
          cols: result.cols,
          mode: result.mode,
        );
        // 컬러차트 모드: 기본 도구를 브러쉬(셀 배경색)로 설정
        if (result.mode == ChartMode.colorChart) {
          _activeTool = ChartTool.brush;
          _activeLayer = DrawLayer.color;
        }
      });
    }
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 0.92],
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
              Expanded(
                child: _chart.mode == ChartMode.colorChart
                    ? _NarrativeWithPreview(
                        chart: _chart,
                        controller: _narrativeController,
                        onChanged: (text) {
                          _pushUndo(_chart);
                          setState(() {
                            _chart = _chart.copyWith(narrativeText: text);
                          });
                          setSheetState(() {});
                        },
                      )
                    : _NarrativeEditor(
                        controller: _narrativeController,
                        onChanged: (text) {
                          _pushUndo(_chart);
                          setState(() {
                            _chart = _chart.copyWith(narrativeText: text);
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
                          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(project.coverPhotoUrl, width: 40, height: 40, fit: BoxFit.cover))
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
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

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
                    PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? 'PDF로 내보내기' : 'Export as PDF')])),
                    PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '이미지로 내보내기' : 'Export as image')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
                  ]
                : [
                    // 편집 모드 메뉴
                    PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.save_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '저장' : 'Save')])),
                    PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')])),
                    PopupMenuItem(value: 'link_project', child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '프로젝트에 연결' : 'Link to project')])),
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
                        // 행 트래킹 — 그리드 위 시각 오버레이만 (컨트롤바 분리)
                        if (widget.readOnly && _trackingEnabled)
                          _TrackingOverlay(
                            chart: _chart,
                            trackingCtrl: _trackingCtrl,
                            chartId: _chart.id,
                            localRow: _trackingCurrentRow,
                            mode: _trackingMode,
                          ),
                        // 트래킹 시작 버튼 (뷰어 모드 + 트래킹 비활성 시)
                        if (widget.readOnly && !_trackingEnabled)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              heroTag: 'trackingFab',
                              backgroundColor: C.lv,
                              onPressed: () => setState(() => _trackingEnabled = true),
                              tooltip: '행 트래킹 시작',
                              child: const Icon(Icons.track_changes_rounded, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 트래킹 컨트롤 바 — 그리드 하단 별도 블록
                if (widget.readOnly && _trackingEnabled)
                  _TrackingControlBlock(
                    chart: _chart,
                    chartId: _chart.id,
                    localRow: _trackingCurrentRow,
                    mode: _trackingMode,
                    onLocalRowChange: (r) => setState(() => _trackingCurrentRow = r),
                    onModeChange: (m) => setState(() => _trackingMode = m),
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

  const _TrackingOverlay({
    required this.chart,
    required this.trackingCtrl,
    required this.chartId,
    required this.localRow,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterByChartIdProvider(chartId)).valueOrNull;
    final currentRow = counter != null ? counter.rowCount.clamp(1, chart.rows) : localRow;
    return ChartTrackingOverlay(
      chart: chart,
      currentRow: currentRow,
      mode: mode,
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
  final ValueChanged<int> onLocalRowChange;
  final ValueChanged<TrackingDisplayMode> onModeChange;
  final VoidCallback onClose;

  const _TrackingControlBlock({
    required this.chart,
    required this.chartId,
    required this.localRow,
    required this.mode,
    required this.onLocalRowChange,
    required this.onModeChange,
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

    if (counter == null && chartId.isNotEmpty) {
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
          onMinus: () => _increment(context, ref, counterId, -1),
          onPlus: () => _increment(context, ref, counterId, 1),
          onLongPressMinus: () => _increment(context, ref, counterId, -5),
          onLongPressPlus: () => _increment(context, ref, counterId, 5),
          onModeChange: onModeChange,
          onClose: onClose,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 14, height: 1.8),
        decoration: InputDecoration(
          hintText: '1단: 겉뜨기 20코\n2단: 안뜨기 20코\n3단: ...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(16),
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
          flex: 3,
          child: _NarrativeEditor(controller: controller, onChanged: onChanged),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
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

/// 서술형 텍스트에서 "[MC]", "[CC1]" 등 색상 라벨을 실제 색상 배지로 렌더링
class _NarrativeRichText extends StatelessWidget {
  final String text;
  final Map<int, String> labels;

  const _NarrativeRichText({required this.text, required this.labels});

  /// 라벨 → argb 역매핑
  Map<String, int> get _argbByLabel =>
      {for (final e in labels.entries) e.value: e.key};

  String _shortHex(int argb) {
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return '#$hex';
  }

  InlineSpan _colorBadge(String label, int argb) {
    final color = Color(argb);
    final isLight = color.computeLuminance() > 0.6;
    final hexStr = _shortHex(argb);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isLight ? color.withValues(alpha: 0.12) : color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: isLight ? 1.0 : 0),
        ),
        child: Text(
          '$label $hexStr',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isLight ? C.tx : Colors.white,
          ),
        ),
      ),
    );
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
    final regex = RegExp(r'\[(MC|CC\d+)\]');
    final spans = <InlineSpan>[];

    // 줄 단위로 처리 — 각 줄의 마지막 레이블 색상을 텍스트 색상으로 적용
    final lines = text.split('\n');
    for (int li = 0; li < lines.length; li++) {
      if (li > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[li];
      final lineMatches = regex.allMatches(line).toList();

      // 줄에서 마지막 레이블의 색상 (텍스트 색상으로 사용, 너무 밝으면 기본색)
      final lastLabel = lineMatches.isNotEmpty ? lineMatches.last.group(1)! : null;
      final lastArgb = lastLabel != null ? byLabel[lastLabel] : null;
      final lineColor = lastArgb != null
          ? (Color(lastArgb).computeLuminance() < 0.7 ? Color(lastArgb) : null)
          : null;

      int cursor = 0;
      for (final m in lineMatches) {
        if (m.start > cursor) {
          spans.add(TextSpan(
            text: line.substring(cursor, m.start),
            style: lineColor != null ? TextStyle(color: lineColor) : null,
          ));
        }
        final label = m.group(1)!;
        final argb = byLabel[label];
        spans.add(argb != null ? _colorBadge(label, argb) : TextSpan(text: m.group(0)));
        cursor = m.end;
      }
      if (cursor < line.length) {
        spans.add(TextSpan(
          text: line.substring(cursor),
          style: lineColor != null ? TextStyle(color: lineColor) : null,
        ));
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, height: 1.8, color: C.tx),
        children: spans,
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
