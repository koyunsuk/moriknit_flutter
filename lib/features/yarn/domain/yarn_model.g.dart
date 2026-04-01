// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yarn_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$YarnModelImpl _$$YarnModelImplFromJson(Map<String, dynamic> json) =>
    _$YarnModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      brandName: json['brandName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      amountGrams: (json['amountGrams'] as num?)?.toInt() ?? 0,
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
      material: json['material'] as String? ?? '',
      yarnLength: json['yarnLength'] as String? ?? '',
      lotNumber: json['lotNumber'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      purchasePlace: json['purchasePlace'] as String? ?? '',
      colorCode: json['colorCode'] as String? ?? '',
    );

Map<String, dynamic> _$$YarnModelImplToJson(_$YarnModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'brandName': instance.brandName,
      'name': instance.name,
      'color': instance.color,
      'weight': instance.weight,
      'amountGrams': instance.amountGrams,
      'memo': instance.memo,
      'photoUrl': instance.photoUrl,
      'purchaseDate': instance.purchaseDate?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
      'material': instance.material,
      'yarnLength': instance.yarnLength,
      'lotNumber': instance.lotNumber,
      'price': instance.price,
      'purchasePlace': instance.purchasePlace,
      'colorCode': instance.colorCode,
    };
