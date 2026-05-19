// 이슈 #782 — 도안 오프라인 영구 캐시 (PDF/이미지).
//
// 영구 저장 위치: `getApplicationDocumentsDirectory() + '/offline_patterns/{patternId}{ext}'`
// 메타 저장: Hive `offline_patterns` box → {patternId: {path, downloadedAt, sizeBytes, kind}}
//
// 사용자가 명시적으로 "오프라인 보관" 버튼을 눌렀을 때만 영구 저장.
// 임시 캐시(temp)와 별개 — 임시 캐시는 OS가 삭제할 수 있지만 이건 안전.

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OfflinePatternEntry {
  final String patternId;
  final String localPath;
  final DateTime downloadedAt;
  final int sizeBytes;
  final String kind; // 'pdf' | 'image'
  // #838 — 도안 카드 썸네일 영구 캐시 경로. 본 파일과 별개로 저장되어
  // 오프라인에서 라이브러리/홈 카드 썸네일을 즉시 보여주기 위함.
  // 옛 entry(빈 값) 호환: nullable / 빈 문자열 가능.
  final String thumbnailPath;
  final int thumbnailBytes;

  const OfflinePatternEntry({
    required this.patternId,
    required this.localPath,
    required this.downloadedAt,
    required this.sizeBytes,
    required this.kind,
    this.thumbnailPath = '',
    this.thumbnailBytes = 0,
  });

  Map<String, dynamic> toMap() => {
        'localPath': localPath,
        'downloadedAt': downloadedAt.millisecondsSinceEpoch,
        'sizeBytes': sizeBytes,
        'kind': kind,
        'thumbnailPath': thumbnailPath,
        'thumbnailBytes': thumbnailBytes,
      };

  factory OfflinePatternEntry.fromMap(String patternId, Map raw) {
    return OfflinePatternEntry(
      patternId: patternId,
      localPath: raw['localPath'] as String? ?? '',
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        raw['downloadedAt'] as int? ?? 0,
      ),
      sizeBytes: raw['sizeBytes'] as int? ?? 0,
      kind: raw['kind'] as String? ?? 'pdf',
      thumbnailPath: raw['thumbnailPath'] as String? ?? '',
      thumbnailBytes: raw['thumbnailBytes'] as int? ?? 0,
    );
  }
}

class PatternOfflineRepository {
  static const _boxName = 'offline_patterns';

  Future<Box<Map>> _box() => Hive.openBox<Map>(_boxName);

