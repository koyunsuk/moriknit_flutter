// 이슈 #783 — 앱 내 네이티브 게시판 (FAQ/QnA/릴리즈) 목록 화면.
//
// 외부 브라우저(launchUrl) 대신 앱 내 네이티브 화면으로 게시판 표시.
// 데이터 소스: landing_board_repository (랜딩과 동일 컬렉션 공유).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../landing/data/landing_board_repository.dart';
import 'app_board_detail_screen.dart';
import 'app_board_write_screen.dart';

class AppBoardListScreen extends ConsumerStatefulWidget {
  final String boardType; // 'faq' | 'qa' | 'release'

  const AppBoardListScreen({super.key, required this.boardType});

  @override
  ConsumerState<AppBoardListScreen> createState() => _AppBoardListScreenState();
}

class _AppBoardListScreenState extends ConsumerState<AppBoardListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _title(String type) {
    switch (type) {
      case 'faq':
        return '자주 묻는 질문';
      case 'qa':
        return 'Q&A 문의';
      case 'release':
        return '릴리즈 노트';
      default:
        return '게시판';
    }
  }

  bool _canWrite(String type, bool isAdmin) {
    if (type == 'qa') return true; // 사용자 작성 가능
    return isAdmin; // FAQ, release 는 admin만
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(landingBoardRepositoryProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAdmin = user?.email == 'koyunsuk@gmail.com';
    final canWrite = _canWrite(widget.boardType, isAdmin);
    final accent = widget.boardType == 'qa'
        ? C.lmD
        : widget.boardType == 'release'
            ? C.lv
            : C.pkD;

    return AppShellScaffold(
      title: _title(widget.boardType),
      subtitle: '',
      showBackButton: true,
      showBgOrbs: true,
      body: Column(
        children: [
          // 검색
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: C.gx,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LandingPost>>(
              stream: repo.getPosts(widget.boardType),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('오류: ${snap.error}', style: T.body.copyWith(color: C.og)),
                  );
                }
                var posts = snap.data ?? [];
                if (_query.isNotEmpty) {
                  posts = posts
                      .where((p) =>
                          p.title.toLowerCase().contains(_query) ||
                          p.content.toLowerCase().contains(_query))
                      .toList();
                }
                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.isEmpty ? '아직 게시글이 없어요.' : '검색 결과가 없어요.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = posts[i];
                    return GlassCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBoardDetailScreen(
                            boardType: widget.boardType,
                            postId: p.id,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: T.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.content,
                            style: T.caption.copyWith(color: C.tx2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                p.authorName,
                                style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(p.createdAt),
                                style: T.caption.copyWith(color: C.mu),
                              ),
                              const Spacer(),
                              if (p.commentCount > 0) ...[
                                Icon(Icons.chat_bubble_outline, size: 12, color: C.mu),
                                const SizedBox(width: 3),
                                Text('${p.commentCount}', style: T.caption.copyWith(color: C.mu)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              onPressed: () {
                if (user == null) {
                  context.push('/login');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppBoardWriteScreen(boardType: widget.boardType),
                  ),
                );
              },
              child: const Icon(Icons.edit_rounded),
            )
          : null,
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month}.${dt.day}';
  }
}
