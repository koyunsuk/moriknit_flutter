import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/pattern_repository.dart';
import '../domain/knit_symbols.dart';
import '../domain/pattern_chart.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/chart_canvas.dart';
import 'widgets/chart_toolbar.dart';

class PatternEditorScreen extends ConsumerStatefulWidget {
  final String? patternId;
  final File? referenceImageFile;
  final String? referencePdfPath;
  const PatternEditorScreen({super.key, this.patternId, this.referenceImageFile, this.referencePdfPath});

  @override
  ConsumerState<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends ConsumerState<PatternEditorScreen> {
  late PatternChart _chart;
  final List<PatternChart> _undoStack = [];
  final List<PatternChart> _redoStack = [];

  ChartTool _activeTool = ChartTool.draw;
  Color _activeColor = Colors.black;
  String? _activeSymbolId;
  bool _isSaving = false;
  bool _showReference = false;
  late TextEditingController _narrativeController;
  File? _referenceImageFile;

  final GlobalKey _chartKey = GlobalKey();

  // 이슈 #98: 전체 조망 — ValueNotifier로 ChartCanvas에 크기 전달
  final ValueNotifier<Size?> _fitToScreenNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _chart = PatternChart.empty(
      id: widget.patternId ?? '',
      title: 'Untitled',
    );
    _narrativeController = TextEditingController(text: _chart.narrativeText);
    _referenceImageFile = widget.referenceImageFile;
    if (widget.patternId != null && widget.patternId!.isNotEmpty) {
      _loadChart(widget.patternId!);
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
    _fitToScreenNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadChart(String id) async {
    final repo = ref.read(patternRepositoryProvider);
    final loaded = await repo.get(id);
    if (loaded != null && mounted) {
      setState(() => _chart = loaded);
      _narrativeController.text = loaded.narrativeText;
    }
  }

  void _pushUndo(PatternChart prev) {
    _undoStack.add(prev);
    _redoStack.clear();
  }

  void _onChartChanged(PatternChart next) {
    _pushUndo(_chart);
    setState(() => _chart = next);
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
    if (_chart.mode == ChartMode.narrative) {
      _narrativeController.clear();
    }
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
      if (mounted) Navigator.of(context).pop();
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
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final bytes = byteData.buffer.asUint8List();

      final user = ref.read(authStateProvider).valueOrNull;
      final creatorName = user?.displayName ?? user?.email ?? 'MoriKnit';

      final pdfDoc = pw.Document();
      final pdfImage = pw.MemoryImage(bytes);

      pdfDoc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Stack(
          children: [
            pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
            pw.Positioned(
              bottom: 20,
              right: 20,
              child: pw.Opacity(
                opacity: 0.25,
                child: pw.Text(
                  'MoriKnit | $creatorName | ${_chart.title}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ),
            ),
          ],
        ),
      ));

      if (!mounted) return;
      await Printing.sharePdf(
        bytes: await pdfDoc.save(),
        filename: '${_chart.title}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
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

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text(_chart.title, style: T.h3),
        actions: [
          // 참조 이미지/PDF 토글 버튼
          if (widget.referenceImageFile != null || widget.referencePdfPath != null)
            IconButton(
              icon: Icon(_showReference ? Icons.image_rounded : Icons.image_outlined),
              tooltip: isKorean ? '참조 이미지' : 'Reference',
              onPressed: () => setState(() => _showReference = !_showReference),
            ),
          // 이슈 #96: PDF 내보내기 버튼
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: isKorean ? 'PDF 내보내기' : 'Export PDF',
            onPressed: _showPdfDialog,
          ),
          // 이슈 #96: 저장 버튼 — runWithMoriLoadingDialog 표준 패턴
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(C.lv),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(isKorean ? '저장' : 'Save'),
              style: TextButton.styleFrom(foregroundColor: C.lvD),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          Column(
            children: [
              // 참조 이미지 패널
              if (_showReference && _referenceImageFile != null)
                Stack(
                  children: [
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Image.file(_referenceImageFile!, fit: BoxFit.contain),
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
                SizedBox(
                  height: 220,
                  child: PDFView(filePath: widget.referencePdfPath!),
                ),
              // 이슈 #97: ChartCanvas — _hitCell이 TransformationController 역행렬로
              // 좌표를 정확히 변환하므로 삭제 후 재클릭 시 좌표 어긋남 없음.
              // CellData.== 구현으로 동일 셀 중복 칠하기도 안전하게 처리됨.
              Expanded(
                child: ClipRect(
                  child: RepaintBoundary(
                    key: _chartKey,
                    child: _chart.mode == ChartMode.narrative
                      ? _NarrativeEditor(
                          controller: _narrativeController,
                          onChanged: (text) {
                            _pushUndo(_chart);
                            setState(() {
                              _chart = PatternChart(
                                id: _chart.id,
                                title: _chart.title,
                                rows: _chart.rows,
                                cols: _chart.cols,
                                mode: _chart.mode,
                                grid: _chart.grid,
                                narrativeText: text,
                              );
                            });
                          },
                        )
                      : ChartCanvas(
                          chart: _chart,
                          tool: _activeTool,
                          activeColor: _activeColor,
                          activeSymbolId: _activeSymbolId,
                          onChartChanged: _onChartChanged,
                          // 이슈 #98: fitToScreenNotifier — 전체 조망 트리거
                          fitToScreenNotifier: _fitToScreenNotifier,
                        ),
                  ),
                ),
              ),
              // 이슈 #98: ChartToolbar.onFitScreen → _triggerFitToScreen
              ChartToolbar(
                mode: _chart.mode,
                activeTool: _activeTool,
                activeColor: _activeColor,
                activeSymbolId: _activeSymbolId,
                canUndo: _undoStack.isNotEmpty,
                canRedo: _redoStack.isNotEmpty,
                onModeChanged: (mode) {
                  setState(() {
                    _chart = PatternChart(
                      id: _chart.id,
                      title: _chart.title,
                      rows: _chart.rows,
                      cols: _chart.cols,
                      mode: mode,
                      grid: _chart.grid,
                      narrativeText: _chart.narrativeText,
                    );
                  });
                },
                onToolChanged: (tool) => setState(() => _activeTool = tool),
                onColorChanged: (color) => setState(() => _activeColor = color),
                onSymbolChanged: (id) => setState(() => _activeSymbolId = id),
                onUndo: _undo,
                onRedo: _redo,
                onClear: _clearChart,
                onExport: _showPdfDialog,
                onFitScreen: _triggerFitToScreen,
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(16),
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
    );
  }
}
