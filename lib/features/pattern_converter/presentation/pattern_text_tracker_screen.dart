import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/pattern/domain/ai_pattern_section.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/parsed_pattern_provider.dart';

class PatternTextTrackerScreen extends ConsumerWidget {
  final String patternId;
  const PatternTextTrackerScreen({super.key, required this.patternId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    debugPrint('[TextTracker] build patternId="$patternId"');
    // #655 무한로딩 fix — stream 대신 단발 get future 사용
    final patternAsync = ref.watch(aiPatternDetailFutureProvider(patternId));

    return patternAsync.when(
      loading: () {
        debugPrint('[TextTracker] LOADING (waiting for stream emit)');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (e, _) {
        debugPrint('[TextTracker] ERROR: $e');
        return _PatternLoadErrorScreen(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(aiPatternDetailFutureProvider(patternId)),
        );
      },
      data: (pattern) {
        debugPrint('[TextTracker] DATA pattern=${pattern?.id} sections=${pattern?.aiSections?.length}');
        if (pattern == null) {
          return Scaffold(
            appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), color: C.tx, onPressed: () => context.pop())),
            body: Center(child: Text(isKorean ? '도안을 찾을 수 없어요.' : 'Pattern not found.')),
          );
        }
        return _TextTrackerView(
          patternId: patternId,
          title: pattern.title,
          sections: pattern.aiSections ?? [],
          isKorean: isKorean,
          chart: pattern,
        );
      },
    );
  }
}

// ── 플랫 스텝 (섹션 인덱스 + 스텝 참조) ─────────────────────────────────────────
class _FlatStep {
  final int sectionIdx;
  final int stepIdx;
  final AiSection section;
  final AiStep step;

  const _FlatStep({
    required this.sectionIdx,
    required this.stepIdx,
    required this.section,
    required this.step,
  });
}

// ── 뷰 ───────────────────────────────────────────────────────────────────────
class _TextTrackerView extends StatefulWidget {
  final String patternId;
  final String title;
  final List<AiSection> sections;
  final bool isKorean;
  final PatternChart chart;

  const _TextTrackerView({
    required this.patternId,
    required this.title,
    required this.sections,
    required this.isKorean,
    required this.chart,
  });

  @override
  State<_TextTrackerView> createState() => _TextTrackerViewState();
}

