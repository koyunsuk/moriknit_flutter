// 이슈 #782 — 도안 명시적 '오프라인 보관' 버튼.
//
// 사용 예:
// ```dart
// OfflineDownloadButton(
//   patternId: pattern.id,
//   sourceUrl: pattern.pdfUrl,  // 또는 imageUrl
//   kind: 'pdf',
//   isKorean: true,
// )
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/pattern_offline_repository.dart';

class OfflineDownloadButton extends ConsumerStatefulWidget {
  final String patternId;
  final String sourceUrl;
  final String kind; // 'pdf' | 'image'
  final bool isKorean;

  const OfflineDownloadButton({
    super.key,
    required this.patternId,
    required this.sourceUrl,
    required this.kind,
    required this.isKorean,
  });

  @override
  ConsumerState<OfflineDownloadButton> createState() =>
      _OfflineDownloadButtonState();
}

class _OfflineDownloadButtonState extends ConsumerState<OfflineDownloadButton> {
  bool _downloading = false;
  double _progress = -1.0;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = -1.0;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final isKorean = widget.isKorean;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '오프라인 보관 중입니다.' : 'Saving for offline...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          await ref.read(patternOfflineRepositoryProvider).download(
                patternId: widget.patternId,
                url: widget.sourceUrl,
                kind: widget.kind,
                onProgress: (p) {
                  if (mounted) setState(() => _progress = p);
                },
              );
        },
      );
      if (!mounted) return;
      ref.invalidate(patternOfflineEntryProvider(widget.patternId));
      showSavedSnackBar(messenger,
          message: isKorean ? '오프라인에 보관됐어요.' : 'Saved for offline.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger,
          message: widget.isKorean ? '다운로드 실패: $e' : 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmRemove() async {
    final isKorean = widget.isKorean;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '오프라인 보관 해제' : 'Remove offline'),
        content: Text(isKorean
            ? '이 도안을 오프라인 보관에서 해제할까요? 인터넷 연결 없이 열 수 없게 됩니다.'
            : 'Remove from offline? You will need internet to open.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '해제' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(patternOfflineRepositoryProvider).remove(widget.patternId);
    if (!mounted) return;
    ref.invalidate(patternOfflineEntryProvider(widget.patternId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.isKorean ? '오프라인 보관에서 해제됐어요.' : 'Removed.'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(patternOfflineEntryProvider(widget.patternId));
    final isKorean = widget.isKorean;

    return entryAsync.when(
      loading: () => IconButton(
        icon: Icon(Icons.cloud_outlined, color: C.mu),
        onPressed: null,
      ),
      error: (_, _) => IconButton(
        icon: Icon(Icons.cloud_outlined, color: C.mu),
        onPressed: _download,
        tooltip: isKorean ? '오프라인 보관' : 'Save offline',
      ),
      data: (entry) {
        if (_downloading) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: _progress >= 0 ? _progress : null,
                  color: C.lv,
                ),
              ),
            ),
          );
        }
        final downloaded = entry != null;
        return GestureDetector(
          onLongPress: downloaded ? _confirmRemove : null,
          child: IconButton(
            icon: Icon(
              downloaded ? Icons.cloud_done_rounded : Icons.cloud_download_outlined,
              color: downloaded ? C.lmD : C.lvD,
            ),
            onPressed: downloaded ? _confirmRemove : _download,
            tooltip: downloaded
                ? (isKorean ? '오프라인 보관됨 (길게 누름: 해제)' : 'Saved offline (long press to remove)')
                : (isKorean ? '오프라인 보관' : 'Save for offline'),
          ),
        );
      },
    );
  }
}
