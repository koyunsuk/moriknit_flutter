import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/subscription_constants.dart';
import '../domain/knit_symbol_entry.dart';

/// Firestore `knit_symbols` 컬렉션 — 뜨개백과와 독립된 도안 심볼 전용 저장소
///
/// #685 — Hive 영속 캐시 우선 emit + Firestore 서버 스냅샷 도착 시 캐시 갱신.
/// 5초 timeout 이내 아무것도 emit 못하면 빈 리스트 한 번 emit (raw exception 차단).
class KnitSymbolRepository {
  KnitSymbolRepository({LocalCache<KnitSymbolEntry>? cache})
      : _cache = cache ??
            LocalCache<KnitSymbolEntry>(
              boxName: SubscriptionConstants.boxCacheKnitSymbols,
              fromJson: KnitSymbolEntry.fromJson,
              toJson: (e) => e.toJson(),
              idOf: (e) => e.id,
            );

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalCache<KnitSymbolEntry> _cache;

  Stream<List<KnitSymbolEntry>> watchAll() async* {
    // 1) Hive 영속 캐시 즉시 emit
    final cached = _cache.readAll()
        .where((e) => e.svgUrl.isNotEmpty && e.abbreviation.isNotEmpty)
        .toList();
    if (cached.isNotEmpty) yield cached;

    bool emittedAny = cached.isNotEmpty;

    // 2) Firestore stream — 서버 응답 시 캐시 갱신
    final firestoreStream = _db
        .collection('knit_symbols')
        .orderBy('order')
        .snapshots()
        .map((snap) {
      final all = snap.docs
          .map((d) => KnitSymbolEntry.fromFirestore(d.id, d.data()))
          .toList();
      // 서버 응답일 때만 영속 캐시 갱신 (fire-and-forget)
      if (!snap.metadata.isFromCache) {
        _cache.writeAll(all);
      }
      return all
          .where((e) => e.svgUrl.isNotEmpty && e.abbreviation.isNotEmpty)
          .toList();
    }).handleError((Object _) {
      // raw exception 노출 금지 — 폴백으로 빈 데이터
      // (handleError가 에러를 swallow하지 못하는 경우를 대비해 transform 사용)
    });

    // 3) 5초 timeout — 첫 emit 없을 경우 빈 리스트
    yield* firestoreStream
        .timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!emittedAny) {
          sink.add(const <KnitSymbolEntry>[]);
          emittedAny = true;
        }
      },
    )
        .map((list) {
      emittedAny = true;
      return list;
    });
  }
}
