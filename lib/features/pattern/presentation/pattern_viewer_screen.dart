import 'dart:convert';
import 'dart:io';
import 'dart:math' show acos, pi, max;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../counter/domain/counter_model.dart';
import '../../project/domain/project_model.dart';
import '../../swatch/domain/swatch_model.dart';
import '../data/pattern_session_repository.dart';
import '../domain/pattern_chart.dart';
import '../domain/pattern_session.dart';

class PatternViewerScreen extends ConsumerStatefulWidget {
  final PatternChart chart;
  const PatternViewerScreen({super.key, required this.chart});

  @override
  ConsumerState<PatternViewerScreen> createState() => _PatternViewerScreenState();
}

class _PatternViewerScreenState extends ConsumerState<PatternViewerScreen> {
  // Tools
  bool _rulerActive = false;
  bool _counterActive = false;
  bool _stickyActive = false;
  bool _highlighterActive = false;

  // Ruler
  double _rulerY = 200.0;

  // Highlighter
  final List<_Stroke> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _highlightColor = const Color(0x66FFFF00);
  bool _isErasing = false;
  static const _highlightColors = [
    Color(0x66FFFF00),
    Color(0x66FF9F0A),
    Color(0x6630D158),
    Color(0x66FF375F),
    Color(0x665AC8FA),
  ];

  // Sticky note
  double _stickyX = 20.0;
  double _stickyY = 120.0;
  final _stickyCtrl = TextEditingController();
  bool _stickyEditing = false;

  // Measurement tool
  bool _measureActive = false;
  _MeasureMode _measureMode = _MeasureMode.grid;
  bool _measureUseInch = false;
  Offset _angleHandle1 = const Offset(80, 200);
  Offset _angleHandle2 = const Offset(260, 200);
  Offset _anglePivot = const Offset(170, 200);
  Offset _circleCenter = const Offset(175, 240);
  double _circleRadius = 80.0;

  // PDF
  String? _localPdfPath;
  bool _pdfLoading = true;
  String? _pdfError;
  int _currentPage = 0;
  int _totalPages = 0;

  String get _id => widget.chart.id;
  bool get _isDark => widget.chart.type == PatternType.pdf;

  // Firestore 세션 동기화
  PatternSession? _session;
  bool _sessionApplied = false;
  // 스티키노트 기본 ID (세션 내 단일 노트 — 기존 UI와 호환)
  static const _defaultStickyId = 'default';

