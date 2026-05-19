// lib/features/pattern/presentation/universal_pattern_viewer_screen.dart
//
// 이슈 #795 후속 — 유니버설 도안 뷰어.
//
// 어떤 타입의 도안이 들어와도 적절한 뷰어로 자동 분기하는 디스패처 화면.
// 최근 작업 / 검색 결과 / 알림 등 다양한 진입점에서 도안 ID 만으로 안전하게 진입.
//
// 근본 개선 — PatternSourceType 기반 분기 (데이터 형태 기반 X)
//
// 분기 규칙 (우선순위 순):
//   1. PDF URL 보유 (sourceType 무관)
//      → PdfViewerScreen
//   2. sourceType == aiConverted
//      → NarrativePatternViewerScreen (서술형 + 단계로그 진입)
//   3. sourceType == editor
//      → PatternEditorScreen(readOnly: true) — 사용자가 직접 그린 차트 도안만
//   4. sourceType == image
//      → ImagePatternViewerScreen (이미지 풀스크린 줌)
//   5. sourceType == external
//      - imageUrl 있음 → ImagePatternViewerScreen
//      - 그 외 → fallback 인라인 뷰어
//   6. 알 수 없는 / fallback
//      → 본 화면 인라인 표시 (이미지·서술형)
//
// 도안 자체가 없으면 안내 화면.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_pattern_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../blueprint/presentation/step_log_screen.dart';
import '../../market/presentation/pdf_viewer_screen.dart';
import '../data/pattern_repository.dart';
import '../domain/ai_pattern_section.dart';
import '../domain/pattern_chart.dart';
import 'image_pattern_viewer_screen.dart';
import 'narrative_pattern_viewer_screen.dart';
import 'pattern_detail_screen.dart';
import 'pattern_editor_screen.dart';
import 'widgets/offline_download_button.dart';

class UniversalPatternViewerScreen extends ConsumerStatefulWidget {
  final String patternId;

  const UniversalPatternViewerScreen({super.key, required this.patternId});

  @override
  ConsumerState<UniversalPatternViewerScreen> createState() =>
      _UniversalPatternViewerScreenState();
}

