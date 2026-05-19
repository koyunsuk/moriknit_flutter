import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pattern_library/domain/pattern_file.dart';
import '../../../providers/dropbox_provider.dart';
import '../../../providers/pattern_library_provider.dart';
import 'dropbox_file_service.dart' show dropboxIsImportable;

/// 이슈 #871 — 사용자가 본인 Dropbox uploadFolder 에 **직접 추가**한 PDF/이미지/도안 파일을
/// 모리니트 앱 진입 시점에 자동 발견.
///
/// 단순화 원칙:
/// - **App start polling** 만 사용. 백그라운드 동기화·실시간 push 없음.
/// - 마지막 동기화 시각(`users/{uid}/private/dropbox.lastSyncedAt`) 이후
///   `server_modified` 가 갱신된 파일만 신규로 간주.
/// - 인입 이메일 Cloud Function 이 업로드한 파일은 `^\d{13}_\d+_` prefix 로 구분되어 제외.
///   (인입은 모리니트 라이브러리에 이미 등록되어 있으므로 중복 등록 방지.)
class DropboxNewFile {
  final String path; // Dropbox path_display (예: /모리니트/도안/sweater.pdf)
  final String name; // 파일명
  final DateTime modifiedAt; // server_modified 또는 client_modified
  final int? size; // 바이트 (메타 기준, 다운로드 전)

  const DropboxNewFile({
    required this.path,
    required this.name,
    required this.modifiedAt,
    this.size,
  });
}

/// Dropbox 폴더 폴링 헬퍼.
///
/// `findNewFiles` → [ 신규 파일 메타 리스트 ]
/// `downloadAndImport` → Storage 업로드 + Firestore pattern_files 도큐먼트 생성
/// `updateLastSyncedAt` → Firestore lastSyncedAt 갱신 (성공 직후 호출)
class DropboxFolderSync {
  DropboxFolderSync(this._ref);
  final Ref _ref;

  /// 인입 이메일 Cloud Function 이 저장하는 파일명 패턴
  /// (functions/index.js → `${now}_${i}_${safeName}`).
  /// 13자리 밀리초 timestamp + `_` + 숫자 인덱스 + `_` prefix 면 인입 산출물로 간주.
  static final RegExp _inboundPattern = RegExp(r'^\d{13}_\d+_');

  static bool isFromInboundEmail(String fileName) {
    return _inboundPattern.hasMatch(fileName);
  }

  /// users/{uid}/private/dropbox 도큐먼트 ref.
  /// uid 가 비어있으면 null 반환 (호출측에서 가드).
  DocumentReference<Map<String, dynamic>>? _privateDocRef(String uid) {
    if (uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('dropbox');
  }

  /// 사용자 Dropbox [folder] 내부에서 마지막 동기화 시각([lastSyncedAt]) 이후
  /// 갱신된 import 가능 파일만 골라 반환.
  ///
  /// - 폴더는 재귀 탐색하지 않음 (list_folder recursive=false).
  /// - 인입 이메일 파일은 제외.
  /// - lastSyncedAt 가 null 이면 폴더 내 **현재 모든 import 가능 파일** 을 신규로 간주.
  ///   (첫 동기화 시점에는 사용자가 미리 둔 파일을 자동 등록하지 않도록
  ///    호출측에서 lastSyncedAt 없을 때 등록 대신 baseline 저장만 하도록 처리.)
  Future<List<DropboxNewFile>> findNewFiles({
    required String folder,
    required DateTime? lastSyncedAt,
  }) async {
    final normalized = _normalizeFolderPath(folder);
    if (normalized == null) return const [];

    final client = _ref.read(dropboxApiClientProvider);

    final result = <DropboxNewFile>[];
    String? cursor;
    var hasMore = true;
    // 안전 가드: 페이지가 폭주하지 않도록 최대 10페이지(약 1만 entries)까지만 탐색.
    var safetyPages = 0;
    while (hasMore && safetyPages < 10) {
      final page = await client.listFolderPage(
        path: cursor == null ? normalized : '',
        cursor: cursor,
      );
      for (final entry in page.entries) {
        if (entry.isFolder) continue;
        if (!dropboxIsImportable(entry.name)) continue;
        if (isFromInboundEmail(entry.name)) continue;
        final mtime = entry.clientModified;
        if (lastSyncedAt != null && mtime != null) {
          if (!mtime.isAfter(lastSyncedAt)) continue;
        }
        result.add(DropboxNewFile(
          path: entry.path,
          name: entry.name,
          modifiedAt: mtime ?? DateTime.now(),
          size: entry.size,
        ));
      }
      cursor = page.cursor;
      hasMore = page.hasMore && cursor != null && cursor.isNotEmpty;
      safetyPages += 1;
    }
    return result;
  }

  /// 단일 파일을 Dropbox 에서 받아 모리니트 라이브러리에 등록.
  /// 반환: 생성된 [PatternFile].
  Future<PatternFile> downloadAndImport(DropboxNewFile file) async {
    final client = _ref.read(dropboxApiClientProvider);
    final Uint8List bytes = await client.downloadFile(file.path);
    final mime = _mimeTypeFromName(file.name);
    final repo = _ref.read(patternFileRepositoryProvider);
    return repo.uploadFile(
      bytes: bytes,
      fileName: file.name,
      mimeType: mime,
      source: PatternFileSource.dropbox,
      sourceMeta: {
        'dropboxPath': file.path,
        'autoSync': true,
      },
    );
  }

  /// users/{uid}/private/dropbox.lastSyncedAt 갱신.
  Future<void> updateLastSyncedAt({required String uid}) async {
    final ref = _privateDocRef(uid);
    if (ref == null) return;
    try {
      await ref.set(
        {
          'lastSyncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort.
    }
  }

  /// Dropbox API 는 루트 경로를 빈 문자열 `""` 로, 하위 폴더는 `/모리니트/도안` 처럼
  /// 끝 슬래시 없는 형식을 사용. 사용자는 끝 슬래시가 있는 표기를 입력하므로 보정.
  static String? _normalizeFolderPath(String folder) {
    final trimmed = folder.trim();
    if (trimmed.isEmpty) return null;
    var path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mori') || lower.endsWith('.json')) {
      return 'application/json';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'application/octet-stream';
  }
}

final dropboxFolderSyncProvider = Provider<DropboxFolderSync>(
  (ref) => DropboxFolderSync(ref),
);
