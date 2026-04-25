// lib/features/pattern/presentation/widgets/section_grouper.dart
//
// 서술형 블록을 섹션(=단계로그) 으로 그룹화하는 편집 UI.
// 이슈 #625 커밋 2 — 도안을 draft→complete 로 승격시키는 핵심 UI.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ai_pattern_section.dart';
import '../../domain/narrative_block.dart';
import '../../domain/pattern_chart.dart';

class SectionGrouper extends StatefulWidget {
  final PatternChart chart;
  final bool isKorean;
  final void Function(PatternChart updated) onChanged;

  const SectionGrouper({
    super.key,
    required this.chart,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  State<SectionGrouper> createState() => _SectionGrouperState();
}

class _SectionGrouperState extends State<SectionGrouper> {
  List<NarrativeBlock> get _blocks => widget.chart.narrativeBlocks;
  List<AiSection> get _sections => widget.chart.aiSections ?? const [];

  static const _autoKeywords = <String>[
    '목판', '몸판', '소매', '앞판', '뒤판', '칼라', '네크', '후드', '주머니', '마무리',
    'back', 'front', 'sleeve', 'collar', 'neck', 'hood', 'pocket', 'finishing',
    'cast on', 'bind off',
  ];

  void _updateChart({
    List<NarrativeBlock>? blocks,
    List<AiSection>? sections,
  }) {
    final nextBlocks = blocks ?? _blocks;
    final nextSections = sections ?? _sections;
    widget.onChanged(
      widget.chart.copyWith(
        narrativeBlocks: nextBlocks,
        aiSections: nextSections,
        narrativeText: NarrativeBlock.toText(nextBlocks),
      ),
    );
  }

  Future<void> _addSection() async {
    final title = await _promptTitle(
      initialTitle: '',
      initialTitleKo: '',
    );
    if (title == null) return;
    final newSection = AiSection(
      id: const Uuid().v4(),
      title: title.en.isEmpty ? title.ko : title.en,
      titleKo: title.ko.isEmpty ? null : title.ko,
      steps: const [],
    );
    _updateChart(sections: [..._sections, newSection]);
  }

  Future<void> _editSection(AiSection sec) async {
    final result = await _promptTitle(
      initialTitle: sec.title,
      initialTitleKo: sec.titleKo ?? '',
    );
    if (result == null) return;
    final updated = sec.copyWith(
      title: result.en.isEmpty ? result.ko : result.en,
      titleKo: result.ko.isEmpty ? null : result.ko,
    );
    _updateChart(
      sections: [
        for (final s in _sections) s.id == sec.id ? updated : s,
      ],
    );
  }

  void _deleteSection(AiSection sec) {
    _updateChart(
      sections: _sections.where((s) => s.id != sec.id).toList(),
      blocks: _blocks
          .map((b) => b.sectionId == sec.id
              ? b.copyWith(sectionId: null)
              : b)
          .toList(),
    );
  }

  void _assignBlockToSection(NarrativeBlock block, String? sectionId) {
    _updateChart(
      blocks: _blocks
          .map((b) => b.id == block.id
              ? b.copyWith(sectionId: sectionId)
              : b)
          .toList(),
    );
  }

  /// 이슈 #625 커밋 3 — 블록을 반복구간에 배정
  void _assignBlockToRegion(NarrativeBlock block, String? regionId) {
    _updateChart(
      blocks: _blocks
          .map((b) => b.id == block.id
              ? b.copyWith(repeatRegionId: regionId)
              : b)
          .toList(),
    );
  }

  String _regionDisplayLabel(RepeatRegion r) {
    final name = widget.isKorean ? (r.labelKo ?? r.label ?? '') : (r.label ?? r.labelKo ?? '');
    if (name.isEmpty) {
      return widget.isKorean
          ? '×${r.repeatCount} (${r.startRow + 1}~${r.endRow + 1}단)'
          : '×${r.repeatCount} (rows ${r.startRow + 1}~${r.endRow + 1})';
    }
    return '$name ×${r.repeatCount}';
  }

  /// 키워드 시작 블록을 자동으로 섹션 경계로 인식
  void _autoDetectSections() {
    final newSections = <AiSection>[..._sections];
    final newBlocks = <NarrativeBlock>[];
    AiSection? currentSection;

    for (final block in _blocks) {
      final lower = block.text.toLowerCase().trim();
      final matched = _autoKeywords.firstWhere(
        (k) => lower.startsWith(k.toLowerCase()),
        orElse: () => '',
      );
      if (matched.isNotEmpty) {
        // 이 블록이 새 섹션 시작
        final existing = newSections.firstWhere(
          (s) => (s.titleKo ?? s.title).toLowerCase() == matched.toLowerCase(),
          orElse: () => AiSection(
            id: const Uuid().v4(),
            title: matched,
            titleKo: _isKoreanWord(matched) ? matched : null,
            steps: const [],
          ),
        );
        if (!newSections.any((s) => s.id == existing.id)) {
          newSections.add(existing);
        }
        currentSection = existing;
      }
      newBlocks.add(
        block.copyWith(sectionId: currentSection?.id),
      );
    }

    _updateChart(blocks: newBlocks, sections: newSections);
  }

  bool _isKoreanWord(String s) {
    return s.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3);
  }

  Future<_TitlePair?> _promptTitle({
    required String initialTitle,
    required String initialTitleKo,
  }) async {
    final koCtrl = TextEditingController(text: initialTitleKo);
    final enCtrl = TextEditingController(text: initialTitle);
    final result = await showDialog<_TitlePair>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(
          widget.isKorean ? '섹션 이름' : 'Section Title',
          style: T.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: koCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '한글',
                hintText: '예: 목판',
                filled: true,
                fillColor: C.gx,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: enCtrl,
              decoration: InputDecoration(
                labelText: 'English',
                hintText: 'e.g. Back',
                filled: true,
                fillColor: C.gx,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ko = koCtrl.text.trim();
              final en = enCtrl.text.trim();
              if (ko.isEmpty && en.isEmpty) return;
              Navigator.pop(ctx, _TitlePair(ko: ko, en: en));
            },
            child: Text(
              widget.isKorean ? '저장' : 'Save',
              style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            widget.isKorean
                ? '서술형 편집 탭에서 도안 내용을 먼저 입력해 주세요.\n줄 단위로 블록이 자동 생성되며, 여기서 섹션으로 묶을 수 있어요.'
                : 'Please enter narrative content first.\nBlocks are created per line and can be grouped into sections here.',
            style: T.caption.copyWith(color: C.mu, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: _buildBlockList()),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 개념 안내: 블록 = 단계로그 상세설명
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: C.lvL,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.lv.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: C.lvD),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.isKorean
                        ? '각 블록은 단계로그 상세설명 한 줄이고, 섹션으로 묶으면 프로젝트 단계로그에 자동 반영돼요.'
                        : 'Each block is one step detail. Grouping into sections mirrors into project step logs.',
                    style: T.caption.copyWith(color: C.lvD, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addSection,
                  icon: Icon(Icons.add_rounded, size: 18, color: C.lvD),
                  label: Text(
                    widget.isKorean ? '섹션 추가' : 'Add Section',
                    style: TextStyle(color: C.lvD, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: C.lv),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _autoDetectSections,
                  icon: Icon(Icons.auto_awesome_rounded, size: 18, color: C.pkD),
                  label: Text(
                    widget.isKorean ? '자동 감지' : 'Auto-Detect',
                    style: TextStyle(color: C.pkD, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: C.pk),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockList() {
    final sortedBlocks = [..._blocks]..sort((a, b) => a.order.compareTo(b.order));
    final children = <Widget>[];
    String? lastSectionId = '__unset__';

    for (final block in sortedBlocks) {
      // 섹션 헤더가 바뀌는 지점에 헤더 삽입
      if (block.sectionId != lastSectionId) {
        final sec = block.sectionId == null
            ? null
            : _sections.firstWhere(
                (s) => s.id == block.sectionId,
                orElse: () => AiSection(
                  id: block.sectionId!,
                  title: '?',
                  steps: const [],
                ),
              );
        children.add(_buildSectionHeader(sec));
        lastSectionId = block.sectionId;
      }
      children.add(_buildBlockRow(block));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: children,
    );
  }

  Widget _buildSectionHeader(AiSection? sec) {
    final isUnassigned = sec == null;
    final title = isUnassigned
        ? (widget.isKorean ? '미분류' : 'Unassigned')
        : (widget.isKorean
            ? (sec.titleKo ?? sec.title)
            : sec.title);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: isUnassigned ? C.bd2 : C.lv,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: T.body.copyWith(
                fontWeight: FontWeight.w700,
                color: isUnassigned ? C.mu : C.tx,
              ),
            ),
          ),
          if (!isUnassigned) ...[
            IconButton(
              onPressed: () => _editSection(sec),
              icon: Icon(Icons.edit_outlined, size: 18, color: C.mu),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              onPressed: () => _deleteSection(sec),
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.og),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockRow(NarrativeBlock block) {
    // 이 블록이 속한 반복구간 레이블 표시용
    final region = block.repeatRegionId == null
        ? null
        : widget.chart.repeatRegions
            .where((r) => r.id == block.repeatRegionId)
            .firstOrNull;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: region != null ? C.pk.withValues(alpha: 0.4) : C.bd,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.text,
                  style: T.caption.copyWith(color: C.tx, height: 1.4),
                ),
              ),
              const SizedBox(width: 4),
              _buildRegionDropdown(block),
              _buildSectionDropdown(block),
            ],
          ),
          // 반복구간 배정된 블록은 하단에 배지 표시
          if (region != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.pkL,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, size: 11, color: C.pkD),
                  const SizedBox(width: 3),
                  Text(
                    _regionDisplayLabel(region),
                    style: T.caption.copyWith(
                      color: C.pkD,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegionDropdown(NarrativeBlock block) {
    final regions = widget.chart.repeatRegions;
    return PopupMenuButton<String?>(
      tooltip: widget.isKorean ? '반복구간 배정' : 'Assign Repeat',
      icon: Icon(
        block.repeatRegionId == null
            ? Icons.repeat_outlined
            : Icons.repeat_rounded,
        size: 18,
        color: block.repeatRegionId == null ? C.mu : C.pkD,
      ),
      onSelected: (value) =>
          _assignBlockToRegion(block, value == '__none__' ? null : value),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: '__none__',
          child: Row(
            children: [
              Icon(Icons.repeat_outlined, size: 16, color: C.mu),
              const SizedBox(width: 8),
              Text(
                widget.isKorean ? '반복 없음' : 'No Repeat',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ),
        ),
        if (regions.isEmpty)
          PopupMenuItem<String?>(
            enabled: false,
            child: Text(
              widget.isKorean
                  ? '반복구간이 없습니다.\n차트 툴바에서 먼저 추가해 주세요.'
                  : 'No repeats yet.\nAdd from chart toolbar first.',
              style: T.caption.copyWith(color: C.mu, fontSize: 10),
            ),
          ),
        for (final r in regions)
          PopupMenuItem<String?>(
            value: r.id,
            child: Row(
              children: [
                Icon(Icons.repeat_rounded, size: 16, color: C.pkD),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _regionDisplayLabel(r),
                    style: T.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionDropdown(NarrativeBlock block) {
    return PopupMenuButton<String?>(
      tooltip: widget.isKorean ? '섹션 할당' : 'Assign Section',
      icon: Icon(
        block.sectionId == null
            ? Icons.label_off_outlined
            : Icons.label_rounded,
        size: 18,
        color: block.sectionId == null ? C.mu : C.lv,
      ),
      onSelected: (value) =>
          _assignBlockToSection(block, value == '__none__' ? null : value),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: '__none__',
          child: Row(
            children: [
              Icon(Icons.label_off_outlined, size: 16, color: C.mu),
              const SizedBox(width: 8),
              Text(
                widget.isKorean ? '미분류' : 'Unassigned',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ),
        ),
        for (final s in _sections)
          PopupMenuItem<String?>(
            value: s.id,
            child: Row(
              children: [
                Icon(Icons.label_rounded, size: 16, color: C.lv),
                const SizedBox(width: 8),
                Text(
                  widget.isKorean ? (s.titleKo ?? s.title) : s.title,
                  style: T.caption,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TitlePair {
  final String ko;
  final String en;
  const _TitlePair({required this.ko, required this.en});
}
