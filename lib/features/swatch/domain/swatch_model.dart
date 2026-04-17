import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'swatch_model.freezed.dart';
part 'swatch_model.g.dart';

@freezed
class SwatchModel with _$SwatchModel {
  const factory SwatchModel({
    required String id,
    required String uid,
    @Default('') String swatchName,
    @Default('') String yarnBrandId,
    @Default('') String yarnBrandName,
    @Default('') String yarnName,
    @Default('') String yarnColor,
    @Default('') String yarnWeight,
    @Default('') String needleBrandId,
    @Default('') String needleBrandName,
    @Default('') String needleMaterial,
    @Default(0.0) double needleSize,
    @Default('') String myNeedleId,
    @Default('') String myYarnId,
    @Default('') String myNeedlePhotoUrl,
    @Default('') String myYarnPhotoUrl,
    @Default(0) int beforeStitchCount,
    @Default(0) int beforeRowCount,
    @Default(0.0) double beforeWidthCm,
    @Default(0.0) double beforeHeightCm,
    @Default('') String beforePhotoUrl,
    @Default(false) bool hasAfterWash,
    @Default(0) int afterStitchCount,
    @Default(0) int afterRowCount,
    @Default(0.0) double afterWidthCm,
    @Default(0.0) double afterHeightCm,
    @Default('') String afterPhotoUrl,
    @Default(0.0) double shrinkageRate,
    @Default('') String memo,
    @Default(false) bool isPublic,
    @Default(false) bool isArchived,
    DateTime? archivedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default('') String projectId,
    @Default(false) bool isDirty,
    /// 최종 완성 콧수 (10×10 게이지 콧수와 별개)
    @Default(0) int finalStitchCount,
    /// 최종 완성 단수 (10×10 게이지 단수와 별개)
    @Default(0) int finalRowCount,
    /// 스와치 시작 날짜 (시작 시점 기록용)
    DateTime? startedAt,
    /// 나의 악세사리 연결
    @Default('') String myAccessoryId,
    @Default('') String myAccessoryName,
  }) = _SwatchModel;

  factory SwatchModel.fromJson(Map<String, dynamic> json) => _$SwatchModelFromJson(json);

  factory SwatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SwatchModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory SwatchModel.empty({required String uid}) {
    return SwatchModel(
      id: '',
      uid: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension SwatchCalculations on SwatchModel {
  double calculateShrinkageRate() {
    if (!hasAfterWash || beforeStitchCount == 0) return 0.0;
    return ((beforeStitchCount - afterStitchCount) / beforeStitchCount) * 100;
  }

  String get gaugeDisplay => '$beforeStitchCount x $beforeRowCount';

  String get needleSizeDisplay => needleSize % 1 == 0 ? '${needleSize.toInt()}mm' : '${needleSize}mm';

  bool get isComplete => beforeStitchCount > 0 && beforeRowCount > 0;
}
