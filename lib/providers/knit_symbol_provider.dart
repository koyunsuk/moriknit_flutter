import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pattern/data/knit_symbol_repository.dart';
import '../features/pattern/domain/knit_symbol_entry.dart';

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
