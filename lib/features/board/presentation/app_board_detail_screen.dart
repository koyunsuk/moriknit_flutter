// 이슈 #783 — 게시판 글 상세 화면.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../landing/data/landing_board_repository.dart';

class AppBoardDetailScreen extends ConsumerStatefulWidget {
  final String boardType;
  final String postId;

  const AppBoardDetailScreen({
    super.key,
    required this.boardType,
    required this.postId,
  });

  @override
  ConsumerState<AppBoardDetailScreen> createState() => _AppBoardDetailScreenState();
}

class _AppBoardDetailScreenState extends ConsumerState<AppBoardDetailScreen> {
  LandingPost? _post;
  bool _loading = true;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(landingBoardRepositoryProvider);
    final post = await repo.getPost(widget.boardType, widget.postId);
    if (!mounted) return;
    setState(() {
      _post = post;
      _loading = false;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final profile = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final repo = ref.read(landingBoardRepositoryProvider);
    await repo.addBoardComment(
      widget.boardType,
      widget.postId,
      LandingComment(
        id: '',
        content: text,
        authorUid: user.uid,
        authorName: profile?.displayName ?? user.displayName ?? '익명',
        createdAt: DateTime.now(),
      ),
    );
    _commentCtrl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final post = _post;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('게시글을 찾을 수 없어요.', style: T.body.copyWith(color: C.mu))),
      );
    }
    final repo = ref.read(landingBoardRepositoryProvider);

    return AppShellScaffold(
      title: post.title,
      subtitle: '',
      showBackButton: true,
      showBgOrbs: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title, style: T.h3),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(post.authorName, style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('${post.createdAt.year}.${post.createdAt.month}.${post.createdAt.day}',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(post.content, style: T.body.copyWith(height: 1.5)),
                      if (post.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (final url in post.imageUrls)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: C.bd.withValues(alpha: 0.15),
                                  height: 120,
                                ),
                                errorWidget: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('댓글 ${post.commentCount}', style: T.bodyBold),
                const SizedBox(height: 8),
                StreamBuilder<List<LandingComment>>(
                  stream: repo.getBoardComments(widget.boardType, widget.postId),
                  builder: (context, snap) {
                    final comments = snap.data ?? [];
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('첫 댓글을 남겨주세요.', style: T.caption.copyWith(color: C.mu)),
                      );
                    }
                    return Column(
                      children: comments
                          .map((c) => GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(c.authorName, style: T.captionBold.copyWith(color: C.tx)),
                                        const SizedBox(width: 6),
                                        Text('${c.createdAt.month}.${c.createdAt.day}',
                                            style: T.caption.copyWith(color: C.mu)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.content, style: T.body),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          // 댓글 입력 (모든 사용자 가능)
          if (ref.watch(authStateProvider).valueOrNull != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: '댓글 작성',
                          filled: true,
                          fillColor: C.gx,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: C.lv),
                      onPressed: _sendComment,
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
