import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/dropbox_provider.dart';
import 'dropbox_download_helper.dart'
    if (dart.library.io) 'dropbox_download_helper_io.dart'
    if (dart.library.html) 'dropbox_download_helper_web.dart';

/// 이슈 #654 — Dropbox 파일 다운로드/저장 헬퍼.
///
/// 모바일/데스크톱: 임시 디렉토리에 저장 후 share_plus 시트로 사용자 위치 선택.
/// 웹: HTML anchor 다운로드 트리거.
class DropboxFileService {
  DropboxFileService(this._ref);
  final Ref _ref;

  /// Dropbox에서 바이트 다운로드 (재사용)
  Future<Uint8List> downloadBytes(String dropboxPath) {
    return _ref.read(dropboxApiClientProvider).downloadFile(dropboxPath);
  }

  /// 다운로드 + 사용자가 디바이스에 저장.
  /// - 웹: 브라우저 다운로드 트리거
  /// - 모바일/데스크톱: 임시 파일 + share_plus (사용자가 위치 선택)
  Future<void> downloadAndSave({
    required String dropboxPath,
    required String fileName,
  }) async {
    final bytes = await downloadBytes(dropboxPath);
    await saveBytesToDevice(bytes: bytes, fileName: fileName);
  }

  /// 이미 다운로드한 bytes를 디바이스에 저장.
  Future<void> saveBytesToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final safe = _sanitizeFileName(fileName);
    if (kIsWeb) {
      // 웹: 브라우저 다운로드
      triggerWebDownload(bytes, safe, _mimeTypeFromName(safe));
      return;
    }

    // 모바일/데스크톱: 임시 파일 작성 후 시스템 공유 시트로 저장 위치 선택
    final tmpDir = await getTemporaryDirectory();
    final file = File('${tmpDir.path}/$safe');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeTypeFromName(safe))],
        text: safe,
      ),
    );
  }

  static String _sanitizeFileName(String input) {
    final cleaned = input.trim().isEmpty ? 'dropbox_file' : input.trim();
    return cleaned.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mori') || lower.endsWith('.json')) {
      return 'application/json';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'application/octet-stream';
  }
}

final dropboxFileServiceProvider = Provider<DropboxFileService>(
  (ref) => DropboxFileService(ref),
);

// ── 화이트리스트 헬퍼 ──────────────────────────────────────────────────────────

/// 미리보기 가능 형식
const dropboxPreviewableExtensions = {
  'jpg', 'jpeg', 'png', 'webp', 'gif',
  'pdf',
  'mori', 'json',
  'txt', 'md',
};

/// 다운로드 가능 형식 (미리보기와 동일)
const dropboxDownloadableExtensions = dropboxPreviewableExtensions;

/// 도안 등록(import) 가능 형식
const dropboxImportableExtensions = {
  'jpg', 'jpeg', 'png', 'webp',
  'pdf',
  'mori', 'json',
  'txt', 'md',
};

String dropboxFileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot >= name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

bool dropboxIsPreviewable(String name) =>
    dropboxPreviewableExtensions.contains(dropboxFileExtension(name));

bool dropboxIsDownloadable(String name) =>
    dropboxDownloadableExtensions.contains(dropboxFileExtension(name));

bool dropboxIsImportable(String name) =>
    dropboxImportableExtensions.contains(dropboxFileExtension(name));
