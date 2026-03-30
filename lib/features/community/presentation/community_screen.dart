import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../my/data/mori_service.dart';
import '../domain/comment_model.dart';
import '../domain/post_model.dart';

const _categoryKeys = ['all', 'showcase', 'questions', 'pattern_share'];

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'community_header_subtitle',
      fallback: t.communityHeaderSubtitle,
    );
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final postsAsync = ref.watch(postsProvider(selectedCategory));
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '커뮤니티' : 'Community',
                subtitle: subtitle,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _categoryKeys.length,
                itemBuilder: (_, index) {
                  final categoryKey = _categoryKeys[index];
                  final isSelected = categoryKey == selectedCategory;
                  return GestureDetector(
                    onTap: () => ref.read(selectedCategoryProvider.notifier).state = categoryKey,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? C.lvD : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: isSelected ? C.lvD : C.bd),
                      ),
                      child: Text(
                        _categoryLabel(categoryKey, isKorean),
                        style: T.sm.copyWith(
                          color: isSelected ? Colors.white : C.tx2,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: postsAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (_, _) => Center(child: Text(isKorean ? '게시글을 불러오지 못했어요.' : 'Unable to load posts.', style: T.body)),
                data: (posts) {
                  if (posts.isEmpty) {
                    return _EmptyCommunity(
                      isKorean: isKorean,
                      onWrite: user == null
                          ? () => showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: '/community')
                          : () => _showWriteSheet(context, ref, user.uid, user.displayName ?? ''),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                    itemCount: posts.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(isKorean ? '게시글 ${posts.length}' : '${posts.length} posts', style: T.bodyBold)),
                              TextButton.icon(
                                onPressed: user == null
                                    ? () => showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: '/community')
                                    : () => _showWriteSheet(context, ref, user.uid, user.displayName ?? ''),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: Text(isKorean ? '글쓰기' : 'Write'),
                              ),
                            ],
                          ),
                        );
                      }
                      return GlassCard(
                        child: _PostRow(post: posts[index - 1], isKorean: isKorean),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWriteSheet(BuildContext context, WidgetRef ref, String uid, String authorName) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = _categoryKeys.first;
    final images = <Uint8List>[];
    final files = <Map<String, dynamic>>[];
    var loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isKorean ? '새 글쓰기' : 'New post', style: T.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '제목' : 'Title')),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: isKorean ? '내용' : 'Content')),
              const SizedBox(height: 10),
              Text(isKorean ? '카테고리' : 'Category', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 6),
              MoriOptionChips<String>(
                options: _categoryKeys
                    .where((k) => k != 'all')
                    .map((k) => (value: k, label: _categoryLabel(k, isKorean)))
                    .toList(),
                selected: category,
                onSelected: (v) => setState(() => category = v),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: images.length >= 4
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 80, limit: 4 - images.length);
                        for (final file in picked) {
                          images.add(await file.readAsBytes());
                        }
                        setState(() {});
                      },
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(isKorean ? '사진 추가 (${images.length}/4)' : 'Add photo (${images.length}/4)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
                  if (result == null) return;
                  for (final file in result.files) {
                    if (file.bytes != null) {
                      files.add({'name': file.name, 'bytes': file.bytes!});
                    }
                  }
                  setState(() {});
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text('${isKorean ? '파일 추가' : 'Attach file'} (${files.length})'),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(images[index], width: 76, height: 76, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
              if (files.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: files.map((file) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: C.bd),
                      ),
                      child: Text(file['name'] as String, style: T.caption.copyWith(color: C.tx2)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final missing = <String>[];
                          if (titleCtrl.text.trim().isEmpty) missing.add(isKorean ? '제목' : 'Title');
                          if (contentCtrl.text.trim().isEmpty) missing.add(isKorean ? '내용' : 'Content');
                          if (missing.isNotEmpty) {
                            await showMissingFieldsDialog(ctx, missing: missing, isKorean: isKorean);
                            return;
                          }
                          setState(() => loading = true);
                          try {
                            await runWithMoriLoadingDialog<void>(
                              ctx,
                              message: isKorean ? '게시하는 중입니다.' : 'Posting...',
                              subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                              task: () async {
                                final repo = ref.read(postRepositoryProvider);
                                final imageUrls = images.isEmpty ? <String>[] : await repo.uploadImages(uid, images);
                                final attachmentUrls = files.isEmpty ? <String>[] : await repo.uploadFiles(uid, files);
                                await repo.createPost(
                                  PostModel(
                                    id: '',
                                    uid: uid,
                                    authorName: authorName.isEmpty ? (isKorean ? '익명' : 'Anonymous') : authorName,
                                    category: category,
                                    title: titleCtrl.text.trim(),
                                    content: contentCtrl.text.trim(),
                                    imageUrls: imageUrls,
                                    attachmentUrls: attachmentUrls,
                                    attachmentNames: files.map((file) => file['name'] as String).toList(),
                                    createdAt: DateTime.now(),
                                  ),
                                );
                              },
                            );
                            if (ctx.mounted) {
                              showSavedSnackBar(ctx, message: isKorean ? '게시되었습니다.' : 'Posted.');
                              Navigator.pop(ctx);
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              showSaveErrorSnackBar(ctx, message: isKorean ? '게시에 실패했습니다.' : 'Failed to post.');
                              setState(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isKorean ? '게시하기' : 'Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCommunity extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onWrite;
  const _EmptyCommunity({required this.isKorean, required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: C.lvL,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.forum_outlined, color: C.lvD, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isKorean ? '아직 게시글이 없어요' : 'No posts yet',
            style: T.bodyBold,
          ),
          const SizedBox(height: 6),
          Text(
            isKorean ? '첫 글을 남겨보세요.' : 'Be the first to post!',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_rounded),
            label: Text(isKorean ? '글 작성하기' : 'Write a post'),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(String key, bool isKorean) {
  switch (key) {
    case 'all':
      return isKorean ? '전체' : 'All';
    case 'showcase':
      return isKorean ? '작품' : 'Showcase';
    case 'questions':
      return isKorean ? '질문' : 'Questions';
    case 'pattern_share':
      return isKorean ? '도안공유' : 'Pattern Share';
    default:
      return key;
  }
}

class _PostRow extends ConsumerStatefulWidget {
  final PostModel post;
  final bool isKorean;
  const _PostRow({required this.post, required this.isKorean});

  @override
  ConsumerState<_PostRow> createState() => _PostRowState();
}

class _PostRowState extends ConsumerState<_PostRow> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    _liked = user != null && widget.post.likedBy.contains(user.uid);
    _likeCount = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(_PostRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id || oldWidget.post.likeCount != widget.post.likeCount) {
      final user = ref.read(authStateProvider).valueOrNull;
      _liked = user != null && widget.post.likedBy.contains(user.uid);
      _likeCount = widget.post.likeCount;
    }
  }

  PostModel get post => widget.post;
  bool get isKorean => widget.isKorean;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(post.category);
    return InkWell(
      onTap: () => _showDetail(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _categoryLabel(post.category, isKorean),
                          style: T.caption.copyWith(color: categoryColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(post.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(post.content, style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(post.authorName, style: T.caption.copyWith(color: C.tx2)),
                      const SizedBox(width: 8),
                      Text(post.timeAgo, style: T.caption.copyWith(color: C.mu)),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final user = ref.read(authStateProvider).valueOrNull;
                          if (user == null) return;
                          setState(() {
                            _liked = !_liked;
                            _likeCount = _liked ? _likeCount + 1 : _likeCount - 1;
                          });
                          ref.read(postRepositoryProvider).toggleLike(post.id, user.uid);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: _liked ? C.pk : C.mu.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 3),
                            Text('$_likeCount', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline_rounded, size: 13, color: C.mu.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}', style: T.caption.copyWith(color: C.mu)),
                      Builder(builder: (ctx) {
                        final u = ref.watch(authStateProvider).valueOrNull;
                        if (u == null || u.uid != post.uid) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => _showAuthorMenu(ctx, ref),
                            child: Icon(Icons.more_vert_rounded, size: 14, color: C.mu),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrls.first,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'showcase':
        return C.pkD;
      case 'questions':
        return C.lvD;
      case 'pattern_share':
        return C.lmD;
      default:
        return C.mu;
    }
  }

  void _showAuthorMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: C.lvD),
              title: Text(isKorean ? '수정' : 'Edit'),
              onTap: () { Navigator.pop(ctx); _editPost(context, ref); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              title: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: Colors.red.shade400)),
              onTap: () async {
                Navigator.pop(ctx);
                final overlay = showSavingOverlay(context, message: isKorean ? '삭제하는 중입니다.' : 'Deleting...');
                await ref.read(postRepositoryProvider).deletePost(post.id);
                overlay.close();
                if (context.mounted) showSavedSnackBar(context, message: isKorean ? '삭제되었습니다.' : 'Deleted.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editPost(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: post.title);
    final contentCtrl = TextEditingController(text: post.content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isKorean ? '게시글 수정' : 'Edit post', style: T.h3),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '제목' : 'Title')),
            const SizedBox(height: 10),
            TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: isKorean ? '내용' : 'Content')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final t = titleCtrl.text.trim();
                  final c = contentCtrl.text.trim();
                  if (t.isEmpty || c.isEmpty) return;
                  await runWithMoriLoadingDialog<void>(
                    ctx,
                    message: isKorean ? '수정하는 중입니다.' : 'Updating...',
                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                    task: () => ref.read(postRepositoryProvider).updatePost(post.id, title: t, content: c),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(isKorean ? '수정 완료' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (kIsWeb && user == null) {
      showLoginRequiredDialog(
        context,
        isKorean: isKorean,
        title: isKorean ? '게시글 상세는 로그인 후 볼 수 있어요' : 'Post details require login',
        fromRoute: '/community',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PostDetailSheet(post: post, categoryColor: _categoryColor(post.category), isKorean: isKorean),
    );
  }
}

class _PostDetailSheet extends ConsumerStatefulWidget {
  final PostModel post;
  final Color categoryColor;
  final bool isKorean;
  const _PostDetailSheet({required this.post, required this.categoryColor, required this.isKorean});

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  final _commentCtrl = TextEditingController();
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // Will be initialized after we have the user — use a placeholder here;
    // actual init happens in build where we have the user reference.
    _liked = false;
    _likeCount = widget.post.likeCount;
  }

  bool _likeInitialized = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _editPost(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: widget.post.title);
    final contentCtrl = TextEditingController(text: widget.post.content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.isKorean ? '게시글 수정' : 'Edit post', style: T.h3),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: widget.isKorean ? '제목' : 'Title')),
            const SizedBox(height: 10),
            TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: widget.isKorean ? '내용' : 'Content')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final t = titleCtrl.text.trim();
                  final c = contentCtrl.text.trim();
                  if (t.isEmpty || c.isEmpty) return;
                  await runWithMoriLoadingDialog<void>(
                    ctx,
                    message: widget.isKorean ? '수정하는 중입니다.' : 'Updating...',
                    subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                    task: () => ref.read(postRepositoryProvider).updatePost(widget.post.id, title: t, content: c),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(widget.isKorean ? '수정 완료' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));
    final isMyPost = user?.uid == widget.post.uid;

    // Initialize like state once we have the user
    if (!_likeInitialized && user != null) {
      _liked = widget.post.likedBy.contains(user.uid);
      _likeCount = widget.post.likeCount;
      _likeInitialized = true;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _categoryLabel(widget.post.category, widget.isKorean),
                        style: T.caption.copyWith(color: widget.categoryColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (isMyPost) ...[
                      IconButton(
                        icon: Icon(Icons.edit_rounded, color: C.lvD, size: 20),
                        onPressed: () => _editPost(context, ref),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: C.og, size: 20),
                        onPressed: () async {
                          final overlay = showSavingOverlay(context, message: widget.isKorean ? '삭제하는 중입니다.' : 'Deleting...');
                          await ref.read(postRepositoryProvider).deletePost(widget.post.id);
                          overlay.close();
                          if (context.mounted) {
                            showSavedSnackBar(context, message: widget.isKorean ? '삭제되었습니다.' : 'Deleted.');
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.post.title, style: T.h2),
                const SizedBox(height: 6),
                Row(children: [
                  Text(widget.post.authorName, style: T.caption.copyWith(color: C.tx2)),
                  const SizedBox(width: 8),
                  Text(widget.post.timeAgo, style: T.caption.copyWith(color: C.mu)),
                ]),
                const Divider(height: 24),
                Text(widget.post.content, style: T.body),
                if (widget.post.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.post.imageUrls
                        .map(
                          (url) => GestureDetector(
                            onTap: () => _showFullImage(context, url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(url, width: 140, height: 140, fit: BoxFit.cover),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: user == null
                      ? null
                      : () async {
                          setState(() {
                            _liked = !_liked;
                            _likeCount += _liked ? 1 : -1;
                          });
                          await ref.read(postRepositoryProvider).toggleLike(widget.post.id, user.uid);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _liked ? C.pk.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _liked ? C.pk : C.bd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: C.pk),
                        const SizedBox(width: 6),
                        Text('$_likeCount', style: T.captionBold.copyWith(color: C.pk)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('${widget.isKorean ? '댓글' : 'Comments'} ${widget.post.commentCount}', style: T.captionBold.copyWith(color: C.mu)),
                const SizedBox(height: 8),
                commentsAsync.when(
                  data: (comments) => comments.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(widget.isKorean ? '첫 댓글을 남겨보세요.' : 'Be the first to comment.', style: T.caption.copyWith(color: C.mu)),
                        )
                      : Column(
                          children: comments
                              .map(
                                (comment) => _CommentTile(
                                  comment: comment,
                                  isMyComment: user?.uid == comment.uid,
                                  onDelete: () => ref.read(commentRepositoryProvider).deleteComment(widget.post.id, comment.id),
                                ),
                              )
                              .toList(),
                        ),
                  loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                  error: (error, _) => Text('$error', style: T.caption.copyWith(color: C.og)),
                ),
              ],
            ),
          ),
          if (user != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.bd))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: widget.isKorean ? '댓글을 입력해주세요...' : 'Write a comment...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: C.bd)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final text = _commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      final comment = CommentModel(
                        id: '',
                        uid: user.uid,
                        authorName: user.displayName ?? (widget.isKorean ? '익명' : 'Anonymous'),
                        content: text,
                        createdAt: DateTime.now(),
                      );
                      _commentCtrl.clear();
                      await ref.read(commentRepositoryProvider).addComment(widget.post.id, comment);
                      MoriService.earn(user.uid, amount: 100, reason: 'comment_post');
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: C.lvD, borderRadius: BorderRadius.circular(99)),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isMyComment;
  final VoidCallback onDelete;
  const _CommentTile({required this.comment, required this.isMyComment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: C.lvL,
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName.characters.first.toUpperCase() : '?',
              style: TextStyle(fontSize: 12, color: C.lvD, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.authorName, style: T.captionBold),
                    const SizedBox(width: 6),
                    Text(comment.timeAgo, style: T.caption.copyWith(color: C.mu)),
                    const Spacer(),
                    if (isMyComment) GestureDetector(onTap: onDelete, child: Icon(Icons.close, size: 14, color: C.mu)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: T.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
