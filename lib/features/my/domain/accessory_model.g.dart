// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accessory_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccessoryModelImpl _$$AccessoryModelImplFromJson(Map<String, dynamic> json) =>
    _$AccessoryModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      type: json['type'] as String? ?? 'other',
      brandName: json['brandName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toInt() ?? 0,
      purchasePlace: json['purchasePlace'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      purchaseDate: json['purchaseDate'] == null
          ? null
          : DateTime.parse(json['purchaseDate'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDirty: json['isDirty'] as bool? ?? false,
    );

Map<String, dynamic> _$$AccessoryModelImplToJson(
        _$AccessoryModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'type': instance.type,
      'brandName': instance.brandName,
      'name': instance.name,
      'quantity': instance.quantity,
      'price': instance.price,
      'purchasePlace': instance.purchasePlace,
      'memo': instance.memo,
      'photoUrl': instance.photoUrl,
      'purchaseDate': instance.purchaseDate?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
    };
