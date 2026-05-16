import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/dropbox_provider.dart';
import '../data/dropbox_auth_provider.dart';
import '../data/dropbox_favorites_repository.dart';
import '../data/dropbox_file_service.dart';
import '../domain/dropbox_file_entry.dart';
import 'dropbox_preview_screen.dart';

const Color _kDropboxBlue = Color(0xFF0061FF);

/// 이슈 #654 — Dropbox 탐색기 화면.
///
/// 폴더 트리 탐색 + 페이지네이션 + 즐겨찾기 + 형식별 미리보기 진입.
class DropboxExplorerScreen extends ConsumerStatefulWidget {
  const DropboxExplorerScreen({super.key});

  @override
  ConsumerState<DropboxExplorerScreen> createState() =>
      _DropboxExplorerScreenState();
}

class _DropboxExplorerScreenState
    extends ConsumerState<DropboxExplorerScreen> {
  final List<String> _pathStack = [''];
  String get _currentPath => _pathStack.last;

  // 페이지네이션 상태 (현재 폴더 한정)
  String? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  List<DropboxFileEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries = const [];
      _cursor = null;
      _hasMore = false;
    });
    try {
      final page = await ref
          .read(dropboxApiClientProvider)
          .listFolderPage(path: _currentPath);
      if (!mounted) return;
      setState(() {
        _entries = page.entries;
        _cursor = page.cursor;
        _hasMore = page.hasMore;
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

  Future<void> _loadMore() async {
    if (!_hasMore || _cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(dropboxApiClientProvider)
          .listFolderPage(path: _currentPath, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...page.entries];
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _enterFolder(String path) {
    setState(() => _pathStack.add(path));
    _reload();
  }

  void _goUp() {
    if (_pathStack.length > 1) {
      setState(() => _pathStack.removeLast());
      _reload();
    }
  }

  Future<void> _toggleFavorite(DropboxFileEntry entry) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await ref
          .read(dropboxFavoritesRepositoryProvider)
          .toggle(dropboxPath: entry.path, name: entry.name);
      if (!mounted) return;
      showSavedSnackBar(
        messenger,
        message: added
            ? (isKorean ? '즐겨찾기에 추가했어요.' : 'Added to favorites.')
            : (isKorean ? '즐겨찾기에서 제거했어요.' : 'Removed from favorites.'),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  void _openPreview(DropboxFileEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DropboxPreviewScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(dropboxAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final favoritesAsync = ref.watch(dropboxFavoritePathsProvider);
    final favorites = favoritesAsync.maybeWhen(
      data: (set) => set,
      orElse: () => const <String>{},
    );

    final displayPath = _pathStack.length == 1 ? '/' : _currentPath;

    return AppShellScaffold(
      showBgOrbs: false,
      useSafeArea: false,
      title: isKorean ? 'Dropbox 탐색기' : 'Dropbox Explorer',
      subtitle: displayPath,
      trailing: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          tooltip: isKorean ? '뒤로' : 'Back',
          onPressed: () {
            if (_pathStack.length > 1) {
              _goUp();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          color: C.mu,
          tooltip: isKorean ? '새로고침' : 'Refresh',
          onPressed: _loading ? null : _reload,
        ),
      ],
      body: !auth.isLoggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isKorean
                      ? 'Dropbox 연결 후 이용할 수 있어요.'
                      : 'Please connect Dropbox first.',
                  style: T.body.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
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
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _reload,
                              child: Text(isKorean ? '다시 시도' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            isKorean
                                ? '이 폴더는 비어 있어요.'
                                : 'This folder is empty.',
                            style: T.body.copyWith(color: C.mu),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notif) {
                            if (notif is ScrollEndNotification &&
                                notif.metrics.pixels >=
                                    notif.metrics.maxScrollExtent - 80) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount:
                                _entries.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: C.bd),
                            itemBuilder: (_, i) {
                              if (i == _entries.length) {
                                // 페이지네이션 로딩 인디케이터
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: _loadingMore
                                        ? CircularProgressIndicator(
                                            color: _kDropboxBlue,
                                            strokeWidth: 2)
                                        : TextButton(
                                            onPressed: _loadMore,
                                            child: Text(isKorean
                                                ? '더 불러오기'
                                                : 'Load more'),
                                          ),
                                  ),
                                );
                              }
                              final e = _entries[i];
                              final isFav = favorites.contains(e.path);
                              return _ExplorerRow(
                                entry: e,
                                isFavorite: isFav,
                                isKorean: isKorean,
                                onTap: e.isFolder
                                    ? () => _enterFolder(e.path)
                                    : dropboxIsPreviewable(e.name) ||
                                            dropboxIsImportable(e.name)
                                        ? () => _openPreview(e)
                                        : null,
                                onFavoriteTap: () => _toggleFavorite(e),
                              );
                            },
                          ),
                        ),
    );
  }
}

class _ExplorerRow extends StatelessWidget {
  const _ExplorerRow({
    required this.entry,
    required this.isFavorite,
    required this.isKorean,
    this.onTap,
    required this.onFavoriteTap,
  });

  final DropboxFileEntry entry;
  final bool isFavorite;
  final bool isKorean;
  final VoidCallback? onTap;
  final VoidCallback onFavoriteTap;

  String _fileSize() {
    final s = entry.size;
    if (s == null) return '';
    if (s < 1024) return '${s}B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)}KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _icon() {
    if (entry.isFolder) return Icons.folder_rounded;
    final ext = dropboxFileExtension(entry.name);
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if ({'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext)) {
      return Icons.image_rounded;
    }
    if (ext == 'mori' || ext == 'json') return Icons.code_rounded;
    if (ext == 'txt' || ext == 'md') return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor() {
    if (entry.isFolder) return C.pk;
    final ext = dropboxFileExtension(entry.name);
    if (ext == 'pdf') return const Color(0xFFE53935);
    if ({'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext)) {
      return const Color(0xFF43A047);
    }
    if (ext == 'mori' || ext == 'json') return _kDropboxBlue;
    if (ext == 'txt' || ext == 'md') return C.lvD;
    return C.mu;
  }

  @override
  Widget build(BuildContext context) {
    final supported = entry.isFolder ||
        dropboxIsPreviewable(entry.name) ||
        dropboxIsImportable(entry.name);

    String? formatLabel;
    if (!entry.isFolder) {
      final ext = dropboxFileExtension(entry.name);
      if (ext.isNotEmpty) formatLabel = ext.toUpperCase();
    }

    return ListTile(
      enabled: onTap != null,
      onTap: onTap,
      leading: Icon(_icon(), color: _iconColor(), size: 28),
      title: Text(
        entry.name,
        style: T.body.copyWith(
          fontSize: 14,
          color: supported ? C.tx : C.mu,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: entry.isFolder
          ? Text(isKorean ? '폴더' : 'Folder',
              style: T.caption.copyWith(color: C.mu))
          : Text(
              [
                ?formatLabel,
                _fileSize(),
                if (entry.clientModified != null)
                  '${entry.clientModified!.year}.${entry.clientModified!.month.toString().padLeft(2, '0')}.${entry.clientModified!.day.toString().padLeft(2, '0')}',
                if (!supported)
                  isKorean ? '지원하지 않는 형식' : 'Unsupported',
              ].where((s) => s.isNotEmpty).join('  ·  '),
              style: T.caption.copyWith(color: C.mu),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!entry.isFolder)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFavorite ? const Color(0xFFFFB300) : C.mu,
                size: 22,
              ),
              tooltip: isKorean ? '즐겨찾기' : 'Favorite',
              onPressed: onFavoriteTap,
            ),
          if (entry.isFolder)
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}
