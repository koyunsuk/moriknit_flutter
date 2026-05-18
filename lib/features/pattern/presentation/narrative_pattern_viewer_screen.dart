// lib/features/pattern/presentation/narrative_pattern_viewer_screen.dart
//
// 이슈 후속 — sourceType=aiConverted 도안 전용 뷰어.
//
// 핵심 책임:
//  - AI 변환 결과(서술형 + 단계로그) 위주 표시
//  - 단계로그 진입 버튼 (blueprintId = chart.id 컨벤션, StepUnitEntryRouter 참조)
//  - 도안 메타데이터(제목·소유자·생성일·이미지) 표시
//
// 기존 도안 격자 뷰어(PatternEditorScreen readOnly)와 분리해서
// AI 변환 도안은 서술형 위주 UX 로 진입.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_pattern_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../blueprint/presentation/step_log_screen.dart';
import '../../market/presentation/pdf_viewer_screen.dart';
import '../domain/pattern_chart.dart';

class NarrativePatternViewerScreen extends ConsumerWidget {
  final PatternChart chart;

  const NarrativePatternViewerScreen({super.key, required this.chart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final hasImage = chart.imageUrl.isNotEmpty;
    final hasPdf = chart.pdfUrl.isNotEmpty;
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
                  // 1. 원본 자료 (이미지 우선, PDF는 별도 버튼)
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedPatternImage(
                        url: chart.imageUrl,
                        patternId: chart.id,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 2. 메타데이터
                  _MetaRow(chart: chart, isKorean: isKorean),
                  const SizedBox(height: 16),

                  // 3. 단계로그 진입 버튼 (AI 변환 핵심 진입점)
                  _StepLogCta(chart: chart, isKorean: isKorean),
                  const SizedBox(height: 16),

                  // 4. PDF 원본 보기 버튼 (있을 때만)
                  if (hasPdf) ...[
                    _PdfCta(chart: chart, isKorean: isKorean),
                    const SizedBox(height: 16),
                  ],

                  // 5. 서술형 본문
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
                  else
                    MoriBlockShell(
                      label: isKorean ? '안내' : 'Notice',
                      icon: Icons.info_outline_rounded,
                      accent: C.mu,
                      child: Text(
                        isKorean
                            ? '단계로그에서 변환된 단계를 확인하세요.'
                            : 'Open Step Log to view converted steps.',
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

class _MetaRow extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _MetaRow({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final created = chart.createdAt;
    final ownerName = chart.sourceOwnerName;
    final hasMeta = created != null || (ownerName != null && ownerName.isNotEmpty);
    if (!hasMeta) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 16, color: C.lvD),
        const SizedBox(width: 6),
        Text(
          isKorean ? 'AI 변환 도안' : 'AI Converted',
          style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
        ),
        if (ownerName != null && ownerName.isNotEmpty) ...[
          const SizedBox(width: 10),
          Icon(Icons.person_rounded, size: 14, color: C.mu),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              ownerName,
              style: T.caption.copyWith(color: C.mu),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (created != null) ...[
          const SizedBox(width: 10),
          Icon(Icons.schedule_rounded, size: 14, color: C.mu),
          const SizedBox(width: 4),
          Text(
            _formatDate(created),
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _StepLogCta extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _StepLogCta({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // StepUnitEntryRouter 컨벤션: AI 변환 도안의 blueprintId = chart.id
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StepLogScreen(blueprintId: chart.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: MoriBlockShell(
        label: isKorean ? '단계로그 열기' : 'Open Step Log',
        icon: Icons.list_alt_rounded,
        accent: C.lv,
        child: Row(
          children: [
            Expanded(
              child: Text(
                isKorean
                    ? 'AI가 변환한 단계를 확인하고 작업을 기록해요.'
                    : 'View converted steps and log your progress.',
                style: T.body.copyWith(color: C.tx),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: C.lv),
          ],
        ),
      ),
    );
  }
}

class _PdfCta extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _PdfCta({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfViewerScreen(
              url: chart.pdfUrl,
              title: chart.title,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: MoriBlockShell(
        label: isKorean ? '원본 PDF 보기' : 'View Original PDF',
        icon: Icons.picture_as_pdf_rounded,
        accent: C.og,
        child: Row(
          children: [
            Expanded(
              child: Text(
                isKorean
                    ? '변환 전 원본 PDF를 그대로 열어볼 수 있어요.'
                    : 'Open the source PDF used for conversion.',
                style: T.body.copyWith(color: C.tx),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: C.og),
          ],
        ),
      ),
    );
  }
}
