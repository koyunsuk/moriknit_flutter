import 'package:intl/intl.dart';

import '../../my/domain/needle_model.dart';
import '../../project/domain/project_model.dart';
import '../../swatch/domain/swatch_model.dart';

enum LabelType { swatch, needle, project }

class LabelData {
  final LabelType type;

  /// 키: 필드 ID, 값: 표시 내용
  final Map<String, String> fields;

  /// 키: 필드 ID, 값: 사람이 읽는 레이블
  final Map<String, String> fieldLabels;

  /// 사용자 자유 메모
  final String customNote;

  /// 현재 표시할 필드 목록 (순서 유지)
  final List<String> enabledFields;

  const LabelData({
    required this.type,
    required this.fields,
    required this.fieldLabels,
    required this.customNote,
    required this.enabledFields,
  });

  LabelData copyWithNote(String note) => LabelData(
        type: type,
        fields: fields,
        fieldLabels: fieldLabels,
        customNote: note,
        enabledFields: enabledFields,
      );

  LabelData copyWithEnabled(List<String> enabled) => LabelData(
        type: type,
        fields: fields,
        fieldLabels: fieldLabels,
        customNote: customNote,
        enabledFields: enabled,
      );

  // ─── 팩토리 ────────────────────────────────────────────────────────

  factory LabelData.empty() => const LabelData(
    type: LabelType.swatch,
    fields: {},
    fieldLabels: {},
    customNote: '',
    enabledFields: [],
  );

  factory LabelData.fromSwatch(SwatchModel swatch) {
    final fmt = DateFormat('yyyy.MM.dd');
    final fields = <String, String>{};
    final labels = <String, String>{};

    // gauge
    if (swatch.beforeStitchCount > 0 || swatch.beforeRowCount > 0) {
      fields['gauge'] =
          '${swatch.beforeStitchCount}코 × ${swatch.beforeRowCount}단';
      labels['gauge'] = '게이지 (10×10cm)';
    }
    // yarn
    if (swatch.yarnName.isNotEmpty) {
      fields['yarn'] = swatch.yarnName;
      labels['yarn'] = '사용실';
    } else if (swatch.yarnBrandName.isNotEmpty) {
      fields['yarn'] = swatch.yarnBrandName;
      labels['yarn'] = '사용실';
    }
    // yarnColor
    if (swatch.yarnColor.isNotEmpty) {
      fields['yarnColor'] = swatch.yarnColor;
      labels['yarnColor'] = '색상';
    }
    // yarnWeight
    if (swatch.yarnWeight.isNotEmpty) {
      fields['yarnWeight'] = swatch.yarnWeight;
      labels['yarnWeight'] = '실 굵기';
    }
    // needle
    if (swatch.needleSize > 0) {
      final sizeStr = swatch.needleSize % 1 == 0
          ? '${swatch.needleSize.toInt()}mm'
          : '${swatch.needleSize}mm';
      fields['needle'] = swatch.needleBrandName.isNotEmpty
          ? '${swatch.needleBrandName} $sizeStr'
          : sizeStr;
      labels['needle'] = '바늘';
    }
    // date
    if (swatch.createdAt != null) {
      fields['date'] = fmt.format(swatch.createdAt!);
      labels['date'] = '작성일';
    }
    // swatchName
    if (swatch.swatchName.isNotEmpty) {
      fields['name'] = swatch.swatchName;
      labels['name'] = '스와치 이름';
    }
    // memo
    if (swatch.memo.isNotEmpty) {
      fields['memo'] = swatch.memo;
      labels['memo'] = '메모';
    }

    // 기본 활성화 순서
    final defaultEnabled = <String>[
      if (fields.containsKey('name')) 'name',
      if (fields.containsKey('gauge')) 'gauge',
      if (fields.containsKey('yarn')) 'yarn',
      if (fields.containsKey('yarnColor')) 'yarnColor',
      if (fields.containsKey('needle')) 'needle',
      if (fields.containsKey('date')) 'date',
    ];

    return LabelData(
      type: LabelType.swatch,
      fields: fields,
      fieldLabels: labels,
      customNote: '',
      enabledFields: defaultEnabled,
    );
  }

  factory LabelData.fromNeedle(NeedleModel needle) {
    final fields = <String, String>{};
    final labels = <String, String>{};

    // name
    if (needle.name.isNotEmpty) {
      fields['name'] = needle.name;
      labels['name'] = '이름';
    }
    // type
    fields['type'] = needle.localizedTypeLabel(true);
    labels['type'] = '종류';

    // size
    fields['size'] = needle.sizeDisplay;
    labels['size'] = '사이즈';

    // brand
    if (needle.brandName.isNotEmpty) {
      fields['brand'] = needle.brandName;
      labels['brand'] = '브랜드';
    }
    // material
    fields['material'] = needle.localizedMaterialLabel(true);
    labels['material'] = '소재';

    // quantity
    if (needle.quantity > 1) {
      fields['quantity'] = '${needle.quantity}개';
      labels['quantity'] = '수량';
    }
    // memo
    if (needle.memo.isNotEmpty) {
      fields['memo'] = needle.memo;
      labels['memo'] = '메모';
    }

    final defaultEnabled = <String>[
      if (fields.containsKey('name')) 'name',
      'type',
      'size',
      if (fields.containsKey('brand')) 'brand',
      'material',
    ];

    return LabelData(
      type: LabelType.needle,
      fields: fields,
      fieldLabels: labels,
      customNote: '',
      enabledFields: defaultEnabled,
    );
  }

  factory LabelData.fromProject(ProjectModel project) {
    final fmt = DateFormat('yyyy.MM.dd');
    final fields = <String, String>{};
    final labels = <String, String>{};

    fields['title'] = project.title;
    labels['title'] = '프로젝트명';

    if (project.yarnName.isNotEmpty) {
      fields['yarn'] = project.yarnBrandName.isNotEmpty
          ? '${project.yarnBrandName} ${project.yarnName}'
          : project.yarnName;
      labels['yarn'] = '사용실';
    } else if (project.yarnBrandName.isNotEmpty) {
      fields['yarn'] = project.yarnBrandName;
      labels['yarn'] = '사용실';
    }
    if (project.yarnColor.isNotEmpty) {
      fields['yarnColor'] = project.yarnColor;
      labels['yarnColor'] = '색상';
    }
    if (project.needleSize > 0) {
      final sizeStr = project.needleSize % 1 == 0
          ? '${project.needleSize.toInt()}mm'
          : '${project.needleSize}mm';
      fields['needle'] = project.needleBrandName.isNotEmpty
          ? '${project.needleBrandName} $sizeStr'
          : sizeStr;
      labels['needle'] = '바늘';
    }
    if (project.startDate != null) {
      fields['startDate'] = fmt.format(project.startDate!);
      labels['startDate'] = '시작일';
    }
    fields['status'] = project.statusEnum.koreanLabel;
    labels['status'] = '상태';

    if (project.memo.isNotEmpty) {
      fields['memo'] = project.memo;
      labels['memo'] = '메모';
    }

    final defaultEnabled = <String>[
      'title',
      if (fields.containsKey('yarn')) 'yarn',
      if (fields.containsKey('needle')) 'needle',
      if (fields.containsKey('startDate')) 'startDate',
      'status',
    ];

    return LabelData(
      type: LabelType.project,
      fields: fields,
      fieldLabels: labels,
      customNote: '',
      enabledFields: defaultEnabled,
    );
  }

  String get typeName {
    switch (type) {
      case LabelType.swatch:
        return '스와치';
      case LabelType.needle:
        return '바늘';
      case LabelType.project:
        return '프로젝트';
    }
  }
}
