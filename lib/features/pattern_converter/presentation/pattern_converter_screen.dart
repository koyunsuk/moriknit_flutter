import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/parsed_pattern_provider.dart';
import '../data/pattern_converter_repository.dart';
import 'ai_pattern_edit_screen.dart';

class PatternConverterScreen extends ConsumerStatefulWidget {
  const PatternConverterScreen({super.key});

  @override
  ConsumerState<PatternConverterScreen> createState() =>
      _PatternConverterScreenState();
}

class _PatternConverterScreenState
    extends ConsumerState<PatternConverterScreen> {
  bool _isUploading = false;
  double _progress = 0;
  int _stage = 1; // 1=업로드, 2=AI분석, 3=저장
  String _statusMessage = '';

  Future<void> _pickAndParse() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;

    final fileName = picked.name;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';

    // 파일 크기 제한 (10MB)
    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        messenger,
        message: isKorean
            ? '파일 크기가 너무 큽니다. 10MB 이하의 파일을 사용해 주세요.'
            : 'File too large. Please use a file under 10MB.',
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
      _stage = 1;
      _statusMessage = isKorean ? 'AI 서버 접속 중...' : 'Connecting to AI server...';
    });

    try {
      final repo = PatternConverterRepository();
      final savedChart = await repo.uploadAndParse(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p < 0.5) {
              _stage = 1;
              _statusMessage = isKorean ? 'AI 서버 접속 중...' : 'Connecting to AI server...';
            } else if (p < 0.9) {
              _stage = 2;
              _statusMessage = isKorean ? 'AI가 도안을 분석하는 중...' : 'AI is analyzing...';
            } else if (p < 1.0) {
              _stage = 3;
              _statusMessage = isKorean ? 'AI 분석이 완료됐어요!' : 'AI analysis complete!';
            } else {
              _stage = 4;
              _statusMessage = isKorean ? '한글로 변환 중...' : 'Converting...';
            }
          });
        },
      );

      // 분석 완료 단계 잠깐 표시
      if (mounted) {
        setState(() {
          _stage = 3;
          _progress = 0.95;
          _statusMessage = isKorean ? 'AI 분석이 완료됐어요!' : 'AI analysis complete!';
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _stage = 4;
          _progress = 1.0;
          _statusMessage = isKorean ? '한글로 변환 중...' : 'Converting...';
        });
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiPatternEditScreen(
            unsavedChart: savedChart,
            onGoToLibrary: () => context.push(Routes.toolsMyParsedPatterns),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errMsg = e
          .toString()
          .split('\n')
          .first
          .replaceAll(RegExp(r'^\[firebase_functions/[^\]]+\]\s*'), '');
      showSaveErrorSnackBar(
        messenger,
        message: isKorean ? '오류가 발생했어요: $errMsg' : 'Error: $errMsg',
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
        title: Text(
          isKorean ? '도안 변환기' : 'Pattern Converter',
          style: T.h3,
        ),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 안내 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: C.lv.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: C.lv, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isKorean
                                ? 'AI 도안 변환기'
                                : 'AI Pattern Converter',
                            style: T.h3.copyWith(color: C.lv),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isKorean
                            ? 'PDF 또는 이미지로 된 뜨개 도안을\n단계별로 따라하기 쉽게 변환해 드려요.\n\n저작권 보호를 위해 앱 내에서만 볼 수 있어요.'
                            : 'Convert your knitting pattern PDF or image\ninto easy step-by-step instructions.\n\nFor copyright protection, only visible within the app.',
                        style: T.sm.copyWith(color: C.tx2, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SectionTitle(
                    title: isKorean ? '지원 형식' : 'Supported Formats'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _FormatChip(
                        label: 'PDF', icon: Icons.picture_as_pdf),
                    const SizedBox(width: 8),
                    _FormatChip(
                        label: 'JPG', icon: Icons.image_rounded),
                    const SizedBox(width: 8),
                    _FormatChip(
                        label: 'PNG', icon: Icons.image_rounded),
                  ],
                ),
                const SizedBox(height: 32),

                if (_isUploading)
                  _UploadProgress(
                      progress: _progress,
                      message: _statusMessage,
                      stage: _stage)
                else
                  _UploadButton(onTap: _pickAndParse),

                const SizedBox(height: 32),

                // 변환된 도안 리스트 인라인 표시
                _InlinePatternList(isKorean: isKorean),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FormatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.lv.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: C.lvD),
          const SizedBox(width: 4),
          Text(label, style: T.caption.copyWith(color: C.lvD)),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: C.lv.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_rounded, size: 48, color: C.lv),
            const SizedBox(height: 12),
            Text(
              '파일을 선택해 주세요',
              style: T.body
                  .copyWith(color: C.lv, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, JPG, PNG 지원',
              style: T.caption.copyWith(color: C.tx2),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  final double progress;
  final String message;
  final int stage; // 1=업로드, 2=AI분석, 3=분석완료, 4=변환중

  const _UploadProgress({
    required this.progress,
    required this.message,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('1', '업로드'),
      ('2', 'AI 분석'),
      ('3', '분석 완료'),
      ('4', '변환'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.lv.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // 단계 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < stages.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 1,
                      color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.2),
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.15),
                        border: Border.all(
                          color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: i + 1 < stage
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                stages[i].$1,
                                style: T.caption.copyWith(
                                  color: i + 1 == stage ? Colors.white : C.lv.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stages[i].$2,
                      style: T.caption.copyWith(
                        color: i + 1 <= stage ? C.lv : C.tx2,
                        fontWeight: i + 1 == stage ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // 단계별 아이콘/인디케이터
          if (stage == 3)
            Icon(Icons.check_circle_rounded, color: C.lv, size: 52)
          else
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: stage == 1 ? progress * 2 : null,
                    strokeWidth: 5,
                    backgroundColor: C.lv.withValues(alpha: 0.15),
                    color: C.lv,
                  ),
                  if (stage == 1)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Text(message, style: T.sm.copyWith(color: C.tx2), textAlign: TextAlign.center),

          // AI 분석 중 → 선형 프로그레스 바
          if (stage == 2) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: C.lv.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(C.lv),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.og.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: C.og),
                  const SizedBox(width: 5),
                  Text('도안 크기에 따라 최대 3분이 소요될 수 있어요.', style: T.caption.copyWith(color: C.og)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InlinePatternList extends ConsumerWidget {
  final bool isKorean;
  const _InlinePatternList({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(aiPatternsProvider);

    return patternsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (patterns) {
        if (patterns.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isKorean ? '변환된 도안' : 'Converted Patterns',
                  style: T.captionBold.copyWith(color: C.mu),
                ),
                Text(
                  '${patterns.length}개',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...patterns.map((p) => _PatternRow(
                  pattern: p,
                  isKorean: isKorean,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiPatternEditScreen(patternId: p.id),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _PatternRow extends StatelessWidget {
  final PatternChart pattern;
  final bool isKorean;
  final VoidCallback onTap;

  const _PatternRow({required this.pattern, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sections = pattern.aiSections ?? [];
    final totalSteps = sections.fold<int>(0, (a, s) => a + s.steps.length);
    final done = sections.fold<int>(0, (a, s) => a + s.steps.where((st) => st.isCompleted).length);
    final pct = totalSteps == 0 ? 0 : (done / totalSteps * 100).toInt();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.description_rounded, color: C.lv, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.title,
                      style: T.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${sections.length}섹션 · $totalSteps단계 · $pct% 완료',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.tx2, size: 18),
          ],
        ),
      ),
    );
  }
}
