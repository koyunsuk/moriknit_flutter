import 'package:cloud_firestore/cloud_firestore.dart';

class PatternStep {
  final String id;
  final String instruction;
  final bool isCompleted;

  const PatternStep({
    required this.id,
    required this.instruction,
    this.isCompleted = false,
  });

  PatternStep copyWith({bool? isCompleted}) => PatternStep(
        id: id,
        instruction: instruction,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'instruction': instruction,
        'isCompleted': isCompleted,
      };

  factory PatternStep.fromMap(Map<String, dynamic> m) => PatternStep(
        id: m['id'] as String? ?? '',
        instruction: m['instruction'] as String? ?? '',
        isCompleted: m['isCompleted'] as bool? ?? false,
      );
}

class PatternSection {
  final String id;
  final String title;
  final List<PatternStep> steps;

  const PatternSection({
    required this.id,
    required this.title,
    required this.steps,
  });

  PatternSection copyWith({List<PatternStep>? steps}) => PatternSection(
        id: id,
        title: title,
        steps: steps ?? this.steps,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'steps': steps.map((s) => s.toMap()).toList(),
      };

  factory PatternSection.fromMap(Map<String, dynamic> m) => PatternSection(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        steps: ((m['steps'] as List?) ?? [])
            .map((s) => PatternStep.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );

  int get totalSteps => steps.length;
  int get completedSteps => steps.where((s) => s.isCompleted).length;
}

class ParsedPattern {
  final String id;
  final String title;
  final String materials;
  final String gauge;
  final String sizes;
  final String sourceFileName;
  final String storageUrl;
  final DateTime createdAt;
  final List<PatternSection> sections;

  const ParsedPattern({
    required this.id,
    required this.title,
    required this.materials,
    required this.gauge,
    required this.sizes,
    required this.sourceFileName,
    required this.storageUrl,
    required this.createdAt,
    required this.sections,
  });

  int get totalSteps => sections.fold(0, (acc, s) => acc + s.totalSteps);
  int get completedSteps => sections.fold(0, (acc, s) => acc + s.completedSteps);
  double get progress => totalSteps == 0 ? 0 : completedSteps / totalSteps;

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'materials': materials,
        'gauge': gauge,
        'sizes': sizes,
        'sourceFileName': sourceFileName,
        'storageUrl': storageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'sections': sections.map((s) => s.toMap()).toList(),
      };

  factory ParsedPattern.fromFirestore(String id, Map<String, dynamic> data) {
    return ParsedPattern(
      id: id,
      title: data['title'] as String? ?? '제목 없음',
      materials: data['materials'] as String? ?? '',
      gauge: data['gauge'] as String? ?? '',
      sizes: data['sizes'] as String? ?? '',
      sourceFileName: data['sourceFileName'] as String? ?? '',
      storageUrl: data['storageUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sections: ((data['sections'] as List?) ?? [])
          .map((s) => PatternSection.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  ParsedPattern copyWithSections(List<PatternSection> sections) => ParsedPattern(
        id: id,
        title: title,
        materials: materials,
        gauge: gauge,
        sizes: sizes,
        sourceFileName: sourceFileName,
        storageUrl: storageUrl,
        createdAt: createdAt,
        sections: sections,
      );
}
