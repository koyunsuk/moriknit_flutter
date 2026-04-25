import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern_converter/data/pattern_converter_repository.dart';
import '../../pattern_converter/presentation/ai_pattern_edit_screen.dart';
import '../data/dropbox_file_service.dart';
import '../domain/dropbox_file_entry.dart';

const Color _kDropboxBlue = Color(0xFF0061FF);

/// 이슈 #654 — Dropbox 파일 미리보기 + 다운로드 + 도안 등록 화면.
///
/// 형식별 분기:
/// - 이미지(jpg/png/webp/gif): Image.memory
/// - PDF: 임시 파일 저장 후 PDFView (모바일/데스크톱) / 미리보기 비활성 (웹은 다운로드만)
/// - .mori/.json: JsonEncoder.indent → SelectableText
/// - txt/md: SelectableText
class DropboxPreviewScreen extends ConsumerStatefulWidget {
  const DropboxPreviewScreen({super.key, required this.entry});
  final DropboxFileEntry entry;

  @override
  ConsumerState<DropboxPreviewScreen> createState() =>
      _DropboxPreviewScreenState();
}

class _DropboxPreviewScreenState extends ConsumerState<DropboxPreviewScreen> {
  Uint8List? _bytes;
  String? _textContent; // mori/txt/md용 디코딩 결과
  String? _pdfPath; // 모바일 PDF용 임시 파일 경로
  bool _loading = true;
  String? _error;