  Box<dynamic>? get _box {
    try {
      return Hive.box<dynamic>(SubscriptionConstants.boxViewerState);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadState();
    _bootstrapSession();
    if (widget.chart.type == PatternType.pdf && !kIsWeb) _loadPdf();
  }

  // Firestore 세션 로드 — Hive 로드 후 호출되어 Firestore 값이 있으면 override.
  Future<void> _bootstrapSession() async {
    try {
      final repo = ref.read(patternSessionRepositoryProvider);
      final loaded = await repo.getOrCreate(_id);
      if (!mounted) return;
      setState(() {
        _session = loaded;
        _sessionApplied = true;
        // Firestore에 기존 값이 있으면 로컬 상태 override
        if (loaded.rulerY != 200.0 || loaded.strokes.isNotEmpty || loaded.stickyNotes.isNotEmpty) {
          _rulerY = loaded.rulerY;
          if (loaded.strokes.isNotEmpty) {
            _strokes
              ..clear()
              ..addAll(loaded.strokes.map((s) {
                final pts = <Offset>[];
                final len = s.xs.length < s.ys.length ? s.xs.length : s.ys.length;
                for (int i = 0; i < len; i++) {
                  pts.add(Offset(s.xs[i], s.ys[i]));
                }
                return _Stroke(points: pts, color: Color(s.colorValue));
              }));
          }
          final note = loaded.stickyNotes.firstWhere(
            (n) => n.id == _defaultStickyId,
            orElse: () => loaded.stickyNotes.isNotEmpty
                ? loaded.stickyNotes.first
                : const StickyNote(id: _defaultStickyId),
          );
          _stickyX = note.x;
          _stickyY = note.y;
          if (note.text.isNotEmpty) _stickyCtrl.text = note.text;
        }
      });
    } catch (_) {
      // 오프라인 등 — Hive 상태 유지
    }
  }

  // Firestore 비동기 업데이트 (fire and forget)
  void _syncRuler() {
    if (!_sessionApplied) return;
    ref.read(patternSessionRepositoryProvider).updateRuler(_id, _rulerY);
  }

  void _syncStrokes() {
    if (!_sessionApplied) return;
    final data = _strokes
        .map((s) => StrokeData(
              xs: s.points.map((p) => p.dx).toList(),
              ys: s.points.map((p) => p.dy).toList(),
              colorValue: s.color.toARGB32(),
            ))
        .toList();
    ref.read(patternSessionRepositoryProvider).updateStrokes(_id, data);
  }

  void _syncSticky() {
    if (!_sessionApplied) return;
    final note = StickyNote(
      id: _defaultStickyId,
      text: _stickyCtrl.text,
      x: _stickyX,
      y: _stickyY,
    );
    ref
        .read(patternSessionRepositoryProvider)
        .updateStickyNote(_id, note);
  }

  @override
  void dispose() {
    _stickyCtrl.dispose();
    super.dispose();
  }

  void _loadState() {
    final b = _box;
    if (b == null) return;
    _rulerY = (b.get('ruler_y_$_id') as double?) ?? 200.0;
    _stickyX = (b.get('sticky_x_$_id') as double?) ?? 20.0;
    _stickyY = (b.get('sticky_y_$_id') as double?) ?? 120.0;
    _stickyCtrl.text = (b.get('sticky_text_$_id') as String?) ?? '';
    final raw = b.get('strokes_$_id') as String?;
    if (raw != null) {
      try {
        for (final s in jsonDecode(raw) as List) {
          final pts = (s['points'] as List)
              .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
              .toList();
          if (pts.isNotEmpty) {
            _strokes.add(_Stroke(points: pts, color: Color(s['color'] as int)));
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  void _saveRuler() {
    _box?.put('ruler_y_$_id', _rulerY);
    _syncRuler();
  }

  void _saveSticky() {
    _box?.put('sticky_x_$_id', _stickyX);
    _box?.put('sticky_y_$_id', _stickyY);
    _box?.put('sticky_text_$_id', _stickyCtrl.text);
    _syncSticky();
  }

  void _saveStrokes() {
    final json = jsonEncode(_strokes.map((s) => {
          'color': s.color.toARGB32(),
          'points': s.points.map((p) => [p.dx, p.dy]).toList(),
        }).toList());
    _box?.put('strokes_$_id', json);
    _syncStrokes();
  }

  Future<void> _loadPdf() async {
    final rawUrl = widget.chart.pdfUrl;
    if (rawUrl.isEmpty) {
      setState(() {
        _pdfError = 'PDF URL이 없어요.';
        _pdfLoading = false;
      });
      return;
    }
    try {
      String url = rawUrl;
      if (!rawUrl.startsWith('http')) {
        url = await FirebaseStorage.instance.ref(rawUrl).getDownloadURL();
      }
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final bytes = await res.expand((b) => b).toList();
      client.close();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/viewer_$_id.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() { _localPdfPath = file.path; _pdfLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _pdfError = '$e'; _pdfLoading = false; });
    }
  }

  Future<void> _createAndLinkCounter(bool isKorean) async {
    final nameCtrl = TextEditingController(text: widget.chart.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '카운터 만들기' : 'Create Counter', style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: isKorean ? '카운터 이름' : 'Counter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel', style: TextStyle(color: C.mu)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '만들기' : 'Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim().isEmpty ? widget.chart.title : nameCtrl.text.trim();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '카운터 만드는 중입니다.' : 'Creating counter...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          final counter = CounterModel.empty(uid: user.uid, name: name)
              .copyWith(patternChartId: _id);
          await ref.read(counterRepositoryProvider).createCounter(counter);
        },
      );
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  // ── 프로젝트 연결 시트 ───────────────────────────────────────
  Future<void> _showLinkProjectSheet(bool isKorean) async {
    final projects = ref.read(projectListProvider).valueOrNull ?? const <ProjectModel>[];
    final selected = await showModalBottomSheet<_ProjectLinkChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectLinkSheet(
        projects: projects,
        currentProjectId: _session?.projectId,
        isKorean: isKorean,
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(patternSessionRepositoryProvider);
          if (selected.createNew) {
            // 새 프로젝트 생성 (도안과 자동 연결)
            final user = ref.read(authStateProvider).valueOrNull;
            if (user == null) return;
            final newProject = ProjectModel.empty(uid: user.uid).copyWith(
              title: widget.chart.title.isEmpty
                  ? (isKorean ? '새 프로젝트' : 'New Project')
                  : widget.chart.title,
              sourcePatternId: _id,
            );
            final created =
                await ref.read(projectRepositoryProvider).createProject(newProject);
            await repo.linkProject(_id, created.id);
            setState(() {
              _session = _session?.copyWith(projectId: created.id) ??
                  _session;
            });
          } else if (selected.unlink) {
            await repo.unlinkProject(_id);
            setState(() {
              _session = _session?.copyWith(clearProjectId: true);
            });
          } else if (selected.projectId != null) {
            await repo.linkProject(_id, selected.projectId!);
            setState(() {
              _session = _session?.copyWith(projectId: selected.projectId);
            });
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '연결됐어요.' : 'Linked.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  // ── 스와치 연결 시트 ─────────────────────────────────────────
  Future<void> _showLinkSwatchSheet(bool isKorean) async {
    final swatches = ref.read(swatchListProvider).valueOrNull ?? const <SwatchModel>[];
    final selected = await showModalBottomSheet<_SwatchLinkChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SwatchLinkSheet(
        swatches: swatches,
        currentSwatchId: _session?.swatchId,
        isKorean: isKorean,
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(patternSessionRepositoryProvider);
          if (selected.unlink) {
            await repo.unlinkSwatch(_id);
            setState(() {
              _session = _session?.copyWith(clearSwatchId: true);
            });
          } else if (selected.swatchId != null) {
            await repo.linkSwatch(_id, selected.swatchId!);
            setState(() {
              _session = _session?.copyWith(swatchId: selected.swatchId);
            });
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '연결됐어요.' : 'Linked.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counter = ref.watch(counterByChartIdProvider(_id)).valueOrNull;

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : null,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.transparent,
        foregroundColor: _isDark ? Colors.white : null,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isDark && _totalPages > 0
            ? Text('$_currentPage / $_totalPages',
                style: T.caption.copyWith(color: Colors.white70))
            : Text(widget.chart.title,
                style: T.h3.copyWith(color: _isDark ? Colors.white : null)),
        actions: [
          _ToolIcon(
            icon: Icons.edit_rounded,
            active: _highlighterActive,
            activeColor: C.og,
            dimColor: _isDark ? Colors.white38 : C.tx2,
            onTap: () => setState(() => _highlighterActive = !_highlighterActive),
          ),
          _ToolIcon(
            icon: Icons.sticky_note_2_rounded,
            active: _stickyActive,
            activeColor: C.lmD,
            dimColor: _isDark ? Colors.white38 : C.tx2,
            onTap: () => setState(() => _stickyActive = !_stickyActive),
          ),
          _ToolIcon(
            icon: Icons.exposure_plus_1_rounded,
            active: _counterActive,
            activeColor: C.pkD,
            dimColor: _isDark ? Colors.white38 : C.tx2,
            onTap: () => setState(() => _counterActive = !_counterActive),
          ),
          _ToolIcon(
            icon: Icons.straighten_rounded,
            active: _rulerActive,
            activeColor: C.lv,
            dimColor: _isDark ? Colors.white38 : C.tx2,
            onTap: () => setState(() => _rulerActive = !_rulerActive),
          ),
          _ToolIcon(
            icon: Icons.square_foot_rounded,
            active: _measureActive,
            activeColor: const Color(0xFF32D74B),
            dimColor: _isDark ? Colors.white38 : C.tx2,
            onTap: () => setState(() {
              _measureActive = !_measureActive;
              if (_measureActive) {
                _angleHandle1 = const Offset(80, 200);
                _angleHandle2 = const Offset(260, 200);
                _anglePivot = const Offset(170, 200);
                _circleCenter = const Offset(175, 240);
                _circleRadius = 80.0;
              }
            }),
          ),
          // 연결 메뉴 (프로젝트 / 스와치)
          PopupMenuButton<String>(
            tooltip: isKorean ? '연결' : 'Link',
            icon: Icon(Icons.link_rounded,
                color: _isDark ? Colors.white70 : C.tx2),
            onSelected: (value) {
              switch (value) {
                case 'link_project':
                  _showLinkProjectSheet(isKorean);
                  break;
                case 'link_swatch':
                  _showLinkSwatchSheet(isKorean);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'link_project',
                child: Row(children: [
                  Icon(Icons.folder_special_rounded, color: C.pkD, size: 18),
                  const SizedBox(width: 8),
                  Text(_session?.projectId != null && _session!.projectId!.isNotEmpty
                      ? (isKorean ? '프로젝트 연결 변경' : 'Change Project')
                      : (isKorean ? '프로젝트 시작하기' : 'Link Project')),
                ]),
              ),
              PopupMenuItem(
                value: 'link_swatch',
                child: Row(children: [
                  Icon(Icons.grid_on_rounded, color: C.lvD, size: 18),
                  const SizedBox(width: 8),
                  Text(_session?.swatchId != null && _session!.swatchId!.isNotEmpty
                      ? (isKorean ? '스와치 연결 변경' : 'Change Swatch')
                      : (isKorean ? '스와치 연결하기' : 'Link Swatch')),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Base content
                  AbsorbPointer(
                    absorbing: _highlighterActive,
                    child: _buildBase(),
                  ),
                  // Strokes always visible (non-interactive when tool off)
                  if (_strokes.isNotEmpty && !_highlighterActive)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _HighlighterPainter(
                            strokes: _strokes,
                            current: const [],
                            currentColor: _highlightColor,
                          ),
                        ),
                      ),
                    ),
                  // Highlighter drawing overlay
                  if (_highlighterActive)
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (d) =>
                            setState(() => _currentStroke = [d.localPosition]),
                        onPanUpdate: (d) {
                          if (_isErasing) {
                            setState(() => _strokes.removeWhere((s) =>
                                s.points.any(
                                    (p) => (p - d.localPosition).distance < 22)));
                            _saveStrokes();
                          } else {
                            setState(() =>
                                _currentStroke = [..._currentStroke, d.localPosition]);
                          }
                        },
                        onPanEnd: (d) {
                          if (!_isErasing && _currentStroke.isNotEmpty) {
                            setState(() {
                              _strokes.add(_Stroke(
                                  points: List.from(_currentStroke),
                                  color: _highlightColor));
                              _currentStroke = [];
                            });
                            _saveStrokes();
                          } else {
                            setState(() => _currentStroke = []);
                          }
                        },
                        child: CustomPaint(
                          painter: _HighlighterPainter(
                            strokes: _strokes,
                            current: _currentStroke,
                            currentColor: _highlightColor,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  // Ruler
                  if (_rulerActive)
                    Positioned(
                      top: _rulerY,
                      left: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 2),
                            child: Text(
                              isKorean ? '↕ 드래그' : '↕ drag',
                              style: TextStyle(
                                color: C.lv.withValues(alpha: 0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onVerticalDragUpdate: (d) {
                              setState(() => _rulerY =
                                  (_rulerY + d.delta.dy).clamp(0, maxH - 60));
                              _saveRuler();
                            },
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: C.lv.withValues(alpha: 0.18),
                                border: Border(
                                  top: BorderSide(color: C.lv, width: 2),
                                  bottom: BorderSide(color: C.lv, width: 2),
                                ),
                              ),
                              child: Row(children: [
                                const SizedBox(width: 12),
                                Icon(Icons.drag_handle_rounded, color: C.lv, size: 18),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Measurement overlays
                  // Vertical rulers — shown in ALL measure modes
                  if (_measureActive)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _VerticalRulerPainter(isDark: _isDark),
                        ),
                      ),
                    ),
                  if (_measureActive && _measureMode == _MeasureMode.grid)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GridPainter(
                              useInch: _measureUseInch, isDark: _isDark),
                        ),
                      ),
                    ),
                  if (_measureActive && _measureMode == _MeasureMode.angle)
                    Positioned.fill(
                      child: _AngleTool(
                        handle1: _angleHandle1,
                        handle2: _angleHandle2,
                        pivot: _anglePivot,
                        isDark: _isDark,
                        onHandle1: (o) => setState(() => _angleHandle1 = o),
                        onHandle2: (o) => setState(() => _angleHandle2 = o),
                        onPivot: (o) => setState(() => _anglePivot = o),
                      ),
                    ),
                  if (_measureActive && _measureMode == _MeasureMode.circle)
                    Positioned.fill(
                      child: _CircleTool(
                        center: _circleCenter,
                        radius: _circleRadius,
                        isDark: _isDark,
                        onCenter: (o) => setState(() => _circleCenter = o),
                        onRadius: (r) => setState(() => _circleRadius = r),
                      ),
                    ),
                  if (_measureActive && _measureMode == _MeasureMode.yarn)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _YarnRulerPainter(isDark: _isDark),
                        ),
                      ),
                    ),
                  // Sticky note
                  if (_stickyActive)
                    Positioned(
                      left: _stickyX.clamp(0, (maxW - 160).clamp(0, double.infinity)),
                      top: _stickyY.clamp(0, (maxH - 140).clamp(0, double.infinity)),
                      child: GestureDetector(
                        onPanUpdate: _stickyEditing
                            ? null
                            : (d) {
                                setState(() {
                                  _stickyX = (_stickyX + d.delta.dx)
                                      .clamp(0, (maxW - 160).clamp(0, double.infinity));
                                  _stickyY = (_stickyY + d.delta.dy)
                                      .clamp(0, (maxH - 140).clamp(0, double.infinity));
                                });
                                _saveSticky();
                              },
                        child: _StickyNoteWidget(
                          controller: _stickyCtrl,
                          isEditing: _stickyEditing,
                          onEditToggle: () =>
                              setState(() => _stickyEditing = !_stickyEditing),
                          onTextChanged: (v) => _saveSticky(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Highlighter toolbar
            if (_highlighterActive)
              _HighlighterBar(
                colors: _highlightColors,
                selected: _highlightColor,
                isErasing: _isErasing,
                isDark: _isDark,
                onColor: (c) => setState(() {
                  _highlightColor = c;
                  _isErasing = false;
                }),
                onEraser: () => setState(() => _isErasing = !_isErasing),
                onClear: () {
                  setState(() => _strokes.clear());
                  _saveStrokes();
                },
              ),
            // Measure bar
            if (_measureActive)
              _MeasureBar(
                mode: _measureMode,
                useInch: _measureUseInch,
                isDark: _isDark,
                onMode: (m) => setState(() => _measureMode = m),
                onToggleUnit: () =>
                    setState(() => _measureUseInch = !_measureUseInch),
              ),
            // Counter dock
            if (_counterActive)
              _CounterDock(
                counter: counter,
                isKorean: isKorean,
                isDark: _isDark,
                onIncrementRow: (delta) {
                  if (counter != null) {
                    final v = (counter.rowCount + delta).clamp(0, 99999);
                    final d = v - counter.rowCount;
                    if (d != 0) {
                      ref.read(counterRepositoryProvider).incrementRow(counter.id, d);
                    }
                  }
                },
                onIncrementStitch: (delta) {
                  if (counter != null) {
                    final v = (counter.stitchCount + delta).clamp(0, 99999);
                    final d = v - counter.stitchCount;
                    if (d != 0) {
                      ref.read(counterRepositoryProvider).incrementStitch(counter.id, d);
                    }
                  }
                },
                onCreateCounter: () => _createAndLinkCounter(isKorean),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildBase() {
    switch (widget.chart.type) {
      case PatternType.image:
        if (widget.chart.imageUrl.isEmpty) {
          return const Center(child: Icon(Icons.broken_image_rounded, size: 64));
        }
        return InteractiveViewer(
          child: Center(
            child: Image.network(
              widget.chart.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (ctx, e, s) =>
                  const Icon(Icons.broken_image_rounded, size: 64),
            ),
          ),
        );
      case PatternType.pdf:
        if (kIsWeb) {
          return const Center(
              child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white54, size: 64));
        }
        if (_pdfLoading) return Center(child: CircularProgressIndicator(color: C.lv));
        if (_pdfError != null) {
          return Center(
              child: Text(_pdfError!,
                  style: const TextStyle(color: Colors.white70)));
        }
        return PDFView(
          filePath: _localPdfPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          onPageChanged: (page, total) {
            if (mounted) {
              setState(() {
                _currentPage = (page ?? 0) + 1;
                _totalPages = total ?? 0;
              });
            }
          },
          onError: (e) {
            if (mounted) setState(() => _pdfError = '$e');
          },
        );
      case PatternType.chart:
        return const SizedBox.shrink();
    }
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _Stroke {
  final List<Offset> points;
  final Color color;
  const _Stroke({required this.points, required this.color});
}

// ── Tool icon ─────────────────────────────────────────────────────────────────

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color dimColor;
  final VoidCallback onTap;
  const _ToolIcon({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.dimColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: active ? activeColor : dimColor),
        onPressed: onTap,
      );
}

// ── Highlighter painter ───────────────────────────────────────────────────────

class _HighlighterPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> current;
  final Color currentColor;
  const _HighlighterPainter(
      {required this.strokes, required this.current, required this.currentColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _draw(canvas, s.points, s.color);
    }
    if (current.length > 1) _draw(canvas, current, currentColor);
  }

  void _draw(Canvas canvas, List<Offset> pts, Color color) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HighlighterPainter old) => true;
}

// ── Highlighter toolbar ───────────────────────────────────────────────────────

class _HighlighterBar extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final bool isErasing;
  final bool isDark;
  final ValueChanged<Color> onColor;
  final VoidCallback onEraser;
  final VoidCallback onClear;
  const _HighlighterBar({
    required this.colors,
    required this.selected,
    required this.isErasing,
    required this.isDark,
    required this.onColor,
    required this.onEraser,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A2E) : C.bg;
    return Container(
      height: 52,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onColor(c),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: selected == c && !isErasing
                      ? Border.all(
                          color: isDark ? Colors.white : C.tx, width: 2)
                      : null,
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: onEraser,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isErasing
                    ? (isDark ? Colors.white24 : C.tx2.withValues(alpha: 0.15))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.backspace_outlined,
                  size: 20, color: isDark ? Colors.white70 : C.tx2),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.delete_sweep_rounded, size: 20, color: C.og),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky note ───────────────────────────────────────────────────────────────

class _StickyNoteWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final ValueChanged<String> onTextChanged;
  const _StickyNoteWidget({
    required this.controller,
    required this.isEditing,
    required this.onEditToggle,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(2, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF176),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.drag_indicator_rounded,
                    size: 14, color: Color(0xFF9E9E9E)),
                const Spacer(),
                GestureDetector(
                  onTap: onEditToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      isEditing
                          ? Icons.check_rounded
                          : Icons.edit_rounded,
                      size: 14,
                      color: const Color(0xFF616161),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: isEditing
                ? TextField(
                    controller: controller,
                    maxLines: null,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF333333), height: 1.4),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onChanged: onTextChanged,
                  )
                : GestureDetector(
                    onTap: onEditToggle,
                    child: Text(
                      controller.text.isEmpty
                          ? '📝 탭해서 편집'
                          : controller.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: controller.text.isEmpty
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF333333),
                        height: 1.4,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Counter dock ──────────────────────────────────────────────────────────────

class _CounterDock extends StatelessWidget {
  final CounterModel? counter;
  final bool isKorean;
  final bool isDark;
  final void Function(int) onIncrementRow;
  final void Function(int) onIncrementStitch;
  final VoidCallback onCreateCounter;
  const _CounterDock({
    required this.counter,
    required this.isKorean,
    required this.isDark,
    required this.onIncrementRow,
    required this.onIncrementStitch,
    required this.onCreateCounter,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F0F1E) : C.bg;
    final muted = isDark ? Colors.white38 : C.mu;

    if (counter == null) {
      return Container(
        height: 76,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.exposure_plus_1_rounded, color: muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isKorean
                    ? '카운터를 연결하면 여기서 바로 사용할 수 있어요'
                    : 'Link a counter to use it here',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onCreateCounter,
              child: Text(isKorean ? '연결하기' : 'Link',
                  style: TextStyle(color: C.pkD, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final textColor = isDark ? Colors.white : C.tx;
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.exposure_plus_1_rounded, color: C.pkD, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  counter!.name,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CounterCtrl(
                  label: isKorean ? '단' : 'Row',
                  value: counter!.rowCount,
                  isDark: isDark,
                  onMinus: () => onIncrementRow(-1),
                  onPlus: () => onIncrementRow(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CounterCtrl(
                  label: isKorean ? '코' : 'St',
                  value: counter!.stitchCount,
                  isDark: isDark,
                  onMinus: () => onIncrementStitch(-1),
                  onPlus: () => onIncrementStitch(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterCtrl extends StatelessWidget {
  final String label;
  final int value;
  final bool isDark;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _CounterCtrl({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : C.tx;
    final muted = isDark ? Colors.white38 : C.mu;
    return Row(
      children: [
        Text(label,
            style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(width: 8),
        _DockBtn(icon: Icons.remove_rounded, isDark: isDark, onTap: onMinus),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 20),
          ),
        ),
        const SizedBox(width: 6),
        _DockBtn(icon: Icons.add_rounded, isDark: isDark, onTap: onPlus),
      ],
    );
  }
}

class _DockBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _DockBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : C.lvL,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isDark ? Colors.white70 : C.lvD),
        ),
      );
}

// ── Measurement tool ──────────────────────────────────────────────────────────

enum _MeasureMode { grid, angle, circle, yarn }

// 160 logical px ≈ 1 inch (Flutter mdpi baseline) → 1cm ≈ 62.99 px
const _pxPerCm = 160.0 / 2.54;
const _pxPerIn = 160.0;
const _measureGreen = Color(0xFF32D74B);

class _GridPainter extends CustomPainter {
  final bool useInch;
  final bool isDark;
  const _GridPainter({required this.useInch, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = useInch ? _pxPerIn : _pxPerCm;
    // 하얀 배경에서도 보이도록 인디고 계열 사용
    final thinColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFF5C6BC0).withValues(alpha: 0.35);
    final boldColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF5C6BC0).withValues(alpha: 0.70);
    final thin = Paint()..color = thinColor..strokeWidth = 0.8;
    final bold = Paint()..color = boldColor..strokeWidth = 1.4;

    int xi = 0;
    for (double x = 0; x <= size.width; x += unit, xi++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), xi % 5 == 0 ? bold : thin);
      if (xi > 0 && xi % 5 == 0) {
        _label(canvas, '$xi${useInch ? '"' : 'cm'}', Offset(x + 2, 3), boldColor);
      }
    }
    int yi = 0;
    for (double y = 0; y <= size.height; y += unit, yi++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), yi % 5 == 0 ? bold : thin);
      if (yi > 0 && yi % 5 == 0) {
        _label(canvas, '$yi${useInch ? '"' : 'cm'}', Offset(3, y + 2), boldColor);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.useInch != useInch || old.isDark != isDark;
}

// ── Yarn/Needle ruler ─────────────────────────────────────────────────────────

const _pxPerMm = _pxPerCm / 10.0;

// 실 두께 표준 (mm) — 국제 공통 명칭
final _yarnWeights = [
  (1.0, 'Lace',       Color(0xFFAB47BC)),
  (2.0, 'Fingering',  Color(0xFF42A5F5)),
  (2.5, 'Sport',      Color(0xFF26C6DA)),
  (3.0, 'DK',         Color(0xFF66BB6A)),
  (4.0, 'Worsted',    Color(0xFFFFCA28)),
  (4.5, 'Aran',       Color(0xFFFFA726)),
  (6.0, 'Bulky',      Color(0xFFEF5350)),
  (9.0, 'S.Bulky',    Color(0xFF8D6E63)),
];

class _YarnRulerPainter extends CustomPainter {
  final bool isDark;
  const _YarnRulerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : Colors.black;
    final bg = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85);
    final cy = size.height / 2;
    const stripH = 56.0;
    const legendH = 28.0;
    final legendY = cy + stripH / 2 + 6;

    // Strip background
    canvas.drawRect(
      Rect.fromLTWH(0, cy - stripH / 2, size.width, stripH),
      Paint()..color = bg,
    );
    // Strip borders
    final border = Paint()
      ..color = _measureGreen.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, cy - stripH / 2), Offset(size.width, cy - stripH / 2), border);
    canvas.drawLine(Offset(0, cy + stripH / 2), Offset(size.width, cy + stripH / 2), border);

    // mm tick marks
    final tickPaint = Paint()..color = base.withValues(alpha: 0.5)..strokeWidth = 0.8;
    final boldTick = Paint()..color = base.withValues(alpha: 0.85)..strokeWidth = 1.5;
    int mm = 0;
    for (double x = 0; x <= size.width; x += _pxPerMm, mm++) {
      final isCm = mm % 10 == 0;
      final is5mm = mm % 5 == 0;
      final h = isCm ? 20.0 : is5mm ? 12.0 : 6.0;
      final p = isCm ? boldTick : tickPaint;
      canvas.drawLine(Offset(x, cy - stripH / 2), Offset(x, cy - stripH / 2 + h), p);
      canvas.drawLine(Offset(x, cy + stripH / 2), Offset(x, cy + stripH / 2 - h), p);
      if (isCm && mm > 0) {
        _drawText(canvas, '${mm ~/ 10}', Offset(x + 2, cy - stripH / 2 + 21),
            base.withValues(alpha: 0.7), 8);
      }
    }

    // Yarn weight marker lines (colored)
    for (final (weightMm, _, color) in _yarnWeights) {
      final x = weightMm * _pxPerMm;
      if (x > size.width) break;
      canvas.drawLine(
        Offset(x, cy - stripH / 2 + 2),
        Offset(x, cy + stripH / 2 - 2),
        Paint()..color = color.withValues(alpha: 0.6)..strokeWidth = 1.5,
      );
    }

    // Guide text
    _drawText(canvas, '← 실·바늘을 여기에 대세요 →',
        Offset(size.width / 2 - 100, cy - 9), base.withValues(alpha: 0.55), 10);

    // Legend background
    canvas.drawRect(
      Rect.fromLTWH(0, legendY, size.width, legendH),
      Paint()..color = bg,
    );

    // Legend items — horizontal, color dot + name
    double lx = 8;
    for (final (weightMm, name, color) in _yarnWeights) {
      final dotR = 4.0;
      canvas.drawCircle(Offset(lx + dotR, legendY + legendH / 2), dotR, Paint()..color = color);
      final label = '${weightMm % 1 == 0 ? weightMm.toInt() : weightMm}mm $name';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(color: base.withValues(alpha: 0.75), fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx + dotR * 2 + 3, legendY + (legendH - tp.height) / 2));
      lx += dotR * 2 + tp.width + 10;
      if (lx > size.width - 20) break;
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_YarnRulerPainter old) => old.isDark != isDark;
}

// ── Angle tool ────────────────────────────────────────────────────────────────

class _AngleTool extends StatelessWidget {
  final Offset handle1, handle2, pivot;
  final bool isDark;
  final ValueChanged<Offset> onHandle1, onHandle2, onPivot;
  const _AngleTool({
    required this.handle1, required this.handle2, required this.pivot,
    required this.isDark, required this.onHandle1, required this.onHandle2,
    required this.onPivot,
  });

  double get _deg {
    final v1 = handle1 - pivot;
    final v2 = handle2 - pivot;
    if (v1.distance < 1 || v2.distance < 1) return 0;
    final cos = (v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance);
    return acos(cos.clamp(-1.0, 1.0)) * 180 / pi;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _AnglePainter(handle1: handle1, handle2: handle2, pivot: pivot),
          ),
        ),
      ),
      _MeasureHandle(pos: pivot, isPivot: true, onDrag: onPivot),
      _MeasureHandle(pos: handle1, onDrag: onHandle1),
      _MeasureHandle(pos: handle2, onDrag: onHandle2),
      Positioned(
        left: pivot.dx + 12,
        top: pivot.dy - 30,
        child: _MeasureLabel(text: '${_deg.toStringAsFixed(1)}°'),
      ),
    ]);
  }
}

class _AnglePainter extends CustomPainter {
  final Offset handle1, handle2, pivot;
  const _AnglePainter({required this.handle1, required this.handle2, required this.pivot});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _measureGreen.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, handle1, p);
    canvas.drawLine(pivot, handle2, p);
  }

  @override
  bool shouldRepaint(_AnglePainter old) => true;
}

// ── Circle tool ───────────────────────────────────────────────────────────────

class _CircleTool extends StatelessWidget {
  final Offset center;
  final double radius;
  final bool isDark;
  final ValueChanged<Offset> onCenter;
  final ValueChanged<double> onRadius;
  const _CircleTool({
    required this.center, required this.radius, required this.isDark,
    required this.onCenter, required this.onRadius,
  });

  @override
  Widget build(BuildContext context) {
    final rHandle = Offset(center.dx + radius, center.dy);
    final dCm = (radius * 2) / _pxPerCm;
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CirclePainter(center: center, radius: radius),
          ),
        ),
      ),
      _MeasureHandle(pos: center, isPivot: true, onDrag: onCenter),
      _MeasureHandle(
        pos: rHandle,
        onDrag: (o) => onRadius(max(24.0, (o - center).distance)),
      ),
      Positioned(
        left: center.dx + 8,
        top: center.dy - 30,
        child: _MeasureLabel(text: '⌀ ${dCm.toStringAsFixed(1)} cm'),
      ),
    ]);
  }
}

class _CirclePainter extends CustomPainter {
  final Offset center;
  final double radius;
  const _CirclePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _measureGreen.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, p);
    final lp = Paint()
      ..color = _measureGreen.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), lp);
  }

