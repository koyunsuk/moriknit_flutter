import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/dropbox_provider.dart';
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
    required this.isKorean,
  });

  final String path;
  final String displayPath;
  final bool canGoUp;
  final void Function(String path) onEnterFolder;
  final VoidCallback onGoUp;
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
                      onTap: entries[i].isFolder ? () => onEnterFolder(entries[i].path) : null,
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
                    Text(e.toString(), style: T.caption.copyWith(color: C.og), textAlign: TextAlign.center),
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
    if (entry.isFolder) return const Color(0xFF4A90E2);
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
