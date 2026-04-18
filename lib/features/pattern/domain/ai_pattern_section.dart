import 'package:uuid/uuid.dart';

/// AI 변환 도안의 단일 단계
class AiStep {
  final String id;
  final String instruction;
  final bool isCompleted;

  const AiStep({
    required this.id,
    required this.instruction,
    this.isCompleted = false,
  });

  AiStep copyWith({String? instruction, bool? isCompleted}) {
    return AiStep(
      id: id,
      instruction: instruction ?? this.instruction,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'instruction': instruction,
        'isCompleted': isCompleted,
      };

  factory AiStep.fromMap(Map<String, dynamic> m) => AiStep(
        id: m['id'] as String? ?? const Uuid().v4(),
        instruction: m['instruction'] as String? ?? '',
        isCompleted: m['isCompleted'] as bool? ?? false,
      );

  factory AiStep.create({required String instruction}) => AiStep(
        id: const Uuid().v4(),
        instruction: instruction,
      );
}

/// AI 변환 도안의 섹션 (여러 단계 포함)
class AiSection {
  final String id;
  final String title;
  final List<AiStep> steps;

  const AiSection({
    required this.id,
    required this.title,
    required this.steps,
  });

  AiSection copyWith({String? title, List<AiStep>? steps}) {
    return AiSection(
      id: id,
      title: title ?? this.title,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'steps': steps.map((s) => s.toMap()).toList(),
      };

  factory AiSection.fromMap(Map<String, dynamic> m) => AiSection(
        id: m['id'] as String? ?? const Uuid().v4(),
        title: m['title'] as String? ?? '',
        steps: (m['steps'] as List<dynamic>?)
                ?.map((s) => AiStep.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
      );

  factory AiSection.create({required String title}) => AiSection(
        id: const Uuid().v4(),
        title: title,
        steps: [],
      );
}