  @override
  bool shouldRepaint(_CirclePainter old) => true;
}

// ── Measure bar ───────────────────────────────────────────────────────────────

class _MeasureBar extends StatelessWidget {
  final _MeasureMode mode;
  final bool useInch;
  final bool isDark;
  final ValueChanged<_MeasureMode> onMode;
  final VoidCallback onToggleUnit;
  const _MeasureBar({
    required this.mode, required this.useInch, required this.isDark,
    required this.onMode, required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A2E) : C.bg;
    final modes = [
      (_MeasureMode.grid, Icons.grid_on_rounded, '격자'),
      (_MeasureMode.angle, Icons.architecture_rounded, '각도'),
      (_MeasureMode.circle, Icons.radio_button_unchecked_rounded, '원'),
      (_MeasureMode.yarn, Icons.straighten_rounded, '실·바늘'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF0F0F1E) : C.gx,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '※ 치수는 기기 화면 특성에 따라 오차가 있을 수 있어 참고용으로만 사용하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : C.mu,
            ),
          ),
        ),
        Container(
      height: 56,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (m, icon, label) in modes) ...[
            GestureDetector(
              onTap: () => onMode(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: mode == m ? _measureGreen.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: mode == m ? _measureGreen : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14,
                      color: mode == m ? _measureGreen : (isDark ? Colors.white38 : C.mu)),
                  const SizedBox(width: 3),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: mode == m ? _measureGreen : (isDark ? Colors.white38 : C.mu),
                          fontWeight: mode == m ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          if (mode == _MeasureMode.grid)
            GestureDetector(
              onTap: onToggleUnit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _measureGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _measureGreen, width: 1),
                ),
                child: Text(useInch ? 'in' : 'cm',
                    style: const TextStyle(
                        color: _measureGreen, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
        ),
      ],
    );
  }
}

