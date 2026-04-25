enum StepBlockType { text, stitchCount, patternLink }

class ProjectStep {
  final String id;
  final String name;
  final String description; // 소제목
  final bool isDone;
  final String note;
  final int order;
  final DateTime createdAt;
  final DateTime? doneAt;
  final String? photoUrl;
  final int targetRow; // 0 = 미설정
  final StepBlockType blockType;
  // 이슈 #627 — 도안 섹션에서 미러링된 단계 추적용 (선택 필드)
  final String? sourceSectionId;
  final String? sourcePatternChartId;

  const ProjectStep({
    required this.id,
    required this.name,
    this.description = '',
    this.isDone = false,
    this.note = '',
    this.order = 0,
    required this.createdAt,
    this.doneAt,
    this.photoUrl,
    this.targetRow = 0,
    this.blockType = StepBlockType.text,
    this.sourceSectionId,
    this.sourcePatternChartId,
  });

  factory ProjectStep.fromMap(Map<String, dynamic> data, String id) {
    return ProjectStep(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isDone: data['isDone'] as bool? ?? false,
      note: data['note'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      doneAt: data['doneAt'] != null ? DateTime.tryParse(data['doneAt'] as String) : null,
      photoUrl: data['photoUrl'] as String?,
      targetRow: (data['targetRow'] as num?)?.toInt() ?? 0,
      blockType: StepBlockType.values.firstWhere(
        (e) => e.name == (data['blockType'] as String?),
        orElse: () => StepBlockType.text,
      ),
      sourceSectionId: data['sourceSectionId'] as String?,
      sourcePatternChartId: data['sourcePatternChartId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'isDone': isDone,
        'note': note,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
        'photoUrl': photoUrl,
        'targetRow': targetRow,
        'blockType': blockType.name,
        if (sourceSectionId != null) 'sourceSectionId': sourceSectionId,
        if (sourcePatternChartId != null) 'sourcePatternChartId': sourcePatternChartId,
      };

  ProjectStep copyWith({
    bool? isDone,
    String? description,
    String? note,
    DateTime? doneAt,
    Object? photoUrl = _sentinel,
    int? targetRow,
    StepBlockType? blockType,
  }) {
    return ProjectStep(
      id: id,
      name: name,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      order: order,
      createdAt: createdAt,
      doneAt: doneAt ?? this.doneAt,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      targetRow: targetRow ?? this.targetRow,
      blockType: blockType ?? this.blockType,
      sourceSectionId: sourceSectionId,
      sourcePatternChartId: sourcePatternChartId,
    );
  }
}

const Object _sentinel = Object();
