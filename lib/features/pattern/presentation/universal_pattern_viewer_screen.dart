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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_pattern_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../market/presentation/pdf_viewer_screen.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';
import 'image_pattern_viewer_screen.dart';
import 'narrative_pattern_viewer_screen.dart';
import 'pattern_editor_screen.dart';

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
      _dispatch(loaded);
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
  void _dispatch(PatternChart chart) {
    if (_redirected) return;

    // 우선순위 1: PDF 자료 보유 (sourceType 무관 — PDF는 항상 PDF 뷰어로)
    if (chart.pdfUrl.isNotEmpty &&
        chart.sourceType != PatternSourceType.aiConverted) {
      _redirected = true;
      Navigator.of(context).pushReplacement(
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
        Navigator.of(context).pushReplacement(
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
          Navigator.of(context).pushReplacement(
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ImagePatternViewerScreen(chart: chart),
          ),
        );
        return;

      case PatternSourceType.external:
        // 외부 자료: 이미지 있으면 이미지 뷰어. (PDF는 위에서 이미 분기.)
        if (chart.imageUrl.isNotEmpty) {
          _redirected = true;
          Navigator.of(context).pushReplacement(
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

    // Fallback 인라인 뷰어 — sourceType 분기에서 처리하지 못한 경우 (안전 표시)
    final chart = _chart!;
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
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (chart.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedPatternImage(
                        url: chart.imageUrl,
                        patternId: chart.id,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (chart.narrativeText.isNotEmpty)
                    MoriBlockShell(
                      label: isKorean ? '도안 설명' : 'Description',
                      icon: Icons.description_rounded,
                      accent: C.lvD,
                      child: Text(
                        chart.narrativeText,
                        style: T.body.copyWith(height: 1.6),
                      ),
                    )
                  else
                    MoriBlockShell(
                      label: isKorean ? '안내' : 'Notice',
                      icon: Icons.info_outline_rounded,
                      accent: C.mu,
                      child: Text(
                        isKorean
                            ? '이 도안에는 표시할 내용이 없어요.'
                            : 'No content to display.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
