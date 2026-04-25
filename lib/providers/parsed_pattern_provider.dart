import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moriknit_flutter/features/pattern/domain/pattern_chart.dart';
import 'package:moriknit_flutter/features/pattern_converter/data/pattern_converter_repository.dart';
import 'package:moriknit_flutter/features/pattern_converter/domain/parsed_pattern.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';

final patternConverterRepositoryProvider = Provider<PatternConverterRepository>(
  (_) => PatternConverterRepository(),
);

/// AI 변환 도안 목록 스트림 (pattern_charts 컬렉션, sourceType == aiConverted)
final aiPatternsProvider = StreamProvider<List<PatternChart>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(patternConverterRepositoryProvider).watchAiPatterns();
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

/// 구버전 호환: 내 파싱된 도안 목록 (parsed_patterns 컬렉션)
final myParsedPatternsProvider = StreamProvider<List<ParsedPattern>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      // 구버전 parsed_patterns 컬렉션은 watchPattern/deletePattern으로만 접근
      // 신규 저장은 모두 pattern_charts로 이동됨
      return const Stream.empty();
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

/// 단일 AI 변환 도안 스트림 (pattern_charts 기반) — 옵션 A: 실시간.
/// 일부 도안에서 stream emit 안되는 회귀 발견 (#655) → 화면에서는 future 변형 사용.
final aiPatternDetailProvider =
    StreamProvider.autoDispose.family<PatternChart?, String>((ref, patternId) {
  return ref.watch(patternConverterRepositoryProvider).watchAiPattern(patternId);
});

/// #655 무한로딩 fix — 단발 get 기반 future provider.
/// 텍스트 트래커 등 실시간 변경 추적이 필요 없는 화면에서 사용.
final aiPatternDetailFutureProvider =
    FutureProvider.autoDispose.family<PatternChart?, String>((ref, patternId) {
  return ref.watch(patternConverterRepositoryProvider).getAiPattern(patternId);
});

/// 구버전 호환: 단일 도안 스트림 (parsed_patterns 기반)
final parsedPatternDetailProvider =
    StreamProvider.family<ParsedPattern?, String>((ref, patternId) {
  return ref.watch(patternConverterRepositoryProvider).watchPattern(patternId);
});
