// lib/features/file_explorer/presentation/file_explorer_screen.dart
//
// 이슈 #660 Phase 2 — 도구함 파일 탐색기.
// 외부 PDF/이미지를 모리니트 도안 라이브러리로 가져오기.
// 모바일: 로컬 파일 선택. 웹: 외부 클라우드(Dropbox 등) 연결 안내.

import 'dart:io';

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
import '../../pattern/data/pattern_repository.dart';

class FileExplorerScreen extends ConsumerStatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  ConsumerState<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends ConsumerState<FileExplorerScreen> {
  // 모바일 — File 객체 사용
  final List<File> _selected = [];
  // 이슈 #683 — 웹 — PlatformFile(bytes 포함) 사용
  final List<PlatformFile> _selectedWeb = [];
  int _imported = 0;
  bool _busy = false;
  String? _error;

  int get _selectedCount => kIsWeb ? _selectedWeb.length : _selected.length;
  bool get _hasSelection => _selectedCount > 0;

  Future<void> _pickFiles(bool isKorean) async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    if (kIsWeb) {
      // 웹 — bytes 보유 항목만 수집
      final webEntries = result.files.where((f) => f.bytes != null).toList();
      setState(() {
        _selectedWeb
          ..clear()
          ..addAll(webEntries);
        _selected.clear();
        _imported = 0;
      });
    } else {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      setState(() {
        _selected
          ..clear()
          ..addAll(files);
        _selectedWeb.clear();
        _imported = 0;
      });
    }
  }

  Future<void> _importAll(bool isKorean) async {
    if (kIsWeb) {
      if (_selectedWeb.isEmpty) return;
      setState(() {
        _busy = true;
        _imported = 0;
        _error = null;
      });
      try {
        final repo = ref.read(patternRepositoryProvider);
        for (final pf in _selectedWeb) {
          final ext = pf.name.contains('.') ? pf.name.split('.').last.toLowerCase() : '';
          final title = pf.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          if (ext == 'pdf') {
            await repo.savePdfPatternFromBytes(
              title: title,
              bytes: pf.bytes!,
              fileName: pf.name,
            );
          } else {
            await repo.saveImagePatternFromBytes(
              title: title,
              bytes: pf.bytes!,
              fileName: pf.name,
            );
          }
          if (!mounted) return;
          setState(() => _imported++);
        }
        if (!mounted) return;
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean
              ? '$_imported개 파일을 도안 라이브러리에 추가했어요.'
              : 'Added $_imported files to library.',
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // 모바일 (기존 코드 보존)
    if (_selected.isEmpty) return;
    setState(() {
      _busy = true;
      _imported = 0;
      _error = null;
    });
    try {
      final repo = ref.read(patternRepositoryProvider);
      for (final file in _selected) {
        final ext = file.path.split('.').last.toLowerCase();
        final base = file.path.split(Platform.pathSeparator).last;
        final title = base.replaceAll(RegExp(r'\.[^.]+$'), '');
        if (ext == 'pdf') {
          await repo.savePdfPattern(title: title, pdfFile: file);
        } else {
          await repo.saveImagePattern(title: title, imageFile: file);
        }
        if (!mounted) return;
        setState(() => _imported++);
      }
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean
            ? '$_imported개 파일을 도안 라이브러리에 추가했어요.'
            : 'Added $_imported files to library.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _iconFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    return Icons.image_rounded;
  }

  Color _colorFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'pdf') return C.og;
    return C.lv;
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Scaffold(
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '파일 탐색기' : 'File Explorer',
                    subtitle: isKorean
                        ? '외부 파일을 도안 라이브러리로 가져와요'
                        : 'Import external files into the pattern library',
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
                        onPressed: () => Navigator.pop(context),
                        tooltip: isKorean ? '뒤로' : 'Back',
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(isKorean)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !_hasSelection
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _importAll(isKorean),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      _busy
                          ? (isKorean ? '$_imported / $_selectedCount 처리 중...' : 'Processing $_imported / $_selectedCount...')
                          : (isKorean ? '$_selectedCount개 라이브러리에 추가' : 'Add $_selectedCount to library'),
                      style: T.bodyBold.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(bool isKorean) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 외부 클라우드 카드 — 모든 환경(모바일/웹) 공통.
          _buildCloudCard(
            isKorean: isKorean,
            icon: Icons.cloud_outlined,
            iconAsset: 'assets/cloud_icons/dropbox.png',
            color: const Color(0xFF0061FF),
            title: 'Dropbox',
            description: isKorean
                ? '드롭박스에 저장된 PDF·이미지 도안 가져오기'
                : 'Import PDF/image patterns from Dropbox',
            onTap: () => context.push(Routes.dropboxExplorer),
          ),
          const SizedBox(height: 10),
          // 이슈 #703 — 외부 클라우드 확장 (Google Drive·iCloud·OneDrive)
          _buildCloudCard(
            isKorean: isKorean,
            icon: Icons.cloud_outlined,
            iconAsset: 'assets/cloud_icons/google_drive.png',
            color: const Color(0xFF1A73E8),
            title: 'Google Drive',
            description: isKorean
                ? 'Google 드라이브에 저장된 PDF·이미지 도안 가져오기'
                : 'Import PDF/image patterns from Google Drive',
            onTap: () => context.push(Routes.googleDrive),
          ),
          const SizedBox(height: 10),
          _buildCloudCard(
            isKorean: isKorean,
            icon: Icons.cloud_outlined,
            iconAsset: 'assets/cloud_icons/icloud.png',
            color: const Color(0xFF1D1D1F),
            title: 'iCloud Drive',
            description: isKorean
                ? 'iCloud에 저장된 PDF·이미지 도안 가져오기 (iOS 전용)'
                : 'Import PDF/image patterns from iCloud (iOS only)',
            onTap: () => context.push(Routes.iCloud),
          ),
          const SizedBox(height: 10),
          _buildCloudCard(
            isKorean: isKorean,
            icon: Icons.cloud_outlined,
            iconAsset: 'assets/cloud_icons/onedrive.png',
            color: const Color(0xFF0078D4),
            title: 'OneDrive',
            description: isKorean
                ? 'OneDrive에 저장된 PDF·이미지 도안 가져오기'
                : 'Import PDF/image patterns from OneDrive',
            onTap: () => context.push(Routes.oneDrive),
          ),
          const SizedBox(height: 14),
          // 로컬 파일 안내 카드
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: C.lv, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKorean ? '외부 파일 한번에 가져오기' : 'Import multiple files',
                        style: T.bodyBold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isKorean
                      ? '폰에 받아둔 PDF·이미지 도안을 여러 개 한꺼번에 모리니트 도안 라이브러리로 옮겨요.\n• 다운로드 폴더, 사진, Drive, Dropbox 어디서나 선택 가능\n• PDF는 자동 커버 추출\n• 이미지는 즉시 라이브러리 추가'
                      : 'Pick multiple PDFs/images from anywhere on your phone (Downloads, Photos, Drive, Dropbox). PDFs get auto cover extraction.',
                  style: T.caption.copyWith(color: C.mu),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _pickFiles(isKorean),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      isKorean ? '파일 선택하기' : 'Choose files',
                      style: T.bodyBold.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lvD,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.og.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: C.og, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: T.caption.copyWith(color: C.og))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // 선택된 파일 목록 (이슈 #683 — kIsWeb 분기)
          if (!_hasSelection)
            _buildEmptyPlaceholder(isKorean)
          else if (kIsWeb)
            ..._selectedWeb.asMap().entries.map((entry) {
              final i = entry.key;
              final pf = entry.value;
              final imported = _busy && i < _imported;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colorFor(pf.name).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(pf.name), color: _colorFor(pf.name), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pf.name, style: T.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(_humanSize(pf.size), style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (imported)
                        Icon(Icons.check_circle_rounded, color: C.lv, size: 22)
                      else if (!_busy)
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: C.mu, size: 20),
                          onPressed: () => setState(() => _selectedWeb.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              );
            })
          else
            ..._selected.asMap().entries.map((entry) {
              final i = entry.key;
              final file = entry.value;
              final stat = file.statSync();
              final base = file.path.split(Platform.pathSeparator).last;
              final imported = _busy && i < _imported;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colorFor(file.path).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(file.path), color: _colorFor(file.path), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(base, style: T.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(_humanSize(stat.size), style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (imported)
                        Icon(Icons.check_circle_rounded, color: C.lv, size: 22)
                      else if (!_busy)
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: C.mu, size: 20),
                          onPressed: () => setState(() => _selected.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// 외부 클라우드 진입 카드 (Dropbox 등). 모바일/웹 공통.
  /// [iconAsset] — 브랜드 PNG 경로. 없거나 로드 실패 시 [icon]으로 fallback.
  Widget _buildCloudCard({
    required bool isKorean,
    required IconData icon,
    String? iconAsset,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: iconAsset != null
                ? Image.asset(
                    iconAsset,
                    width: 26,
                    height: 26,
                    errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 22),
                  )
                : Icon(icon, color: color, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.bodyBold),
              const SizedBox(height: 2),
              Text(description, style: T.caption.copyWith(color: C.mu)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
      ]),
    );
  }

  Widget _buildEmptyPlaceholder(bool isKorean) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: C.mu),
          const SizedBox(height: 8),
          Text(
            isKorean ? '아직 선택한 파일이 없어요' : 'No files selected yet',
            style: T.body.copyWith(color: C.mu),
          ),
          const SizedBox(height: 4),
          Text(
            isKorean
                ? '위 "파일 선택하기" 버튼을 눌러 시작해요'
                : 'Tap "Choose files" above to begin',
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ),
    );
  }
}
