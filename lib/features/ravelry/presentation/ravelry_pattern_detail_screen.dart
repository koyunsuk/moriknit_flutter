import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/pattern_library_provider.dart';
import '../../pattern_library/domain/pattern_file.dart';
import '../data/ravelry_repository.dart';
import '../domain/ravelry_models.dart';
import 'ravelry_project_edit_sheet.dart';

// ── 도안 상세 프로바이더 ─────────────────────────────────────────────────────────
final _patternDetailProvider = FutureProvider.family<RavelryPatternDetail, int>(
  (ref, id) {
    final repo = ref.watch(ravelryRepositoryProvider);
    if (repo == null) throw Exception('Ravelry 연결이 필요합니다.');
    return repo.fetchPatternDetail(id);
  },
);

class RavelryPatternDetailScreen extends ConsumerWidget {
  final int patternId;
  final String patternName;

  const RavelryPatternDetailScreen({
    super.key,
    required this.patternId,
    required this.patternName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final detailAsync = ref.watch(_patternDetailProvider(patternId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(patternName, style: T.h3),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: C.og, size: 48),
                    const SizedBox(height: 12),
                    Text('$e',
                        style: T.caption.copyWith(color: C.og),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(_patternDetailProvider(patternId)),
                      child: Text(isKorean ? '다시 시도' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (detail) => _PatternDetailBody(
              detail: detail,
              isKorean: isKorean,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternDetailBody extends ConsumerStatefulWidget {
  const _PatternDetailBody({required this.detail, required this.isKorean});
  final RavelryPatternDetail detail;
  final bool isKorean;

  @override
  ConsumerState<_PatternDetailBody> createState() => _PatternDetailBodyState();
}

class _PatternDetailBodyState extends ConsumerState<_PatternDetailBody> {
  bool _downloading = false;

  Future<void> _downloadToLibrary(String fileUrl, String fileName) async {
    final isKorean = widget.isKorean;
    final repo = ref.read(ravelryRepositoryProvider);
    if (repo == null) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '다운로드 중입니다.' : 'Downloading...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final bytes = await repo.downloadPatternFile(fileUrl);
          final ext = fileName.split('.').last.toLowerCase();
          final mimeType = ext == 'pdf'
              ? 'application/pdf'
              : ext == 'png'
                  ? 'image/png'
                  : 'image/jpeg';
          await ref.read(patternFileRepositoryProvider).uploadFile(
            bytes: bytes,
            fileName: fileName,
            mimeType: mimeType,
            source: PatternFileSource.ravelry,
            sourceMeta: {'ravelryPatternId': widget.detail.id, 'fileUrl': fileUrl},
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '도안 라이브러리에 저장됐어요.' : 'Saved to pattern library.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '다운로드 실패: $e' : 'Download failed: $e');
    }
  }

  Future<void> _downloadPdf() async {
    final detail = widget.detail;
    final isKorean = widget.isKorean;

    // files 목록 우선, 없으면 pdf_url 직접 사용
    if (detail.files.isNotEmpty) {
      final file = detail.files.first;
      if (file.url != null) {
        await _downloadToLibrary(file.url!, file.fileName);
        return;
      }
    }
    if (detail.pdfUrl != null) {
      final fileName = '${detail.name.replaceAll(RegExp(r'[^\w가-힣]'), '_')}.pdf';
      await _downloadToLibrary(detail.pdfUrl!, fileName);
      return;
    }
    if (!mounted) return;
    showSaveErrorSnackBar(
      ScaffoldMessenger.of(context),
      message: isKorean ? '다운로드 가능한 파일이 없어요.' : 'No downloadable files found.',
    );
  }

  Future<void> _viewPattern() async {
    final detail = widget.detail;
    final isKorean = widget.isKorean;
    final repo = ref.read(ravelryRepositoryProvider);
    if (repo == null) return;

    // 1. detail.files에서 다운로드 가능한 URL 찾기
    String? downloadUrl = detail.files.isNotEmpty ? detail.files.first.url : null;
    downloadUrl ??= detail.pdfUrl;

    // 2. 없으면 fetchPatternFiles로 추가 조회
    if (downloadUrl == null) {
      try {
        final files = await repo.fetchPatternFiles(detail.id);
        downloadUrl = files.isNotEmpty ? files.first.url : null;
      } catch (e) {
        // 파일 목록 조회 실패 시 fallback 진행
        debugPrint('[Ravelry] fetchPatternFiles error: $e');
      }
    }

    // 3. 다운로드 가능한 URL이 있으면 인앱 PDF 뷰어
    if (downloadUrl != null) {
      if (!mounted) return;
      final url = downloadUrl;
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: isKorean ? '도안을 불러오는 중입니다.' : 'Loading pattern...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
          task: () async {
            final bytes = await repo.downloadPatternFile(url);
            final tmpDir = await getTemporaryDirectory();
            final fileName = detail.name.replaceAll(RegExp(r'[^\w가-힣]'), '_');
            final file = File('${tmpDir.path}/$fileName.pdf');
            await file.writeAsBytes(bytes);
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PdfViewerScreen(title: detail.name, filePath: file.path),
              ),
            );
          },
        );
      } catch (e) {
        if (!mounted) return;
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
      return;
    }

    // 4. 다운로드 불가능하면 외부 브라우저로 fallback
    final fallbackUrl = detail.ravelryUrl;
    if (fallbackUrl == null) return;
    await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final isKorean = widget.isKorean;
    final hasDownload = detail.pdfUrl != null || detail.files.isNotEmpty;
    final hasView = detail.pdfUrl != null || detail.files.isNotEmpty || detail.ravelryUrl != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 커버 이미지
          if (detail.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: detail.photoUrls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Container(color: C.lvL, child: Icon(Icons.menu_book_rounded, color: C.lv, size: 48)),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 도안 이름 + 저자
          Text(detail.name, style: T.h3),
          if (detail.authorName != null) ...[
            const SizedBox(height: 4),
            Text(detail.authorName!, style: T.body.copyWith(color: C.mu)),
          ],
          const SizedBox(height: 12),

          // 메타 칩
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (detail.isFree)
                _MetaChip(label: isKorean ? '무료' : 'Free', color: C.lv)
              else if (detail.price != null)
                _MetaChip(label: '\$${detail.price!.toStringAsFixed(2)}'),
              if (detail.craft != null)
                _MetaChip(label: detail.craft!),
              if (detail.difficultyAverage != null)
                _MetaChip(label: '★ ${detail.difficultyAverage!.toStringAsFixed(1)}'),
              ...detail.categories.take(3).map((c) => _MetaChip(label: c)),
            ],
          ),
          const SizedBox(height: 20),

          // 액션 버튼 1행: 도안 보기 + 라이브러리 저장
          Row(
            children: [
              if (hasView)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewPattern,
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(isKorean ? '도안 보기' : 'View Pattern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.pk,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (hasView && hasDownload) const SizedBox(width: 8),
              if (hasDownload)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloading ? null : _downloadPdf,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(isKorean ? '라이브러리 저장' : 'Save to Library'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.lv,
                      side: BorderSide(color: C.lv),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 액션 버튼 2행: Ravelry에서 보기
          if (detail.ravelryUrl != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(detail.ravelryUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(isKorean ? 'Ravelry에서 보기' : 'View on Ravelry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.lv,
                  side: BorderSide(color: C.lv.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showRavelryProjectEditSheet(
                context,
                ref,
                patternId: detail.id,
                patternName: detail.name,
                isKorean: isKorean,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isKorean ? '라벨리 프로젝트 시작하기' : 'Start Ravelry Project'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.lv,
                side: BorderSide(color: C.lv.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // 설명
          if (detail.notesHtml != null && detail.notesHtml!.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionTitle(title: isKorean ? '도안 설명' : 'Pattern Notes'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Text(
                detail.notesHtml!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                style: T.sm.copyWith(color: C.tx2, height: 1.6),
              ),
            ),
          ],

          // 다운로드 파일 목록
          if (detail.files.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionTitle(title: isKorean ? '다운로드 파일' : 'Download Files'),
            const SizedBox(height: 8),
            ...detail.files.map((f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.attach_file_rounded, color: C.lv, size: 20),
              title: Text(f.fileName, style: T.sm),
              trailing: f.url != null
                  ? IconButton(
                      icon: Icon(Icons.download_rounded, color: C.lv),
                      onPressed: () => _downloadToLibrary(f.url!, f.fileName),
                    )
                  : null,
            )),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.mu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: T.caption.copyWith(color: c, fontSize: 11)),
    );
  }
}

// ── 인앱 PDF 뷰어 ───────────────────────────────────────────────────────────────
class _PdfViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  const _PdfViewerScreen({required this.title, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: T.h3, overflow: TextOverflow.ellipsis),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: PDFView(filePath: filePath),
    );
  }
}
