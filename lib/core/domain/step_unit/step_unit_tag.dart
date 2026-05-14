/// 이슈 #687 — StepUnit 분류 태그.
/// 템플릿 검색·자동 매칭(craft/yarn/needle 등)에 사용.
enum StepUnitTagKind { craft, yarn, needle, skillLevel, garmentType, custom }

class StepUnitTag {
  final StepUnitTagKind kind;
  final String value;

  const StepUnitTag(this.kind, this.value);

  Map<String, dynamic> toMap() => {'kind': kind.name, 'value': value};

  factory StepUnitTag.fromMap(Map<String, dynamic> m) => StepUnitTag(
        StepUnitTagKind.values.firstWhere(
          (e) => e.name == m['kind'],
          orElse: () => StepUnitTagKind.custom,
        ),
        m['value'] as String? ?? '',
      );
}
