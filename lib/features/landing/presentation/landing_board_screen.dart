import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../data/landing_board_repository.dart';
import 'landing_top_bar.dart';

const double _landingMaxWidth = 1160;
const Color _landingBg = Color(0xFFFFF8FB);

// ── 게시판 제목 헬퍼 ──────────────────────────────────────────────────────────

String _boardTitle(String type) {
  switch (type) {
    case 'review':
      return '리뷰 게시판';
    case 'release':
      return '릴리즈 노트';
    case 'qa':
      return '문의하기 Q&A';
    default:
      return '게시판';
  }
}

String _boardSubtitle(String type) {
  switch (type) {
    case 'review':
      return '모리니트를 사용하고 느낀 점을 자유롭게 공유해보세요.';
    case 'release':
      return '모리니트 앱의 업데이트 내역을 확인하세요.';
    case 'qa':
      return '궁금한 점은 무엇이든 질문해주세요. 빠르게 답변드릴게요.';
    default:
      return '';
  }
}

// ── 게시판 목록 화면 (route: /reviews, /releases, /qa) ───────────────────────

class LandingBoardListScreen extends ConsumerWidget {
  final String boardType;

  const LandingBoardListScreen({super.key, required this.boardType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(landingBoardRepositoryProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: _landingBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (user == null) {
            context.go('/login?source=board');
          } else {
            context.push('/board/$boardType/write');
          }
        },
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: LandingTopBar()),

          // 페이지 헤더
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1A1A2E),
              padding:
                  const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _landingMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _boardTitle(boardType),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _boardSubtitle(boardType),
                        style: const TextStyle(
                            color: Color(0xFFB0A8D8), fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 게시글 목록
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _landingMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: StreamBuilder<List<LandingPost>>(
                    stream: repo.getPosts(boardType),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('오류가 발생했습니다: ${snapshot.error}'));
                      }
                      final posts = snapshot.data ?? [];
                      if (posts.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Text(
                              '아직 게시글이 없어요. 첫 번째 글을 작성해보세요!',
                              style: TextStyle(
                                  fontSize: 15, color: Color(0xFF7C5CBF)),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: posts
                            .map((p) => _PostCard(
                                  post: p,
                                  onTap: () => context
                                      .push('/board/$boardType/${p.id}'),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final LandingPost post;
  final VoidCallback onTap;

  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(post.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1B4B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF7C5CBF)),
                  ),
                  const SizedBox(width: 8),
                  const Text('·',
                      style: TextStyle(color: Color(0xFFB0A8D8))),
                  const SizedBox(width: 8),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFB0A8D8))),
                  const Spacer(),
                  const Icon(Icons.comment_outlined,
                      size: 14, color: Color(0xFFB0A8D8)),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB0A8D8)),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: Color(0xFFB0A8D8)),
                  const SizedBox(width: 4),
                  Text(
                    '${post.viewCount}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB0A8D8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 게시글 상세 화면 (route: /board/:type/:id) ────────────────────────────────

class LandingBoardDetailScreen extends ConsumerStatefulWidget {
  final String boardType;
  final String postId;

  const LandingBoardDetailScreen({
    super.key,
    required this.boardType,
    required this.postId,
  });

  @override
  ConsumerState<LandingBoardDetailScreen> createState() =>
      _LandingBoardDetailScreenState();
}

class _LandingBoardDetailScreenState
    extends ConsumerState<LandingBoardDetailScreen> {
  final _commentController = TextEditingController();
  bool _submitting = false;
  LandingPost? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final repo = ref.read(landingBoardRepositoryProvider);
    final post = await repo.getPost(widget.boardType, widget.postId);
    if (mounted) {
      setState(() {
        _post = post;
        _loading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go('/login?source=board');
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(landingBoardRepositoryProvider);
      await repo.addBoardComment(
        widget.boardType,
        widget.postId,
        LandingComment(
          id: '',
          content: text,
          authorUid: user.uid,
          authorName: user.displayName ?? '익명',
          createdAt: DateTime.now(),
        ),
      );
      _commentController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 작성에 실패했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(landingBoardRepositoryProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: _landingBg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: LandingTopBar()),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _landingMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _post == null
                          ? const Center(child: Text('게시글을 찾을 수 없어요.'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 뒤로가기
                                TextButton.icon(
                                  onPressed: () => context
                                      .go('/${_backRoute(widget.boardType)}'),
                                  icon: const Icon(Icons.arrow_back_ios,
                                      size: 16),
                                  label: Text(
                                      _boardTitle(widget.boardType)),
                                  style: TextButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFF8B5CF6)),
                                ),
                                const SizedBox(height: 16),

                                // 제목
                                Text(
                                  _post!.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      _post!.authorName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF7C5CBF)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('·',
                                        style: TextStyle(
                                            color: Color(0xFFB0A8D8))),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('yyyy년 MM월 dd일')
                                          .format(_post!.createdAt),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFB0A8D8)),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.visibility_outlined,
                                        size: 14,
                                        color: Color(0xFFB0A8D8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_post!.viewCount}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB0A8D8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Divider(color: Color(0xFFEEE8FF)),
                                const SizedBox(height: 24),

                                // 내용
                                Text(
                                  _post!.content,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.8,
                                      color: Color(0xFF1E1B4B)),
                                ),
                                const SizedBox(height: 40),
                                const Divider(color: Color(0xFFEEE8FF)),
                                const SizedBox(height: 24),

                                // 댓글
                                _CommentsSection(
                                  commentsStream:
                                      repo.getBoardComments(
                                          widget.boardType,
                                          widget.postId),
                                ),
                                const SizedBox(height: 20),

                                // 댓글 입력
                                if (user != null)
                                  _CommentInput(
                                    controller: _commentController,
                                    submitting: _submitting,
                                    onSubmit: _submitComment,
                                  )
                                else
                                  _LoginPrompt(
                                    onTap: () => context
                                        .go('/login?source=board'),
                                  ),

                                const SizedBox(height: 60),
                              ],
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _backRoute(String type) {
    switch (type) {
      case 'review':
        return 'reviews';
      case 'release':
        return 'releases';
      case 'qa':
        return 'qa';
      default:
        return '';
    }
  }
}

