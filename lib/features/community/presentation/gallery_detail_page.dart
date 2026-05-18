import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';
import '../../../providers/project_provider.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../project/data/public_project_service.dart';
import '../../project/domain/project_model.dart';
import '../domain/comment_model.dart';

class GalleryDetailPage extends ConsumerStatefulWidget {
  final PublicProjectEntry entry;
  final String currentUid;

  const GalleryDetailPage({
    super.key,
    required this.entry,
    required this.currentUid,
  });

  @override
  ConsumerState<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends ConsumerState<GalleryDetailPage> {
  late bool _isLiked;
  late int _likeCount;
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.currentUid.isNotEmpty &&
        widget.entry.likedBy.contains(widget.currentUid);
    _likeCount = widget.entry.likeCount;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleToggle() async {
    if (widget.currentUid.isEmpty) return;
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });
    await ref.read(publicProjectServiceProvider).toggleLike(
          entryId: widget.entry.id,
          uid: widget.currentUid,
        );
  }

  Future<void> _deleteEntry(BuildContext context, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isKorean ? '게시물 삭제' : 'Delete Post'),
        content: Text(isKorean ? '갤러리에서 삭제하시겠어요?' : 'Remove from gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isKorean ? '삭제' : 'Delete',
                style: TextStyle(color: C.og)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(publicProjectServiceProvider)
          .unpublishProject(uid: widget.entry.uid, projectId: widget.entry.projectId)
          .timeout(const Duration(seconds: 15));
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: '삭제 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editTitle(BuildContext context, bool isKorean) async {
    final ctrl = TextEditingController(text: widget.entry.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isKorean ? '제목 수정' : 'Edit Title'),
        content: TextField(
          controller: ctrl,
          decoration:
              InputDecoration(hintText: isKorean ? '제목' : 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: Text(isKorean ? '저장' : 'Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!context.mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(publicProjectServiceProvider)
          .updateEntryTitle(widget.entry.id, result)
          .timeout(const Duration(seconds: 15));
      if (!context.mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _forkProject(BuildContext context, bool isKorean) async {
    final entry = widget.entry;
    try {
      ProjectModel? newProject;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '함께 뜨기를 시작하는 중입니다.' : 'Joining knit-along...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          newProject = await ref.read(projectRepositoryProvider).forkProject(
            originProjectId: entry.projectId,
            originUserId: entry.uid,
            originOwnerName: entry.ownerName,
            title: entry.title,
            yarnName: entry.yarnName,
            yarnBrandName: entry.yarnBrandName,
            yarnWeight: entry.yarnWeight,
            needleSize: entry.needleSize,
            sourcePatternId: entry.sourcePatternId,
          );
          // 연결된 도안의 forkCount +1
          if (entry.sourcePatternId.isNotEmpty) {
            await ref.read(patternRepositoryProvider).incrementForkCount(
              sourceOwnerId: entry.uid,
              patternId: entry.sourcePatternId,
            );
          }
        },
      );
      if (!context.mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '내 프로젝트에 추가됐어요!' : 'Added to your projects!',
      );
      if (context.mounted && newProject != null) {
        Navigator.pop(context);
        context.push('${Routes.projectList}/${newProject!.id}');
      }
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _sendComment(bool isKorean) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _sendingComment = true);
    try {
      final comment = CommentModel(
        id: '',
        uid: user.uid,
        authorName:
            user.displayName ?? (isKorean ? '익명' : 'Anonymous'),
        content: text,
        createdAt: DateTime.now(),
      );
      await ref
          .read(galleryCommentRepositoryProvider)
          .addComment(widget.entry.id, comment);
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final currentUid = widget.currentUid;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final isOwner = currentUid.isNotEmpty && currentUid == entry.uid;
    final dateStr = entry.finishDate != null
        ? DateFormat('yyyy.MM.dd').format(entry.finishDate!)
        : null;
    final commentsAsync = ref.watch(galleryCommentsProvider(entry.id));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(entry.title, style: T.h3),
        centerTitle: false,
        actions: [
          // 좋아요 버튼
          GestureDetector(
            onTap: currentUid.isEmpty ? null : _handleToggle,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isLiked
                    ? C.pk.withValues(alpha: 0.12)
                    : C.bd.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 16,
                    color: _isLiked ? C.pk : C.mu,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_likeCount',
                    style: T.caption.copyWith(
                      color: _isLiked ? C.pk : C.mu,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fork 버튼 (비소유자 + 로그인 상태 + 도안 연결된 경우만)
          if (!isOwner && currentUid.isNotEmpty && entry.sourcePatternId.isNotEmpty)
            TextButton.icon(
              onPressed: () => _forkProject(context, isKorean),
              icon: Icon(Icons.fork_right_rounded, size: 16, color: C.lv),
              label: Text(
                isKorean ? '함께 뜨기' : 'Knit along',
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: C.lv.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          if (isOwner)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: C.mu),
              onSelected: (v) {
                if (v == 'edit') _editTitle(context, isKorean);
                if (v == 'delete') _deleteEntry(context, isKorean);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'edit',
                    child: Text(isKorean ? '수정' : 'Edit')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(isKorean ? '삭제' : 'Delete',
                        style: TextStyle(color: C.og))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 커버 이미지
                  if (entry.coverPhotoUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: entry.coverPhotoUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorWidget: (_, e, s) =>
                            Container(height: 200, color: C.lvL),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 작성자
                  if (entry.ownerName.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 13, color: C.mu),
                        const SizedBox(width: 4),
                        Text(entry.ownerName,
                            style: T.caption.copyWith(color: C.mu)),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // 상세 정보 섹션
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.bd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateStr != null)
                          _DetailRow(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF4CAF50),
                            label: isKorean ? '완성일' : 'Finished',
                            value: dateStr,
                          ),
                        if (entry.yarnBrandName.isNotEmpty) ...[
                          if (dateStr != null)
                            const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.storefront_outlined,
                            iconColor: C.lv,
                            label: isKorean ? '실 브랜드' : 'Brand',
                            value: entry.yarnBrandName,
                          ),
                        ],
                        if (entry.yarnName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.layers_rounded,
                            iconColor: C.lv,
                            label: isKorean ? '실 이름' : 'Yarn',
                            value: entry.yarnName,
                          ),
                        ],
                        if (entry.yarnWeight.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.fiber_manual_record_rounded,
                            iconColor: C.mu,
                            label: isKorean ? '실 굵기' : 'Weight',
                            value: entry.yarnWeight,
                          ),
                        ],
                        if (entry.needleSize > 0) ...[
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.circle_outlined,
                            iconColor: C.mu,
                            label: isKorean ? '바늘' : 'Needle',
                            value:
                                '${entry.needleSize.toStringAsFixed(2)}mm',
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 완료된 단계 목록
                  if (entry.stepTitles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      isKorean ? '완료한 단계' : 'Completed Steps',
                      style: T.caption.copyWith(
                          color: C.mu, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ...entry.stepTitles.map((title) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: C.lv),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(title,
                                      style: T.caption
                                          .copyWith(color: C.tx))),
                            ],
                          ),
                        )),
                  ],
                  // 추가 이미지 앨범
                  if (entry.photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      isKorean ? '작품 사진' : 'Photos',
                      style: T.caption.copyWith(
                          color: C.mu, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: entry.photoUrls
                          .map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(imageUrl: url,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, e, s) =>
                                        Container(color: C.lvL)),
                              ))
                          .toList(),
                    ),
                  ],
                  // 댓글 섹션
                  const SizedBox(height: 20),
                  Divider(color: C.bd, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    isKorean ? '댓글' : 'Comments',
                    style: T.caption.copyWith(
                        color: C.mu, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  commentsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (comments) => comments.isEmpty
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              isKorean
                                  ? '첫 댓글을 남겨보세요.'
                                  : 'Be the first to comment.',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          )
                        : Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: comments.map((c) {
                              final isMyComment = currentUid == c.uid;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: C.lvL,
                                      child: Text(
                                        c.authorName.isNotEmpty
                                            ? c.authorName.characters
                                                .first
                                                .toUpperCase()
                                            : '?',
                                        style: T.caption.copyWith(
                                            color: C.lv,
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(c.authorName,
                                                style: T.caption
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight
                                                                .w600)),
                                            const SizedBox(width: 6),
                                            Text(c.timeAgo,
                                                style: T.caption
                                                    .copyWith(
                                                        color: C.mu,
                                                        fontSize: 10)),
                                          ]),
                                          const SizedBox(height: 2),
                                          Text(c.content,
                                              style: T.caption
                                                  .copyWith(
                                                      color: C.tx)),
                                        ],
                                      ),
                                    ),
                                    if (isMyComment)
                                      GestureDetector(
                                        onTap: () => ref
                                            .read(
                                                galleryCommentRepositoryProvider)
                                            .deleteComment(
                                                entry.id, c.id),
                                        child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: C.mu),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // 하단 댓글 입력창
          if (currentUid.isNotEmpty)
            SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: C.bg,
                  border: Border(top: BorderSide(color: C.bd)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        style: T.caption.copyWith(color: C.tx),
                        decoration: InputDecoration(
                          hintText: isKorean
                              ? '댓글 입력...'
                              : 'Add a comment...',
                          hintStyle: T.caption.copyWith(color: C.mu),
                          filled: true,
                          fillColor: C.gx,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: C.bd),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: C.bd),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: C.lv),
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(isKorean),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendingComment
                          ? null
                          : () => _sendComment(isKorean),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: C.lv, shape: BoxShape.circle),
                        child: _sendingComment
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(label,
              style: T.caption
                  .copyWith(color: C.mu, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value, style: T.caption.copyWith(color: C.tx)),
        ),
      ],
    );
  }
}
