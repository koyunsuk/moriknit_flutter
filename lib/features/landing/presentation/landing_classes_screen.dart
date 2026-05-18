import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/editorial_provider.dart';
import '../../home/domain/editorial_post.dart';
import 'landing_scaffold.dart';

const double _kDesktop = 900.0;

// ──────────────────────────────────────────────────────────────────────────────
// 클라스 랜딩 페이지 — /classes
//   히어로 + 코스 카탈로그 + 강사 + 에디토리얼(뜨개소식) + 후기 + CTA
// ──────────────────────────────────────────────────────────────────────────────
class LandingClassesScreen extends ConsumerStatefulWidget {
  const LandingClassesScreen({super.key});

  @override
  ConsumerState<LandingClassesScreen> createState() =>
      _LandingClassesScreenState();
}

class _LandingClassesScreenState extends ConsumerState<LandingClassesScreen> {
  String _category = 'all'; // 'all' | 'beginner' | 'intermediate' | 'advanced'

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _kDesktop;

    final filtered = _category == 'all'
        ? _kCourses
        : _kCourses.where((c) => c.level == _category).toList();

    return LandingFeatureScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  isDesktop ? 40 : 28,
                  isDesktop ? 24 : 16,
                  isDesktop ? 60 : 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(isDesktop: isDesktop),
                    const SizedBox(height: 40),
                    _SectionTitle(
                      icon: Icons.school_rounded,
                      title: '클라스 카탈로그',
                      subtitle: '레벨별로 골라 듣는 모리니트 클라스',
                    ),
                    const SizedBox(height: 16),
                    _CategoryChips(
                      current: _category,
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 20),
                    _CourseGrid(courses: filtered, isDesktop: isDesktop),
                    const SizedBox(height: 56),
                    _SectionTitle(
                      icon: Icons.person_pin_rounded,
                      title: '강사 소개',
                      subtitle: '오랜 경험을 담은 모리니트 시그니처 강사진',
                    ),
                    const SizedBox(height: 16),
                    _InstructorRow(isDesktop: isDesktop),
                    const SizedBox(height: 56),
                    _SectionTitle(
                      icon: Icons.auto_stories_rounded,
                      title: '오늘의 knitting 소식',
                      subtitle: '모리니트 에디터가 직접 큐레이션한 뜨개 콘텐츠',
                    ),
                    const SizedBox(height: 16),
                    _EditorialBoard(isDesktop: isDesktop),
                    const SizedBox(height: 56),
                    _SectionTitle(
                      icon: Icons.format_quote_rounded,
                      title: '수강생 후기',
                      subtitle: '먼저 경험한 분들의 솔직한 이야기',
                    ),
                    const SizedBox(height: 16),
                    _ReviewWall(isDesktop: isDesktop),
                    const SizedBox(height: 56),
                    _CtaPanel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 히어로 패널
// ──────────────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final bool isDesktop;
  const _Hero({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 24,
        vertical: isDesktop ? 56 : 36,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFFCE7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.20)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, size: 14, color: Color(0xFF7C3AED)),
                SizedBox(width: 6),
                Text(
                  'MORIKNIT CLASS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B21B6),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 14),
          Text(
            '뜨개를 처음 시작하는 분도,\n나만의 도안을 만들고 싶은 분도.',
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A2E),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '모리니트 클라스는 손뜨개의 첫걸음부터 차트·서술형 도안 작성, AI 변환 활용까지 — 손끝의 작은 동작 하나하나를 친절하게 안내합니다.',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: const Color(0xFF374151),
              height: 1.7,
            ),
          ),
          SizedBox(height: isDesktop ? 28 : 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(icon: Icons.video_library_rounded, label: '실습 영상 200+'),
              _HeroBadge(icon: Icons.workspace_premium_rounded, label: '검증된 강사진'),
              _HeroBadge(icon: Icons.devices_rounded, label: '앱 + 웹 동시 학습'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 섹션 타이틀
// ──────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: const Color(0xFF7C3AED), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 카테고리 칩
// ──────────────────────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _CategoryChips({required this.current, required this.onChanged});

  static const _items = <(String, String)>[
    ('all', '전체'),
    ('beginner', '입문'),
    ('intermediate', '중급'),
    ('advanced', '고급'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _items.map((e) {
        final selected = current == e.$1;
        return GestureDetector(
          onTap: () => onChanged(e.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF7C3AED) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF7C3AED).withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              e.$2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF5B21B6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 코스 그리드
// ──────────────────────────────────────────────────────────────────────────────
class _CourseGrid extends StatelessWidget {
  final List<_Course> courses;
  final bool isDesktop;
  const _CourseGrid({required this.courses, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cols = isDesktop ? 3 : 1;
    return LayoutBuilder(
      builder: (context, c) {
        final spacing = 16.0;
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: courses
              .map((course) => SizedBox(
                    width: itemW,
                    child: _CourseCard(course: course),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일 (그라디언트 + 아이콘)
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [course.color, course.color.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    course.icon,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _levelLabel(course.level),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  course.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // 챕터 미리보기
                ...course.chapters.take(3).map((ch) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: BoxDecoration(
                              color: course.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ch,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF374151),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${course.totalMinutes}분 · ${course.chapters.length}챕터',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      course.instructor,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: course.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'beginner':
        return '입문';
      case 'intermediate':
        return '중급';
      case 'advanced':
        return '고급';
      default:
        return '전체';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 강사 소개
// ──────────────────────────────────────────────────────────────────────────────
class _InstructorRow extends StatelessWidget {
  final bool isDesktop;
  const _InstructorRow({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cols = isDesktop ? 3 : 1;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 16.0;
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _kInstructors
              .map((i) => SizedBox(
                    width: itemW,
                    child: _InstructorCard(instructor: i),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _InstructorCard extends StatelessWidget {
  final _Instructor instructor;
  const _InstructorCard({required this.instructor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      instructor.color,
                      instructor.color.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    instructor.initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructor.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instructor.role,
                      style: TextStyle(
                        fontSize: 12,
                        color: instructor.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            instructor.bio,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: instructor.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: instructor.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: instructor.color,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 에디토리얼 보드 — Firestore editorial_posts (letter/tips/trending) 통합
// ──────────────────────────────────────────────────────────────────────────────
class _EditorialBoard extends ConsumerWidget {
  final bool isDesktop;
  const _EditorialBoard({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letterAsync = ref.watch(editorialLatestProvider('letter'));
    final tipsAsync = ref.watch(editorialLatestProvider('tips'));
    final trendingAsync = ref.watch(editorialLatestProvider('trending'));
    final youtubeAsync = ref.watch(editorialLatestProvider('youtube'));

    final List<EditorialPost> posts = [
      ...letterAsync.valueOrNull ?? const <EditorialPost>[],
      ...tipsAsync.valueOrNull ?? const <EditorialPost>[],
      ...trendingAsync.valueOrNull ?? const <EditorialPost>[],
      ...youtubeAsync.valueOrNull ?? const <EditorialPost>[],
    ];

    if (posts.isEmpty) {
      return _EditorialPlaceholder(isDesktop: isDesktop);
    }

    final cols = isDesktop ? 3 : 1;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 16.0;
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: posts
              .take(6)
              .map((p) => SizedBox(
                    width: itemW,
                    child: _EditorialCard(post: p),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _EditorialCard extends StatelessWidget {
  final EditorialPost post;
  const _EditorialCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final isYoutube =
        post.type == 'youtube' && post.youtubeVideoId.isNotEmpty;
    final hasImage = post.imageUrl.isNotEmpty || isYoutube;
    final thumbUrl = isYoutube
        ? 'https://img.youtube.com/vi/${post.youtubeVideoId}/mqdefault.jpg'
        : post.imageUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (isYoutube) {
          launchUrl(
            Uri.parse('https://www.youtube.com/watch?v=${post.youtubeVideoId}'),
            mode: LaunchMode.externalApplication,
          );
        } else if (post.attachmentUrl.isNotEmpty) {
          launchUrl(Uri.parse(post.attachmentUrl),
              mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDE9FE)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: thumbUrl,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: double.infinity,
                      height: 140,
                      color: const Color(0xFFF5F3FF),
                      child: const Icon(Icons.image_outlined,
                          color: Color(0xFFB39DDB), size: 32),
                    ),
                  ),
                  if (isYoutube)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 28),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: post.type),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'letter' => ('뜨개 레터', const Color(0xFF7C3AED)),
      'tips' => ('추천 정보', const Color(0xFF0891B2)),
      'trending' => ('인기 토픽', const Color(0xFFEC4899)),
      'youtube' => ('YouTube', const Color(0xFFE11D48)),
      _ => ('소식', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EditorialPlaceholder extends StatelessWidget {
  final bool isDesktop;
  const _EditorialPlaceholder({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cols = isDesktop ? 3 : 1;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 16.0;
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            cols,
            (i) => SizedBox(
              width: itemW,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFEDE9FE), style: BorderStyle.solid),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '곧 새로운 뜨개 소식이 올라올 예정이에요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 수강생 후기
// ──────────────────────────────────────────────────────────────────────────────
class _ReviewWall extends StatelessWidget {
  final bool isDesktop;
  const _ReviewWall({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cols = isDesktop ? 3 : 1;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 16.0;
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _kReviews
              .map((r) => SizedBox(
                    width: itemW,
                    child: _ReviewCard(review: r),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star_rounded,
                size: 16,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"${review.text}"',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A2E),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded,
                      size: 18, color: Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    review.course,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CTA
// ──────────────────────────────────────────────────────────────────────────────
class _CtaPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '지금 바로 모리니트 클라스를 시작해 보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '회원가입 후 모든 입문 강의를 무료로 들을 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/signup?source=classes'),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('무료로 시작하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF5B21B6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined, size: 16),
                label: const Text('홈으로 돌아가기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 가상 데이터 모델
// ──────────────────────────────────────────────────────────────────────────────
class _Course {
  final String title;
  final String summary;
  final String level; // beginner | intermediate | advanced
  final String instructor;
  final int totalMinutes;
  final List<String> chapters;
  final IconData icon;
  final Color color;

  const _Course({
    required this.title,
    required this.summary,
    required this.level,
    required this.instructor,
    required this.totalMinutes,
    required this.chapters,
    required this.icon,
    required this.color,
  });
}

const List<_Course> _kCourses = [
  _Course(
    title: '초보자 코바늘 입문',
    summary:
        '코바늘을 처음 잡는 분도 30일 안에 작은 가방 하나를 완성할 수 있도록 손동작과 기초 코를 차근차근 익혀요.',
    level: 'beginner',
    instructor: '윤모리',
    totalMinutes: 240,
    chapters: [
      '도구 준비와 실 잡는 법',
      '사슬뜨기·짧은뜨기·긴뜨기 기초 3종',
      '원형뜨기로 작은 컵받침 만들기',
      '간단한 토트백 완성하기',
    ],
    icon: Icons.favorite_rounded,
    color: Color(0xFFEC4899),
  ),
  _Course(
    title: '대바늘 모자 만들기',
    summary:
        '겉뜨기·안뜨기부터 코늘리기·코줄이기까지, 머리에 꼭 맞는 비니 한 개를 완성하는 4주 클라스.',
    level: 'beginner',
    instructor: '한라벤',
    totalMinutes: 320,
    chapters: [
      '대바늘 잡기와 첫 코 만들기',
      '메리야스뜨기·고무뜨기 익히기',
      '게이지 측정과 사이즈 조정',
      '비니 본체 + 마무리 코 정리',
    ],
    icon: Icons.emoji_emotions_rounded,
    color: Color(0xFF7C3AED),
  ),
  _Course(
    title: 'AI 도안 변환 마스터',
    summary:
        '내 손에 있는 PDF 도안을 모리니트 AI로 변환하고, 차트·서술형으로 자유롭게 편집하는 실전 워크플로우.',
    level: 'intermediate',
    instructor: '강도안',
    totalMinutes: 280,
    chapters: [
      'PDF 업로드와 자동 분석 흐름',
      '서술형 섹션 그룹화·편집',
      '차트 보정과 RS/WS 구분',
      '완성 도안으로 프로젝트 시작하기',
    ],
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF0891B2),
  ),
  _Course(
    title: '서술형 도안 작성법',
    summary:
        '내 디자인을 글로 풀어내는 법. 단계 표기·반복 구간·약어 사용까지 깔끔한 도안 한 편을 함께 만들어요.',
    level: 'intermediate',
    instructor: '윤모리',
    totalMinutes: 360,
    chapters: [
      '도안 표준 기호와 약어',
      '반복 구간(Repeat) 표기법',
      '사이즈 다중 표기 패턴',
      '리뷰 받고 다듬는 마지막 한 끗',
    ],
    icon: Icons.edit_note_rounded,
    color: Color(0xFF65A30D),
  ),
  _Course(
    title: '레이스 숄 패턴 디자인',
    summary:
        '얇은 실로 풀어내는 레이스 숄. 차트 작성, 바늘 사이즈 선택, 블로킹까지 전 과정을 다루는 고급 클라스.',
    level: 'advanced',
    instructor: '한라벤',
    totalMinutes: 480,
    chapters: [
      '레이스 차트 읽기와 직접 그리기',
      '얇은 실 게이지 잡는 법',
      '복잡한 패턴 반복 구조 설계',
      '블로킹과 마감 디테일',
    ],
    icon: Icons.spa_rounded,
    color: Color(0xFFC026D3),
  ),
  _Course(
    title: '판매용 도안 만들기',
    summary:
        '도안을 상품으로 — 표지 디자인, 카피라이팅, 가격 책정과 배포 채널 운영까지 실전 노하우 모음.',
    level: 'advanced',
    instructor: '강도안',
    totalMinutes: 300,
    chapters: [
      '판매용 도안의 필수 구성',
      '표지·미리보기 이미지 만들기',
      '가격 정책과 라이선스 정리',
      '마켓 등록과 후기 관리',
    ],
    icon: Icons.storefront_rounded,
    color: Color(0xFFEA580C),
  ),
];

class _Instructor {
  final String name;
  final String role;
  final String initial;
  final String bio;
  final List<String> tags;
  final Color color;

  const _Instructor({
    required this.name,
    required this.role,
    required this.initial,
    required this.bio,
    required this.tags,
    required this.color,
  });
}

const List<_Instructor> _kInstructors = [
  _Instructor(
    name: '윤모리',
    role: '시니어 니트 디자이너',
    initial: '윤',
    bio:
        '15년 차 손뜨개 작가. 라벨리에서 활동 중이며, 초보자도 따라올 수 있는 친절한 설명이 강점입니다.',
    tags: ['코바늘', '입문 친화', '소품 디자인'],
    color: Color(0xFFEC4899),
  ),
  _Instructor(
    name: '한라벤',
    role: '대바늘 전문 강사',
    initial: '한',
    bio:
        '12년 차 대바늘 강사. 모자·스웨터·숄까지 다양한 의류 도안을 직접 디자인하고 가르칩니다.',
    tags: ['대바늘', '의류', '레이스'],
    color: Color(0xFF7C3AED),
  ),
  _Instructor(
    name: '강도안',
    role: '도안·AI 변환 전문가',
    initial: '강',
    bio:
        'PDF 도안 변환과 디지털 도안 제작 전문가. 내 도안을 더 효율적으로 만드는 디지털 워크플로우를 알려드려요.',
    tags: ['AI 변환', '서술형', '디지털 워크플로우'],
    color: Color(0xFF0891B2),
  ),
];

class _Review {
  final String name;
  final String course;
  final String text;
  final int rating;
  const _Review({
    required this.name,
    required this.course,
    required this.text,
    required this.rating,
  });
}

const List<_Review> _kReviews = [
  _Review(
    name: '김지윤',
    course: '초보자 코바늘 입문',
    text:
        '뜨개를 처음 시작하는 입장에서 정말 친절했어요. 영상 한 편 분량이 부담 없어서 매일 조금씩 따라가다 보니 어느새 가방 하나가 완성됐네요.',
    rating: 5,
  ),
  _Review(
    name: '박서영',
    course: '대바늘 모자 만들기',
    text:
        '게이지 부분이 늘 헷갈렸는데 강사님이 한 땀씩 보여주셔서 단번에 이해됐어요. 사이즈 조정까지 자신 있게 할 수 있게 되었습니다.',
    rating: 5,
  ),
  _Review(
    name: '이하늘',
    course: 'AI 도안 변환 마스터',
    text:
        '들고 있던 PDF 도안 수십 장이 정리되는 기분이에요. 서술형 그룹화 기능이 진짜 신세계입니다.',
    rating: 4,
  ),
];
