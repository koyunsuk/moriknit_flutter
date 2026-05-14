// lib/features/blueprint/domain/step_unit_groupmeta.dart
//
// 이슈 #687 (Phase G) — 청사진 내 그룹(섹션) 메타.
//
// StepUnitGroup(인스턴스 뷰)과 달리, 청사진(StepBlueprint)에 저장되는
// 가벼운 메타 정보만 보유. 실제 단위(StepBlueprintUnit)는 subcollection에서
// 별도 로딩되며 본 메타는 `unitIds` 로 참조만 한다.

class StepGroupMeta {
  final String id;
  final String title;
  final String? titleKo;
  final String? titleEn;
  final int order;

  /// subcollection 안의 StepBlueprintUnit.id 리스트.
  final List<String> unitIds;

  const StepGroupMeta({
    required this.id,
    required this.title,
    this.titleKo,
    this.titleEn,
    this.order = 0,
    this.unitIds = const [],
  });

  String localizedTitle(bool ko) =>
      ko ? (titleKo ?? title) : (titleEn ?? title);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (titleKo != null) 'titleKo': titleKo,
        if (titleEn != null) 'titleEn': titleEn,
        'order': order,
        'unitIds': unitIds,
      };

  factory StepGroupMeta.fromMap(Map<String, dynamic> m) => StepGroupMeta(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        titleKo: m['titleKo'] as String?,
        titleEn: m['titleEn'] as String?,
        order: m['order'] as int? ?? 0,
        unitIds: ((m['unitIds'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  StepGroupMeta copyWith({
    String? id,
    String? title,
    String? titleKo,
    String? titleEn,
    int? order,
    List<String>? unitIds,
  }) =>
      StepGroupMeta(
        id: id ?? this.id,
        title: title ?? this.title,
        titleKo: titleKo ?? this.titleKo,
        titleEn: titleEn ?? this.titleEn,
        order: order ?? this.order,
        unitIds: unitIds ?? this.unitIds,
      );
}
