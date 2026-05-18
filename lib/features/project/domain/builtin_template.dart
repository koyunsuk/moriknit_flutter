import 'package:cloud_firestore/cloud_firestore.dart';

/// 프리셋(=템플릿=단계로그=서술형도안) 종류 구분.
/// 사용자 철학: "모리니트가 먼저 만들어준 것 = 프리셋, 모두 동일한 개념".
/// - projectSteps: 단계로그 기반 템플릿 (탑다운/양말/모자/크롭레글런 등)
/// - bodyMeasurement: 인형 치수 프리셋 (Barbie/Tammy/Paola/Disney/Mimi 등)
///   → 게이지 계산기로 이동 + 치수 자동 입력 트리거
@Deprecated('Phase E3 (#687) — step_blueprints/kind=template 로 통합. Phase E4에서 삭제 예정.')
enum BuiltinTemplateKind {
  projectSteps,
  bodyMeasurement;

  String get value => switch (this) {
        BuiltinTemplateKind.projectSteps => 'project_steps',
        BuiltinTemplateKind.bodyMeasurement => 'body_measurement',
      };

  static BuiltinTemplateKind fromValue(String? v) => switch (v) {
        'body_measurement' => BuiltinTemplateKind.bodyMeasurement,
        _ => BuiltinTemplateKind.projectSteps, // 기본값 — 기존 데이터 호환
      };
}

/// 이슈 #787 — 기본 템플릿 카테고리 분류.
/// 4그룹: 의상 / 소품 / 인형 / 아기용.
/// 라벨은 화면에서 카테고리 칩으로 사용.
enum BuiltinTemplateCategory {
  clothing,
  accessory,
  doll,
  baby;

  /// Firestore/JSON 저장값.
  String get value => switch (this) {
        BuiltinTemplateCategory.clothing => 'clothing',
        BuiltinTemplateCategory.accessory => 'accessory',
        BuiltinTemplateCategory.doll => 'doll',
        BuiltinTemplateCategory.baby => 'baby',
      };

  /// 저장값 → enum 복원. 기본값은 의상(clothing).
  static BuiltinTemplateCategory fromValue(String? v) => switch (v) {
        'accessory' => BuiltinTemplateCategory.accessory,
        'doll' => BuiltinTemplateCategory.doll,
        'baby' => BuiltinTemplateCategory.baby,
        _ => BuiltinTemplateCategory.clothing,
      };

  String label({required bool isKorean}) {
    if (isKorean) {
      return switch (this) {
        BuiltinTemplateCategory.clothing => '의상',
        BuiltinTemplateCategory.accessory => '소품',
        BuiltinTemplateCategory.doll => '인형',
        BuiltinTemplateCategory.baby => '아기용',
      };
    }
    return switch (this) {
      BuiltinTemplateCategory.clothing => 'Clothing',
      BuiltinTemplateCategory.accessory => 'Accessory',
      BuiltinTemplateCategory.doll => 'Doll',
      BuiltinTemplateCategory.baby => 'Baby',
    };
  }
}

@Deprecated('Phase E3 (#687) — step_blueprints/kind=template 로 통합 (마이그레이션 완료). Phase E4에서 삭제 예정.')
class BuiltinTemplate {
  final String id;
  final BuiltinTemplateKind kind;
  final BuiltinTemplateCategory category;
  final String titleKo;
  final String titleEn;
  final String descKo;
  final String descEn;
  final String iconName;
  final String colorHex;
  final List<String> stepsKo;
  final List<String> stepsEn;
  final List<String> stepNotesKo;
  final List<String> stepNotesEn;
  final List<int> stepTargetRows;
  /// kind=bodyMeasurement일 때 사용되는 치수 데이터.
  /// BodyMeasurement/UserGauge/EaseSettings/기타 추천 실·바늘 정보 포함.
  final Map<String, dynamic>? measurementData;
  final int order;
  final bool isActive;

  const BuiltinTemplate({
    required this.id,
    this.kind = BuiltinTemplateKind.projectSteps,
    this.category = BuiltinTemplateCategory.clothing,
    required this.titleKo,
    required this.titleEn,
    required this.descKo,
    required this.descEn,
    required this.iconName,
    required this.colorHex,
    required this.stepsKo,
    required this.stepsEn,
    required this.stepNotesKo,
    required this.stepNotesEn,
    required this.stepTargetRows,
    this.measurementData,
    required this.order,
    required this.isActive,
  });

  factory BuiltinTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BuiltinTemplate(
      id: doc.id,
      kind: BuiltinTemplateKind.fromValue(data['kind'] as String?),
      category: BuiltinTemplateCategory.fromValue(data['category'] as String?),
      titleKo: data['titleKo'] as String? ?? '',
      titleEn: data['titleEn'] as String? ?? '',
      descKo: data['descKo'] as String? ?? '',
      descEn: data['descEn'] as String? ?? '',
      iconName: data['iconName'] as String? ?? '',
      colorHex: data['colorHex'] as String? ?? '#B47EEB',
      stepsKo: List<String>.from(data['stepsKo'] as List? ?? []),
      stepsEn: List<String>.from(data['stepsEn'] as List? ?? []),
      stepNotesKo: List<String>.from(data['stepNotesKo'] as List? ?? []),
      stepNotesEn: List<String>.from(data['stepNotesEn'] as List? ?? []),
      stepTargetRows: List<int>.from(data['stepTargetRows'] as List? ?? []),
      measurementData: data['measurementData'] as Map<String, dynamic>?,
      order: data['order'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.value,
        'category': category.value,
        'titleKo': titleKo,
        'titleEn': titleEn,
        'descKo': descKo,
        'descEn': descEn,
        'iconName': iconName,
        'colorHex': colorHex,
        'stepsKo': stepsKo,
        'stepsEn': stepsEn,
        'stepNotesKo': stepNotesKo,
        'stepNotesEn': stepNotesEn,
        'stepTargetRows': stepTargetRows,
        if (measurementData != null) 'measurementData': measurementData,
        'order': order,
        'isActive': isActive,
      };

  BuiltinTemplate copyWith({
    String? id,
    BuiltinTemplateKind? kind,
    BuiltinTemplateCategory? category,
    String? titleKo,
    String? titleEn,
    String? descKo,
    String? descEn,
    String? iconName,
    String? colorHex,
    List<String>? stepsKo,
    List<String>? stepsEn,
    List<String>? stepNotesKo,
    List<String>? stepNotesEn,
    List<int>? stepTargetRows,
    Map<String, dynamic>? measurementData,
    int? order,
    bool? isActive,
  }) {
    return BuiltinTemplate(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      titleKo: titleKo ?? this.titleKo,
      titleEn: titleEn ?? this.titleEn,
      descKo: descKo ?? this.descKo,
      descEn: descEn ?? this.descEn,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      stepsKo: stepsKo ?? this.stepsKo,
      stepsEn: stepsEn ?? this.stepsEn,
      stepNotesKo: stepNotesKo ?? this.stepNotesKo,
      stepNotesEn: stepNotesEn ?? this.stepNotesEn,
      stepTargetRows: stepTargetRows ?? this.stepTargetRows,
      measurementData: measurementData ?? this.measurementData,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}
