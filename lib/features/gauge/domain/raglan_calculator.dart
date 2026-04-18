class RaglanSize {
  final String label;
  final int baseFront;
  final int baseBack;
  final int baseSleeve;
  final int baseIncreaseRounds;

  const RaglanSize({
    required this.label,
    required this.baseFront,
    required this.baseBack,
    required this.baseSleeve,
    required this.baseIncreaseRounds,
  });
}

class RaglanResult {
  final int castOnCount;
  final int increaseRounds;
  final int raglanRows;
  final int frontStitches;
  final int backStitches;
  final int sleeveStitches;
  final int bodyStitches;

  const RaglanResult({
    required this.castOnCount,
    required this.increaseRounds,
    required this.raglanRows,
    required this.frontStitches,
    required this.backStitches,
    required this.sleeveStitches,
    required this.bodyStitches,
  });
}

class RaglanCalculator {
  static const double _stdStitchGauge = 21.0;
  static const double _stdRowGauge = 29.0;

  static const List<RaglanSize> sizes = [
    RaglanSize(label: 'XS',  baseFront: 36, baseBack: 36, baseSleeve: 6,  baseIncreaseRounds: 5),
    RaglanSize(label: 'S',   baseFront: 38, baseBack: 38, baseSleeve: 6,  baseIncreaseRounds: 5),
    RaglanSize(label: 'M',   baseFront: 42, baseBack: 42, baseSleeve: 6,  baseIncreaseRounds: 5),
    RaglanSize(label: 'L',   baseFront: 42, baseBack: 42, baseSleeve: 8,  baseIncreaseRounds: 5),
    RaglanSize(label: 'XL',  baseFront: 44, baseBack: 44, baseSleeve: 8,  baseIncreaseRounds: 5),
    RaglanSize(label: '2XL', baseFront: 44, baseBack: 44, baseSleeve: 8,  baseIncreaseRounds: 5),
    RaglanSize(label: '3XL', baseFront: 44, baseBack: 44, baseSleeve: 8,  baseIncreaseRounds: 5),
  ];

  static int _toEven(int n) => n % 2 == 0 ? n : n + 1;

  static RaglanResult calculate({
    required double myStitchGauge,
    required double myRowGauge,
    required RaglanSize size,
  }) {
    final rS = myStitchGauge / _stdStitchGauge;
    final rR = myRowGauge / _stdRowGauge;

    final increaseRounds = (size.baseIncreaseRounds * rR).round();
    final raglanRows = increaseRounds * 2;

    final scaledFront = _toEven((size.baseFront * rS).round());
    final scaledBack = _toEven((size.baseBack * rS).round());
    final scaledSleeve = _toEven((size.baseSleeve * rS).round());

    final increasePerPart = increaseRounds * 2;

    final frontStitches = scaledFront + increasePerPart;
    final backStitches = scaledBack + increasePerPart;
    final sleeveStitches = scaledSleeve + increasePerPart;

    final basecastOn = size.baseFront + size.baseBack + size.baseSleeve * 2 + 8;
    final castOnCount = _toEven((basecastOn * rS).round());

    return RaglanResult(
      castOnCount: castOnCount,
      increaseRounds: increaseRounds,
      raglanRows: raglanRows,
      frontStitches: frontStitches,
      backStitches: backStitches,
      sleeveStitches: sleeveStitches,
      bodyStitches: frontStitches + backStitches,
    );
  }
}
