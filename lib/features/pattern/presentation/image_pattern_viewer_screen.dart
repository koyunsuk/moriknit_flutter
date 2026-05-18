// lib/features/pattern/presentation/image_pattern_viewer_screen.dart
//
// 이슈 후속 — sourceType=image 또는 external(이미지) 도안 전용 뷰어.
//
// 핵심 책임:
//  - imageUrl 풀스크린 줌·팬 뷰
//  - 캡션·설명·메타 표시
//  - UniversalPatternViewerScreen 의 _dispatch 에서 pushReplacement 진입
//
// 기존 인라인 표시 위젯과 동일한 외형 토큰/공통 위젯 사용 (BgOrbs, MoriBlockShell, T, C).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_pattern_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/pattern_chart.dart';

class ImagePatternViewerScreen extends ConsumerWidget {
  final PatternChart chart;

  const ImagePatternViewerScreen({super.key, required this.chart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final hasImage = chart.imageUrl.isNotEmpty;
    final hasNarrative = chart.narrativeText.isNotEmpty;

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
                  if (hasImage) ...[
                    _ZoomableImage(chart: chart),
                    const SizedBox(height: 16),
                  ],
                  if (hasNarrative)
                    MoriBlockShell(
                      label: isKorean ? '도안 설명' : 'Description',
                      icon: Icons.description_rounded,
                      accent: C.lvD,
                      child: Text(
                        chart.narrativeText,
                        style: T.body.copyWith(height: 1.6),
                      ),
                    )
                  else if (!hasImage)
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

/// 이미지 풀스크린 줌·팬 뷰 — InteractiveViewer 기반.
class _ZoomableImage extends StatelessWidget {
  final PatternChart chart;
  const _ZoomableImage({required this.chart});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: CachedPatternImage(
          url: chart.imageUrl,
          patternId: chart.id,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
