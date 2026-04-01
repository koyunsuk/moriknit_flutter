// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swatch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SwatchModelImpl _$$SwatchModelImplFromJson(Map<String, dynamic> json) =>
    _$SwatchModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      swatchName: json['swatchName'] as String? ?? '',
      yarnBrandId: json['yarnBrandId'] as String? ?? '',
      yarnBrandName: json['yarnBrandName'] as String? ?? '',
      yarnName: json['yarnName'] as String? ?? '',
      yarnColor: json['yarnColor'] as String? ?? '',
      yarnWeight: json['yarnWeight'] as String? ?? '',
      needleBrandId: json['needleBrandId'] as String? ?? '',
      needleBrandName: json['needleBrandName'] as String? ?? '',
      needleMaterial: json['needleMaterial'] as String? ?? '',
      needleSize: (json['needleSize'] as num?)?.toDouble() ?? 0.0,
      myNeedleId: json['myNeedleId'] as String? ?? '',
      beforeStitchCount: (json['beforeStitchCount'] as num?)?.toInt() ?? 0,
      beforeRowCount: (json['beforeRowCount'] as num?)?.toInt() ?? 0,
      beforeWidthCm: (json['beforeWidthCm'] as num?)?.toDouble() ?? 0.0,
      beforeHeightCm: (json['beforeHeightCm'] as num?)?.toDouble() ?? 0.0,
      beforePhotoUrl: json['beforePhotoUrl'] as String? ?? '',
      hasAfterWash: json['hasAfterWash'] as bool? ?? false,
      afterStitchCount: (json['afterStitchCount'] as num?)?.toInt() ?? 0,
      afterRowCount: (json['afterRowCount'] as num?)?.toInt() ?? 0,
      afterWidthCm: (json['afterWidthCm'] as num?)?.toDouble() ?? 0.0,
      afterHeightCm: (json['afterHeightCm'] as num?)?.toDouble() ?? 0.0,
      afterPhotoUrl: json['afterPhotoUrl'] as String? ?? '',
      shrinkageRate: (json['shrinkageRate'] as num?)?.toDouble() ?? 0.0,
      memo: json['memo'] as String? ?? '',
      isPublic: json['isPublic'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      archivedDate: json['archivedDate'] == null
          ? null
          : DateTime.parse(json['archivedDate'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      projectId: json['projectId'] as String? ?? '',
      isDirty: json['isDirty'] as bool? ?? false,
    );

Map<String, dynamic> _$$SwatchModelImplToJson(_$SwatchModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'swatchName': instance.swatchName,
      'yarnBrandId': instance.yarnBrandId,
      'yarnBrandName': instance.yarnBrandName,
      'yarnName': instance.yarnName,
      'yarnColor': instance.yarnColor,
      'yarnWeight': instance.yarnWeight,
      'needleBrandId': instance.needleBrandId,
      'needleBrandName': instance.needleBrandName,
      'needleMaterial': instance.needleMaterial,
      'needleSize': instance.needleSize,
      'myNeedleId': instance.myNeedleId,
      'beforeStitchCount': instance.beforeStitchCount,
      'beforeRowCount': instance.beforeRowCount,
      'beforeWidthCm': instance.beforeWidthCm,
      'beforeHeightCm': instance.beforeHeightCm,
      'beforePhotoUrl': instance.beforePhotoUrl,
      'hasAfterWash': instance.hasAfterWash,
      'afterStitchCount': instance.afterStitchCount,
      'afterRowCount': instance.afterRowCount,
      'afterWidthCm': instance.afterWidthCm,
      'afterHeightCm': instance.afterHeightCm,
      'afterPhotoUrl': instance.afterPhotoUrl,
      'shrinkageRate': instance.shrinkageRate,
      'memo': instance.memo,
      'isPublic': instance.isPublic,
      'isArchived': instance.isArchived,
      'archivedDate': instance.archivedDate?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'projectId': instance.projectId,
      'isDirty': instance.isDirty,
    };
