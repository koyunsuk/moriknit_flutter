// lib/features/pattern/data/symbol_svg_repository.dart
//
// 심볼 SVG 본문 하이브리드 캐시 — 오프라인에서도 도안에디터가 100% 동작하도록.
//
// 우선순위 (Firebase 최신 디자인 우선, 인라인은 오프라인 폴백):
//   1. 메모리 캐시 (앱 세션 동안 재호출 0)
//   2. Hive 영속 캐시 (한 번 다운로드한 Firebase SVG 영구 보관)
//   3. Firestore knit_symbols → Storage URL 다운로드 → Hive 저장
//   4. 인라인 폴백 (kKnitSymbolSvgData) — 오프라인 + 본 적 없는 심볼만 사용
//
// 메모리 캐시 1단계 추가 (앱 세션 동안 HTTP/Hive 재호출 0).
//
// 키 정책:
//   - 우선 symbolId (소문자 abbr 정규화 — knit_symbol_provider 과 동일 규칙)
//   - svgUrl 만 들어와도 URL → svg 조회 가능
//
// 회귀 위험 0:
//   - 기존 kKnitSymbolSvgData / SvgSymbolCache / MoriSymbolView 그대로 유지
//   - 신규 위젯 SymbolSvgWidget이 이 Repository를 사용
//   - 점진 교체 가능

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/subscription_constants.dart';
import '../../../providers/knit_symbol_provider.dart';
import '../domain/knit_symbol_svgs.dart';

class SymbolSvgRepository {
  SymbolSvgRepository(this._ref);

  final Ref _ref;

  /// 세션 메모리 캐시 — Hive/HTTP 재진입 차단.
  final Map<String, String> _mem = <String, String>{};

  /// URL 다운로드 중복 차단 (동시 호출 시 단일 future 공유).
  final Map<String, Future<String?>> _inflight = <String, Future<String?>>{};

  Box<Map>? _box() {
    if (kIsWeb) return null;
    const name = SubscriptionConstants.boxKnitSymbolSvgCache;
    if (!Hive.isBoxOpen(name)) return null;
    return Hive.box<Map>(name);
  }

  /// 키 정규화 — abbreviation/id를 소문자 + underscore 형태로.
  String _normalize(String key) => key.toLowerCase().trim().replaceAll(' ', '_');

  /// SVG 본문 조회 — 비동기 (Hive → 인라인 → 네트워크 순)
  ///
  /// [symbolId] 정규화된 키 ('k', 'p', 'yo', 'c4f' 등). null/empty 허용 — 그 경우 [svgUrl]로 조회.
  /// [svgUrl] Firebase Storage 또는 일반 SVG URL (옵션).
  Future<String?> getSvg({String? symbolId, String? svgUrl}) async {
    final id = symbolId == null ? null : _normalize(symbolId);

    // 1) 메모리 캐시 우선
    if (id != null && _mem.containsKey(id)) return _mem[id];
    if (svgUrl != null && svgUrl.isNotEmpty && _mem.containsKey(svgUrl)) {
      return _mem[svgUrl];
    }

    // 2) Hive 영속 캐시
    final box = _box();
    if (box != null) {
      if (id != null) {
        final entry = box.get(id);
        final svg = entry == null ? null : entry['svg'] as String?;
        if (svg != null && svg.isNotEmpty) {
          _mem[id] = svg;
          return svg;
        }
      }
      if (svgUrl != null && svgUrl.isNotEmpty) {
        final entry = box.get(_urlKey(svgUrl));
        final svg = entry == null ? null : entry['svg'] as String?;
        if (svg != null && svg.isNotEmpty) {
          _mem[svgUrl] = svg;
          return svg;
        }
      }
    }

    // 3) Firestore knit_symbols svgUrl 해석 → 네트워크 다운로드 (Firebase 최신 디자인 우선)
    var effectiveUrl = svgUrl;
    if ((effectiveUrl == null || effectiveUrl.isEmpty) && id != null) {
      final urlMap = _ref.read(unifiedSymbolSvgUrlProvider);
      effectiveUrl = urlMap[id];
    }
    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      final downloaded = await _downloadAndCache(id, effectiveUrl);
      if (downloaded != null && downloaded.isNotEmpty) {
        return downloaded;
      }
    }

    // 4) 인라인 폴백 (오프라인 + Firebase 실패 시에만)
    if (id != null) {
      final inline = kKnitSymbolSvgData[id];
      if (inline != null && inline.isNotEmpty) {
        _mem[id] = inline;
        return inline;
      }
    }

