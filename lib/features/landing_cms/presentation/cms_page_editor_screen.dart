// 이슈 — 랜딩 CMS: 페이지 편집기.
//
// - 섹션 목록 (ReorderableListView)
// - 섹션 추가 / 삭제 / 편집(시트)
// - 상태 배지 + 발행 / 초안되돌리기
//
// 어드민 콘솔(다크 테마) 내부에서 렌더링되므로 별도 Scaffold 사용 안 함.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/landing_cms_repository.dart';
import '../domain/landing_page.dart';
import 'cms_section_editor_sheet.dart';

class CmsPageEditorScreen extends ConsumerStatefulWidget {
  final String pageId;
  final String pageTitle;
  final VoidCallback? onBack;

  const CmsPageEditorScreen({
    super.key,
    required this.pageId,
    required this.pageTitle,
    this.onBack,
  });

  @override
  ConsumerState<CmsPageEditorScreen> createState() =>
      _CmsPageEditorScreenState();
}

class _CmsPageEditorScreenState extends ConsumerState<CmsPageEditorScreen> {
  LandingPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(landingCmsRepositoryProvider);
      final page = await repo.fetchPage(widget.pageId);
      setState(() {
        _page = page ??
            LandingPage.empty(widget.pageId, title: widget.pageTitle);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _savePage() async {
    final page = _page;
    if (page == null) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '저장하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          await ref.read(landingCmsRepositoryProvider).savePage(page);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '저장됐어요.');
      // 새 updatedAt 가져오기.
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _publish() async {
    final ok = await _confirm(
      title: '발행하시겠어요?',
      body: '현재 저장된 내용이 즉시 공개됩니다.',
      okLabel: '발행',
    );
    if (!ok || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '발행하는 중입니다.',
        task: () async {
          await ref.read(landingCmsRepositoryProvider).publishPage(widget.pageId);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '발행됐어요.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _revert() async {
    final ok = await _confirm(
      title: '초안으로 되돌리시겠어요?',
      body: '발행이 해제되고 코드 fallback이 노출됩니다.',
      okLabel: '되돌리기',
    );
    if (!ok || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '되돌리는 중입니다.',
        task: () async {
          await ref.read(landingCmsRepositoryProvider).revertToDraft(widget.pageId);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '초안으로 되돌렸어요.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    String okLabel = '확인',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
            ),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _addSection() async {
    final newSection = LandingSection(
      id: 'sec_${DateTime.now().microsecondsSinceEpoch}',
      type: SectionType.hero,
      order: (_page?.sections.length ?? 0),
      content: const {},
    );
    final edited = await showCmsSectionEditorSheet(context, initial: newSection);
    if (!mounted) return;
    if (edited == null || _page == null) return;
    final next = List<LandingSection>.from(_page!.sections)..add(edited);
    setState(() {
      _page = _page!.copyWith(sections: _reindex(next));
    });
  }

  void _editSection(LandingSection section) async {
    final edited =
        await showCmsSectionEditorSheet(context, initial: section);
    if (!mounted) return;
    if (edited == null || _page == null) return;
    final next = _page!.sections
        .map((s) => s.id == section.id ? edited : s)
        .toList();
    setState(() {
      _page = _page!.copyWith(sections: _reindex(next));
    });
  }

  void _deleteSection(LandingSection section) async {
    final ok = await _confirm(
      title: '섹션을 삭제하시겠어요?',
      body: '되돌릴 수 없습니다.',
      okLabel: '삭제',
    );
    if (!mounted) return;
    if (!ok || _page == null) return;
    final next = _page!.sections.where((s) => s.id != section.id).toList();
    setState(() {
      _page = _page!.copyWith(sections: _reindex(next));
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_page == null) return;
    final list = List<LandingSection>.from(_page!.sections);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() {
      _page = _page!.copyWith(sections: _reindex(list));
    });
  }

  List<LandingSection> _reindex(List<LandingSection> list) {
    final out = <LandingSection>[];
    for (var i = 0; i < list.length; i++) {
      out.add(list[i].copyWith(order: i));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('로드 실패: $_error',
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    final page = _page!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(page),
        const Divider(height: 1, color: Color(0xFF334155)),
        Expanded(child: _sectionList(page)),
      ],
    );
  }

  Widget _toolbar(LandingPage page) {
    final published = page.status == PublishStatus.published;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, color: Color(0xFFCBD5E1)),
            tooltip: '목록으로',
          ),
          const SizedBox(width: 4),
          Text(
            '${page.title}  ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF8FAFC),
            ),
          ),
          _statusBadge(published),
          const SizedBox(width: 12),
          Text('id=${page.id}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('섹션 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE2E8F0),
              side: const BorderSide(color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _savePage,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('저장(초안)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          if (published)
            OutlinedButton.icon(
              onPressed: _revert,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('초안으로'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFBBF24),
                side: const BorderSide(color: Color(0xFFFBBF24)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _publish,
              icon: const Icon(Icons.public, size: 18),
              label: const Text('발행'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool published) {
    final color = published ? const Color(0xFF22C55E) : const Color(0xFFFBBF24);
    final label = published ? '발행됨' : '초안';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionList(LandingPage page) {
    if (page.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.web_asset_off,
                  size: 36, color: Color(0xFF64748B)),
              const SizedBox(height: 12),
              const Text(
                '아직 섹션이 없어요',
                style: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 4),
              Text(
                '"섹션 추가" 버튼으로 시작해 보세요.\n저장 전까지는 기존 랜딩 코드가 그대로 노출됩니다.',
                textAlign: TextAlign.center,
                style: T.caption.copyWith(color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: page.sections.length,
      buildDefaultDragHandles: false,
      onReorder: _reorder,
      itemBuilder: (context, index) {
        final s = page.sections[index];
        return _SectionRow(
          key: ValueKey(s.id),
          index: index,
          section: s,
          onEdit: () => _editSection(s),
          onDelete: () => _deleteSection(s),
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  final int index;
  final LandingSection section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SectionRow({
    super.key,
    required this.index,
    required this.section,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                section.type.label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE2E8F0)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _preview(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFCBD5E1), fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF94A3B8)),
              tooltip: '편집',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFFB7185)),
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }

  String _preview(LandingSection s) {
    final title = (s.content['title'] as String?)?.trim();
    if (title != null && title.isNotEmpty) return title;
    final body = (s.content['body'] as String?)?.trim();
    if (body != null && body.isNotEmpty) {
      return body.length > 40 ? '${body.substring(0, 40)}...' : body;
    }
    final items = s.content['items'];
    if (items is List) return '${items.length}개 항목';
    return '(빈 섹션)';
  }
}
