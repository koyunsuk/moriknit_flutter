@Deprecated('Phase E3 (#687) — step_blueprints/kind=template 로 통합 (마이그레이션 완료). Phase E4에서 삭제 예정.')
class UserTemplate {
  final String id;
  final String title;
  final String description;
  final List<String> stepTitles;
  final List<String> stepDescs;
  final String photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserTemplate({
    required this.id,
    required this.title,
    this.description = '',
    required this.stepTitles,
    required this.stepDescs,
    this.photoUrl = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory UserTemplate.fromMap(Map<String, dynamic> data, String id) {
    return UserTemplate(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      stepTitles: List<String>.from(data['stepTitles'] as List? ?? []),
      stepDescs: List<String>.from(data['stepDescs'] as List? ?? []),
      photoUrl: data['photoUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.tryParse(data['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'stepTitles': stepTitles,
        'stepDescs': stepDescs,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