  /// 다운로드된 도안 메타 조회.
  Future<OfflinePatternEntry?> get(String patternId) async {
    if (kIsWeb) return null;
    try {
      final box = await _box();
      final raw = box.get(patternId);
      if (raw == null) return null;
      final entry = OfflinePatternEntry.fromMap(patternId, raw);
      // 파일 실제 존재 확인 — 없으면 메타도 정리
      final file = File(entry.localPath);
      if (!await file.exists()) {
        await box.delete(patternId);
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// URL에서 영구 캐시로 다운로드 + 메타 저장.
  /// onProgress: 진행률 0.0~1.0 (Content-Length 헤더 없으면 -1 전달).
  ///
  /// #832 fix: 2회차 이상 다운로드 안전 처리.
  /// - HTTP statusCode 검증 (4xx/5xx는 즉시 에러 throw)
  /// - 기존 파일이 있으면 .tmp 로 먼저 받고 성공 후 swap (중간 실패해도 기존 파일 보존)
  /// - http.Client 명시 close (connection pool leak 방지)
  /// - sink 실패 시 finally 에서 안전 close + 부분 파일 정리
  ///
  /// #838 — [thumbnailUrl] 함께 다운로드해 영구 캐시. 본 파일과 별개로
  /// 도안 카드 썸네일 즉시 표시용. 실패해도 본 다운로드는 성공으로 처리.
  Future<OfflinePatternEntry> download({
    required String patternId,
    required String url,
    required String kind,
    String? thumbnailUrl,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web does not support offline pattern cache.');
    }
    if (url.isEmpty) {
      throw ArgumentError('Download URL is empty (patternId=$patternId).');
    }
    // #832 fix — pdfUrl/imageUrl 필드에 절대 URL 대신 Storage path("users/{uid}/...")
    //   가 저장된 옛 도안 케이스 방어. http(s):// 가 아니면 Storage path로 간주하고
    //   download URL을 만들어 사용.
    final resolvedUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : await FirebaseStorage.instance.ref(url).getDownloadURL();
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/offline_patterns');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    final ext = kind == 'pdf' ? 'pdf' : 'jpg';
    final finalFile = File('${offlineDir.path}/$patternId.$ext');
    final tmpFile = File('${offlineDir.path}/$patternId.$ext.tmp');

    // 직전에 실패해서 남은 .tmp 파일이 있으면 정리.
    if (await tmpFile.exists()) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }

    final client = http.Client();
    IOSink? sink;
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(resolvedUrl)));
      // 4xx/5xx 응답을 파일에 쓰면 다음번 file.exists() 가 true 라서
      // "다운로드된 것처럼" 보이지만 실제로는 에러 본문이 들어있음.
      // → 명시적 throw 로 호출 측에 노출.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(resolvedUrl),
        );
      }
      final total = response.contentLength ?? -1;
      sink = tmpFile.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null) {
          onProgress(total > 0 ? received / total : -1.0);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      // 다운로드 성공 → 기존 최종 파일 제거 후 .tmp 를 최종 경로로 이동.
      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {
          // 삭제 실패해도 rename 으로 덮어쓰기 시도.
        }
      }
      await tmpFile.rename(finalFile.path);

      final size = await finalFile.length();

      // #838 — 썸네일 함께 캐시 (선택, 실패해도 본 다운로드는 성공으로 인정).
      String thumbPath = '';
      int thumbBytes = 0;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        try {
          // 본 파일이 image 면 본 파일이 곧 썸네일 → 별도 다운로드 생략.
          if (kind == 'image' && thumbnailUrl == url) {
            thumbPath = finalFile.path;
            thumbBytes = size;
          } else {
            final cached = await _downloadThumbnail(
              patternId: patternId,
              url: thumbnailUrl,
              offlineDir: offlineDir,
            );
            if (cached != null) {
              thumbPath = cached.path;
              thumbBytes = await cached.length();
            }
          }
        } catch (_) {
          // 썸네일 실패는 무시. 본 다운로드 성공으로 처리.
        }
      }

      final entry = OfflinePatternEntry(
        patternId: patternId,
        localPath: finalFile.path,
        downloadedAt: DateTime.now(),
        sizeBytes: size,
        kind: kind,
        thumbnailPath: thumbPath,
        thumbnailBytes: thumbBytes,
      );
      final box = await _box();
      await box.put(patternId, entry.toMap());
      return entry;
    } catch (_) {
      // 실패 시 .tmp 정리 (기존 최종 파일은 보존됨).
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// #838 — 썸네일 영구 캐시 다운로드 (본 파일과 별개).
  /// `{offlineDir}/{patternId}.thumb.jpg` 로 저장. 실패 시 null.
  /// 본 다운로드 흐름과 동일하게 .tmp swap 패턴 사용.
  Future<File?> _downloadThumbnail({
    required String patternId,
    required String url,
    required Directory offlineDir,
  }) async {
    final resolvedUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : await FirebaseStorage.instance.ref(url).getDownloadURL();
    final finalFile = File('${offlineDir.path}/$patternId.thumb.jpg');
    final tmpFile = File('${offlineDir.path}/$patternId.thumb.jpg.tmp');
    if (await tmpFile.exists()) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
    final client = http.Client();
    IOSink? sink;
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(resolvedUrl)));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      sink = tmpFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }
      await tmpFile.rename(finalFile.path);
      return finalFile;
    } catch (_) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// 영구 캐시 삭제. 본 파일 + 썸네일 함께 정리.
  Future<void> remove(String patternId) async {
    if (kIsWeb) return;
    try {
      final box = await _box();
      final raw = box.get(patternId);
      if (raw != null) {
        final entry = OfflinePatternEntry.fromMap(patternId, raw);
        final file = File(entry.localPath);
        if (await file.exists()) await file.delete();
        // #838 — 썸네일도 함께 삭제 (본 파일과 같은 경로면 중복 삭제 회피).
        if (entry.thumbnailPath.isNotEmpty &&
            entry.thumbnailPath != entry.localPath) {
          final thumb = File(entry.thumbnailPath);
          if (await thumb.exists()) {
            try {
              await thumb.delete();
            } catch (_) {}
          }
        }
      }
      await box.delete(patternId);
    } catch (_) {}
  }

  /// 전체 다운로드된 도안 목록.
  Future<List<OfflinePatternEntry>> all() async {
    if (kIsWeb) return [];
    try {
      final box = await _box();
      return box.keys
          .map((k) => k as String)
          .map((id) {
            final raw = box.get(id);
            if (raw == null) return null;
            return OfflinePatternEntry.fromMap(id, raw);
          })
          .whereType<OfflinePatternEntry>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final patternOfflineRepositoryProvider =
    Provider<PatternOfflineRepository>((ref) {
  return PatternOfflineRepository();
});

/// #783 — 영구 캐시된 모든 도안의 총 바이트 합계.
/// #838 — 썸네일 캐시 바이트도 포함 (본 파일 == 썸네일인 image 케이스는 중복 합산 회피).
final offlinePatternsTotalBytesProvider = FutureProvider<int>((ref) async {
  final list = await ref.read(patternOfflineRepositoryProvider).all();
  return list.fold<int>(0, (sum, e) {
    var total = sum + e.sizeBytes;
    if (e.thumbnailPath.isNotEmpty && e.thumbnailPath != e.localPath) {
      total += e.thumbnailBytes;
    }
    return total;
  });
});

/// 특정 도안의 오프라인 다운로드 상태 (실시간 갱신용 - 트리거 시 invalidate).
///
/// #861 — autoDispose 적용. 카드가 화면에서 사라지면 dispose → 재진입 시 fresh load.
/// 이전: stale 캐시 유지 → 다른 화면에서 다운로드해도 카드 아이콘 갱신 안 됨 →
/// 사용자가 이미 다운로드된 도안에 재다운로드 시도 → 서버 비용 증가.
final patternOfflineEntryProvider = FutureProvider.autoDispose
    .family<OfflinePatternEntry?, String>((ref, patternId) {
  return ref.read(patternOfflineRepositoryProvider).get(patternId);
});
