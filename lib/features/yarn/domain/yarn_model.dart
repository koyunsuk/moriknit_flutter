import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/firestore_json.dart';

part 'yarn_model.freezed.dart';
part 'yarn_model.g.dart';

@freezed
class YarnModel with _$YarnModel {
  const factory YarnModel({
    required String id,
    required String uid,
    @Default('') String brandName,
    @Default('') String name,
    @Default('') String color,
    @Default('') String weight,
    @Default(0) int amountGrams,
    @Default('') String memo,
    @Default('') String photoUrl,
    DateTime? purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
    @Default('') String material,
    @Default('') String yarnLength,
    @Default('') String lotNumber,
    @Default(0) int price,
    @Default('') String purchasePlace,
    @Default('') String colorCode,
  }) = _YarnModel;

  factory YarnModel.fromJson(Map<String, dynamic> json) =>
      _$YarnModelFromJson(json);

  factory YarnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return YarnModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory YarnModel.empty({required String uid}) => YarnModel(
        id: '',
        uid: uid,
        createdAt: DateTime.now(),
      );
}
