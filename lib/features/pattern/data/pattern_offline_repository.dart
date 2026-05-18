// 이슈 #782 — 도안 오프라인 영구 캐시 (PDF/이미지).
//
// 영구 저장 위치: `getApplicationDocumentsDirectory() + '/offline_patterns/{patternId}{ext}'`
// 메타 저장: Hive `offline_patterns` box → {patternId: {path, downloadedAt, sizeBytes, kind}}
//
// 사용자가 명시적으로 "오프라인 보관" 버튼을 눌렀을 때만 영구 저장.
// 임시 캐시(temp)와 별개 — 임시 캐시는 OS가 삭제할 수 있지만 이건 안전.

import 'dart:io';

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

  const OfflinePatternEntry({
    required this.patternId,
    required this.localPath,
    required this.downloadedAt,
    required this.sizeBytes,
    required this.kind,
  });

  Map<String, dynamic> toMap() => {
        'localPath': localPath,
        'downloadedAt': downloadedAt.millisecondsSinceEpoch,
        'sizeBytes': sizeBytes,
        'kind': kind,
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
  Future<OfflinePatternEntry> download({
    required String patternId,
    required String url,
    required String kind,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web does not support offline pattern cache.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/offline_patterns');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    final ext = kind == 'pdf' ? 'pdf' : 'jpg';
    final file = File('${offlineDir.path}/$patternId.$ext');

    final response = await http.Client().send(http.Request('GET', Uri.parse(url)));
    final total = response.contentLength ?? -1;
    final sink = file.openWrite();
    int received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (onProgress != null) {
        onProgress(total > 0 ? received / total : -1.0);
      }
    }
    await sink.close();

    final size = await file.length();
    final entry = OfflinePatternEntry(
      patternId: patternId,
      localPath: file.path,
      downloadedAt: DateTime.now(),
      sizeBytes: size,
      kind: kind,
    );
    final box = await _box();
    await box.put(patternId, entry.toMap());
    return entry;
  }

  /// 영구 캐시 삭제.
  Future<void> remove(String patternId) async {
    if (kIsWeb) return;
    try {
      final box = await _box();
      final raw = box.get(patternId);
      if (raw != null) {
        final entry = OfflinePatternEntry.fromMap(patternId, raw);
        final file = File(entry.localPath);
        if (await file.exists()) await file.delete();
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
final offlinePatternsTotalBytesProvider = FutureProvider<int>((ref) async {
  final list = await ref.read(patternOfflineRepositoryProvider).all();
  return list.fold<int>(0, (sum, e) => sum + e.sizeBytes);
});

/// 특정 도안의 오프라인 다운로드 상태 (실시간 갱신용 - 트리거 시 invalidate).
final patternOfflineEntryProvider =
    FutureProvider.family<OfflinePatternEntry?, String>((ref, patternId) {
  return ref.read(patternOfflineRepositoryProvider).get(patternId);
});
