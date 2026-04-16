import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/knit_symbol_entry.dart';

/// Firestore `knit_symbols` 컬렉션 — 뜨개백과와 독립된 도안 심볼 전용 저장소
class KnitSymbolRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<KnitSymbolEntry>> watchAll() {
    return _db
        .collection('knit_symbols')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => KnitSymbolEntry.fromFirestore(d.id, d.data()))
            .where((e) => e.svgUrl.isNotEmpty && e.abbreviation.isNotEmpty)
            .toList());
  }
}
