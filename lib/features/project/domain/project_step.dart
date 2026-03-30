class ProjectStep {
  final String id;
  final String name;
  final bool isDone;
  final String note;
  final int order;
  final DateTime createdAt;
  final DateTime? doneAt;
  final String? photoUrl;

  const ProjectStep({
    required this.id,
    required this.name,
    this.isDone = false,
    this.note = '',
    this.order = 0,
    required this.createdAt,
    this.doneAt,
    this.photoUrl,
  });

  factory ProjectStep.fromMap(Map<String, dynamic> data, String id) {
    return ProjectStep(
      id: id,
      name: data['name'] as String? ?? '',
      isDone: data['isDone'] as bool? ?? false,
      note: data['note'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      doneAt: data['doneAt'] != null ? DateTime.tryParse(data['doneAt'] as String) : null,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isDone': isDone,
        'note': note,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
        'photoUrl': photoUrl,
      };

  ProjectStep copyWith({
    bool? isDone,
    String? note,
    DateTime? doneAt,
    Object? photoUrl = _sentinel,
  }) {
    return ProjectStep(
      id: id,
      name: name,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      order: order,
      createdAt: createdAt,
      doneAt: doneAt ?? this.doneAt,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
    );
  }
}

const Object _sentinel = Object();
