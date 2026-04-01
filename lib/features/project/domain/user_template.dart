class UserTemplate {
  final String id;
  final String title;
  final String description;
  final List<String> stepTitles;
  final List<String> stepDescs;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserTemplate({
    required this.id,
    required this.title,
    this.description = '',
    required this.stepTitles,
    required this.stepDescs,
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
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.tryParse(data['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'stepTitles': stepTitles,
        'stepDescs': stepDescs,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
