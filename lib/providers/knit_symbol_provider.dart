import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pattern/data/knit_symbol_repository.dart';
import '../features/pattern/domain/crochet_symbols.dart';
import '../features/pattern/domain/knit_symbol_entry.dart';
import '../features/pattern/domain/knit_symbols.dart';

final knitSymbolRepositoryProvider =
    Provider<KnitSymbolRepository>((_) => KnitSymbolRepository());

/// Firestore knit_symbols 컬렉션 스트림 (order 오름차순)
final knitSymbolsProvider = StreamProvider<List<KnitSymbolEntry>>((ref) {
  return ref.watch(knitSymbolRepositoryProvider).watchAll();
});

/// symbolId(abbreviation key) → svgUrl 맵 — chart_canvas SVG 렌더링에 사용
final knitSymbolSvgUrlProvider = Provider<Map<String, String>>((ref) {
  final symbols = ref.watch(knitSymbolsProvider).valueOrNull ?? [];
  return {for (final s in symbols) s.symbolId: s.svgUrl};
});

/// symbolId → KnitSymbolEntry 맵 — span 정보 조회에 사용
final knitSymbolByIdProvider = Provider<Map<String, KnitSymbolEntry>>((ref) {
  final symbols = ref.watch(knitSymbolsProvider).valueOrNull ?? [];
  return {for (final s in symbols) s.symbolId: s};
});

// ─────────────────────────────────────────────────────────────────────────
// #672 — 단일 SVG 소스 통합 Provider
// ─────────────────────────────────────────────────────────────────────────

/// **단일 진실의 원천**으로 통합된 심볼 svgUrl 맵.
///
/// 우선순위:
///   1. Firestore knit_symbols 컬렉션 (관리자가 등록한 모든 심볼 — 대바늘 + 코바늘)
///   2. 정적 KnitSymbolLibrary (대바늘 60종 abbr 키 → 임시 빈값, Firestore가 비어있을 때 폴백)
///   3. 정적 CrochetSymbolLibrary 하드코딩 firebaseUrl (코바늘 30종, Firestore 등록 전 임시)
///
/// 키 정규화: 가능한 모든 키를 등록 (id / abbr 양쪽 모두).
/// Firestore에 코바늘이 등록되면 그 값이 우선 — 자동 전환.
final unifiedSymbolSvgUrlProvider = Provider<Map<String, String>>((ref) {
  final firestoreSymbols = ref.watch(knitSymbolsProvider).valueOrNull ?? [];

  final result = <String, String>{};

  // 1) 정적 코바늘 30종 (하드코딩 firebaseUrl) — 가장 낮은 우선순위.
  //    Firestore에 같은 키가 들어오면 덮어씌워짐.
  for (final c in kCrochetSymbols) {
    if (!c.hasSvg || c.firebaseUrl.isEmpty) continue;
    final keyId = c.id;
    final keyAbbr = c.abbreviation.toLowerCase().replaceAll(' ', '_');
    result[keyId] = c.firebaseUrl;
    result[keyAbbr] = c.firebaseUrl;
  }

  // 2) Firestore knit_symbols (대바늘+코바늘 통합) — 가장 높은 우선순위.
  //    KnitSymbolEntry.symbolId = abbreviation 기반 키.
  //    KnitSymbol(id, abbr) 정적 라이브러리 매칭 — id 키도 함께 등록.
  for (final s in firestoreSymbols) {
    if (s.svgUrl.isEmpty) continue;
    result[s.symbolId] = s.svgUrl;
    final knit = KnitSymbolLibrary.byAbbr(s.abbreviation);
    if (knit != null) {
      result[knit.id] = s.svgUrl;
    }
  }

  return result;
});
