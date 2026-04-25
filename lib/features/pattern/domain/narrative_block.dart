// lib/features/pattern/domain/narrative_block.dart
//
// 서술형 블록 — 도안의 서술형 텍스트를 줄 단위 원자로 분해한 구조.
// 섹션(=단계로그)에 속하거나, 반복구간(RepeatRegion)에 연결될 수 있습니다.

import 'package:uuid/uuid.dart';

class NarrativeBlock {
  final String id;
  final String text;
  final int order;

  /// 소속 섹션 ID — 프로젝트 단계로그와 미러링되는 상위 그룹
  final String? sectionId;

  /// 연결된 반복구간 ID — 같은 ID를 공유하는 블록들은 하나의 반복 단위
  final String? repeatRegionId;

  const NarrativeBlock({
    required this.id,
    required this.text,
    required this.order,
    this.sectionId,
    this.repeatRegionId,
  });

  NarrativeBlock copyWith({
    String? text,
    int? order,
    Object? sectionId = _sentinel,
    Object? repeatRegionId = _sentinel,
  }) {
    return NarrativeBlock(
      id: id,
      text: text ?? this.text,
      order: order ?? this.order,
      sectionId: identical(sectionId, _sentinel)
          ? this.sectionId
          : sectionId as String?,
      repeatRegionId: identical(repeatRegionId, _sentinel)
          ? this.repeatRegionId
          : repeatRegionId as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'order': order,
        if (sectionId != null) 'sectionId': sectionId,
        if (repeatRegionId != null) 'repeatRegionId': repeatRegionId,
      };

  factory NarrativeBlock.fromMap(Map<String, dynamic> m) => NarrativeBlock(
        id: (m['id'] as String?) ?? const Uuid().v4(),
        text: (m['text'] as String?) ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
        sectionId: m['sectionId'] as String?,
        repeatRegionId: m['repeatRegionId'] as String?,
      );

  factory NarrativeBlock.create({
    required String text,
    int order = 0,
    String? sectionId,
    String? repeatRegionId,
  }) =>
      NarrativeBlock(
        id: const Uuid().v4(),
        text: text,
        order: order,
        sectionId: sectionId,
        repeatRegionId: repeatRegionId,
      );

  static const Object _sentinel = Object();

  /// 통짜 문자열 → 블록 리스트 변환 (줄 단위 분리, 빈 줄 skip)
  /// 호환 레이어: 기존 `narrativeText` 필드만 있는 도안을 로드할 때 사용.
  static List<NarrativeBlock> fromText(String text) {
    if (text.isEmpty) return const [];
    final lines = text.split('\n');
    final blocks = <NarrativeBlock>[];
    int order = 0;
    for (final raw in lines) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      blocks.add(NarrativeBlock(
        id: const Uuid().v4(),
        text: t,
        order: order,
      ));
      order++;
    }
    return blocks;
  }

  /// 블록 리스트 → 통짜 문자열 변환 (order 순으로 줄바꿈 조인)
  /// 호환 레이어: `narrativeText` 필드 유지를 위한 역변환.
  static String toText(List<NarrativeBlock> blocks) {
    if (blocks.isEmpty) return '';
    final sorted = [...blocks]..sort((a, b) => a.order.compareTo(b.order));
    return sorted.map((b) => b.text).join('\n');
  }

  /// 통짜 텍스트 편집 결과를 기존 블록 리스트와 대조하여 ID를 최대한 보존.
  ///
  /// 원칙: 블록 ID == 단계로그 식별자. 텍스트 편집 시에도 보존되어야 함.
  ///
  /// 매칭 규칙 (greedy):
  /// - 기존 블록과 텍스트가 정확히 같고 아직 매칭되지 않았으면 → 기존 ID·sectionId·repeatRegionId 유지
  /// - 기존 블록과 순서상 대응되며 일부 문자가 수정된 경우 → 기존 ID 유지, 텍스트만 업데이트
  /// - 매칭되지 않으면 → 새 ID 생성
  ///
  /// order는 새 텍스트의 줄 순서에 맞게 재설정됨.
  static List<NarrativeBlock> reconcile(
    String newText,
    List<NarrativeBlock> oldBlocks,
  ) {
    if (newText.isEmpty) return const [];

    final newLines = newText
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // 기존 블록: order 기준 정렬
    final sortedOld = [...oldBlocks]..sort((a, b) => a.order.compareTo(b.order));
    final usedIds = <String>{};

    // 1단계: 정확 텍스트 매칭 우선
    final resultByIndex = List<NarrativeBlock?>.filled(newLines.length, null);

    // 텍스트 → 기존 블록 매핑 (중복 텍스트 대응: 큐)
    final oldByText = <String, List<NarrativeBlock>>{};
    for (final b in sortedOld) {
      oldByText.putIfAbsent(b.text, () => []).add(b);
    }

    for (int i = 0; i < newLines.length; i++) {
      final line = newLines[i];
      final candidates = oldByText[line];
      if (candidates != null && candidates.isNotEmpty) {
        // 아직 사용 안 된 기존 블록 소비
        final matched = candidates.removeAt(0);
        if (!usedIds.contains(matched.id)) {
          usedIds.add(matched.id);
          resultByIndex[i] = matched.copyWith(order: i);
        }
      }
    }

    // 2단계: 정확 매칭 안 된 줄 처리 — 순서 인접 기반 fuzzy 매칭으로 ID 유지 시도
    // 각 미매칭 줄에 대해, 아직 사용 안 된 기존 블록 중 순서상 가장 가까운 것과 매칭
    final unusedOld = sortedOld.where((b) => !usedIds.contains(b.id)).toList();
    int oldCursor = 0;
    for (int i = 0; i < newLines.length; i++) {
      if (resultByIndex[i] != null) continue;
      if (oldCursor >= unusedOld.length) break;

      // 남은 미사용 기존 블록 중 순서상 다음 후보
      final candidate = unusedOld[oldCursor];
      if (_isSimilar(newLines[i], candidate.text)) {
        // 유사하면 ID 유지하고 텍스트만 교체
        usedIds.add(candidate.id);
        resultByIndex[i] = candidate.copyWith(text: newLines[i], order: i);
        oldCursor++;
      }
    }

    // 3단계: 남은 미매칭 줄 → 새 블록 생성
    final result = <NarrativeBlock>[];
    for (int i = 0; i < newLines.length; i++) {
      final block = resultByIndex[i];
      if (block != null) {
        result.add(block);
      } else {
        result.add(NarrativeBlock(
          id: const Uuid().v4(),
          text: newLines[i],
          order: i,
        ));
      }
    }
    return result;
  }

  /// 단순 유사도: 길이·접두 일치로 판정. 오타·작은 수정 허용.
  /// 성능 우선 — Levenshtein 등 정교한 측정은 사용 안 함.
  static bool _isSimilar(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;

    // 한쪽 길이가 너무 다르면 유사 아님
    final la = a.length;
    final lb = b.length;
    final maxLen = la > lb ? la : lb;
    final minLen = la > lb ? lb : la;
    if (minLen < maxLen * 0.5) return false;

    // 앞 50% 이상 같으면 유사로 간주
    final prefix = minLen ~/ 2;
    if (prefix > 0 && a.substring(0, prefix) == b.substring(0, prefix)) {
      return true;
    }
    return false;
  }
}
