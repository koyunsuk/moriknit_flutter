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
  /// 이슈 #821 — 도안 1개당 카운터 1개 정책.
  ///
  /// 카운터는 도안 단계(섹션) 전환의 진행 상태도 추적함.
  /// [currentStepIndex] = 현재 진행 중인 도안 섹션의 인덱스(0-based).
  /// projectStepId는 첫 단계 ID로 시작하지만 사용자가 단계를 전환하면
  /// currentStepIndex만 변경되고 projectStepId는 그대로 유지됨(앵커 역할).
  /// 더 세분화된 카운터가 필요하면 사용자가 단계 화면에서 [추가 카운터] 수동 생성.
  const factory CounterModel({
    required String id,
    required String uid,
    required String name,
    @Default('') String projectId,
    @Default('') String projectStepId,
    @Default(0) int stitchCount,
    @Default(0) int rowCount,
    @Default(0) int targetStitchCount,
    @Default(0) int targetRowCount,
    @Default([]) List<CounterMark> marks,
    @Default('') String photoUrl,
    @Default('') String patternChartId,
    @Default('') String patternFileId,
    @Default(0) int currentStepIndex,
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
