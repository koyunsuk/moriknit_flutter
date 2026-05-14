import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show acos, pi, max;
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
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
// 이슈 #665 Phase 5 — 원형 도안 PDF 내보내기.
import '../data/round_chart_pdf_exporter.dart';
import '../domain/ai_pattern_section.dart';
import '../domain/narrative_block.dart';
import '../domain/pattern_chart.dart';
import '../domain/pattern_session.dart';
// 이슈 #665 후속 — 원형 도안 트래킹/헤어라인 오버레이.
import '../domain/round_chart.dart';
// 이슈 #668 — 자유 Path 도안 뷰어.
import 'widgets/guide_path_editor_view.dart';
import 'widgets/round_chart_painter.dart';
import 'widgets/round_tracking_overlay.dart';

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

  // Ruler (가로 트래킹바)
  double _rulerY = 200.0;
  double _rulerHeight = 34.0; // #643: 사용자 조정 가능
  double _rulerBaseY = 200.0; // #643: 카운터 rowCount=1 기준 Y
  bool _rulerFollowCounter = true; // #643: 카운터 연동 on/off

  // Highlighter (이슈 #663-B — undo/redo/clear 시스템)
  final List<_Stroke> _strokes = [];
  final List<_Stroke> _redoStack = [];
  List<Offset> _currentStroke = [];
  Color _highlightColor = const Color(0x66FFFF00);
  static const _highlightColors = [
    Color(0x66FFFF00),
    Color(0x66FF9F0A),
    Color(0x6630D158),
    Color(0x66FF375F),
    Color(0x665AC8FA),
  ];

  // Sticky notes (이슈 #663-A — 다중 노트. 기존 단일 변수 → List)
  final List<_LocalStickyNote> _stickyNotes = [];

  // Timer
  bool _timerDockVisible = false;
  bool _timerRunning = false;
  int _sessionSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  int _reminderIntervalMin = 40;
  int _reminderCountdown = 0;
  int _reminderIndex = 0;
  // 이슈 #649 Phase 1 — 타이머 자동 이름 ("도안: {chart.title}"). 사용자 편집 가능.
  String _timerName = '';

  static const _reminders = [
    '잠시 스트레칭하세요 🙆',
    '물 한잔 마시세요 💧',
    '잠시 환기하세요 🌬️',
    '눈을 잠깐 감고 쉬어요 👁️',
    '손목을 가볍게 풀어주세요 🤲',
    '어깨를 돌려보세요 🔄',
    '잠깐 일어나서 걸어볼까요? 🚶',
    '목을 좌우로 천천히 돌려보세요 ↔️',
  ];

  // Vertical hairline (세로 헤어라인)
  bool _hairlineActive = false;
  double _hairlineX = 0.5;
  double _hairlineWidth = 20.0; // #643: 사용자 조정 가능

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

  // ── 이슈 #665 후속 — 원형 도안 전용 트래킹/헤어라인 state (사각 코드와 분리) ──
  /// 현재 라운드 (1-base).
  int _roundTrackingRound = 1;

  /// 현재 세그먼트 (0-base, -1 = 전체 라운드만 표시, 진행 표시 없음).
  int _roundTrackingSegment = -1;

  /// 현재 헤어라인 각도 (라디안). -π/2 = 12시 방향.
  double _roundHairlineAngle = -1.5707963267948966;

  /// 트래킹 호 활성 여부.
  bool _roundTrackingActive = false;

  /// 회전 헤어라인 활성 여부.
  bool _roundHairlineActive = false;

  /// 현재 라운드의 코마다 정확히 정렬할지 (헤어라인 스냅).
  bool _roundHairlineSnap = true;

  String get _id => widget.chart.id;
  bool get _isDark => widget.chart.type == PatternType.pdf;

  /// 텍스트뷰어 아이콘 — 항상 활성. 클릭 시 데이터 유무에 따라 안내.
  /// (이전: aiSections만 체크 → 일부 도안에서 비활성화 버그)
  bool get _hasNarrativeContent => true;

  /// 실제 표시 가능한 컨텐츠가 있는지 (클릭 시 분기용)
  bool get _hasAnyTextContent =>
      widget.chart.narrativeText.trim().isNotEmpty ||
      widget.chart.narrativeBlocks.isNotEmpty ||
      (widget.chart.aiSections?.isNotEmpty ?? false);

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
    debugPrint('[PatternViewerScreen] INIT id=${widget.chart.id} type=${widget.chart.type.name} title="${widget.chart.title}"');
    _loadState();
    _bootstrapSession();
    if (widget.chart.type == PatternType.pdf && !kIsWeb) _loadPdf();
  }

  // Firestore 세션 로드 — Hive 로드 후 호출되어 Firestore 값이 있으면 override.
  Future<void> _bootstrapSession() async {
    try {
      final repo = ref.read(patternSessionRepositoryProvider);
      final loaded = await repo.getOrCreate(_id);

      // 이슈 #627 (B-11) — 도안이 프로젝트에 연결돼 있으면 PatternSession.projectId 자동 설정.
      // 프로젝트 작업시간 집계가 자동으로 반영되도록 함.
      if (loaded.projectId == null &&
          widget.chart.linkedProjectId != null &&
          widget.chart.linkedProjectId!.isNotEmpty) {
        await repo.linkProject(_id, widget.chart.linkedProjectId!);
      }

      if (!mounted) return;
      setState(() {
        _session = loaded;
        _sessionApplied = true;
        _totalSeconds = loaded.totalSeconds;
        // 이슈 #649 Phase 1 — 타이머 이름 초기화 (저장값 우선, 없으면 "도안: {title}")
        final stored = loaded.timerName?.trim() ?? '';
        _timerName = stored.isNotEmpty
            ? stored
            : '도안: ${widget.chart.title}';
        // Firestore에 기존 값이 있으면 로컬 상태 override
        if (loaded.rulerY != 200.0 || loaded.hairlineX != null || loaded.strokes.isNotEmpty || loaded.stickyNotes.isNotEmpty) {
          _rulerY = loaded.rulerY;
          if (loaded.hairlineX != null) _hairlineX = loaded.hairlineX!;
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
          // 이슈 #663-A — 다중 스티키 노트 로드. Firestore에 저장된 모든 노트 채움.
          if (loaded.stickyNotes.isNotEmpty) {
            for (final n in _stickyNotes) {
              n.dispose();
            }
            _stickyNotes
              ..clear()
              ..addAll(loaded.stickyNotes.map((n) => _LocalStickyNote(
                    id: n.id,
                    text: n.text,
                    x: n.x,
                    y: n.y,
                  )));
          }
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

  /// 이슈 #663-A — 스티키 노트 List 전체를 Firestore에 동기화 (덮어쓰기).
  void _syncStickyNotes() {
    if (!_sessionApplied) return;
    final notes = _stickyNotes
        .map((n) => StickyNote(id: n.id, text: n.controller.text, x: n.x, y: n.y))
        .toList();
    ref
        .read(patternSessionRepositoryProvider)
        .setStickyNotes(_id, notes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 타이머 세션 종료 시 누적시간 Firestore 저장
    if (_sessionApplied && _sessionSeconds > 0) {
      ref.read(patternSessionRepositoryProvider)
          .updateTotalSeconds(_id, _totalSeconds + _sessionSeconds);
    }
    // 이슈 #663-A — 모든 스티키 노트 컨트롤러 정리
    for (final n in _stickyNotes) {
      n.dispose();
    }
    super.dispose();
  }

  // ── 타이머 메서드 ──────────────────────────────────────────────
  void _startTimer() {
    if (_timerRunning) return;
    // 이슈 #649 Phase 1 — 첫 시작 시 자동 이름 Firestore에 저장 (없을 때만)
    if (_sessionApplied &&
        (_session?.timerName == null || _session!.timerName!.trim().isEmpty)) {
      final auto = _timerName.trim().isEmpty
          ? '도안: ${widget.chart.title}'
          : _timerName;
      _timerName = auto;
      ref.read(patternSessionRepositoryProvider).updateTimerName(_id, auto);
    }
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _sessionSeconds++;
        _reminderCountdown++;
        if (_reminderCountdown >= _reminderIntervalMin * 60) {
          _reminderCountdown = 0;
          final msg = _reminders[_reminderIndex % _reminders.length];
          _reminderIndex++;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _timerRunning = false);
  }

  void _syncTimerToFirestore() {
    if (!_sessionApplied) return;
    ref.read(patternSessionRepositoryProvider)
        .updateTotalSeconds(_id, _totalSeconds + _sessionSeconds);
  }

  /// 이슈 #649 Phase 1 — 타이머 이름 인라인 편집
  Future<void> _editTimerName() async {
    final ctrl = TextEditingController(text: _timerName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1A1A2E) : C.bg,
        title: Text(
          '타이머 이름',
          style: T.h3.copyWith(color: _isDark ? Colors.white : C.tx),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: _isDark ? Colors.white : C.tx),
          decoration: InputDecoration(
            hintText: '예: 도안: ${widget.chart.title}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: T.body.copyWith(color: C.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('저장',
                style: T.body.copyWith(color: C.lvD, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _timerName = result);
    if (_sessionApplied) {
      ref.read(patternSessionRepositoryProvider).updateTimerName(_id, result);
    }
  }

  String _formatSession(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotal(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _loadState() {
    final b = _box;
    if (b == null) return;
    _rulerY = (b.get('ruler_y_$_id') as double?) ?? 200.0;
    _rulerHeight = (b.get('ruler_h_$_id') as double?) ?? 34.0; // #643
    _rulerBaseY = (b.get('ruler_base_y_$_id') as double?) ?? _rulerY; // #643
    _rulerFollowCounter = (b.get('ruler_follow_$_id') as bool?) ?? true; // #643
    _hairlineX = (b.get('hairline_x_$_id') as double?) ?? 0.5;
    _hairlineWidth = (b.get('hairline_w_$_id') as double?) ?? 20.0; // #643
    // 이슈 #663-A — 다중 스티키 노트: 신규 List JSON 로드 + 구 단일키 마이그레이션
    final stickyJson = b.get('sticky_notes_$_id') as String?;
    if (stickyJson != null) {
      try {
        for (final n in jsonDecode(stickyJson) as List) {
          _stickyNotes.add(_LocalStickyNote(
            id: n['id'] as String,
            text: n['text'] as String? ?? '',
            x: (n['x'] as num).toDouble(),
            y: (n['y'] as num).toDouble(),
          ));
        }
      } catch (_) {}
    }
    if (_stickyNotes.isEmpty) {
      final oldX = b.get('sticky_x_$_id') as double?;
      final oldY = b.get('sticky_y_$_id') as double?;
      final oldText = b.get('sticky_text_$_id') as String?;
      if (oldX != null || oldY != null || (oldText?.isNotEmpty ?? false)) {
        _stickyNotes.add(_LocalStickyNote(
          id: _defaultStickyId,
          text: oldText ?? '',
          x: oldX ?? 20.0,
          y: oldY ?? 120.0,
        ));
      }
    }
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

  void _saveHairline() {
    _box?.put('hairline_x_$_id', _hairlineX);
    _box?.put('hairline_w_$_id', _hairlineWidth); // #643
    if (_sessionApplied) {
      ref.read(patternSessionRepositoryProvider).updateHairline(_id, _hairlineX);
    }
  }

  void _saveRuler() {
    _box?.put('ruler_y_$_id', _rulerY);
    _box?.put('ruler_h_$_id', _rulerHeight); // #643
    _box?.put('ruler_base_y_$_id', _rulerBaseY); // #643
    _box?.put('ruler_follow_$_id', _rulerFollowCounter); // #643
    _syncRuler();
  }

  /// 이슈 #663-A — 스티키 노트 List 통째로 hive 저장 + Firestore 동기화.
  void _saveStickyNotes() {
    final json = jsonEncode(_stickyNotes.map((n) => {
          'id': n.id,
          'text': n.controller.text,
          'x': n.x,
          'y': n.y,
        }).toList());
    _box?.put('sticky_notes_$_id', json);
    _syncStickyNotes();
  }

  /// 이슈 #663-A — 새 스티키 노트 추가.
  void _addStickyNote() {
    setState(() {
      final newId = 'note_${DateTime.now().millisecondsSinceEpoch}';
      final offset = (_stickyNotes.length * 24) % 120;
      _stickyNotes.add(_LocalStickyNote(
        id: newId,
        x: 20.0 + offset,
        y: 120.0 + offset,
      ));
    });
    _saveStickyNotes();
  }

  /// 이슈 #663-A — 스티키 노트 삭제.
  void _deleteStickyNote(int index) {
    if (index < 0 || index >= _stickyNotes.length) return;
    setState(() {
      _stickyNotes[index].dispose();
      _stickyNotes.removeAt(index);
    });
    _saveStickyNotes();
  }

  void _saveStrokes() {
    final json = jsonEncode(_strokes.map((s) => {
          'color': s.color.toARGB32(),
          'points': s.points.map((p) => [p.dx, p.dy]).toList(),
        }).toList());
    _box?.put('strokes_$_id', json);
    _syncStrokes();
  }

  /// 이슈 #663-B — 마지막 형광펜 stroke 한 단계 되돌리기.
  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redoStack.add(_strokes.removeLast());
    });
    _saveStrokes();
  }

  /// 이슈 #663-B — undo한 stroke 다시 적용.
  void _redoStroke() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _strokes.add(_redoStack.removeLast());
    });
    _saveStrokes();
  }

  /// 이슈 #663-B — 모든 형광펜 stroke 삭제 (redo 포함).
  void _clearStrokes() {
    setState(() {
      _strokes.clear();
      _redoStack.clear();
    });
    _saveStrokes();
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

  // ── 이슈 #665 후속 — 원형 도안 전용 헬퍼/뷰어 (사각 코드와 분리) ──

  /// 원형 도안에서 사용할 SVG 심볼 픽처 콜백.
  /// SvgSymbolCache provider 미연결 시에도 안전하게 null 반환.
  ui.Picture? _roundSymbolPicture(String id) => null;

  /// 이슈 #665 Phase 5 — 원형 도안 PDF 공유 (시스템 공유 시트).
  /// 도식·라운드 코수 표·심볼 범례를 포함한 출판용 PDF 생성.
  Future<void> _shareRoundChartPdf(bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? 'PDF 생성 중입니다.' : 'Generating PDF...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          final user = ref.read(authStateProvider).valueOrNull;
          final author =
              user?.displayName ?? user?.email ?? 'MoriKnit';
          await RoundChartPdfExporter().share(
            pattern: widget.chart,
            author: author,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// 라운드 이전/다음 이동 (1..rounds 사이로 클램프).
  void _shiftRound(int delta) {
    final round = widget.chart.roundData!;
    final next = (_roundTrackingRound + delta).clamp(1, round.rounds);
    setState(() {
      _roundTrackingRound = next;
      // 라운드가 바뀌면 세그먼트 진행은 초기화.
      _roundTrackingSegment = -1;
    });
  }

  /// 세그먼트 1칸 진행 (다음 코).
  void _advanceSegment() {
    final round = widget.chart.roundData!;
    final stitchCount = round.stitchCountForRound(_roundTrackingRound);
    if (stitchCount <= 0) return;
    setState(() {
      final next = _roundTrackingSegment + 1;
      if (next >= stitchCount) {
        // 다음 라운드로 자동 진행.
        if (_roundTrackingRound < round.rounds) {
          _roundTrackingRound += 1;
          _roundTrackingSegment = -1;
        } else {
          _roundTrackingSegment = stitchCount - 1;
        }
      } else {
        _roundTrackingSegment = next;
      }
    });
  }

  /// 세그먼트 1칸 되돌리기.
  void _retreatSegment() {
    if (_roundTrackingSegment <= -1) return;
    setState(() => _roundTrackingSegment -= 1);
  }

  /// 헤어라인 시계방향 회전 (코마다 1칸).
  void _rotateHairlineCw() {
    final round = widget.chart.roundData!;
    final stitchCount = round.stitchCountForRound(_roundTrackingRound);
    if (stitchCount <= 0) return;
    final step = (2 * pi) / stitchCount;
    setState(() {
      _roundHairlineAngle = _normalizeAngle(_roundHairlineAngle + step);
    });
  }

  /// 헤어라인 반시계방향 회전 (코마다 1칸).
  void _rotateHairlineCcw() {
    final round = widget.chart.roundData!;
    final stitchCount = round.stitchCountForRound(_roundTrackingRound);
    if (stitchCount <= 0) return;
    final step = (2 * pi) / stitchCount;
    setState(() {
      _roundHairlineAngle = _normalizeAngle(_roundHairlineAngle - step);
    });
  }

  /// -π ~ π 범위로 정규화.
  double _normalizeAngle(double a) {
    var v = a;
    while (v > pi) {
      v -= 2 * pi;
    }
    while (v < -pi) {
      v += 2 * pi;
    }
    return v;
  }

  /// 현재 헤어라인 각도를 시계 표기(12:00, 3:00 ...) 비슷하게 표시.
  String _formatHairlineClock() {
    // 12시 = -π/2 → 0시
    var deg = _roundHairlineAngle * 180 / pi + 90;
    while (deg < 0) {
      deg += 360;
    }
    while (deg >= 360) {
      deg -= 360;
    }
    final hour = (deg / 30).floor();
    final minute = (((deg % 30) / 30) * 60).round();
    final hh = hour == 0 ? 12 : hour;
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// 원형 도안 전용 뷰어 (사각 build 본체와 완전 분리).
  Widget _buildRoundViewer() {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final round = widget.chart.roundData!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.chart.title,
          style: T.h3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 트래킹 호 토글
          Tooltip(
            message: isKorean ? '원형 트래킹바' : 'Round Tracking',
            child: IconButton(
              icon: Icon(
                Icons.donut_large_rounded,
                color: _roundTrackingActive ? C.lv : C.tx,
              ),
              onPressed: () => setState(
                () => _roundTrackingActive = !_roundTrackingActive,
              ),
            ),
          ),
          // 회전 헤어라인 토글
          Tooltip(
            message: isKorean ? '회전 헤어라인' : 'Rotating Hairline',
            child: IconButton(
              icon: Icon(
                Icons.straighten_rounded,
                color: _roundHairlineActive ? C.pkD : C.tx,
              ),
              onPressed: () => setState(
                () => _roundHairlineActive = !_roundHairlineActive,
              ),
            ),
          ),
          // 이슈 #665 Phase 5 — PDF 내보내기 (원형 전용)
          Tooltip(
            message: isKorean ? 'PDF로 공유' : 'Share as PDF',
            child: IconButton(
              icon: Icon(Icons.picture_as_pdf_rounded, color: C.tx),
              onPressed: () => _shareRoundChartPdf(isKorean),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1) 도안 캔버스 (RoundChartView + 오버레이)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      // 1-1) 기본 원형 도안
                      Positioned.fill(
                        child: RoundChartView(
                          chart: round,
                          symbolPicture: _roundSymbolPicture,
                        ),
                      ),
                      // 1-2) 트래킹 호 오버레이
                      if (_roundTrackingActive)
                        Positioned.fill(
                          child: RoundTrackingArc(
                            chart: round,
                            currentRound: _roundTrackingRound,
                            currentSegment: _roundTrackingSegment,
                            canvasSize: size,
                            color: C.lv,
                          ),
                        ),
                      // 1-3) 회전 헤어라인 오버레이
                      if (_roundHairlineActive)
                        Positioned.fill(
                          child: RoundHairlineRay(
                            chart: round,
                            angleRadians: _roundHairlineAngle,
                            canvasSize: size,
                            color: C.pkD,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // 2) 컨트롤 패널 (트래킹 / 헤어라인 활성 시만)
            if (_roundTrackingActive || _roundHairlineActive)
              _buildRoundControls(isKorean, round),
          ],
        ),
      ),
    );
  }

  /// 원형 도안 전용 컨트롤 패널 (라운드 이동 + 회전 버튼).
  Widget _buildRoundControls(bool isKorean, RoundChart round) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(top: BorderSide(color: C.lv.withValues(alpha: 0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 트래킹: 라운드 이동 ──
          if (_roundTrackingActive)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: C.lv,
                  tooltip: isKorean ? '이전 라운드' : 'Previous Round',
                  onPressed:
                      _roundTrackingRound > 1 ? () => _shiftRound(-1) : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'R$_roundTrackingRound / ${round.rounds}'
                      '${_roundTrackingSegment >= 0 ? '  ·  ${_roundTrackingSegment + 1}/${round.stitchCountForRound(_roundTrackingRound)}코' : ''}',
                      style: T.body.copyWith(
                        color: C.lvD,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: C.lv,
                  tooltip: isKorean ? '다음 라운드' : 'Next Round',
                  onPressed: _roundTrackingRound < round.rounds
                      ? () => _shiftRound(1)
                      : null,
                ),
                // 세그먼트 진행/되돌리기
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: C.lvD,
                  tooltip: isKorean ? '코 되돌리기' : 'Previous Stitch',
                  onPressed:
                      _roundTrackingSegment > -1 ? _retreatSegment : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: C.lvD,
                  tooltip: isKorean ? '코 진행' : 'Next Stitch',
                  onPressed: _advanceSegment,
                ),
              ],
            ),

          // ── 헤어라인: 회전 ──
          if (_roundHairlineActive) ...[
            if (_roundTrackingActive) const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.rotate_left_rounded),
                  color: C.pkD,
                  tooltip: isKorean ? '반시계 회전' : 'Counter-clockwise',
                  onPressed: _rotateHairlineCcw,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${isKorean ? "각도" : "Angle"}: ${_formatHairlineClock()}',
                      style: T.body.copyWith(
                        color: C.pkD,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded),
                  color: C.pkD,
                  tooltip: isKorean ? '시계 회전' : 'Clockwise',
                  onPressed: _rotateHairlineCw,
                ),
              ],
            ),
            // 스냅 옵션
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  isKorean ? '코마다 정확히 정렬' : 'Snap to stitch',
                  style: T.caption,
                ),
                Checkbox(
                  value: _roundHairlineSnap,
                  activeColor: C.pkD,
                  onChanged: (v) =>
                      setState(() => _roundHairlineSnap = v ?? true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 이슈 #668 — 자유 Path 도안 뷰어 (읽기 전용 GuidePathEditorView 재사용) ──
    if (widget.chart.chartType == ChartShape.guidePath) {
      final isKorean = ref.watch(appLanguageProvider).isKorean;
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.chart.title.isEmpty
                ? (isKorean ? '자유 Path 도안' : 'Free Path Chart')
                : widget.chart.title,
            style: T.h3,
          ),
        ),
        body: GuidePathEditorView(
          chart: widget.chart,
          onChange: (_) {},
          isReadOnly: true,
        ),
      );
    }

    // ── 이슈 #665 후속 — 원형 도안이면 별도 뷰어로 분기 (사각 코드 보호) ──
    if (widget.chart.chartType != ChartShape.rect &&
        widget.chart.roundData != null) {
      return _buildRoundViewer();
    }

    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final counter = ref.watch(counterByChartIdProvider(_id)).valueOrNull;

    // #643 — 카운터 rowCount 변경 시 트래킹바 Y 자동 이동
    ref.listen<AsyncValue<CounterModel?>>(counterByChartIdProvider(_id), (prev, next) {
      final c = next.valueOrNull;
      if (c == null || !_rulerFollowCounter || !_rulerActive) return;
      final prevRow = prev?.valueOrNull?.rowCount;
      if (prevRow == null || prevRow == c.rowCount) return;
      setState(() {
        _rulerY = _rulerBaseY + (c.rowCount - 1) * _rulerHeight;
      });
      _saveRuler();
    });

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF1A1A2E) : null,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF1A1A2E) : Colors.transparent,
        foregroundColor: _isDark ? Colors.white : null,
        elevation: 0,
        titleSpacing: 0, // #643 — 오버플로우 방지 (9개 툴 공간 확보)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
        ),
        title: _isDark && _totalPages > 0
            ? Text('$_currentPage / $_totalPages',
                style: T.caption.copyWith(color: Colors.white70),
                overflow: TextOverflow.ellipsis)
            : Text(widget.chart.title,
                style: T.h3.copyWith(color: _isDark ? Colors.white : null),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
        actions: [
          // #643 — 종류별 재정렬: ① 가이드 → ② 카운트 → ③ 주석 → ④ 측정 → ⑤ 읽기 → ⑥ 시간 → ⑦ 이동
          // ① 가이드 — 세로 헤어라인 (가로 트래킹바 룰러 아이콘 90° 회전)
          Tooltip(
            message: isKorean ? '세로 헤어라인' : 'Vertical Hairline',
            child: IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              visualDensity: VisualDensity.compact,
              icon: Transform.rotate(
                angle: pi / 2,
                child: Icon(
                  Icons.horizontal_rule_rounded,
                  size: 22,
                  color: _hairlineActive
                      ? const Color(0xFFF59E0B)
                      : (_isDark ? Colors.white : C.tx),
                ),
              ),
              onPressed: () => setState(() => _hairlineActive = !_hairlineActive),
            ),
          ),
          // ① 가이드 — 가로 트래킹바
          _ToolIcon(
            icon: Icons.horizontal_rule_rounded,
            active: _rulerActive,
            activeColor: C.lv,
            dimColor: _isDark ? Colors.white : C.tx,
            onTap: () => setState(() => _rulerActive = !_rulerActive),
          ),
          // ② 카운트 — 카운터
          _ToolIcon(
            icon: Icons.exposure_plus_1_rounded,
            active: _counterActive,
            activeColor: C.pkD,
            dimColor: _isDark ? Colors.white : C.tx,
            onTap: () => setState(() => _counterActive = !_counterActive),
          ),
          // ③ 주석 — 하이라이터
          _ToolIcon(
            icon: Icons.edit_rounded,
            active: _highlighterActive,
            activeColor: C.og,
            dimColor: _isDark ? Colors.white : C.tx,
            onTap: () => setState(() => _highlighterActive = !_highlighterActive),
          ),
          // ③ 주석 — 스티키노트 (이슈 #663-A 후속: 토글 ON 시 자동 1개 추가)
          _ToolIcon(
            icon: Icons.sticky_note_2_rounded,
            active: _stickyActive,
            activeColor: C.lmD,
            dimColor: _isDark ? Colors.white : C.tx,
            onTap: () {
              setState(() => _stickyActive = !_stickyActive);
              if (_stickyActive && _stickyNotes.isEmpty) {
                _addStickyNote();
              }
            },
          ),
          // ④ 측정 — 측정도구
          _ToolIcon(
            icon: Icons.square_foot_rounded,
            active: _measureActive,
            activeColor: const Color(0xFF32D74B),
            dimColor: _isDark ? Colors.white : C.tx,
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
          // ⑤ 읽기 — 서술형 도안 뷰어
          // #625 이후 narrativeBlocks/aiSections 도입 — 세 필드 중 하나라도 있으면 활성화
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.subject_rounded,
              size: 22,
              color: _hasNarrativeContent
                  ? (_isDark ? Colors.white : C.tx2)
                  : (_isDark ? Colors.white24 : C.tx2.withValues(alpha: 0.3)),
            ),
            tooltip: isKorean ? '텍스트 뷰어' : 'Text Viewer',
            onPressed: () {
              // 1. aiSections 있으면 PatternTextTrackerScreen (단계로그 체크리스트)
              final hasSections = widget.chart.aiSections?.isNotEmpty ?? false;
              if (hasSections) {
                context.push(
                  '${Routes.toolsMyParsedPatterns}/${widget.chart.id}/text',
                );
                return;
              }
              // 2. 서술형(text/blocks)만 있으면 _NarrativeViewerScreen
              if (_hasAnyTextContent) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _NarrativeViewerScreen(
                      title: widget.chart.title,
                      narrativeText: widget.chart.narrativeText,
                      isKorean: isKorean,
                      blocks: widget.chart.narrativeBlocks,
                      sections: widget.chart.aiSections ?? const [],
                      repeatRegions: widget.chart.repeatRegions,
                    ),
                  ),
                );
                return;
              }
              // 3. 둘 다 없음 — 안내 snackbar (변환기 진입 유도)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isKorean
                        ? '단계로그가 없어요. AI 변환기로 단계로그를 만들어보세요.'
                        : 'No step log. Try AI converter to generate one.',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          // ⑥ 시간 — 타이머
          _ToolIcon(
            icon: Icons.timer_rounded,
            active: _timerDockVisible,
            activeColor: C.lv,
            dimColor: _isDark ? Colors.white : C.tx,
            onTap: () => setState(() => _timerDockVisible = !_timerDockVisible),
          ),
          // ⑦ 이동 — 연결 메뉴 (프로젝트 / 스와치)
          PopupMenuButton<String>(
            tooltip: isKorean ? '연결' : 'Link',
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            icon: Icon(Icons.link_rounded,
                size: 22,
                color: _isDark ? Colors.white : C.tx),
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
                  // Highlighter drawing overlay (이슈 #663-B — 지우개 모드 제거, undo/redo 사용)
                  if (_highlighterActive)
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (d) =>
                            setState(() => _currentStroke = [d.localPosition]),
                        onPanUpdate: (d) {
                          setState(() =>
                              _currentStroke = [..._currentStroke, d.localPosition]);
                        },
                        onPanEnd: (d) {
                          if (_currentStroke.isNotEmpty) {
                            setState(() {
                              _strokes.add(_Stroke(
                                  points: List.from(_currentStroke),
                                  color: _highlightColor));
                              _currentStroke = [];
                              _redoStack.clear(); // 새 stroke 추가 시 redo 스택 무효화
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
                  // Ruler (가로 트래킹바) — #643: 높이 사용자 조정 + 카운터 연동
                  if (_rulerActive) ...[
                    // 상단 안내 + 중앙 본체
                    Positioned(
                      top: _rulerY.clamp(0.0, (maxH - _rulerHeight).clamp(0.0, double.infinity)),
                      left: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 2),
                            child: Row(
                              children: [
                                Text(
                                  isKorean ? '↕ 이동 / ⇅ 높이' : '↕ move / ⇅ height',
                                  style: TextStyle(
                                    color: C.lv.withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_rulerHeight.toInt()}px',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (_rulerFollowCounter) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: C.pkD.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '↔ 카운터',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onVerticalDragUpdate: (d) {
                              setState(() {
                                _rulerY = (_rulerY + d.delta.dy).clamp(0, maxH - _rulerHeight);
                                _rulerBaseY = _rulerY; // 사용자 수동 이동 시 새 기준점
                              });
                              _saveRuler();
                            },
                            child: Container(
                              height: _rulerHeight,
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
                                const Spacer(),
                                // 카운터 연동 토글
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _rulerFollowCounter = !_rulerFollowCounter);
                                    _saveRuler();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _rulerFollowCounter ? C.pkD : Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _rulerFollowCounter ? '🔗' : '⛓️‍💥',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 상단 가장자리 드래그 핸들 (높이 조정)
                    Positioned(
                      top: (_rulerY + 14 - 10).clamp(0.0, (maxH - 20).clamp(0.0, double.infinity)),
                      left: 0,
                      right: 0,
                      height: 20,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (d) {
                          setState(() {
                            final newHeight = (_rulerHeight - d.delta.dy).clamp(14.0, maxH * 0.5);
                            final diff = _rulerHeight - newHeight;
                            _rulerHeight = newHeight;
                            _rulerY = (_rulerY + diff).clamp(0.0, maxH - _rulerHeight);
                            _rulerBaseY = _rulerY;
                          });
                          _saveRuler();
                        },
                        child: const MouseRegion(cursor: SystemMouseCursors.resizeUpDown),
                      ),
                    ),
                    // 하단 가장자리 드래그 핸들 (높이 조정)
                    Positioned(
                      top: (_rulerY + 14 + _rulerHeight - 10).clamp(0.0, (maxH - 20).clamp(0.0, double.infinity)),
                      left: 0,
                      right: 0,
                      height: 20,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (d) {
                          setState(() {
                            _rulerHeight = (_rulerHeight + d.delta.dy).clamp(14.0, maxH * 0.5);
                          });
                          _saveRuler();
                        },
                        child: const MouseRegion(cursor: SystemMouseCursors.resizeUpDown),
                      ),
                    ),
                  ],
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
                  // Vertical hairline — #643: 너비 드래그 조정 가능 반투명 밴드
                  if (_hairlineActive) ...[
                    // 반투명 밴드 본체
                    Positioned(
                      left: (_hairlineX * maxW - _hairlineWidth / 2).clamp(0.0, maxW - _hairlineWidth),
                      top: 0,
                      bottom: 0,
                      width: _hairlineWidth,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                            border: const Border(
                              left: BorderSide(color: Color(0xFFF59E0B), width: 2),
                              right: BorderSide(color: Color(0xFFF59E0B), width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 좌측 가장자리 — 너비 조정
                    Positioned(
                      left: (_hairlineX * maxW - _hairlineWidth / 2 - 14).clamp(-14.0, maxW - _hairlineWidth),
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            _hairlineWidth = (_hairlineWidth - d.delta.dx * 2).clamp(8.0, maxW * 0.6);
                          });
                          _saveHairline();
                        },
                        child: const MouseRegion(cursor: SystemMouseCursors.resizeLeftRight),
                      ),
                    ),
                    // 우측 가장자리 — 너비 조정
                    Positioned(
                      left: (_hairlineX * maxW + _hairlineWidth / 2 - 14).clamp(0.0, maxW - 14),
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            _hairlineWidth = (_hairlineWidth + d.delta.dx * 2).clamp(8.0, maxW * 0.6);
                          });
                          _saveHairline();
                        },
                        child: const MouseRegion(cursor: SystemMouseCursors.resizeLeftRight),
                      ),
                    ),
                    // 중앙 핸들 — X 위치 이동 + "↔ 이동 | ←→ 너비" 안내
                    Positioned(
                      left: (_hairlineX * maxW - 18).clamp(0.0, maxW - 36),
                      top: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onHorizontalDragUpdate: (d) {
                              setState(() {
                                _hairlineX = (_hairlineX + d.delta.dx / maxW).clamp(0.0, 1.0);
                              });
                              _saveHairline();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_hairlineWidth.toInt()}px',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // 이슈 #663-A — 다중 스티키 노트 + 추가 버튼
                  if (_stickyActive) ...[
                    for (int i = 0; i < _stickyNotes.length; i++)
                      Positioned(
                        left: _stickyNotes[i].x.clamp(0, (maxW - 160).clamp(0, double.infinity)),
                        top: _stickyNotes[i].y.clamp(0, (maxH - 140).clamp(0, double.infinity)),
                        child: GestureDetector(
                          onPanUpdate: _stickyNotes[i].editing
                              ? null
                              : (d) {
                                  setState(() {
                                    _stickyNotes[i].x = (_stickyNotes[i].x + d.delta.dx)
                                        .clamp(0, (maxW - 160).clamp(0, double.infinity)).toDouble();
                                    _stickyNotes[i].y = (_stickyNotes[i].y + d.delta.dy)
                                        .clamp(0, (maxH - 140).clamp(0, double.infinity)).toDouble();
                                  });
                                  _saveStickyNotes();
                                },
                          child: _StickyNoteWidget(
                            controller: _stickyNotes[i].controller,
                            isEditing: _stickyNotes[i].editing,
                            onEditToggle: () =>
                                setState(() => _stickyNotes[i].editing = !_stickyNotes[i].editing),
                            onAdd: _addStickyNote,
                            onDelete: () => _deleteStickyNote(i),
                            onTextChanged: (v) => _saveStickyNotes(),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // Highlighter toolbar (이슈 #663-B — undo/redo/clear)
            if (_highlighterActive)
              _HighlighterBar(
                colors: _highlightColors,
                selected: _highlightColor,
                isDark: _isDark,
                canUndo: _strokes.isNotEmpty,
                canRedo: _redoStack.isNotEmpty,
                onColor: (c) => setState(() => _highlightColor = c),
                onUndo: _undoStroke,
                onRedo: _redoStroke,
                onClear: _clearStrokes,
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
            // Timer dock
            if (_timerDockVisible)
              _TimerDock(
                sessionSeconds: _sessionSeconds,
                totalSeconds: _totalSeconds,
                isRunning: _timerRunning,
                reminderIntervalMin: _reminderIntervalMin,
                isDark: _isDark,
                timerName: _timerName,
                onRename: _editTimerName,
                onStart: _startTimer,
                onPause: _pauseTimer,
                onSave: _syncTimerToFirestore,
                onIntervalChanged: (min) => setState(() {
                  _reminderIntervalMin = min;
                  _reminderCountdown = 0;
                }),
                formatSession: _formatSession,
                formatTotal: _formatTotal,
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

/// 이슈 #663-A — 스티키 노트 다중 추가용 로컬 상태 (각 노트의 컨트롤러 + 위치 + 편집 상태).
class _LocalStickyNote {
  final String id;
  final TextEditingController controller;
  double x;
  double y;
  bool editing = false;
  _LocalStickyNote({
    required this.id,
    String text = '',
    this.x = 20,
    this.y = 120,
  }) : controller = TextEditingController(text: text);
  void dispose() => controller.dispose();
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
        // #643 — 9개 툴 항상 표시 위한 간격 축소 (오버플로우 방지)
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: active ? activeColor : dimColor, size: 22),
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

/// 이슈 #663-B — 기존 X(지우개)/휴지통 2버튼 → undo/redo/clear 3버튼으로 업데이트.
/// canUndo/canRedo로 비활성화 상태 시각 표시.
class _HighlighterBar extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final bool isDark;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<Color> onColor;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  const _HighlighterBar({
    required this.colors,
    required this.selected,
    required this.isDark,
    required this.canUndo,
    required this.canRedo,
    required this.onColor,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A2E) : C.bg;
    final iconBase = isDark ? Colors.white70 : C.tx2;
    final iconDim = isDark ? Colors.white24 : C.tx2.withValues(alpha: 0.30);
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
                  border: selected == c
                      ? Border.all(
                          color: isDark ? Colors.white : C.tx, width: 2)
                      : null,
                ),
              ),
            ),
          const Spacer(),
          // Undo
          IconButton(
            tooltip: '실행 취소',
            onPressed: canUndo ? onUndo : null,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.undo_rounded, size: 22, color: canUndo ? iconBase : iconDim),
          ),
          // Redo
          IconButton(
            tooltip: '다시 실행',
            onPressed: canRedo ? onRedo : null,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.redo_rounded, size: 22, color: canRedo ? iconBase : iconDim),
          ),
          // Clear (전체 삭제)
          IconButton(
            tooltip: '전체 삭제',
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_sweep_rounded, size: 22, color: C.og),
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
  final VoidCallback onAdd; // 이슈 #663-A 후속 — 노트 헤더에서 새 노트 추가
  final VoidCallback onDelete; // 이슈 #663-A — 다중 노트 삭제
  final ValueChanged<String> onTextChanged;
  const _StickyNoteWidget({
    required this.controller,
    required this.isEditing,
    required this.onEditToggle,
    required this.onAdd,
    required this.onDelete,
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
                // 이슈 #663-A 후속 — 좌측 + 버튼: 새 노트 추가 (FAB 대체)
                GestureDetector(
                  onTap: onAdd,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.add_rounded, size: 16, color: Color(0xFF616161)),
                  ),
                ),
                const Icon(Icons.drag_indicator_rounded,
                    size: 14, color: Color(0xFF9E9E9E)),
                const Spacer(),
                GestureDetector(
                  onTap: onEditToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isEditing
                          ? Icons.check_rounded
                          : Icons.edit_rounded,
                      size: 14,
                      color: const Color(0xFF616161),
                    ),
                  ),
                ),
                // 이슈 #663-A — 노트 삭제 X 버튼
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.close_rounded, size: 14, color: Color(0xFFC62828)),
                  ),
                ),
                const SizedBox(width: 4),
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

