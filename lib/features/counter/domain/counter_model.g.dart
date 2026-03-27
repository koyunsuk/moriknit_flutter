// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'counter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CounterMarkImpl _$$CounterMarkImplFromJson(Map<String, dynamic> json) =>
    _$CounterMarkImpl(
      timestamp: DateTime.parse(json['timestamp'] as String),
      stitchCount: (json['stitchCount'] as num?)?.toInt() ?? 0,
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String? ?? '',
    );

Map<String, dynamic> _$$CounterMarkImplToJson(_$CounterMarkImpl instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'stitchCount': instance.stitchCount,
      'rowCount': instance.rowCount,
      'note': instance.note,
    };

_$CounterModelImpl _$$CounterModelImplFromJson(Map<String, dynamic> json) =>
    _$CounterModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      name: json['name'] as String,
      projectId: json['projectId'] as String? ?? '',
      stitchCount: (json['stitchCount'] as num?)?.toInt() ?? 0,
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      targetStitchCount: (json['targetStitchCount'] as num?)?.toInt() ?? 0,
      targetRowCount: (json['targetRowCount'] as num?)?.toInt() ?? 0,
      marks: (json['marks'] as List<dynamic>?)
              ?.map((e) => CounterMark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDirty: json['isDirty'] as bool? ?? false,
    );

Map<String, dynamic> _$$CounterModelImplToJson(_$CounterModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'name': instance.name,
      'projectId': instance.projectId,
      'stitchCount': instance.stitchCount,
      'rowCount': instance.rowCount,
      'targetStitchCount': instance.targetStitchCount,
      'targetRowCount': instance.targetRowCount,
      'marks': instance.marks,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
    };
