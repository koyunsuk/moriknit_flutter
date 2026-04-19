import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/dropbox_provider.dart';
import '../../../providers/pattern_library_provider.dart';
import '../../pattern_library/domain/pattern_file.dart';
import '../data/dropbox_auth_provider.dart';
import '../domain/dropbox_file_entry.dart';

const Color _kDropboxBlue = Color(0xFF0061FF);

// ── 파일 목록 프로바이더 (경로 기반) ─────────────────────────────────────────────
final _dropboxFolderProvider = FutureProvider.family<List<DropboxFileEntry>, String>(
  (ref, path) => ref.watch(dropboxApiClientProvider).listFolder(path),
);

// ── 드롭박스 메인 화면 ────────────────────────────────────────────────────────────
class DropboxScreen extends ConsumerStatefulWidget {
  const DropboxScreen({super.key});

  @override
  ConsumerState<DropboxScreen> createState() => _DropboxScreenState();
}

class _DropboxScreenState extends ConsumerState<DropboxScreen> {
  // 폴더 탐색 스택 — 루트는 빈 문자열
  final List<String> _pathStack = [''];

  String get _currentPath => _pathStack.last;

  void _enterFolder(String path) {
    setState(() => _pathStack.add(path));
  }

  void _goUp() {
    if (_pathStack.length > 1) {
      setState(() => _pathStack.removeLast());
    }
  }

  String _displayPath() {
    if (_pathStack.length == 1) return '/';
    return _pathStack.last;
  }

