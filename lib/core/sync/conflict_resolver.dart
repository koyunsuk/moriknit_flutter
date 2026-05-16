// 이슈 #704 Phase 1 — 충돌 해결기.
//
// 로컬 변경분과 서버 최신본이 다를 때 어떻게 합칠지 정책으로 표현.
// Repository 레이어에서 동기화 시점에 사용.
//
// 정책:
// - manual: 자동 해결 X. 호출자가 처리 (예: 사용자에게 선택 UI).
// - lastWriteWins: updatedAt이 더 최신인 쪽 채택.
// - sum: 누적값(타이머 누적초 등) — local + server 합산.
// - union: 컬렉션/리스트의 합집합.

/// 충돌 해결 정책.
enum ConflictPolicy { manual, lastWriteWins, sum, union }

/// 충돌 해결 시 manual 정책으로 자동 해결이 불가능함을 알리는 예외.
class ManualResolutionRequired implements Exception {
  final String message;
  const ManualResolutionRequired([this.message = 'Manual resolution required']);
  @override
  String toString() => 'ManualResolutionRequired: $message';
}

/// 충돌 해결기.
/// [T] 타입에 대한 local/server 두 값을 정책에 따라 합쳐 반환.
///
/// 사용:
/// ```dart
/// final resolver = ConflictResolver<Map<String,dynamic>>(
///   policy: ConflictPolicy.lastWriteWins,
///   updatedAtSelector: (m) => DateTime.parse(m['updatedAt'] as String),
/// );
/// final winner = resolver.resolve(local, server);
/// ```
class ConflictResolver<T> {
  final ConflictPolicy policy;

  /// manual 외 정책에서 updatedAt 비교용 셀렉터.
  final DateTime Function(T value)? updatedAtSelector;

  /// sum 정책에서 누적값 추출용 셀렉터.
  final num Function(T value)? sumSelector;

  /// sum 정책에서 합산 결과를 다시 T로 반영하는 빌더.
  final T Function(T base, num totalSum)? sumApplier;

  /// union 정책에서 합집합 대상 컬렉션 추출용.
  final Iterable Function(T value)? unionSelector;

  /// union 정책에서 합집합 결과를 다시 T로 반영.
  final T Function(T base, List union)? unionApplier;

  /// 커스텀 머저 (정책으로 표현 못 하는 케이스 대응).
  final T Function(T local, T server)? merger;

  const ConflictResolver({
    required this.policy,
    this.updatedAtSelector,
    this.sumSelector,
    this.sumApplier,
    this.unionSelector,
    this.unionApplier,
    this.merger,
  });

  /// 충돌 해결.
  /// manual 정책 + merger 없음 → ManualResolutionRequired throw.
  T resolve(T local, T server) {
    if (merger != null) return merger!(local, server);

    switch (policy) {
      case ConflictPolicy.manual:
        throw const ManualResolutionRequired();
      case ConflictPolicy.lastWriteWins:
        final sel = updatedAtSelector;
        if (sel == null) {
          throw StateError('lastWriteWins requires updatedAtSelector');
        }
        final lu = sel(local);
        final su = sel(server);
        return lu.isAfter(su) ? local : server;
      case ConflictPolicy.sum:
        final sel = sumSelector;
        final app = sumApplier;
        if (sel == null || app == null) {
          throw StateError('sum policy requires sumSelector and sumApplier');
        }
        return app(server, sel(local) + sel(server));
      case ConflictPolicy.union:
        final sel = unionSelector;
        final app = unionApplier;
        if (sel == null || app == null) {
          throw StateError('union policy requires unionSelector and unionApplier');
        }
        final merged = <dynamic>{...sel(local), ...sel(server)}.toList();
        return app(server, merged);
    }
  }
}
