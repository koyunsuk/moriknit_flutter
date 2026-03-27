import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'counter_model.freezed.dart';
part 'counter_model.g.dart';

@freezed
class CounterMark with _$CounterMark {
  const factory CounterMark({
    required DateTime timestamp,
    @Default(0) int stitchCount,
    @Default(0) int rowCount,
    @Default('') String note,
  }) = _CounterMark;

  factory CounterMark.fromJson(Map<String, dynamic> json) => _$CounterMarkFromJson(json);
}

@freezed
class CounterModel with _$CounterModel {
  const factory CounterModel({
    required String id,
    required String uid,
    required String name,
    @Default('') String projectId,
    @Default(0) int stitchCount,
    @Default(0) int rowCount,
    @Default(0) int targetStitchCount,
    @Default(0) int targetRowCount,
    @Default([]) List<CounterMark> marks,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
  }) = _CounterModel;

  factory CounterModel.fromJson(Map<String, dynamic> json) => _$CounterModelFromJson(json);

  factory CounterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CounterModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory CounterModel.empty({required String uid, String name = 'New Counter'}) {
    return CounterModel(
      id: '',
      uid: uid,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension CounterCalculations on CounterModel {
  double get stitchProgress => targetStitchCount > 0 ? (stitchCount / targetStitchCount).clamp(0.0, 1.0) : 0.0;
  double get rowProgress => targetRowCount > 0 ? (rowCount / targetRowCount).clamp(0.0, 1.0) : 0.0;
  bool get hasTargets => targetStitchCount > 0 || targetRowCount > 0;
}
