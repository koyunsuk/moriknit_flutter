import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'needle_model.freezed.dart';
part 'needle_model.g.dart';

@freezed
class NeedleModel with _$NeedleModel {
  const factory NeedleModel({
    required String id,
    required String uid,
    required double size,
    @Default('') String brandName,
    @Default('') String name,
    @Default('bamboo') String material,
    @Default('straight') String type,
    @Default(1) int quantity,
    @Default('') String memo,
    @Default('') String photoUrl,
    @Default(0) int price,
    @Default('') String purchasePlace,
    DateTime? purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
  }) = _NeedleModel;

  factory NeedleModel.fromJson(Map<String, dynamic> json) => _$NeedleModelFromJson(json);

  factory NeedleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NeedleModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory NeedleModel.empty({required String uid}) {
    return NeedleModel(
      id: '',
      uid: uid,
      size: 3.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension NeedleModelExt on NeedleModel {
  String get sizeDisplay {
    if (size == 0.0) return '셋트';
    return size % 1 == 0 ? '${size.toInt()}mm' : '${size}mm';
  }

  String localizedMaterialLabel(bool isKorean) {
    switch (material) {
      case 'metal':
        return isKorean ? '금속' : 'Metal';
      case 'wood':
        return isKorean ? '나무' : 'Wood';
      case 'plastic':
        return isKorean ? '플라스틱' : 'Plastic';
      default:
        return isKorean ? '대나무' : 'Bamboo';
    }
  }

  String get materialLabel {
    return localizedMaterialLabel(false);
  }

  String localizedTypeLabel(bool isKorean) {
    switch (type) {
      case 'circular':
        return isKorean ? '줄바늘' : 'Circular';
      case 'dpn':
        return isKorean ? '막대바늘' : 'Double-pointed';
      case 'interchangeable':
        return isKorean ? '조립식바늘' : 'Interchangeable';
      case 'cable':
        return isKorean ? '케이블 바늘' : 'Cable';
      default:
        return isKorean ? '일반바늘' : 'Straight';
    }
  }

  String get typeLabel {
    return localizedTypeLabel(false);
  }
}