class _TextTrackerViewState extends State<_TextTrackerView> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _stepKeys = {};

  int _currentIdx = 0;
  double _fontSize = 16.0;

  static const _fontSizes = [13.0, 16.0, 19.0];

  late List<_FlatStep> _flat;

  // ── #655 분할 모드 ───────────────────────────────────────────
  bool _splitMode = false;
  double _splitRatio = 0.42; // 도안 원본 비율 (세로분할: 상단 / 가로분할: 좌측)
  bool _splitHorizontal = false; // false=세로분할(상하), true=가로분할(좌우)

  @override
  void initState() {
    super.initState();
    _buildFlat();
    for (var i = 0; i < _flat.length; i++) {
      _stepKeys[i] = GlobalKey();
    }
  }

  void _buildFlat() {
    _flat = [];
    for (var si = 0; si < widget.sections.length; si++) {
      final sec = widget.sections[si];
      for (var ti = 0; ti < sec.steps.length; ti++) {
        _flat.add(_FlatStep(sectionIdx: si, stepIdx: ti, section: sec, step: sec.steps[ti]));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(int idx) {
    if (idx < 0 || idx >= _flat.length) return;
    setState(() => _currentIdx = idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _stepKeys[idx];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  void _cycleFontSize() {
    final next = (_fontSizes.indexOf(_fontSize) + 1) % _fontSizes.length;
    setState(() => _fontSize = _fontSizes[next]);
  }

  String _stepText(AiStep step) {
    if (widget.isKorean && (step.instructionKo?.isNotEmpty ?? false)) {
      return step.instructionKo!;
    }
    return step.instruction;
  }

  String _sectionTitle(AiSection sec) {
    if (widget.isKorean && (sec.titleKo?.isNotEmpty ?? false)) return sec.titleKo!;
    return sec.title;
  }

  @override
  Widget build(BuildContext context) {
    final total = _flat.length;
    final progress = total == 0 ? 0.0 : (_currentIdx + 1) / total;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 분할 토글 (#655) — 도안 원본이 있을 때만 표시
          if (_canSplit())
            IconButton(
              tooltip: widget.isKorean
                  ? (_splitMode ? '단일 모드' : '도안 원본과 함께 보기')
                  : (_splitMode ? 'Single mode' : 'Split with source'),
              icon: Icon(
                _splitMode ? Icons.view_agenda_rounded : Icons.splitscreen_rounded,
                color: _splitMode ? C.lv : Colors.white70,
                size: 22,
              ),
              onPressed: () => setState(() => _splitMode = !_splitMode),
            ),
          // 가로/세로 분할 방향 토글 (#655 후속) — 분할 모드일 때만 표시
          if (_canSplit() && _splitMode)
            IconButton(
              tooltip: widget.isKorean
                  ? (_splitHorizontal ? '상하 분할' : '좌우 분할')
                  : (_splitHorizontal ? 'Top/Bottom' : 'Left/Right'),
              icon: Icon(
                _splitHorizontal
                    ? Icons.swap_horiz_rounded
                    : Icons.swap_vert_rounded,
                color: C.lv,
                size: 22,
              ),
              onPressed: () => setState(() => _splitHorizontal = !_splitHorizontal),
            ),
          // 폰트 크기 조절
          TextButton(
            onPressed: _cycleFontSize,
            child: Text(
              'Aa',
              style: TextStyle(
                color: C.lv,
                fontSize: _fontSize == _fontSizes[0] ? 13 : _fontSize == _fontSizes[1] ? 15 : 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 상단 트래킹 바 ────────────────────────────────────────────────
          _TopBar(progress: progress, current: _currentIdx + 1, total: total),
          // ── 본문 영역 (분할/단일) ─────────────────────────────────────────
          Expanded(child: _buildBody()),
          // ── 하단 네비게이션 바 ─────────────────────────────────────────
          _BottomNav(
            current: _currentIdx,
            total: total,
            onPrev: _currentIdx > 0 ? () => _goTo(_currentIdx - 1) : null,
            onNext: _currentIdx < total - 1 ? () => _goTo(_currentIdx + 1) : null,
          ),
        ],
      ),
    );
  }

  /// #655 — 도안 원본 분할 가능 여부 (image/pdf URL 보유 시)
  bool _canSplit() {
    final t = widget.chart.type;
    if (t == PatternType.image) return widget.chart.imageUrl.isNotEmpty;
    if (t == PatternType.pdf) return widget.chart.pdfUrl.isNotEmpty;
    return false; // chart 모드는 미지원 (Phase 1)
  }

  /// #655 — 본문 영역 빌더 (단일 / 세로분할 / 가로분할)
  Widget _buildBody() {
    final textPane = _buildTextList();
    if (!_splitMode || !_canSplit()) return textPane;

    final source = _SourcePane(chart: widget.chart, isKorean: widget.isKorean);

    if (_splitHorizontal) {
      // 좌우 분할 — 좌측: 도안 원본, 우측: 텍스트
      return LayoutBuilder(builder: (ctx, c) {
        final totalW = c.maxWidth;
        final leftW = (totalW * _splitRatio).clamp(140.0, totalW - 140.0);
        return Row(
          children: [
            SizedBox(width: leftW, child: source),
            _SplitHandle(
              vertical: true,
              onDrag: (delta, _) {
                setState(() {
                  final newRatio = (_splitRatio + delta / totalW).clamp(0.18, 0.78);
                  _splitRatio = newRatio;
                });
              },
            ),
            Expanded(child: textPane),
          ],
        );
      });
    }

    // 상하 분할 — 상단: 도안 원본, 하단: 텍스트
    return LayoutBuilder(builder: (ctx, c) {
      final totalH = c.maxHeight;
      final topH = (totalH * _splitRatio).clamp(120.0, totalH - 140.0);
      return Column(
        children: [
          SizedBox(height: topH, child: source),
          _SplitHandle(
            vertical: false,
            onDrag: (delta, _) {
              setState(() {
                final newRatio = (_splitRatio + delta / totalH).clamp(0.18, 0.78);
                _splitRatio = newRatio;
              });
            },
          ),
          Expanded(child: textPane),
        ],
      );
    });
  }

  /// 텍스트 리스트 영역
  Widget _buildTextList() {
    if (_flat.isEmpty) {
      return Center(
        child: Text(
          widget.isKorean ? '단계가 없어요.' : 'No steps found.',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    final items = _buildItems();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  List<Widget> _buildItems() {
    final items = <Widget>[];
    int? lastSectionIdx;

    for (var i = 0; i < _flat.length; i++) {
      final flat = _flat[i];
      final isActive = i == _currentIdx;

      // 섹션 헤더 (섹션이 바뀔 때만)
      if (flat.sectionIdx != lastSectionIdx) {
        lastSectionIdx = flat.sectionIdx;
        items.add(_SectionHeader(
          title: _sectionTitle(flat.section),
          stepCount: flat.section.steps.length,
          isActive: flat.sectionIdx == _flat[_currentIdx].sectionIdx,
        ));
      }

      // 스텝 텍스트
      items.add(_StepTile(
        key: _stepKeys[i],
        index: i,
        text: _stepText(flat.step),
        isActive: isActive,
        fontSize: _fontSize,
        onTap: () => _goTo(i),
      ));
    }
    return items;
  }
}

// ── 상단 트래킹 바 ────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final double progress;
  final int current;
  final int total;

  const _TopBar({required this.progress, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(C.lv),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$current / $total',
                style: TextStyle(color: C.lv, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 섹션 헤더 ─────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int stepCount;
  final bool isActive;

  const _SectionHeader({required this.title, required this.stepCount, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? C.lv.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: C.lv.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_rounded, size: 14, color: isActive ? C.lv : Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? C.lv : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Text(
            '$stepCount rows',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── 스텝 타일 ─────────────────────────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final int index;
  final String text;
  final bool isActive;
  final double fontSize;
  final VoidCallback onTap;

  const _StepTile({
    super.key,
    required this.index,
    required this.text,
    required this.isActive,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isActive
              ? C.lv.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border(left: BorderSide(color: C.lv, width: 3))
              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 라인 번호
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive ? C.lv : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // 텍스트
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: fontSize,
                  height: 1.65,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 하단 네비게이션 바 ────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _BottomNav({
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          // 이전
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            label: '이전',
            onTap: onPrev,
          ),
          // 스텝 카운터
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${current + 1} / $total',
                  style: TextStyle(
                    color: C.lv,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          // 다음
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            label: '다음',
            onTap: onNext,
            isNext: true,
          ),
        ],
      ),
    );
  }
}

// ── #655 분할 핸들 (가로/세로 모두 지원) ────────────────────────────────────
class _SplitHandle extends StatelessWidget {
  final void Function(double delta, double totalSize) onDrag;
  /// true = 좌우 분할 핸들 (수직 막대), false = 상하 분할 핸들 (수평 막대)
  final bool vertical;
  const _SplitHandle({required this.onDrag, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => vertical
          ? onDrag(d.delta.dx, size.width)
          : onDrag(d.delta.dy, size.height),
      child: MouseRegion(
        cursor: vertical
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.resizeUpDown,
        child: Container(
          width: vertical ? 14 : null,
          height: vertical ? null : 14,
          color: const Color(0xFF1A1A2E),
          alignment: Alignment.center,
          child: Container(
            width: vertical ? 4 : 56,
            height: vertical ? 56 : 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── #655 도안 원본 패널 (Image / PDF) ────────────────────────────────────────
class _SourcePane extends StatefulWidget {
  final PatternChart chart;
  final bool isKorean;
  const _SourcePane({required this.chart, required this.isKorean});

  @override
  State<_SourcePane> createState() => _SourcePaneState();
}

class _SourcePaneState extends State<_SourcePane> {
  String? _localPdfPath;
  bool _pdfLoading = false;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    if (widget.chart.type == PatternType.pdf && !kIsWeb) _loadPdf();
  }

  Future<void> _loadPdf() async {
    final raw = widget.chart.pdfUrl;
    if (raw.isEmpty) return;
    setState(() => _pdfLoading = true);
    try {
      String url = raw;
      if (!raw.startsWith('http')) {
        url = await FirebaseStorage.instance.ref(raw).getDownloadURL();
      }
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final bytes = await res.expand((b) => b).toList();
      client.close();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tracker_split_${widget.chart.id}.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() { _localPdfPath = file.path; _pdfLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _pdfError = '$e'; _pdfLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chart;
    Widget content;
    switch (c.type) {
      case PatternType.image:
        content = c.imageUrl.isEmpty
            ? const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48))
            : InteractiveViewer(
                child: Center(
                  child: Image.network(
                    c.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                  ),
                ),
              );
        break;
      case PatternType.pdf:
        if (kIsWeb) {
          content = Center(
            child: Text(
              widget.isKorean ? '웹에서 PDF 미리보기 미지원' : 'PDF preview not supported on web',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          );
        } else if (_pdfLoading) {
          content = Center(child: CircularProgressIndicator(color: C.lv));
        } else if (_pdfError != null) {
          content = Center(
            child: Text(_pdfError!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          );
        } else if (_localPdfPath == null) {
          content = const SizedBox.shrink();
        } else {
          content = PDFView(
            filePath: _localPdfPath!,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
          );
        }
        break;
      case PatternType.chart:
        content = Center(
          child: Text(
            widget.isKorean ? '차트 도안은 분할 미리보기 미지원' : 'Chart pattern not supported',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        );
        break;
    }
    return Container(
      color: Colors.black,
      child: content,
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isNext;

  const _NavBtn({required this.icon, required this.label, required this.onTap, this.isNext = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: enabled ? C.lv.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: enabled ? Border.all(color: C.lv.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: isNext
                ? [Text(label, style: TextStyle(color: enabled ? C.lv : Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(width: 2), Icon(icon, color: enabled ? C.lv : Colors.white38, size: 20)]
                : [Icon(icon, color: enabled ? C.lv : Colors.white38, size: 20), const SizedBox(width: 2), Text(label, style: TextStyle(color: enabled ? C.lv : Colors.white38, fontSize: 13, fontWeight: FontWeight.w600))],
          ),
        ),
      ),
    );
  }
}

// ── #684 로드 실패 플레이스홀더 (친화 메시지 + 재시도) ───────────────────────
class _PatternLoadErrorScreen extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onRetry;
  const _PatternLoadErrorScreen({required this.isKorean, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                isKorean ? '도안 데이터를 불러오지 못했어요' : 'Failed to load pattern data.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isKorean ? '다시 시도' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
