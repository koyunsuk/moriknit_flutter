// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'needle_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NeedleModelImpl _$$NeedleModelImplFromJson(Map<String, dynamic> json) =>
    _$NeedleModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      size: (json['size'] as num).toDouble(),
      brandName: json['brandName'] as String? ?? '',
      material: json['material'] as String? ?? 'bamboo',
      type: json['type'] as String? ?? 'straight',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      memo: json['memo'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDirty: json['isDirty'] as bool? ?? false,
    );

Map<String, dynamic> _$$NeedleModelImplToJson(_$NeedleModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'size': instance.size,
      'brandName': instance.brandName,
      'material': instance.material,
      'type': instance.type,
      'quantity': instance.quantity,
      'memo': instance.memo,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
    };
