/// 이슈 #687 — StepUnit 사용자 인스턴스 진행 상태.
/// 청사진(blueprint)일 때는 null, 프로젝트에 적용된 인스턴스만 값 보유.
class StepUnitProgress {
  final bool isDone;
  final DateTime? doneAt;
  final String? photoUrl;
  final String? note;
  final int currentRow;
  final String? linkedCounterId;

  const StepUnitProgress({
    this.isDone = false,
    this.doneAt,
    this.photoUrl,
    this.note,
    this.currentRow = 0,
    this.linkedCounterId,
  });

  Map<String, dynamic> toMap() => {
        'isDone': isDone,
        if (doneAt != null) 'doneAt': doneAt!.toIso8601String(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (note != null) 'note': note,
        'currentRow': currentRow,
        if (linkedCounterId != null) 'linkedCounterId': linkedCounterId,
      };

  factory StepUnitProgress.fromMap(Map<String, dynamic> m) => StepUnitProgress(
        isDone: m['isDone'] as bool? ?? false,
        doneAt: m['doneAt'] == null
            ? null
            : DateTime.tryParse(m['doneAt'] as String),
        photoUrl: m['photoUrl'] as String?,
        note: m['note'] as String?,
        currentRow: m['currentRow'] as int? ?? 0,
        linkedCounterId: m['linkedCounterId'] as String?,
      );
}