// ── 게시글 작성 화면 (route: /board/:type/write) ──────────────────────────────

class LandingBoardWriteScreen extends ConsumerStatefulWidget {
  final String boardType;

  const LandingBoardWriteScreen({super.key, required this.boardType});

  @override
  ConsumerState<LandingBoardWriteScreen> createState() =>
      _LandingBoardWriteScreenState();
}

class _LandingBoardWriteScreenState
    extends ConsumerState<LandingBoardWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 비로그인 시 로그인 페이지로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        context.go('/login?source=board');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go('/login?source=board');
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(landingBoardRepositoryProvider);
      final postId = await repo.createPost(LandingPost(
        id: '',
        title: title,
        content: content,
        authorUid: user.uid,
        authorName: user.displayName ?? '익명',
        createdAt: DateTime.now(),
        type: widget.boardType,
      ));
      if (!mounted) return;
      context.go('/board/${widget.boardType}/$postId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('글 작성에 실패했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _landingBg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: LandingTopBar()),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 뒤로가기
                      TextButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        label: const Text('목록으로'),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        '${_boardTitle(widget.boardType)} 글쓰기',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 제목
                      const Text(
                        '제목',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4C3D8A)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: '제목을 입력하세요',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E0F8)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E0F8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF8B5CF6)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 내용
                      const Text(
                        '내용',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4C3D8A)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: '내용을 입력하세요',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E0F8)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E0F8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF8B5CF6)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        maxLines: 12,
                        minLines: 8,
                      ),
                      const SizedBox(height: 28),

                      // 제출 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : const Text('게시글 등록'),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 댓글 위젯 ─────────────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  final Stream<List<LandingComment>> commentsStream;

  const _CommentsSection({required this.commentsStream});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '댓글',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B4B)),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<LandingComment>>(
          stream: commentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final comments = snapshot.data ?? [];
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '첫 번째 댓글을 남겨보세요.',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF7C5CBF)),
                ),
              );
            }
            return Column(
              children: comments
                  .map((c) => _CommentItem(comment: c))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final LandingComment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy.MM.dd HH:mm').format(comment.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment.authorName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4C3D8A)),
              ),
              const Spacer(),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF7C5CBF))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: Color(0xFF1E1B4B)),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInput({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '댓글을 입력하세요...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E0F8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E0F8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
            minLines: 1,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: submitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('등록',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _LoginPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '로그인 후 댓글을 작성할 수 있어요.',
              style:
                  TextStyle(fontSize: 14, color: Color(0xFF4C3D8A)),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text(
              '로그인',
              style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
