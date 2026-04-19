import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/auth_provider.dart';
import '../data/landing_board_repository.dart';
import 'landing_scaffold.dart';
import 'landing_top_bar.dart';

const double _landingMaxWidth = 1160;
const Color _landingBg = Color(0xFFFFF8FB);

// ── 공지사항 목록 화면 (route: /notices) ─────────────────────────────────────

class LandingNoticeListScreen extends ConsumerWidget {
  const LandingNoticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(landingBoardRepositoryProvider);

    return LandingScaffold(
      slivers: [
          // 페이지 헤더
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _landingMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '공지사항',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '모리니트의 새로운 소식과 업데이트를 확인하세요.',
                        style: TextStyle(
                            color: Color(0xFFB0A8D8), fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 공지 목록
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: StreamBuilder<List<LandingPost>>(
                    stream: repo.getNotices(),
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
                      final notices = snapshot.data ?? [];
                      if (notices.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Text(
                              '등록된 공지사항이 없어요.',
                              style: TextStyle(
                                  fontSize: 15, color: Color(0xFF7C5CBF)),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: notices
                            .map((n) => _NoticeCard(
                                  notice: n,
                                  onTap: () => context
                                      .push('/notices/${n.id}'),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final LandingPost notice;
  final VoidCallback onTap;

  const _NoticeCard({required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(notice.createdAt);
    final hasFile = notice.fileUrl.isNotEmpty || notice.fileUrls.isNotEmpty;
    final fileName = notice.fileName.isNotEmpty
        ? notice.fileName
        : (notice.fileNames.isNotEmpty ? notice.fileNames.first : '첨부파일');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notice.isPinned
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
              : const Color(0xFFE5E0F8),
          width: notice.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 썸네일
            if (notice.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  notice.imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 60,
                    color: const Color(0xFFF5F0FF),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Color(0xFF8B5CF6), size: 24),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (notice.isPinned) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '📌 공지',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B5CF6)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          notice.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notice.isPinned ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7C5CBF)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF8B5CF6)),
                    ],
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 13, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 4),
                        Text(
                          '첨부파일: $fileName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공지사항 상세 화면 (route: /notices/:id) ──────────────────────────────────

class LandingNoticeDetailScreen extends ConsumerStatefulWidget {
  final String noticeId;

  const LandingNoticeDetailScreen({super.key, required this.noticeId});

  @override
  ConsumerState<LandingNoticeDetailScreen> createState() =>
      _LandingNoticeDetailScreenState();
}

class _LandingNoticeDetailScreenState
    extends ConsumerState<LandingNoticeDetailScreen> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment(LandingPost notice) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go('/login?source=notice');
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(landingBoardRepositoryProvider);
      await repo.addNoticeComment(
        widget.noticeId,
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
          SliverToBoxAdapter(child: LandingTopBar()),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: FutureBuilder<LandingPost?>(
                    future: repo.getNotice(widget.noticeId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final notice = snapshot.data;
                      if (notice == null) {
                        return const Center(
                            child: Text('공지사항을 찾을 수 없어요.'));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 뒤로가기
                          TextButton.icon(
                            onPressed: () => context.go('/notices'),
                            icon: const Icon(Icons.arrow_back_ios,
                                size: 16),
                            label: const Text('공지사항 목록'),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(height: 16),

                          // 제목
                          if (notice.isPinned)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '📌 공지',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B5CF6)),
                              ),
                            ),
                          Text(
                            notice.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('yyyy년 MM월 dd일').format(notice.createdAt),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF7C5CBF)),
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFEEE8FF)),
                          const SizedBox(height: 24),

                          // 내용
                          Text(
                            notice.content,
                            style: const TextStyle(
                                fontSize: 15, height: 1.8, color: Color(0xFF1E1B4B)),
                          ),
                          // 첨부 이미지 (단건 imageUrl + 복수 imageUrls 통합)
                          _NoticeImages(notice: notice),
                          // 첨부 파일 (단건 fileUrl + 복수 fileUrls 통합)
                          _NoticeFiles(notice: notice),
                          const SizedBox(height: 40),
                          const Divider(color: Color(0xFFEEE8FF)),
                          const SizedBox(height: 24),

                          // 댓글
                          _CommentsSection(
                            commentsStream:
                                repo.getNoticeComments(widget.noticeId),
                          ),
                          const SizedBox(height: 20),

                          // 댓글 입력
                          if (user != null)
                            _CommentInput(
                              controller: _commentController,
                              submitting: _submitting,
                              onSubmit: () => _submitComment(notice),
                            )
                          else
                            _LoginPrompt(
                              onTap: () => context
                                  .go('/login?source=notice'),
                            ),

                          const SizedBox(height: 60),
                        ],
                      );
                    },
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

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

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
                  style: TextStyle(fontSize: 14, color: Color(0xFF7C5CBF)),
                ),
              );
            }
            return Column(
              children: comments.map((c) => _CommentItem(comment: c)).toList(),
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
    final dateStr = DateFormat('yyyy.MM.dd HH:mm').format(comment.createdAt);
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
              style: TextStyle(fontSize: 14, color: Color(0xFF4C3D8A)),
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

// ── 공지사항 첨부 이미지 위젯 ─────────────────────────────────────────────────

class _NoticeImages extends StatelessWidget {
  final LandingPost notice;

  const _NoticeImages({required this.notice});

  @override
  Widget build(BuildContext context) {
    // 단건 imageUrl + 복수 imageUrls 통합 (중복 제거)
    final urls = <String>[
      if (notice.imageUrl.isNotEmpty) notice.imageUrl,
      ...notice.imageUrls.where((u) => u.isNotEmpty && u != notice.imageUrl),
    ];

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      children: urls.map((url) {
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, color: Color(0xFF8B5CF6), size: 32),
                    SizedBox(height: 8),
                    Text('이미지를 불러올 수 없어요', style: TextStyle(color: Color(0xFF7C5CBF), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 공지사항 첨부 파일 위젯 ───────────────────────────────────────────────────

class _NoticeFiles extends StatelessWidget {
  final LandingPost notice;

  const _NoticeFiles({required this.notice});

  @override
  Widget build(BuildContext context) {
    // 단건 fileUrl + 복수 fileUrls 통합 (중복 제거)
    final files = <({String url, String name})>[
      if (notice.fileUrl.isNotEmpty)
        (url: notice.fileUrl, name: notice.fileName),
      ...notice.fileUrls
          .asMap()
          .entries
          .where((e) => e.value.isNotEmpty && e.value != notice.fileUrl)
          .map((e) => (
                url: e.value,
                name: e.key < notice.fileNames.length
                    ? notice.fileNames[e.key]
                    : '',
              )),
    ];

    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      children: files.map((f) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse(f.url),
              mode: LaunchMode.externalApplication,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded,
                      color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.name.isNotEmpty ? f.name : '첨부 파일',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4C3D8A),
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.download_rounded,
                      color: Color(0xFF8B5CF6), size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    '다운로드',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
