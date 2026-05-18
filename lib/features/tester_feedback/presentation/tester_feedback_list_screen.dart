// lib/features/tester_feedback/presentation/tester_feedback_list_screen.dart
//
// 이슈 #794 — 도안별 테스터 피드백 목록 + 작성/응답/해결 토글.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../data/tester_feedback_repository.dart';
import '../domain/tester_feedback.dart';

class TesterFeedbackListScreen extends ConsumerStatefulWidget {
  final String blueprintId;

  const TesterFeedbackListScreen({super.key, required this.blueprintId});

  @override
  ConsumerState<TesterFeedbackListScreen> createState() =>
      _TesterFeedbackListScreenState();
}

class _TesterFeedbackListScreenState
    extends ConsumerState<TesterFeedbackListScreen> {
  TesterFeedbackCategory? _filterCategory;
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final blueprintAsync =
        ref.watch(blueprintByIdProvider(widget.blueprintId));
    final feedbackAsync =
        ref.watch(testerFeedbackByBlueprintProvider(widget.blueprintId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          isKorean ? '테스터 피드백' : 'Tester Feedback',
          style: T.h3,
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: AsyncDataView<StepBlueprint?>(
              async: blueprintAsync,
              builder: (origin) {
                if (origin == null) {
                  return Center(
                    child: Text(
                      isKorean
                          ? '도안을 불러올 수 없어요.'
                          : 'Could not load blueprint.',
                      style: T.body.copyWith(color: C.mu),
                    ),
                  );
                }
                final isOwner = origin.ownerUid == currentUid;
                final canSubmit = !isOwner ||
                    origin.ownerUid == currentUid; // 누구나 작성 가능
                return Column(
                  children: [
                    _FilterRow(
                      selected: _filterCategory,
                      showResolved: _showResolved,
                      isKorean: isKorean,
                      onCategory: (c) => setState(() => _filterCategory = c),
                      onToggleResolved: () =>
                          setState(() => _showResolved = !_showResolved),
                    ),
                    Expanded(
                      child: AsyncDataView<List<TesterFeedback>>(
                        async: feedbackAsync,
                        isEmpty: (list) =>
                            _applyFilter(list).isEmpty,
                        emptyBuilder: () => _EmptyState(isKorean: isKorean),
                        builder: (list) {
                          final filtered = _applyFilter(list);
                          return ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _FeedbackCard(
                              feedback: filtered[i],
                              blueprintId: widget.blueprintId,
                              isOwner: isOwner,
                              currentUid: currentUid,
                              isKorean: isKorean,
                            ),
                          );
                        },
                      ),
                    ),
                    if (canSubmit)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_comment_rounded,
                                  size: 18),
                              label: Text(isKorean
                                  ? '피드백 작성'
                                  : 'Write Feedback'),
                              onPressed: () => _openComposeSheet(origin),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TesterFeedback> _applyFilter(List<TesterFeedback> list) {
    return list.where((f) {
      if (!_showResolved && f.resolved) return false;
      if (_filterCategory != null && f.category != _filterCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openComposeSheet(StepBlueprint blueprint) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = ref.read(currentUserProvider).valueOrNull;
    final authorName =
        profile?.displayName ?? user.displayName ?? (isKorean ? '익명' : 'Anonymous');

    final result = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ComposeSheet(isKorean: isKorean),
    );
    if (result == null) return;
    if (!mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(testerFeedbackRepositoryProvider).create(
                blueprintId: widget.blueprintId,
                authorName: authorName,
                category: result.category,
                content: result.content,
              );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: '$e',
      );
    }
  }
}

class _FilterRow extends StatelessWidget {
  final TesterFeedbackCategory? selected;
  final bool showResolved;
  final bool isKorean;
  final ValueChanged<TesterFeedbackCategory?> onCategory;
  final VoidCallback onToggleResolved;

  const _FilterRow({
    required this.selected,
    required this.showResolved,
    required this.isKorean,
    required this.onCategory,
    required this.onToggleResolved,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          _Chip(
            label: isKorean ? '전체' : 'All',
            selected: selected == null,
            onTap: () => onCategory(null),
          ),
          const SizedBox(width: 6),
          for (final c in TesterFeedbackCategory.values) ...[
            _Chip(
              label: c.label(isKorean),
              selected: selected == c,
              onTap: () => onCategory(c),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: showResolved ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: showResolved ? C.lv : C.lv.withValues(alpha: 0.2),
              ),
            ),
            child: InkWell(
              onTap: onToggleResolved,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      showResolved
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: showResolved ? Colors.white : C.lvD,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isKorean ? '해결 포함' : 'Resolved',
                      style: T.caption.copyWith(
                        color: showResolved ? Colors.white : C.lvD,
                        fontWeight: showResolved
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? Colors.white : C.lvD,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends ConsumerStatefulWidget {
  final TesterFeedback feedback;
  final String blueprintId;
  final bool isOwner;
  final String currentUid;
  final bool isKorean;

  const _FeedbackCard({
    required this.feedback,
    required this.blueprintId,
    required this.isOwner,
    required this.currentUid,
    required this.isKorean,
  });

  @override
  ConsumerState<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<_FeedbackCard> {
  final _replyCtrl = TextEditingController();
  bool _replying = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final isMine = f.authorUid == widget.currentUid;
    final canModerate = widget.isOwner; // 도안 작성자만 해결 토글 가능
    final isKorean = widget.isKorean;

    return MoriBlockShell(
      label: f.category.label(isKorean),
      icon: _categoryIcon(f.category),
      accent: f.resolved ? C.mu : C.lvD,
      trailing: canModerate
          ? IconButton(
              icon: Icon(
                f.resolved
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: f.resolved ? C.lvD : C.mu,
                size: 22,
              ),
              tooltip:
                  isKorean ? (f.resolved ? '해결 취소' : '해결됨') : 'Resolved',
              onPressed: _toggleResolved,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.authorName, style: T.captionBold.copyWith(color: C.tx)),
              const SizedBox(width: 6),
              Text(
                '${f.createdAt.month}.${f.createdAt.day} ${f.createdAt.hour.toString().padLeft(2, '0')}:${f.createdAt.minute.toString().padLeft(2, '0')}',
                style: T.caption.copyWith(color: C.mu),
              ),
              if (isMine) ...[
                const SizedBox(width: 6),
                _MeBadge(isKorean: isKorean),
              ],
              const Spacer(),
              if (isMine)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: C.og),
                  onPressed: _delete,
                  tooltip: isKorean ? '삭제' : 'Delete',
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(f.content, style: T.body.copyWith(height: 1.5)),
          if (f.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in f.replies) ...[
                    Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: C.lvD),
                        const SizedBox(width: 4),
                        Text(r.authorName,
                            style: T.captionBold.copyWith(color: C.tx)),
                        const SizedBox(width: 4),
                        Text(
                          '${r.createdAt.month}.${r.createdAt.day}',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(r.content, style: T.caption),
                    ),
                    if (r != f.replies.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
          if (canModerate) ...[
            const SizedBox(height: 8),
            if (_replying)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: isKorean ? '응답 입력' : 'Reply',
                        filled: true,
                        fillColor: C.gx,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: C.lv),
                    onPressed: _sendReply,
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: C.mu),
                    onPressed: () => setState(() => _replying = false),
                  ),
                ],
              )
            else
              TextButton.icon(
                icon: Icon(Icons.reply_rounded, size: 16, color: C.lv),
                label: Text(
                  isKorean ? '응답하기' : 'Reply',
                  style: T.caption.copyWith(
                    color: C.lv,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => setState(() => _replying = true),
              ),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(TesterFeedbackCategory c) {
    switch (c) {
      case TesterFeedbackCategory.bug:
        return Icons.bug_report_rounded;
      case TesterFeedbackCategory.unclear:
        return Icons.help_outline_rounded;
      case TesterFeedbackCategory.missing:
        return Icons.warning_amber_rounded;
      case TesterFeedbackCategory.suggestion:
        return Icons.lightbulb_outline_rounded;
      case TesterFeedbackCategory.other:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  Future<void> _toggleResolved() async {
    final f = widget.feedback;
    try {
      await ref.read(testerFeedbackRepositoryProvider).setResolved(
            widget.blueprintId,
            f.id,
            !f.resolved,
          );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: '$e',
      );
    }
  }

  Future<void> _sendReply() async {
    final isKorean = widget.isKorean;
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = ref.read(currentUserProvider).valueOrNull;
    final authorName = profile?.displayName ??
        user.displayName ??
        (isKorean ? '익명' : 'Anonymous');
    try {
      await ref.read(testerFeedbackRepositoryProvider).addReply(
            blueprintId: widget.blueprintId,
            feedbackId: widget.feedback.id,
            authorName: authorName,
            content: text,
          );
      _replyCtrl.clear();
      if (mounted) setState(() => _replying = false);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: '$e',
      );
    }
  }

  Future<void> _delete() async {
    final isKorean = widget.isKorean;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '삭제할까요?' : 'Delete?'),
        content: Text(isKorean
            ? '이 피드백을 삭제합니다.'
            : 'This feedback will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: TextStyle(color: C.og),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(testerFeedbackRepositoryProvider)
          .delete(widget.blueprintId, widget.feedback.id);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: '$e',
      );
    }
  }
}

class _MeBadge extends StatelessWidget {
  final bool isKorean;
  const _MeBadge({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isKorean ? '나' : 'You',
        style: T.caption.copyWith(
          color: C.og,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isKorean;
  const _EmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.feedback_outlined, size: 48, color: C.mu),
            const SizedBox(height: 10),
            Text(
              isKorean ? '아직 피드백이 없어요' : 'No feedback yet',
              style: T.bodyBold.copyWith(color: C.mu),
            ),
            const SizedBox(height: 6),
            Text(
              isKorean
                  ? '테스터가 도안에 대한 의견을 보내면 여기에 표시돼요.'
                  : 'Testers feedback will appear here.',
              style: T.caption.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeResult {
  final TesterFeedbackCategory category;
  final String content;
  const _ComposeResult({required this.category, required this.content});
}

class _ComposeSheet extends StatefulWidget {
  final bool isKorean;
  const _ComposeSheet({required this.isKorean});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  TesterFeedbackCategory _category = TesterFeedbackCategory.bug;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '피드백 작성' : 'Write Feedback', style: T.h3),
          const SizedBox(height: 14),
          SectionTitle(title: isKorean ? '카테고리' : 'Category'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in TesterFeedbackCategory.values)
                _Chip(
                  label: c.label(isKorean),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SectionTitle(title: isKorean ? '내용' : 'Content'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: isKorean
                  ? '어떤 부분이 헷갈렸나요? 구체적으로 알려주세요.'
                  : 'What was unclear or buggy? Be specific.',
              filled: true,
              fillColor: C.gx,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(
                  context,
                  _ComposeResult(category: _category, content: text),
                );
              },
              child: Text(isKorean ? '보내기' : 'Send'),
            ),
          ),
        ],
      ),
    );
  }
}