// ── Shared measure widgets ────────────────────────────────────────────────────

class _MeasureHandle extends StatelessWidget {
  final Offset pos;
  final bool isPivot;
  final ValueChanged<Offset> onDrag;
  const _MeasureHandle({required this.pos, this.isPivot = false, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    const sz = 28.0;
    return Positioned(
      left: pos.dx - sz / 2,
      top: pos.dy - sz / 2,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(Offset(pos.dx + d.delta.dx, pos.dy + d.delta.dy)),
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: isPivot ? _measureGreen.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: _measureGreen, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(
            isPivot ? Icons.open_with_rounded : Icons.drag_indicator_rounded,
            size: 14,
            color: isPivot ? Colors.white : _measureGreen,
          ),
        ),
      ),
    );
  }
}

class _MeasureLabel extends StatelessWidget {
  final String text;
  const _MeasureLabel({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _measureGreen,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

// ── Vertical ruler (모든 측정 모드 공통) ──────────────────────────────────────

class _VerticalRulerPainter extends CustomPainter {
  final bool isDark;
  const _VerticalRulerPainter({required this.isDark});

  static const _stripW = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : Colors.black;
    final bg = (isDark ? const Color(0xFF1A1A2E) : Colors.white).withValues(alpha: 0.90);
    final borderPaint = Paint()
      ..color = _measureGreen.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    final tickPaint = Paint()..color = base.withValues(alpha: 0.55)..strokeWidth = 0.9;
    final boldTick = Paint()..color = base.withValues(alpha: 0.85)..strokeWidth = 1.4;

    // ── Left strip (cm) ──
    canvas.drawRect(Rect.fromLTWH(0, 0, _stripW, size.height), Paint()..color = bg);
    canvas.drawLine(const Offset(_stripW, 0), Offset(_stripW, size.height), borderPaint);
    _drawText(canvas, 'cm', const Offset(6, 6), _measureGreen, 10, bold: true);

    int ci = 0;
    for (double y = 0; y <= size.height; y += _pxPerCm, ci++) {
      final isMajor = ci % 5 == 0;
      final tickW = isMajor ? 18.0 : ci % 2 == 0 ? 10.0 : 6.0;
      canvas.drawLine(Offset(_stripW - tickW, y), Offset(_stripW, y),
          isMajor ? boldTick : tickPaint);
      if (ci > 0) {
        _drawText(canvas, '$ci', Offset(2, y - 8),
            base.withValues(alpha: isMajor ? 0.85 : 0.55), isMajor ? 9.0 : 8.0);
      }
    }

    // ── Right strip (inch) ──
    final rx = size.width - _stripW;
    canvas.drawRect(Rect.fromLTWH(rx, 0, _stripW, size.height), Paint()..color = bg);
    canvas.drawLine(Offset(rx, 0), Offset(rx, size.height), borderPaint);
    _drawText(canvas, 'in', Offset(rx + 6, 6), _measureGreen, 10, bold: true);

    int ii = 0;
    for (double y = 0; y <= size.height; y += _pxPerIn, ii++) {
      final isMajor = ii % 6 == 0;
      final tickW = isMajor ? 18.0 : 10.0;
      canvas.drawLine(Offset(rx, y), Offset(rx + tickW, y),
          isMajor ? boldTick : tickPaint);
      if (ii > 0) {
        _drawText(canvas, '$ii"', Offset(rx + tickW + 2, y - 8),
            base.withValues(alpha: isMajor ? 0.85 : 0.55), isMajor ? 9.0 : 8.0);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double fontSize,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_VerticalRulerPainter old) => old.isDark != isDark;
}

// ── 연결 선택 데이터 ──────────────────────────────────────────────────────────

class _ProjectLinkChoice {
  final String? projectId;
  final bool createNew;
  final bool unlink;
  const _ProjectLinkChoice({this.projectId, this.createNew = false, this.unlink = false});
}

class _SwatchLinkChoice {
  final String? swatchId;
  final bool unlink;
  const _SwatchLinkChoice({this.swatchId, this.unlink = false});
}

// ── 프로젝트 연결 바텀시트 ─────────────────────────────────────────────────────

class _ProjectLinkSheet extends StatelessWidget {
  final List<ProjectModel> projects;
  final String? currentProjectId;
  final bool isKorean;

  const _ProjectLinkSheet({
    required this.projects,
    required this.currentProjectId,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final hasLinked = currentProjectId != null && currentProjectId!.isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.bd,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.folder_special_rounded, color: C.pkD, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isKorean ? '프로젝트에 연결' : 'Link to Project',
                      style: T.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _LinkActionTile(
                      icon: Icons.add_rounded,
                      iconColor: C.lv,
                      title: isKorean ? '새 프로젝트 시작하기' : 'Start New Project',
                      subtitle: isKorean
                          ? '이 도안을 기반으로 새 프로젝트 생성'
                          : 'Create a new project from this pattern',
                      onTap: () => Navigator.pop(
                          ctx, const _ProjectLinkChoice(createNew: true)),
                    ),
                    if (hasLinked)
                      _LinkActionTile(
                        icon: Icons.link_off_rounded,
                        iconColor: C.og,
                        title: isKorean ? '연결 해제' : 'Unlink',
                        subtitle: isKorean
                            ? '현재 프로젝트와 연결을 해제합니다'
                            : 'Remove link to current project',
                        onTap: () => Navigator.pop(
                            ctx, const _ProjectLinkChoice(unlink: true)),
                      ),
                    if (projects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          isKorean ? '기존 프로젝트에 연결' : 'Link to existing',
                          style: T.sm.copyWith(color: C.mu, fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (final p in projects)
                        _ProjectRow(
                          project: p,
                          isSelected: p.id == currentProjectId,
                          onTap: () => Navigator.pop(
                              ctx, _ProjectLinkChoice(projectId: p.id)),
                        ),
                    ] else ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          isKorean
                              ? '연결할 프로젝트가 없어요.\n위에서 새 프로젝트를 만들어 주세요.'
                              : 'No projects found.\nTry starting a new one above.',
                          textAlign: TextAlign.center,
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final ProjectModel project;
  final bool isSelected;
  final VoidCallback onTap;
  const _ProjectRow({
    required this.project,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? C.lv.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? C.lv : C.bd,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: C.pk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                image: project.coverPhotoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(project.coverPhotoUrl),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: project.coverPhotoUrl.isEmpty
                  ? Icon(Icons.folder_rounded, color: C.pkD, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title.isEmpty ? '(untitled)' : project.title,
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (project.yarnName.isNotEmpty)
                    Text(project.yarnName,
                        style: T.caption.copyWith(color: C.mu),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: C.lv, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 스와치 연결 바텀시트 ───────────────────────────────────────────────────────

class _SwatchLinkSheet extends StatelessWidget {
  final List<SwatchModel> swatches;
  final String? currentSwatchId;
  final bool isKorean;

  const _SwatchLinkSheet({
    required this.swatches,
    required this.currentSwatchId,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final hasLinked = currentSwatchId != null && currentSwatchId!.isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.bd,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.grid_on_rounded, color: C.lvD, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isKorean ? '스와치에 연결' : 'Link to Swatch',
                      style: T.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    if (hasLinked)
                      _LinkActionTile(
                        icon: Icons.link_off_rounded,
                        iconColor: C.og,
                        title: isKorean ? '연결 해제' : 'Unlink',
                        subtitle: isKorean
                            ? '현재 스와치와 연결을 해제합니다'
                            : 'Remove link to current swatch',
                        onTap: () => Navigator.pop(
                            ctx, const _SwatchLinkChoice(unlink: true)),
                      ),
                    if (swatches.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          isKorean ? '기존 스와치에 연결' : 'Link to existing',
                          style: T.sm.copyWith(color: C.mu, fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (final s in swatches)
                        _SwatchRow(
                          swatch: s,
                          isSelected: s.id == currentSwatchId,
                          onTap: () => Navigator.pop(
                              ctx, _SwatchLinkChoice(swatchId: s.id)),
                        ),
                    ] else ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          isKorean
                              ? '연결할 스와치가 없어요.\n먼저 스와치를 만들어 주세요.'
                              : 'No swatches found.\nCreate a swatch first.',
                          textAlign: TextAlign.center,
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final SwatchModel swatch;
  final bool isSelected;
  final VoidCallback onTap;
  const _SwatchRow({
    required this.swatch,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = swatch.swatchName.isEmpty
        ? (swatch.yarnName.isEmpty ? '(untitled)' : swatch.yarnName)
        : swatch.swatchName;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? C.lv.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? C.lv : C.bd,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                image: swatch.beforePhotoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(swatch.beforePhotoUrl),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: swatch.beforePhotoUrl.isEmpty
                  ? Icon(Icons.grid_on_rounded, color: C.lvD, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (swatch.gaugeDisplay != '0 x 0')
                    Text(swatch.gaugeDisplay,
                        style: T.caption.copyWith(color: C.mu),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: C.lv, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 공용 액션 타일 ─────────────────────────────────────────────────────────────

class _LinkActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.bodyBold),
                  const SizedBox(height: 2),
                  Text(subtitle, style: T.caption.copyWith(color: C.mu)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}
