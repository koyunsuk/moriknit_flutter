import 'package:cloud_firestore/cloud_firestore.dart';

class BuiltinTemplate {
  final String id;
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
  final int order;
  final bool isActive;

  const BuiltinTemplate({
    required this.id,
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
    required this.order,
    required this.isActive,
  });

  factory BuiltinTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BuiltinTemplate(
      id: doc.id,
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
      order: data['order'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
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
        'order': order,
        'isActive': isActive,
      };

  BuiltinTemplate copyWith({
    String? id,
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
    int? order,
    bool? isActive,
  }) {
    return BuiltinTemplate(
      id: id ?? this.id,
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
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}
