import 'step_unit.dart';
import 'step_unit_origin.dart';

/// 이슈 #687 — StepUnit 묶음 (섹션 단위).
/// 도안 섹션·템플릿 그룹 모두 표현 가능. units 안에 StepUnit 리스트.
class StepUnitGroup {
  final String id;
  final String title;
  final String? titleKo;
  final String? titleEn;
  final int order;
  final List<StepUnit> units;
  final StepUnitOrigin? origin;

  const StepUnitGroup({
    required this.id,
    required this.title,
    this.titleKo,
    this.titleEn,
    this.order = 0,
    this.units = const [],
    this.origin,
  });

  String localizedTitle(bool ko) =>
      ko ? (titleKo ?? title) : (titleEn ?? title);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (titleKo != null) 'titleKo': titleKo,
        if (titleEn != null) 'titleEn': titleEn,
        'order': order,
        'units': units.map((u) => u.toMap()).toList(),
        if (origin != null) 'origin': origin!.toMap(),
      };

  factory StepUnitGroup.fromMap(Map<String, dynamic> m) => StepUnitGroup(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        titleKo: m['titleKo'] as String?,
        titleEn: m['titleEn'] as String?,
        order: m['order'] as int? ?? 0,
        units: ((m['units'] as List?) ?? [])
            .map(
              (u) => StepUnit.fromMap(Map<String, dynamic>.from(u as Map)),
            )
            .toList(),
        origin: m['origin'] == null
            ? null
            : StepUnitOrigin.fromMap(
                Map<String, dynamic>.from(m['origin'] as Map),
              ),
      );
}