class _UniversalPatternViewerScreenState
    extends ConsumerState<UniversalPatternViewerScreen> {
  PatternChart? _chart;
  bool _loading = true;
  String? _error;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(patternRepositoryProvider);
      final loaded = await repo.get(widget.patternId);
      if (!mounted) return;
      if (loaded == null) {
        setState(() {
          _error = 'not_found';
          _loading = false;
        });
        return;
      }
      setState(() {
        _chart = loaded;
        _loading = false;
      });
      // #810 정정 — sourceType 분기 제거. universal_pattern_viewer 자체 인라인 표시로 통일.
      //   이전 분기 시 NarrativeViewer/ImageViewer/PdfViewerScreen 으로 pushReplacement →
      //   OfflineDownloadButton 등 기존 기능 회귀 + GlobalKey 충돌. 사용자 정정 요청.
      // _dispatch(loaded);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// PatternSourceType 기반으로 적절한 뷰어로 분기.
  ///
  /// 데이터 형태(rows/cols)가 아니라 사용자 의도(sourceType)를 기준으로 함.
  /// → AI 변환 도안이 우연히 rows/cols 있어도 차트 에디터로 가지 않음.
  ///
  /// #810 — 분기 제거 후 호출되지 않음. 향후 재활성화 가능성을 위해 보존.
  // ignore: unused_element
  void _dispatch(PatternChart chart) {
    if (_redirected) return;

    // 우선순위 1: PDF 자료 보유 (sourceType 무관 — PDF는 항상 PDF 뷰어로)
    if (chart.pdfUrl.isNotEmpty &&
        chart.sourceType != PatternSourceType.aiConverted) {
      _redirected = true;
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(
            url: chart.pdfUrl,
            title: chart.title,
          ),
        ),
      );
      return;
    }

    // 우선순위 2~5: sourceType 기반
    switch (chart.sourceType) {
      case PatternSourceType.aiConverted:
        _redirected = true;
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NarrativePatternViewerScreen(chart: chart),
          ),
        );
        return;

      case PatternSourceType.editor:
        // 사용자가 도안에디터로 직접 그린 도안만 차트 격자 뷰어로.
        // rows/cols 가 0이면 아래 fallback(인라인)으로.
        if (chart.rows > 0 && chart.cols > 0) {
          _redirected = true;
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => PatternEditorScreen(
                patternId: chart.id,
                readOnly: true,
              ),
            ),
          );
          return;
        }
        break;

      case PatternSourceType.image:
        _redirected = true;
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ImagePatternViewerScreen(chart: chart),
          ),
        );
        return;

      case PatternSourceType.external:
        // 외부 자료: 이미지 있으면 이미지 뷰어. (PDF는 위에서 이미 분기.)
        if (chart.imageUrl.isNotEmpty) {
          _redirected = true;
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ImagePatternViewerScreen(chart: chart),
            ),
          );
          return;
        }
        break;
    }

    // Fallback: 알 수 없는 형태 / 빈 도안 — 본 화면 인라인 표시 (안전)
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Stack(
          children: [
            const BgOrbs(),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_error == 'not_found' || _chart == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Stack(
          children: [
            const BgOrbs(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: C.mu),
                    const SizedBox(height: 12),
                    Text(
                      isKorean
                          ? '도안을 찾을 수 없어요'
                          : 'Pattern not found',
                      style: T.bodyBold.copyWith(color: C.mu),
                    ),
                    if (_error != null && _error != 'not_found') ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: T.caption.copyWith(color: C.mu),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // #810 정정 — fallback 본문 대신 도안 라이브러리와 동일한 PatternDetailScreen 직접 사용.
    //   사용자 의도: "유니버셜 뷰어 = 도안 라이브러리에서 뜨는 뷰어 (PatternDetailScreen)"
    //   최근 작업 / 변환 결과 / 검색 결과 등 모든 진입이 같은 풍부한 화면을 보게 됨.
    return PatternDetailScreen(chart: _chart!);

    // ignore: dead_code, unused_local_variable
    final chart = _chart!;
    // ignore: dead_code, unused_local_variable
    final String? offlineSourceUrl = chart.pdfUrl.isNotEmpty
        ? chart.pdfUrl
        : (chart.imageUrl.isNotEmpty ? chart.imageUrl : null);
    // ignore: dead_code, unused_local_variable
    final String offlineKind = chart.pdfUrl.isNotEmpty ? 'pdf' : 'image';
    // ignore: dead_code
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(chart.title, style: T.h3),
        actions: [
          if (offlineSourceUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OfflineDownloadButton(
                patternId: chart.id,
                sourceUrl: offlineSourceUrl,
                kind: offlineKind,
                // #838 — 썸네일(=imageUrl) 함께 영구 캐시.
                thumbnailUrl: chart.imageUrl.isNotEmpty ? chart.imageUrl : null,
                isKorean: isKorean,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildSections(context, chart, isKorean),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 인라인 fallback 뷰어 — 도안의 모든 콘텐츠를 한 화면에 동시 표시 (#810).
  ///
  /// 섹션 순서:
  ///   1. 이미지 (InteractiveViewer 인라인 줌 + 풀스크린 진입 버튼)
  ///   2. PDF 인라인 (PDFView, 고정 높이)
  ///   3. 차트 격자 미리보기 + "차트 에디터로 열기" 버튼
  ///   4. 단계로그 (aiSections 또는 step_blueprints 진입 버튼)
  ///   5. 서술형 텍스트
  /// 모든 섹션이 비면 안내 카드 표시.
  List<Widget> _buildSections(
    BuildContext context,
    PatternChart chart,
    bool isKorean,
  ) {
    final widgets = <Widget>[];
    final hasImage = chart.imageUrl.isNotEmpty;
    final hasPdf = chart.pdfUrl.isNotEmpty;
    final hasChart = chart.rows > 0 && chart.cols > 0;
    // ignore: deprecated_member_use_from_same_package
    final aiSections = chart.aiSections ?? const <AiSection>[];
    final hasSteps = aiSections.isNotEmpty;
    final hasNarrative = chart.narrativeText.isNotEmpty;
    final hasAny = hasImage || hasPdf || hasChart || hasSteps || hasNarrative;

    // 1. 이미지 — 인라인 줌 + 풀스크린 진입
    if (hasImage) {
      widgets.add(_InlineImageSection(chart: chart, isKorean: isKorean));
      widgets.add(const SizedBox(height: 16));
    }

    // 2. PDF — 인라인 표시
    if (hasPdf) {
      widgets.add(_InlinePdfSection(chart: chart, isKorean: isKorean));
      widgets.add(const SizedBox(height: 16));
    }

    // 3. 차트 격자 미리보기 + 에디터 진입
    if (hasChart) {
      widgets.add(_ChartPreviewSection(chart: chart, isKorean: isKorean));
      widgets.add(const SizedBox(height: 16));
    }

    // 4. 단계로그 (aiSections 보유 시) — 카드 리스트 미리보기 + 풀 단계로그 진입
    if (hasSteps) {
      widgets.add(_StepsSection(
        chart: chart,
        sections: aiSections,
        isKorean: isKorean,
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // 5. 서술형 본문
    if (hasNarrative) {
      widgets.add(MoriBlockShell(
        label: isKorean ? '도안 설명' : 'Description',
        icon: Icons.description_rounded,
        accent: C.lvD,
        child: Text(
          chart.narrativeText,
          style: T.body.copyWith(height: 1.6),
        ),
      ));
    }

    // Fallback 안내 — 표시할 내용이 하나도 없을 때
    if (!hasAny) {
      widgets.add(MoriBlockShell(
        label: isKorean ? '안내' : 'Notice',
        icon: Icons.info_outline_rounded,
        accent: C.mu,
        child: Text(
          isKorean
              ? '이 도안에는 표시할 내용이 없어요.'
              : 'No content to display.',
          style: T.body.copyWith(color: C.mu),
        ),
      ));
    }

    return widgets;
  }
}

// ============================================================================
// 섹션 1: 이미지 (인라인 줌 + 풀스크린 진입)
// ============================================================================
class _InlineImageSection extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _InlineImageSection({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: isKorean ? '이미지' : 'Image',
      icon: Icons.image_rounded,
      accent: C.pk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: CachedPatternImage(
                url: chart.imageUrl,
                patternId: chart.id,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImagePatternViewerScreen(chart: chart),
                  ),
                );
              },
              icon: Icon(Icons.zoom_out_map_rounded, size: 16, color: C.pk),
              label: Text(
                isKorean ? '풀스크린으로 보기' : 'View fullscreen',
                style: T.caption.copyWith(color: C.pk, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 섹션 2: PDF 인라인 (PDFView, 고정 높이)
// ============================================================================
class _InlinePdfSection extends StatefulWidget {
  final PatternChart chart;
  final bool isKorean;
  const _InlinePdfSection({required this.chart, required this.isKorean});

  @override
  State<_InlinePdfSection> createState() => _InlinePdfSectionState();
}

class _InlinePdfSectionState extends State<_InlinePdfSection> {
  String? _localPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.chart.pdfUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final bytes = await response.expand((b) => b).toList();
      client.close();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/pattern_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() {
          _localPath = file.path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return MoriBlockShell(
      label: isKorean ? '원본 PDF' : 'Original PDF',
      icon: Icons.picture_as_pdf_rounded,
      accent: C.og,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 480,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPdfBody(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PdfViewerScreen(
                      url: widget.chart.pdfUrl,
                      title: widget.chart.title,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.open_in_full_rounded, size: 16, color: C.og),
              label: Text(
                isKorean ? '전체화면으로 보기' : 'Open fullscreen',
                style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfBody() {
    final isKorean = widget.isKorean;
    if (kIsWeb) {
      return Container(
        color: C.gx,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, color: C.mu, size: 40),
              const SizedBox(height: 12),
              Text(
                isKorean
                    ? '웹에서는 외부 앱으로 PDF를 엽니다'
                    : 'PDF opens in an external app on web',
                style: T.body.copyWith(color: C.mu),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(widget.chart.pdfUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(isKorean ? '외부 앱으로 열기' : 'Open in external app'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.og,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return Container(
        color: C.gx,
        child: Center(child: CircularProgressIndicator(color: C.og)),
      );
    }
    if (_error != null) {
      return Container(
        color: C.gx,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: C.mu, size: 40),
              const SizedBox(height: 8),
              Text(
                isKorean ? 'PDF를 불러올 수 없어요' : 'Failed to load PDF',
                style: T.body.copyWith(color: C.mu),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(widget.chart.pdfUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  isKorean ? '외부 앱으로 열기' : 'Open in external app',
                  style: TextStyle(color: C.og),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onError: (e) {
        if (mounted) setState(() => _error = '$e');
      },
    );
  }
}

// ============================================================================
// 섹션 3: 차트 격자 미리보기 + 에디터 진입
// ============================================================================
class _ChartPreviewSection extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _ChartPreviewSection({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: isKorean ? '차트' : 'Chart',
      icon: Icons.grid_on_rounded,
      accent: C.lv,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 격자 메타 정보
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 14, color: C.mu),
              const SizedBox(width: 4),
              Text(
                isKorean
                    ? '${chart.rows}단 × ${chart.cols}코'
                    : '${chart.rows} rows × ${chart.cols} cols',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 간단한 격자 미리보기 (CustomPaint)
          AspectRatio(
            aspectRatio: chart.cols / chart.rows,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: C.gx,
                child: CustomPaint(
                  painter: _GridPreviewPainter(chart: chart),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PatternEditorScreen(
                      patternId: chart.id,
                      readOnly: true,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.open_in_full_rounded, size: 16, color: C.lv),
              label: Text(
                isKorean ? '차트 에디터로 열기' : 'Open in chart editor',
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 간단한 격자 미리보기 페인터 — 셀 배경색만 그림.
/// 큰 도안에서도 가벼운 표시를 위해 stroke 없이 fill만.
class _GridPreviewPainter extends CustomPainter {
  final PatternChart chart;
  _GridPreviewPainter({required this.chart});

  @override
  void paint(Canvas canvas, Size size) {
    if (chart.rows == 0 || chart.cols == 0) return;
    final cellW = size.width / chart.cols;
    final cellH = size.height / chart.rows;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int r = 0; r < chart.rows; r++) {
      for (int c = 0; c < chart.cols; c++) {
        final cell = chart.grid[r][c];
        final color = cell.color;
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(c * cellW, r * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPreviewPainter old) =>
      old.chart != chart;
}

// ============================================================================
// 섹션 4: 단계 카드 리스트 + 풀 단계로그 진입
// ============================================================================
class _StepsSection extends StatelessWidget {
  final PatternChart chart;
  final List<AiSection> sections;
  final bool isKorean;
  const _StepsSection({
    required this.chart,
    required this.sections,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    // 미리보기: 최대 3개 섹션, 각 섹션의 첫 2개 단계까지만 표시.
    final previewSections = sections.take(3).toList();
    return MoriBlockShell(
      label: isKorean ? '단계로그' : 'Step Log',
      icon: Icons.list_alt_rounded,
      accent: C.lm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in previewSections) ...[
            _SectionPreviewCard(
              section: s,
              isKorean: isKorean,
            ),
            const SizedBox(height: 8),
          ],
          if (sections.length > previewSections.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                isKorean
                    ? '외 ${sections.length - previewSections.length}개 섹션'
                    : '+${sections.length - previewSections.length} more sections',
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StepLogScreen(blueprintId: chart.id),
                  ),
                );
              },
              icon: Icon(Icons.arrow_forward_rounded, size: 16, color: C.lm),
              label: Text(
                isKorean ? '단계로그 전체 보기' : 'Open full step log',
                style: T.caption.copyWith(color: C.lm, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPreviewCard extends StatelessWidget {
  final AiSection section;
  final bool isKorean;
  const _SectionPreviewCard({required this.section, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final title = isKorean
        ? (section.titleKo ?? section.title)
        : section.title;
    final previewSteps = section.steps.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.lm.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? (isKorean ? '제목 없음' : 'Untitled') : title,
            style: T.bodyBold.copyWith(color: C.tx),
          ),
          if (previewSteps.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final step in previewSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: T.body.copyWith(color: C.mu)),
                    Expanded(
                      child: Text(
                        isKorean
                            ? (step.instructionKo ?? step.instruction)
                            : step.instruction,
                        style: T.body.copyWith(color: C.tx, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            if (section.steps.length > previewSteps.length)
              Text(
                isKorean
                    ? '외 ${section.steps.length - previewSteps.length}개 단계'
                    : '+${section.steps.length - previewSteps.length} more steps',
                style: T.caption.copyWith(color: C.mu),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isKorean ? '단계 없음' : 'No steps',
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
        ],
      ),
    );
  }
}