  String get _ext => dropboxFileExtension(widget.entry.name);
  bool get _isImage =>
      {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(_ext);
  bool get _isPdf => _ext == 'pdf';
  bool get _isMori => _ext == 'mori' || _ext == 'json';
  bool get _isText => _ext == 'txt' || _ext == 'md';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!dropboxIsPreviewable(widget.entry.name) &&
        !dropboxIsImportable(widget.entry.name)) {
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      final svc = ref.read(dropboxFileServiceProvider);
      final bytes = await svc.downloadBytes(widget.entry.path);
      if (!mounted) return;

      // 텍스트형은 디코딩
      String? text;
      if (_isMori) {
        try {
          final raw = utf8.decode(bytes);
          final decoded = jsonDecode(raw);
          text = const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          text = utf8.decode(bytes, allowMalformed: true);
        }
      } else if (_isText) {
        text = utf8.decode(bytes, allowMalformed: true);
      }

      // PDF는 임시 파일 작성 (모바일/데스크톱만 — 웹은 PDFView 미지원)
      String? pdfPath;
      if (_isPdf && !kIsWeb) {
        try {
          final tmp = await getTemporaryDirectory();
          final safe =
              widget.entry.name.replaceAll(RegExp(r'[^\w가-힣.\-]'), '_');
          final f = File('${tmp.path}/$safe');
          await f.writeAsBytes(bytes);
          pdfPath = f.path;
        } catch (_) {
          // PDF 임시 저장 실패 — 미리보기 불가, 다운로드만 가능
        }
      }

      setState(() {
        _bytes = bytes;
        _textContent = text;
        _pdfPath = pdfPath;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _downloadToDevice() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '다운로드 중입니다.' : 'Downloading...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(dropboxFileServiceProvider).saveBytesToDevice(
              bytes: bytes,
              fileName: widget.entry.name,
            ),
      );
      if (!mounted) return;
      showSavedSnackBar(messenger,
          message: isKorean ? '다운로드가 완료됐어요.' : 'Download complete.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  Future<void> _registerAsPattern() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final bytes = _bytes;
    if (bytes == null) return;

    if (!dropboxIsImportable(widget.entry.name)) {
      showSaveErrorSnackBar(
        messenger,
        message: isKorean ? '이 형식은 도안 등록을 지원하지 않아요.' : 'Unsupported format.',
      );
      return;
    }

    try {
      // 형식별 분기
      if (_isImage || _isPdf) {
        // 이미지/PDF → AI 변환 (uploadAndParse)
        final mimeType = _isPdf
            ? 'application/pdf'
            : _ext == 'png'
                ? 'image/png'
                : _ext == 'webp'
                    ? 'image/webp'
                    : 'image/jpeg';

        // 파일 크기 제한 (10MB)
        const maxBytes = 10 * 1024 * 1024;
        if (bytes.length > maxBytes) {
          showSaveErrorSnackBar(
            messenger,
            message: isKorean
                ? '파일 크기가 너무 큽니다. 10MB 이하의 파일을 사용해 주세요.'
                : 'File too large. Please use a file under 10MB.',
          );
          return;
        }

        final chart = await runWithMoriLoadingDialog<PatternChart>(
          context,
          message: isKorean ? 'AI가 도안을 분석 중입니다.' : 'AI is analyzing...',
          subtitle: isKorean
              ? '도안 크기에 따라 최대 3분이 소요될 수 있어요.'
              : 'May take up to 3 minutes.',
          task: () => PatternConverterRepository().uploadAndParse(
            bytes: bytes,
            fileName: widget.entry.name,
            mimeType: mimeType,
            translateToKorean: false,
          ),
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiPatternEditScreen(
              unsavedChart: chart,
              onGoToLibrary: () =>
                  context.push(Routes.toolsMyParsedPatterns),
            ),
          ),
        );
      } else if (_isMori) {
        // .mori → PatternChart 직접 import
        final saved =
            await runWithMoriLoadingDialog<PatternChart?>(
          context,
          message: isKorean ? '도안을 가져오는 중입니다.' : 'Importing pattern...',
          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () async {
            final raw = utf8.decode(bytes);
            final decoded = jsonDecode(raw);
            if (decoded is! Map<String, dynamic>) {
              throw Exception(
                isKorean ? '올바른 .mori 파일이 아니에요.' : 'Invalid .mori file.');
            }
            final chartJson = decoded['chart'];
            if (chartJson is! Map<String, dynamic>) {
              throw Exception(isKorean
                  ? '도안 데이터를 찾을 수 없어요.'
                  : 'Chart data not found.');
            }
            final chart = PatternChart.fromJson(chartJson).copyWith(id: '');
            return PatternRepository().save(chart);
          },
        );
        if (!mounted) return;
        showSavedSnackBar(messenger,
            message: isKorean
                ? '도안 라이브러리에 저장됐어요.'
                : 'Saved to pattern library.');
        if (saved != null) {
          // 도안 라이브러리로 이동
          context.push(Routes.toolsPatterns);
        }
      } else if (_isText) {
        // txt/md → 텍스트(서술형) 도안으로 저장
        final text = utf8.decode(bytes, allowMalformed: true);
        final title = widget.entry.name.replaceAll(
            RegExp(r'\.(txt|md)$', caseSensitive: false), '');
        await runWithMoriLoadingDialog<PatternChart>(
          context,
          message:
              isKorean ? '도안을 저장하는 중입니다.' : 'Saving pattern...',
          subtitle:
              isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
          task: () => PatternRepository().save(PatternChart(
            id: '',
            title: title,
            rows: 0,
            cols: 0,
            mode: ChartMode.narrative,
            grid: const <List<CellData>>[],
            narrativeText: text,
            type: PatternType.chart,
            sourceType: PatternSourceType.external,
          )),
        );
        if (!mounted) return;
        showSavedSnackBar(messenger,
            message: isKorean
                ? '서술형 도안으로 저장됐어요.'
                : 'Saved as narrative pattern.');
        context.push(Routes.toolsPatterns);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e
          .toString()
          .split('\n')
          .first
          .replaceAll(RegExp(r'^\[firebase_functions/[^\]]+\]\s*'), '');
      showSaveErrorSnackBar(messenger, message: msg);
    }
  }

  /// .mori 파일을 별도로 import (PatternExportService 활용 — 파일 피커 경로 우회)
  /// 위 _registerAsPattern에서 직접 처리하므로 별도 호출 불요. (참고용 미사용)

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final supported = dropboxIsPreviewable(widget.entry.name) ||
        dropboxIsImportable(widget.entry.name);
    final canDownload = dropboxIsDownloadable(widget.entry.name);
    final canImport = dropboxIsImportable(widget.entry.name);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.entry.name,
            style: T.h3.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: !supported
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.do_disturb_alt_rounded,
                        color: C.mu, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      isKorean
                          ? '지원하지 않는 형식이에요.'
                          : 'Unsupported file format.',
                      style: T.body.copyWith(color: C.mu),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isKorean
                          ? '지원: PDF, 이미지(jpg/png/webp/gif), .mori, txt, md'
                          : 'Supported: PDF, images, .mori, txt, md',
                      style: T.caption.copyWith(color: C.tx2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kDropboxBlue))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: C.og, size: 40),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: T.caption.copyWith(color: C.og),
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    )
                  : _buildPreview(isKorean),
      bottomNavigationBar: !supported
          ? null
          : SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (canDownload)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _bytes == null ? null : _downloadToDevice,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(isKorean ? '다운로드' : 'Download'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: _kDropboxBlue,
                            side: const BorderSide(color: _kDropboxBlue),
                          ),
                        ),
                      ),
                    if (canDownload && canImport)
                      const SizedBox(width: 10),
                    if (canImport)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _bytes == null ? null : _registerAsPattern,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label:
                              Text(isKorean ? '도안으로 등록' : 'Add as pattern'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: C.lv,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPreview(bool isKorean) {
    if (_isImage) {
      return InteractiveViewer(
        child: Center(
          child: _bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.contain)
              : const SizedBox.shrink(),
        ),
      );
    }
    if (_isPdf) {
      if (kIsWeb) {
        // 웹은 PDFView 미지원 — 다운로드 안내
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_rounded,
                    color: const Color(0xFFE53935), size: 56),
                const SizedBox(height: 12),
                Text(
                  isKorean
                      ? '웹 브라우저에서는 PDF 미리보기를 지원하지 않아요.\n다운로드 후 보거나 도안으로 등록해 주세요.'
                      : 'PDF preview is not available on web.\nDownload or register as pattern.',
                  style: T.body.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      if (_pdfPath == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return PDFView(filePath: _pdfPath);
    }
    if (_isMori || _isText) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _textContent ?? '',
          style: T.caption.copyWith(
            fontFamily: 'monospace',
            color: C.tx,
            height: 1.5,
            fontSize: 12,
          ),
        ),
      );
    }
    return Center(
      child: Text(
        isKorean ? '미리보기를 표시할 수 없어요.' : 'No preview available.',
        style: T.body.copyWith(color: C.mu),
      ),
    );
  }
}
