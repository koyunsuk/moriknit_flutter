import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'project_model.freezed.dart';
part 'project_model.g.dart';

enum ProjectStatus { planning, swatching, inProgress, blocking, finished }

extension ProjectStatusExt on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.swatching:
        return 'Swatching';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.blocking:
        return 'Blocked';
      case ProjectStatus.finished:
        return 'Finished';
    }
  }

  String get koreanLabel {
    switch (this) {
      case ProjectStatus.planning:
        return '계획 중';
      case ProjectStatus.swatching:
        return '스와치 중';
      case ProjectStatus.inProgress:
        return '진행 중';
      case ProjectStatus.blocking:
        return '보류';
      case ProjectStatus.finished:
        return '완료';
    }
  }

  String localizedLabel(bool isKorean) => isKorean ? koreanLabel : label;

  String get value {
    switch (this) {
      case ProjectStatus.planning:
        return 'planning';
      case ProjectStatus.swatching:
        return 'swatching';
      case ProjectStatus.inProgress:
        return 'in_progress';
      case ProjectStatus.blocking:
        return 'blocking';
      case ProjectStatus.finished:
        return 'finished';
    }
  }

  static ProjectStatus fromValue(String value) {
    switch (value) {
      case 'swatching':
        return ProjectStatus.swatching;
      case 'in_progress':
        return ProjectStatus.inProgress;
      case 'blocking':
        return ProjectStatus.blocking;
      case 'finished':
        return ProjectStatus.finished;
      default:
        return ProjectStatus.planning;
    }
  }
}

@freezed
class ProjectModel with _$ProjectModel {
  const factory ProjectModel({
    required String id,
    required String uid,
    required String title,
    @Default('') String description,
    @Default('planning') String status,
    @Default(0.0) double progressPercent,
    @Default('') String yarnBrandId,
    @Default('') String yarnBrandName,
    @Default('') String yarnName,
    @Default('') String yarnColor,
    @Default('') String yarnWeight,
    @Default(0.0) double needleSize,
    @Default('') String needleBrandName,
    @Default('') String swatchId,
    @Default([]) List<String> counterIds,
    @Default([]) List<String> photoUrls,
    @Default('') String coverPhotoUrl,
    @Default('') String memo,
    DateTime? startDate,
    DateTime? targetDate,
    DateTime? finishDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
    @Default(0) int completedStepCount,
    @Default(0) int totalStepCount,
  }) = _ProjectModel;

  factory ProjectModel.fromJson(Map<String, dynamic> json) => _$ProjectModelFromJson(json);

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory ProjectModel.empty({required String uid}) {
    return ProjectModel(
      id: '',
      uid: uid,
      title: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension ProjectModelExt on ProjectModel {
  ProjectStatus get statusEnum => ProjectStatusExt.fromValue(status);
  bool get isFinished => status == ProjectStatus.finished.value;
  String get progressDisplay => '${progressPercent.toStringAsFixed(0)}%';
}
