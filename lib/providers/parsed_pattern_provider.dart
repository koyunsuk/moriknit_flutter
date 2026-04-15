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

/// 단일 AI 변환 도안 스트림 (pattern_charts 기반)
final aiPatternDetailProvider =
    StreamProvider.family<PatternChart?, String>((ref, patternId) {
  return ref.watch(patternConverterRepositoryProvider).watchAiPattern(patternId);
});

/// 구버전 호환: 단일 도안 스트림 (parsed_patterns 기반)
final parsedPatternDetailProvider =
    StreamProvider.family<ParsedPattern?, String>((ref, patternId) {
  return ref.watch(patternConverterRepositoryProvider).watchPattern(patternId);
});
