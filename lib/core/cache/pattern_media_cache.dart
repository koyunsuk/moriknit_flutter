// lib/core/cache/pattern_media_cache.dart
//
// #704 Phase 2 — 도안 이미지/PDF 로컬 캐시.
// 본 적 있는 도안의 미디어를 디바이스에 저장해서 오프라인에서도 표시.
// 웹은 SDK 자체 캐시 의존(no-op).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PatternMediaCache {
  PatternMediaCache._();
  static final PatternMediaCache instance = PatternMediaCache._();

  static const _subDir = 'pattern_media';
  static const _timeout = Duration(seconds: 12);

  Directory? _baseDir;

  Future<Directory?> _ensureDir() async {
    if (kIsWeb) return null;
    if (_baseDir != null) return _baseDir;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_subDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _baseDir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  String _sanitizeId(String value) {
    // 파일명 호환을 위한 결정론적 해시 (FNV-1a 32bit — JS 호환).
    // 충돌 위험은 patternId + urlHash 조합으로 완화.
    int hash = 0x811c9dc5;
    const int prime = 0x01000193;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _resolveExt(String type) {
    final t = type.toLowerCase();
    if (t == 'pdf') return 'pdf';
    if (t == 'png') return 'png';
    if (t == 'webp') return 'webp';
    return 'jpg';
  }

  /// 캐시 파일 경로 (존재 여부와 무관).
  Future<File?> _fileFor({
    required String patternId,
    required String url,
    required String type,
  }) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    final safeId = _sanitizeId(patternId);
    final urlHash = _sanitizeId(url).substring(0, 8);
    final ext = _resolveExt(type);
    return File('${dir.path}/${safeId}_$urlHash.$ext');
  }

  /// 이미 캐시된 파일이 있으면 반환. 없으면 다운로드 시도 후 저장.
  /// 오프라인 등 실패 시 캐시본이 있으면 그걸 반환, 없으면 null.
  Future<File?> getOrFetch(
    String url, {
    required String patternId,
    String type = 'jpg',
  }) async {
    if (kIsWeb) return null;
    if (url.isEmpty) return null;

    final file = await _fileFor(patternId: patternId, url: url, type: type);
    if (file == null) return null;

    if (await file.exists()) {
      // 캐시 적중. 빠른 반환.
      return file;
    }

    // 백그라운드/네트워크 다운로드.
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(res.bodyBytes, flush: true);
        return file;
      }
    } catch (_) {
      // 오프라인/타임아웃/실패 — 캐시 없으면 null 반환.
    }
    return null;
  }

  /// 캐시 적중 여부만 빠르게 확인 (다운로드 시도 X).
  Future<File?> peek(
    String url, {
    required String patternId,
    String type = 'jpg',
  }) async {
    if (kIsWeb) return null;
    if (url.isEmpty) return null;
    final file = await _fileFor(patternId: patternId, url: url, type: type);
    if (file == null) return null;
    if (await file.exists()) return file;
    return null;
  }

  /// 특정 도안의 모든 미디어 캐시 제거.
  Future<void> remove(String patternId) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    final prefix = _sanitizeId(patternId);
    try {
      await for (final entry in dir.list()) {
        if (entry is File) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith('${prefix}_')) {
            try {
              await entry.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// 모든 캐시 비우기.
  Future<void> clearAll() async {
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _baseDir = null;
    } catch (_) {}
  }
}
