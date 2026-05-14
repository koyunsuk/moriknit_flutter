import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/subscription_constants.dart';
import '../domain/encyclopedia_entry.dart';

class EncyclopediaRepository {
  EncyclopediaRepository({LocalCache<EncyclopediaEntry>? cache})
      : _cache = cache ??
            LocalCache<EncyclopediaEntry>(
              boxName: SubscriptionConstants.boxCacheEncyclopedia,
              fromJson: EncyclopediaEntry.fromJson,
              toJson: (e) => e.toJson(),
              idOf: (e) => e.id,
            );

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalCache<EncyclopediaEntry> _cache;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('encyclopedia');

  /// Firestore 쓰기용 payload — id/createdAt 제외 (서버 측 doc.id/serverTimestamp 보존)
  Map<String, dynamic> _writePayload(EncyclopediaEntry entry) {
    final map = Map<String, dynamic>.from(entry.toJson());
    map.remove('id');
    map.remove('createdAt');
    return map;
  }

  Stream<List<EncyclopediaEntry>> watchAll() async* {
    final cached = _cache.readAll();
    if (cached.isNotEmpty) yield cached;

    bool emittedAny = cached.isNotEmpty;
    yield* _col
        .orderBy('order')
        .snapshots()
        .map((s) {
          final list = s.docs.map(EncyclopediaEntry.fromFirestore).toList();
          if (!s.metadata.isFromCache) {
            // fire-and-forget — 캐시 실패해도 UX 영향 X
            _cache.writeAll(list);
          }
          return list;
        })
        .timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) {
            if (!emittedAny) sink.add(const <EncyclopediaEntry>[]);
          },
        )
        .map((list) {
          emittedAny = true;
          return list;
        });
  }

  Stream<List<EncyclopediaEntry>> watchByCategory(String category) {
    return _col
        .where('category', isEqualTo: category)
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(EncyclopediaEntry.fromFirestore).toList());
  }

  /// 코바늘 전용 — 클라이언트 필터링 (인덱스/필드 누락에 견고).
  /// craftType이 'crochet' 또는 'Crochet'(대소문자 무시) 항목 모두 포함.
  Stream<List<EncyclopediaEntry>> watchCrochet() {
    return watchAll().map(
      (entries) => entries
          .where((e) => e.craftType.toLowerCase().trim() == 'crochet')
          .toList(),
    );
  }

  /// 대바늘 전용 — craftType 필드가 없는 구버전 항목 포함 (전체 로드 후 클라이언트 필터)
  Stream<List<EncyclopediaEntry>> watchKnitting() {
    return watchAll().map(
      (entries) => entries
          .where((e) {
            final t = e.craftType.toLowerCase().trim();
            // craftType 필드 없거나 빈값은 구버전 = 대바늘로 간주.
            return t == 'knitting' || t.isEmpty;
          })
          .toList(),
    );
  }

  Stream<List<EncyclopediaEntry>> watchByCraftType(String craftType) {
    if (craftType == 'knitting') return watchKnitting();
    return watchCrochet();
  }

  Future<void> createEntry(EncyclopediaEntry entry) async {
    await _col.add({
      ..._writePayload(entry),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEntry(EncyclopediaEntry entry) async {
    await _col.doc(entry.id).update(_writePayload(entry));
  }

  Future<void> deleteEntry(String id) async {
    await _col.doc(id).delete();
  }
}