    return null;
  }

  /// URL 다운로드 + Hive 저장 (중복 호출 차단).
  Future<String?> _downloadAndCache(String? id, String url) {
    final inflightKey = id ?? url;
    final existing = _inflight[inflightKey];
    if (existing != null) return existing;

    final future = _fetchUrl(id, url).whenComplete(() {
      _inflight.remove(inflightKey);
    });
    _inflight[inflightKey] = future;
    return future;
  }

  Future<String?> _fetchUrl(String? id, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final svg = response.body;
      if (svg.isEmpty) return null;

      // 메모리 + Hive 저장
      if (id != null) _mem[id] = svg;
      _mem[url] = svg;

      final box = _box();
      if (box != null) {
        final fetchedAt = DateTime.now().millisecondsSinceEpoch;
        final record = <String, dynamic>{'svg': svg, 'fetchedAt': fetchedAt};
        try {
          if (id != null) await box.put(id, record);
          await box.put(_urlKey(url), record);
        } catch (_) {
          // 저장 실패는 무음 — 메모리 캐시는 그대로 활용 가능.
        }
      }
      return svg;
    } catch (_) {
      return null;
    }
  }

  /// 동기 조회 — UI 빌드 안에서 메모리/인라인만 즉시 사용.
  /// 캐시/인라인 모두 없으면 null 반환 후 호출자가 [getSvg]로 비동기 트리거.
  String? getSvgSync({String? symbolId, String? svgUrl}) {
    final id = symbolId == null ? null : _normalize(symbolId);
    if (id != null && _mem.containsKey(id)) return _mem[id];
    if (svgUrl != null && svgUrl.isNotEmpty && _mem.containsKey(svgUrl)) {
      return _mem[svgUrl];
    }
    // Hive (동기 접근)
    final box = _box();
    if (box != null) {
      if (id != null) {
        final entry = box.get(id);
        final svg = entry == null ? null : entry['svg'] as String?;
        if (svg != null && svg.isNotEmpty) {
          _mem[id] = svg;
          return svg;
        }
      }
      if (svgUrl != null && svgUrl.isNotEmpty) {
        final entry = box.get(_urlKey(svgUrl));
        final svg = entry == null ? null : entry['svg'] as String?;
        if (svg != null && svg.isNotEmpty) {
          _mem[svgUrl] = svg;
          return svg;
        }
      }
    }
    // 인라인
    if (id != null) {
      final inline = kKnitSymbolSvgData[id];
      if (inline != null && inline.isNotEmpty) {
        _mem[id] = inline;
        return inline;
      }
    }
    return null;
  }

  /// 시동 시 호출 — 알려진 모든 심볼 SVG를 백그라운드 다운로드 + 캐시.
  ///
  /// 동작:
  ///   1. Firestore knit_symbols 스트림에서 첫 emit 대기
  ///   2. 각 항목의 svgUrl을 순차 다운로드 (이미 캐시된 것은 skip)
  ///   3. 인라인 폴백만 있는 심볼은 패스 (네트워크 불필요)
  ///
  /// 사용자 체감 0 — 모두 백그라운드.
  Future<void> prefetchAll() async {
    if (kIsWeb) return; // 웹은 Firestore IndexedDB persistence가 대체
    try {
      // 첫 emit만 대기 — 5초 timeout
      final entries = await _ref
          .read(knitSymbolRepositoryProvider)
          .watchAll()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);

      for (final entry in entries) {
        if (entry.svgUrl.isEmpty) continue;
        final id = _normalize(entry.symbolId);
        // 이미 캐시되어 있으면 skip
        if (getSvgSync(symbolId: id, svgUrl: entry.svgUrl) != null) continue;
        // 백그라운드 다운로드 — 결과는 무시 (캐시에 자동 저장)
        unawaited(_downloadAndCache(id, entry.svgUrl));
      }
    } catch (_) {
      // prefetch 실패는 UX 영향 X — 다음 화면 진입 시 lazy load.
    }
  }

  /// URL → 안전한 Hive 키 (base64 변환).
  String _urlKey(String url) =>
      'url:${base64Url.encode(utf8.encode(url))}';

  /// 외부에서 단일 심볼 캐시 수동 무효화 (관리자 SVG 재업로드 등).
  Future<void> invalidate({String? symbolId, String? svgUrl}) async {
    final id = symbolId == null ? null : _normalize(symbolId);
    if (id != null) _mem.remove(id);
    if (svgUrl != null) _mem.remove(svgUrl);
    final box = _box();
    if (box != null) {
      try {
        if (id != null) await box.delete(id);
        if (svgUrl != null) await box.delete(_urlKey(svgUrl));
      } catch (_) {}
    }
  }
}

final symbolSvgRepositoryProvider = Provider<SymbolSvgRepository>((ref) {
  return SymbolSvgRepository(ref);
});
