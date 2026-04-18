import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/landing_board_repository.dart';
import 'landing_scaffold.dart';

const double _classMaxWidth = 1160;

// ── 클라스 목록 화면 (route: /classes) ────────────────────────────────────────

class LandingClassListScreen extends ConsumerWidget {
  const LandingClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(landingBoardRepositoryProvider);

    return LandingScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A2E1A), Color(0xFF2D4A2D), Color(0xFF3A5C3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _classMaxWidth),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFF4ADE80).withValues(alpha: 0.45)),
                        ),
                        child: const Text(
                          'MORIKNIT CLASS',
                          style: TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '클라스',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '모리니트 뜨개 클라스 강의',
                        style: TextStyle(
                            color: Color(0xFFD6CFEE), fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _classMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: StreamBuilder<List<LandingPost>>(
                  stream: repo.getPosts('class'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
                    }
                    final posts = snapshot.data ?? [];
                    if (posts.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(Icons.school_rounded, size: 48, color: Color(0xFF4ADE80)),
                              SizedBox(height: 16),
                              Text(
                                '곧 첫 번째 클라스가 시작될 예정이에요.',
                                style: TextStyle(fontSize: 15, color: Color(0xFF7C5CBF)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '기대해 주세요!',
                                style: TextStyle(fontSize: 13, color: Color(0xFFB0A8D8)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return _ClassGrid(posts: posts);
                  },
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _ClassGrid extends StatelessWidget {
  final List<LandingPost> posts;

  const _ClassGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 900 ? 3 : width > 600 ? 2 : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _ClassCard(
          post: post,
          onTap: () => context.push('/classes/${post.id}'),
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  final LandingPost post;
  final VoidCallback onTap;

  const _ClassCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(post.createdAt);
    final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2E1A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _e, _s) => _ClassImagePlaceholder(),
                    )
                  : _ClassImagePlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2E1A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CLASS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D4A2D),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B4B),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (post.content.isNotEmpty)
                      Text(
                        post.content,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C5CBF),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB0A8D8)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2E1A), Color(0xFF3A5C3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.school_rounded, size: 48, color: Colors.white54),
    );
  }
}

// ── 클라스 상세 화면 (route: /classes/:id) ────────────────────────────────────

class LandingClassDetailScreen extends ConsumerStatefulWidget {
  final String classId;

  const LandingClassDetailScreen({super.key, required this.classId});

  @override
  ConsumerState<LandingClassDetailScreen> createState() =>
      _LandingClassDetailScreenState();
}

class _LandingClassDetailScreenState
    extends ConsumerState<LandingClassDetailScreen> {
  LandingPost? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    final repo = ref.read(landingBoardRepositoryProvider);
    final post = await repo.getPost('class', widget.classId);
    if (mounted) {
      setState(() {
        _post = post;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LandingScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _classMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _post == null
                        ? const Center(child: Text('클라스를 찾을 수 없어요.'))
                        : _ClassDetailBody(post: _post!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassDetailBody extends StatelessWidget {
  final LandingPost post;

  const _ClassDetailBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/classes'),
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          label: const Text('클라스 목록'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF2D4A2D)),
        ),
        const SizedBox(height: 16),

        if (post.imageUrls.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              post.imageUrls.first,
              width: double.infinity,
              height: 360,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'CLASS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D4A2D),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          post.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E1B4B),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              post.authorName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7C5CBF)),
            ),
            const SizedBox(width: 8),
            const Text('·', style: TextStyle(color: Color(0xFFB0A8D8))),
            const SizedBox(width: 8),
            Text(
              DateFormat('yyyy년 MM월 dd일').format(post.createdAt),
              style: const TextStyle(fontSize: 13, color: Color(0xFFB0A8D8)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFFEEE8FF)),
        const SizedBox(height: 24),

        Text(
          post.content,
          style: const TextStyle(
              fontSize: 16, height: 1.9, color: Color(0xFF1E1B4B)),
        ),

        if (post.imageUrls.length > 1) ...[
          const SizedBox(height: 32),
          const Divider(color: Color(0xFFEEE8FF)),
          const SizedBox(height: 20),
          const Text(
            '첨부 이미지',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 12),
          ...post.imageUrls.skip(1).map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              )),
        ],

        const SizedBox(height: 60),
      ],
    );
  }
}