  static String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return '';
  }

  Future<void> _importFile(DropboxFileEntry entry) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final mimeType = _mimeTypeFromName(entry.name);
    if (mimeType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '지원하지 않는 파일 형식이에요. (PDF, JPG, PNG, GIF, WEBP)'
              : 'Unsupported file type. (PDF, JPG, PNG, GIF, WEBP)'),
        ),
      );
      return;
    }

    // 1단계: 다운로드만
    Uint8List bytes;
    try {
      bytes = await runWithMoriLoadingDialog<Uint8List>(
        context,
        message: isKorean ? '파일을 불러오는 중입니다.' : 'Loading file...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(dropboxApiClientProvider).downloadFile(entry.path),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = '$e';
      if (msg.contains('DROPBOX_SCOPE_ERROR')) {
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(
              isKorean ? 'Dropbox 파일 접근 권한 없음' : 'Dropbox File Access Denied',
              style: T.h3,
            ),
            content: Text(
              isKorean
                  ? 'Dropbox 앱의 파일 다운로드 권한이 비활성화되어 있습니다.\n\n'
                      '해결 방법:\n'
                      '1. Dropbox 연결을 해제하세요\n'
                      '2. 다시 연결하여 재인증하세요\n\n'
                      '문제가 계속되면 개발자에게 문의하세요.'
                  : 'Dropbox file download permission is disabled.\n\n'
                      'How to fix:\n'
                      '1. Disconnect Dropbox\n'
                      '2. Reconnect to re-authenticate\n\n'
                      'Contact the developer if the issue persists.',
              style: T.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isKorean ? '닫기' : 'Close'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await ref.read(dropboxAuthProvider.notifier).logout();
                  if (mounted) setState(() => _pathStack..clear()..add(''));
                },
                child: Text(
                  isKorean ? '연결 해제' : 'Disconnect',
                  style: T.body.copyWith(color: C.og, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        return;
      }
      final short = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: short);
      return;
    }

    // 2단계: 뷰어 열기
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DropboxFileViewer(
          bytes: bytes,
          fileName: entry.name,
          mimeType: mimeType,
          dropboxPath: entry.path,
          isKorean: isKorean,
          onSave: (bytes) async {
            await ref.read(patternFileRepositoryProvider).uploadFile(
              bytes: bytes,
              fileName: entry.name,
              mimeType: mimeType,
              source: PatternFileSource.dropbox,
              sourceMeta: {'dropboxPath': entry.path},
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(dropboxAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: 'Dropbox',
                subtitle: auth.isLoggedIn
                    ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                    : (isKorean ? '드롭박스 계정을 연결하세요' : 'Connect your Dropbox account'),
                trailing: auth.isLoggedIn
                    ? [
                        TextButton(
                          onPressed: () async {
                            await ref.read(dropboxAuthProvider.notifier).logout();
                            if (mounted) setState(() => _pathStack..clear()..add(''));
                          },
                          child: Text(
                            isKorean ? '연결 해제' : 'Disconnect',
                            style: T.caption.copyWith(color: C.og),
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            Expanded(
              child: auth.isLoading
                  ? Center(child: CircularProgressIndicator(color: _kDropboxBlue))
                  : auth.isLoggedIn
                      ? _FileBrowser(
                          path: _currentPath,
                          displayPath: _displayPath(),
                          canGoUp: _pathStack.length > 1,
                          onEnterFolder: _enterFolder,
                          onGoUp: _goUp,
                          onFileSelected: _importFile,
                          isKorean: isKorean,
                        )
                      : _ConnectPrompt(isKorean: isKorean),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 연결 전 화면 ─────────────────────────────────────────────────────────────────
class _ConnectPrompt extends ConsumerWidget {
  const _ConnectPrompt({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(dropboxAuthProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kDropboxBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_rounded, color: _kDropboxBlue, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              isKorean ? 'Dropbox를 연결하세요' : 'Connect Dropbox',
              style: T.h3,
            ),
            const SizedBox(height: 10),
            Text(
              isKorean
                  ? 'Dropbox에 저장된 도안 파일을 앱에서 바로 탐색할 수 있어요.'
                  : 'Browse pattern files stored in your Dropbox.',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (auth.error != null) ...[
              Text(auth.error!, style: T.caption.copyWith(color: C.og)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () => ref.read(dropboxAuthProvider.notifier).login(),
                icon: const Icon(Icons.cloud_rounded, size: 20),
                label: Text(isKorean ? 'Dropbox 연결하기' : 'Connect Dropbox'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDropboxBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: T.bodyBold.copyWith(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 파일 브라우저 ─────────────────────────────────────────────────────────────────
class _FileBrowser extends ConsumerWidget {
  const _FileBrowser({
    required this.path,
    required this.displayPath,
    required this.canGoUp,
    required this.onEnterFolder,
    required this.onGoUp,
    required this.onFileSelected,
    required this.isKorean,
  });

  final String path;
  final String displayPath;
  final bool canGoUp;
  final void Function(String path) onEnterFolder;
  final VoidCallback onGoUp;
  final void Function(DropboxFileEntry) onFileSelected;
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_dropboxFolderProvider(path));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경로 표시줄
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kDropboxBlue.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: C.bd)),
          ),
          child: Row(
            children: [
              if (canGoUp) ...[
                GestureDetector(
                  onTap: onGoUp,
                  child: Icon(Icons.arrow_back_ios_rounded, size: 18, color: _kDropboxBlue),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  displayPath,
                  style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: C.mu,
                onPressed: () => ref.invalidate(_dropboxFolderProvider(path)),
                tooltip: isKorean ? '새로고침' : 'Refresh',
              ),
            ],
          ),
        ),
        // 파일 목록
        Expanded(
          child: entriesAsync.when(
            data: (entries) => entries.isEmpty
                ? Center(
                    child: Text(
                      isKorean ? '이 폴더는 비어 있어요.' : 'This folder is empty.',
                      style: T.body.copyWith(color: C.mu),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: C.bd),
                    itemBuilder: (_, i) => _FileRow(
                      entry: entries[i],
                      isKorean: isKorean,
                      onTap: entries[i].isFolder
                          ? () => onEnterFolder(entries[i].path)
                          : () => onFileSelected(entries[i]),
                    ),
                  ),
            loading: () => Center(child: CircularProgressIndicator(color: _kDropboxBlue)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: C.og, size: 40),
                    const SizedBox(height: 12),
                    Text(e.toString(), style: T.caption.copyWith(color: C.og), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(_dropboxFolderProvider(path)),
                      child: Text(isKorean ? '다시 시도' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 파일/폴더 행 ─────────────────────────────────────────────────────────────────
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.isKorean,
    this.onTap,
  });

  final DropboxFileEntry entry;
  final bool isKorean;
  final VoidCallback? onTap;

  String _fileSize() {
    final s = entry.size;
    if (s == null) return '';
    if (s < 1024) return '${s}B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)}KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _icon() {
    if (entry.isFolder) return Icons.folder_rounded;
    final name = entry.name.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor() {
    if (entry.isFolder) return C.pk;
    final name = entry.name.toLowerCase();
    if (name.endsWith('.pdf')) return const Color(0xFFE53935);
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return const Color(0xFF43A047);
    }
    return C.mu;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(_icon(), color: _iconColor(), size: 28),
      title: Text(entry.name, style: T.body.copyWith(fontSize: 14)),
      subtitle: entry.isFolder
          ? Text(isKorean ? '폴더' : 'Folder', style: T.caption.copyWith(color: C.mu))
          : Text(
              [
                _fileSize(),
                if (entry.clientModified != null)
                  '${entry.clientModified!.year}.${entry.clientModified!.month.toString().padLeft(2, '0')}.${entry.clientModified!.day.toString().padLeft(2, '0')}',
              ].where((s) => s.isNotEmpty).join('  ·  '),
              style: T.caption.copyWith(color: C.mu),
            ),
      trailing: entry.isFolder
          ? Icon(Icons.chevron_right_rounded, color: C.mu)
          : null,
    );
  }
}

// ── Dropbox 파일 뷰어 ─────────────────────────────────────────────────────────
class _DropboxFileViewer extends ConsumerStatefulWidget {
  const _DropboxFileViewer({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.dropboxPath,
    required this.isKorean,
    required this.onSave,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String dropboxPath;
  final bool isKorean;
  final Future<void> Function(Uint8List bytes) onSave;

  @override
  ConsumerState<_DropboxFileViewer> createState() => _DropboxFileViewerState();
}

class _DropboxFileViewerState extends ConsumerState<_DropboxFileViewer> {
  String? _pdfPath;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.mimeType == 'application/pdf') {
      _writeTempPdf();
    }
  }

  Future<void> _writeTempPdf() async {
    final tmpDir = await getTemporaryDirectory();
    final safe = widget.fileName.replaceAll(RegExp(r'[^\w가-힣.\-]'), '_');
    final file = File('${tmpDir.path}/$safe');
    await file.writeAsBytes(widget.bytes);
    if (mounted) setState(() => _pdfPath = file.path);
  }

  Future<void> _saveToLibrary() async {
    if (_saved) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => widget.onSave(widget.bytes),
      );
      if (!mounted) return;
      setState(() => _saved = true);
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '도안 라이브러리에 저장됐어요.' : 'Saved to pattern library.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.mimeType == 'application/pdf';

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.fileName, style: T.h3.copyWith(fontSize: 14)),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          if (!_saved)
            TextButton.icon(
              onPressed: _saveToLibrary,
              icon: Icon(Icons.save_alt_rounded, size: 18, color: C.lv),
              label: Text(
                widget.isKorean ? '라이브러리 저장' : 'Save',
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.check_circle_rounded, color: C.lv, size: 22),
            ),
        ],
      ),
      body: isPdf
          ? _pdfPath == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(filePath: _pdfPath!)
          : InteractiveViewer(
              child: Center(
                child: Image.memory(widget.bytes, fit: BoxFit.contain),
              ),
            ),
    );
  }
}
