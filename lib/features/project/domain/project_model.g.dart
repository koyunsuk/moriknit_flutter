// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProjectModelImpl _$$ProjectModelImplFromJson(Map<String, dynamic> json) =>
    _$ProjectModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'planning',
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      yarnBrandId: json['yarnBrandId'] as String? ?? '',
      yarnBrandName: json['yarnBrandName'] as String? ?? '',
      yarnName: json['yarnName'] as String? ?? '',
      yarnColor: json['yarnColor'] as String? ?? '',
      yarnWeight: json['yarnWeight'] as String? ?? '',
      needleSize: (json['needleSize'] as num?)?.toDouble() ?? 0.0,
      needleBrandName: json['needleBrandName'] as String? ?? '',
      swatchId: json['swatchId'] as String? ?? '',
      counterIds: (json['counterIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      coverPhotoUrl: json['coverPhotoUrl'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      targetDate: json['targetDate'] == null
          ? null
          : DateTime.parse(json['targetDate'] as String),
      finishDate: json['finishDate'] == null
          ? null
          : DateTime.parse(json['finishDate'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDirty: json['isDirty'] as bool? ?? false,
      completedStepCount: (json['completedStepCount'] as num?)?.toInt() ?? 0,
      totalStepCount: (json['totalStepCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ProjectModelImplToJson(_$ProjectModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'title': instance.title,
      'description': instance.description,
      'status': instance.status,
      'progressPercent': instance.progressPercent,
      'yarnBrandId': instance.yarnBrandId,
      'yarnBrandName': instance.yarnBrandName,
      'yarnName': instance.yarnName,
      'yarnColor': instance.yarnColor,
      'yarnWeight': instance.yarnWeight,
      'needleSize': instance.needleSize,
      'needleBrandName': instance.needleBrandName,
      'swatchId': instance.swatchId,
      'counterIds': instance.counterIds,
      'photoUrls': instance.photoUrls,
      'coverPhotoUrl': instance.coverPhotoUrl,
      'memo': instance.memo,
      'startDate': instance.startDate?.toIso8601String(),
      'targetDate': instance.targetDate?.toIso8601String(),
      'finishDate': instance.finishDate?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
      'completedStepCount': instance.completedStepCount,
      'totalStepCount': instance.totalStepCount,
    };
