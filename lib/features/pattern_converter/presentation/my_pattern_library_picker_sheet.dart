// 이슈 #860 — 내 도안 라이브러리에서 PDF/이미지 파일을 가져오는 공통 시트.
// 변환기/번역기 두 화면에서 동일하게 호출 가능.
//
// 사용처:
//   - PatternConverterScreen (도안 변환기): 내 도안 → AI 변환
//   - PatternTranslatorScreen (도안 번역기): 내 도안 → AI 번역
//
// 동작:
//   1) `users/{uid}/pattern_charts` 에서 사용자 도안 목록 로드 (patternListProvider)
//   2) pdfUrl 또는 imageUrl 이 있는 도안만 필터링 (변환·번역 가능한 자료 도안)
//   3) 도안 카드 탭 → Storage 다운로드 → bytes/fileName 반환
//
// 반환값: MyPatternPickResult(bytes, fileName)
//   - bytes: 다운로드된 PDF/이미지 원본
//   - fileName: 변환기 mime 추론을 위해 확장자 포함 ("도안제목.pdf" 등)

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';

/// 내 도안 라이브러리에서 선택한 파일 결과.
class MyPatternPickResult {
  final Uint8List bytes;
  final String fileName;
  const MyPatternPickResult({required this.bytes, required this.fileName});
}

/// 내 도안 라이브러리에서 PDF/이미지 도안을 선택하는 공통 시트.
///
/// 반환: 선택 시 [MyPatternPickResult], 취소 시 null.
Future<MyPatternPickResult?> showMyPatternLibraryPickerSheet(
  BuildContext context, {
  required bool isKorean,
}) {
  return showModalBottomSheet<MyPatternPickResult>(
    context: context,
    backgroundColor: C.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MyPatternLibraryPickerSheet(isKorean: isKorean),
  );
}

class _MyPatternLibraryPickerSheet extends ConsumerWidget {
  final bool isKorean;
  const _MyPatternLibraryPickerSheet({required this.isKorean});

  /// PDF/이미지 도안만 통과 (변환·번역 가능한 원본 자료가 있는 도안).
  bool _hasImportableFile(PatternChart c) {
    return c.pdfUrl.isNotEmpty || c.imageUrl.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(patternListProvider);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.bookmark_rounded, color: C.lvD, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isKorean ? '내 도안 라이브러리' : 'My Pattern Library',
                      style: T.h3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: C.mu),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isKorean
                    ? '저장된 PDF/이미지 도안에서 선택하면 다운로드 후 진행돼요.'
                    : 'Pick a saved PDF/image pattern — it downloads then proceeds.',
                style: T.caption.copyWith(color: C.mu, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AsyncDataView<List<PatternChart>>(
                  async: patternsAsync,
                  placeholderRows: 4,
                  rowHeight: 72,
                  loadingHint: isKorean ? '도안 목록을 불러오는 중...' : 'Loading patterns...',
                  isEmpty: (list) => list.where(_hasImportableFile).isEmpty,
                  emptyBuilder: () => EmptyBlockPlaceholder(
                    message: isKorean
                        ? 'PDF/이미지가 첨부된 도안이 없어요.\n도안 라이브러리에서 먼저 등록해 주세요.'
                        : 'No PDF/image patterns yet.\nAdd one in your Pattern Library first.',
                    rows: 3,
                    rowHeight: 60,
                  ),
                  builder: (all) {
                    final list = all.where(_hasImportableFile).toList();
                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _PatternTile(
                        pattern: list[i],
                        isKorean: isKorean,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternTile extends StatefulWidget {
  final PatternChart pattern;
  final bool isKorean;
  const _PatternTile({required this.pattern, required this.isKorean});

  @override
  State<_PatternTile> createState() => _PatternTileState();
}

class _PatternTileState extends State<_PatternTile> {
  bool _loading = false;

  String get _ext {
    if (widget.pattern.pdfUrl.isNotEmpty) return 'pdf';
    final url = widget.pattern.imageUrl.toLowerCase();
    if (url.contains('.png')) return 'png';
    return 'jpg';
  }

  String get _label =>
      _ext == 'pdf' ? 'PDF' : (_ext == 'png' ? 'PNG' : 'JPG');

  IconData get _icon => _ext == 'pdf'
      ? Icons.picture_as_pdf_rounded
      : Icons.image_rounded;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await _download(widget.pattern);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isKorean
                ? '파일을 불러오지 못했어요: $e'
                : 'Failed to load file: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// pdfUrl 우선, 없으면 imageUrl. Storage 상대경로면 getDownloadURL로 해석.
  Future<MyPatternPickResult> _download(PatternChart c) async {
    final hasPdf = c.pdfUrl.isNotEmpty;
    final raw = hasPdf ? c.pdfUrl : c.imageUrl;

    String resolved = raw;
    if (!raw.startsWith('http')) {
      // Storage 상대경로 → 다운로드 URL.
      // 도안 라이브러리 저장 시 'users/{uid}/...' 형태로 들어올 수 있음.
      resolved = await FirebaseStorage.instance.ref(raw).getDownloadURL();
    }

    final res = await http.get(Uri.parse(resolved));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final bytes = res.bodyBytes;

    // 파일명: 도안 제목 + 확장자. 제목에 부적절 문자 제거.
    final safeTitle = (c.title.isEmpty ? 'pattern' : c.title)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final fileName = '$safeTitle.$_ext';
    return MyPatternPickResult(bytes: bytes, fileName: fileName);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.pattern;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.gx,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.bd),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.lvL,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: C.lvD, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title.isEmpty
                          ? (widget.isKorean ? '제목 없음' : 'Untitled')
                          : c.title,
                      style: T.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        MoriChip(label: _label),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _formatUpdatedAt(c.createdAt, widget.isKorean),
                            style: T.caption.copyWith(color: C.mu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: C.lv),
                )
              else
                Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUpdatedAt(DateTime? dt, bool isKorean) {
    if (dt == null) return '';
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return isKorean ? '$y.$m.$d' : '$y-$m-$d';
  }
}

