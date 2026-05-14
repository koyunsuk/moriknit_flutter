/// 이슈 #687 — StepUnit 원본 추적용 메타.
/// 도안/섹션/템플릿/Ravelry 등 어떤 자산에서 파생됐는지 역참조.
class StepUnitOrigin {
  final String? patternChartId;
  final String? sectionId;
  final String? templateId;
  final String? ravelryPatternId;

  const StepUnitOrigin({
    this.patternChartId,
    this.sectionId,
    this.templateId,
    this.ravelryPatternId,
  });

  Map<String, dynamic> toMap() => {
        if (patternChartId != null) 'patternChartId': patternChartId,
        if (sectionId != null) 'sectionId': sectionId,
        if (templateId != null) 'templateId': templateId,
        if (ravelryPatternId != null) 'ravelryPatternId': ravelryPatternId,
      };

  factory StepUnitOrigin.fromMap(Map<String, dynamic> m) => StepUnitOrigin(
        patternChartId: m['patternChartId'] as String?,
        sectionId: m['sectionId'] as String?,
        templateId: m['templateId'] as String?,
        ravelryPatternId: m['ravelryPatternId'] as String?,
      );
}
