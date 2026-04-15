import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../pattern/presentation/pattern_detail_screen.dart';
import '../data/pattern_converter_repository.dart';

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
  String _statusMessage = '';

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    final fileName = picked.name;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';

    final isKorean = ref.read(appLanguageProvider).isKorean;

    setState(() {
      _isUploading = true;
      _progress = 0;
      _statusMessage =
          isKorean ? '파일을 업로드하는 중...' : 'Uploading file...';
    });

    try {
      final repo = PatternConverterRepository();
      final savedChart = await repo.uploadAndParse(
        file: file,
        fileName: fileName,
        mimeType: mimeType,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p < 0.5) {
              _statusMessage =
                  isKorean ? '파일을 업로드하는 중...' : 'Uploading...';
            } else if (p < 1.0) {
              _statusMessage =
                  isKorean ? 'AI가 도안을 분석하는 중...' : 'AI is analyzing...';
            } else {
              _statusMessage = isKorean ? '분석 완료!' : 'Done!';
            }
          });
        },
      );

      if (!mounted) return;
      // 파싱 완료 → 수정 모드로 열기 (제목·설명 수정 후 저장하면 라이브러리로 이동)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatternDetailScreen(
            chart: savedChart,
            initialIsEditing: true,
            onSaveComplete: () {
              if (mounted) context.go(Routes.toolsPatterns);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '오류가 발생했어요: $e' : 'Error: $e',
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
                      progress: _progress, message: _statusMessage)
                else
                  _UploadButton(onTap: _pickAndParse),

                const SizedBox(height: 32),

                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        context.push(Routes.toolsMyParsedPatterns),
                    icon: Icon(Icons.folder_open_rounded,
                        color: C.lv, size: 18),
                    label: Text(
                      isKorean ? '변환된 도안 보기' : 'View Converted Patterns',
                      style: T.sm.copyWith(color: C.lv),
                    ),
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
  const _UploadProgress(
      {required this.progress, required this.message});

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 8),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: C.lv.withValues(alpha: 0.15),
                  color: C.lv,
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: T.caption.copyWith(
                      color: C.lv, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: T.sm.copyWith(color: C.tx2),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