// ── Timer dock ────────────────────────────────────────────────────────────────

class _TimerDock extends StatelessWidget {
  final int sessionSeconds;
  final int totalSeconds;
  final bool isRunning;
  final int reminderIntervalMin;
  final bool isDark;
  // 이슈 #649 Phase 1 — 타이머 이름 + 편집 콜백
  final String timerName;
  final VoidCallback onRename;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onSave;
  final ValueChanged<int> onIntervalChanged;
  final String Function(int) formatSession;
  final String Function(int) formatTotal;

  const _TimerDock({
    required this.sessionSeconds,
    required this.totalSeconds,
    required this.isRunning,
    required this.reminderIntervalMin,
    required this.isDark,
    required this.timerName,
    required this.onRename,
    required this.onStart,
    required this.onPause,
    required this.onSave,
    required this.onIntervalChanged,
    required this.formatSession,
    required this.formatTotal,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F0F1E) : C.bg;
    final textColor = isDark ? Colors.white : C.tx;
    final muted = isDark ? Colors.white38 : C.mu;
    final accumulated = totalSeconds + sessionSeconds;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이슈 #649 Phase 1 — 타이머 이름 (탭하여 편집)
          GestureDetector(
            onTap: onRename,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 13, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      timerName.isEmpty ? '타이머 이름' : timerName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.timer_rounded, color: C.lv, size: 16),
              const SizedBox(width: 6),
              // 세션 타이머
              Text(
                formatSession(sessionSeconds),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              // 누적 시간
              Text(
                '누적 ${formatTotal(accumulated)}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const Spacer(),
              // 시작/일시정지 버튼
              GestureDetector(
                onTap: isRunning ? onPause : onStart,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.lv.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                    isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: C.lv,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 알림 간격 설정 버튼
              GestureDetector(
                onTap: () => _showIntervalPicker(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : C.gx,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : C.bd),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 14, color: muted),
                      const SizedBox(width: 4),
                      Text(
                        '$reminderIntervalMin분',
                        style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIntervalPicker(BuildContext context) {
    const intervals = [10, 20, 30, 40, 50, 60];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '건강 알림 간격',
              style: T.h3.copyWith(color: isDark ? Colors.white : C.tx),
            ),
            const SizedBox(height: 4),
            Text(
              'N분마다 스트레칭·물마시기 등 알림을 보내요',
              style: T.caption.copyWith(color: C.mu),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intervals.map((min) {
                final selected = min == reminderIntervalMin;
                return GestureDetector(
                  onTap: () {
                    onIntervalChanged(min);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? C.lv : C.lv.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      '$min분',
                      style: TextStyle(
                        color: selected ? Colors.white : C.lvD,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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

// ── 서술형 도안 뷰어 ──────────────────────────────────────────────────────────

class _NarrativeViewerScreen extends StatelessWidget {
  final String title;
  final String narrativeText;
  final bool isKorean;
  // 이슈 #625 커밋 4 — 섹션·반복구간 렌더링용 (optional, 비어있으면 기존 통짜 뷰)
  final List<NarrativeBlock> blocks;
  final List<AiSection> sections;
  final List<RepeatRegion> repeatRegions;

  const _NarrativeViewerScreen({
    required this.title,
    required this.narrativeText,
    required this.isKorean,
    this.blocks = const [],
    this.sections = const [],
    this.repeatRegions = const [],
  });

  bool get _hasSectionsOrRepeats =>
      blocks.isNotEmpty && (sections.isNotEmpty || repeatRegions.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(isKorean ? '서술형 도안' : 'Narrative Pattern',
                style: T.caption.copyWith(color: C.mu)),
          ],
        ),
      ),
      body: narrativeText.trim().isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.subject_rounded, size: 48, color: C.mu),
                  const SizedBox(height: 12),
                  Text(
                    isKorean
                        ? '서술형 도안이 없어요.\n도안에디터에서 생성해 주세요.'
                        : 'No narrative pattern.\nGenerate it in the pattern editor.',
                    textAlign: TextAlign.center,
                    style: T.body.copyWith(color: C.mu),
                  ),
                ],
              ),
            )
          : _hasSectionsOrRepeats
              ? _NarrativeSectionedView(
                  blocks: blocks,
                  sections: sections,
                  repeatRegions: repeatRegions,
                  isKorean: isKorean,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: SelectableText(
                    narrativeText,
                    style: T.body.copyWith(height: 1.8),
                  ),
                ),
    );
  }
}

/// 이슈 #625 커밋 4 — 섹션/반복구간 구조가 있을 때의 서술형 뷰어.
/// 기존 통짜 뷰와 분리된 신규 위젯 — 기존 동작 영향 없음.
class _NarrativeSectionedView extends StatefulWidget {
  final List<NarrativeBlock> blocks;
  final List<AiSection> sections;
  final List<RepeatRegion> repeatRegions;
  final bool isKorean;

  const _NarrativeSectionedView({
    required this.blocks,
    required this.sections,
    required this.repeatRegions,
    required this.isKorean,
  });

  @override
  State<_NarrativeSectionedView> createState() =>
      _NarrativeSectionedViewState();
}

class _NarrativeSectionedViewState extends State<_NarrativeSectionedView> {
  final Set<String> _collapsed = {}; // 접힌 섹션 ID

  RepeatRegion? _regionOf(NarrativeBlock b) {
    if (b.repeatRegionId == null) return null;
    for (final r in widget.repeatRegions) {
      if (r.id == b.repeatRegionId) return r;
    }
    return null;
  }

  String _sectionTitle(AiSection? s) {
    if (s == null) return widget.isKorean ? '미분류' : 'Unassigned';
    return widget.isKorean ? (s.titleKo ?? s.title) : s.title;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.blocks]..sort((a, b) => a.order.compareTo(b.order));

    // 섹션 순서대로 그룹화 (섹션별 블록 + 미분류 마지막)
    final groups = <String?, List<NarrativeBlock>>{};
    for (final b in sorted) {
      groups.putIfAbsent(b.sectionId, () => []).add(b);
    }

    final orderedSecs = <AiSection?>[
      ...widget.sections,
      if (groups.containsKey(null)) null,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final sec in orderedSecs)
            if (groups[sec?.id] != null && groups[sec?.id]!.isNotEmpty)
              _buildSection(sec, groups[sec?.id]!),
        ],
      ),
    );
  }

  Widget _buildSection(AiSection? sec, List<NarrativeBlock> blocks) {
    final isCollapsed = sec != null && _collapsed.contains(sec.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: sec == null
                ? null
                : () => setState(() {
                      if (isCollapsed) {
                        _collapsed.remove(sec.id);
                      } else {
                        _collapsed.add(sec.id);
                      }
                    }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: sec == null ? C.bd2 : C.lv,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sectionTitle(sec),
                      style: T.bodyBold.copyWith(
                        color: sec == null ? C.mu : C.tx,
                      ),
                    ),
                  ),
                  Text(
                    '${blocks.length}',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  if (sec != null)
                    Icon(
                      isCollapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      color: C.mu,
                    ),
                ],
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in blocks) _buildBlockLine(b),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockLine(NarrativeBlock b) {
    final region = _regionOf(b);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              b.text,
              style: T.body.copyWith(height: 1.6),
            ),
          ),
          if (region != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.pkL,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, size: 10, color: C.pkD),
                  const SizedBox(width: 2),
                  Text(
                    '×${region.repeatCount}',
                    style: T.caption.copyWith(
                      color: C.pkD,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
