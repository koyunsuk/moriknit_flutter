import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/encyclopedia_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/post_provider.dart';
import '../../community/domain/post_model.dart';
import '../../encyclopedia/domain/encyclopedia_entry.dart';
import '../../market/domain/market_item.dart';

const double _landingMaxWidth = 1160;

// ── 최근 가입자 스트림 ─────────────────────────────────────────────────────────
final _landingRecentUsersProvider = StreamProvider<List<String>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(8)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final name = (doc.data()['displayName'] as String?)?.trim() ?? '';
            return name.isNotEmpty ? name : '새 메이커';
          }).toList());
});

// ── 통계 ──────────────────────────────────────────────────────────────────────
final _landingStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = FirebaseFirestore.instance;
  final results = await Future.wait([
    db.collection('users').limit(500).get(),
    db.collection('projects').limit(500).get(),
    db.collection('market_items').limit(500).get(),
  ]);
  return {
    'users': results[0].size,
    'projects': results[1].size,
    'market': results[2].size,
  };
});

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final marketAsync = ref.watch(marketItemsProvider);
    final postsAsync = ref.watch(postsProvider(communityAllCategory));
    final encyclopediaAsync = ref.watch(encyclopediaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _LandingTopBar(
              isLoggedIn: user != null,
              onLogin: () => context.go(Routes.login),
              onOpenApp: () => context.go(Routes.home),
            ),
          ),
          SliverToBoxAdapter(
            child: _PromoBanner(
              onTap: user == null ? () => context.go(Routes.login) : () => context.go(Routes.home),
            ),
          ),
          SliverToBoxAdapter(
            child: _LandingHero(
              isLoggedIn: user != null,
              onLogin: () => context.go(Routes.login),
              onOpenApp: () => context.go(Routes.home),
            ),
          ),
          // ── 앱 화면 목업 ───────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _AppScreensSection()),
          // ── 통계 바 ────────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _StatsBar()),
          // ── 인기 마켓 ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '인기 마켓',
              subtitle: '실, 도안, 뜨개 도구를 미리 살펴보세요.',
              actionLabel: user == null ? '로그인 후 더 보기' : '마켓으로',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.market),
              child: marketAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (_, _) => const _LandingEmptyCard(icon: Icons.storefront_outlined, title: '마켓 데이터를 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
                data: (items) => items.isEmpty
                    ? const _LandingEmptyCard(icon: Icons.storefront_outlined, title: '등록된 상품이 아직 없어요', message: '관리자와 판매자가 등록한 상품이 여기에 표시됩니다.')
                    : _LandingCardGrid(children: items.take(6).map((item) => _MarketPreviewCard(item: item)).toList()),
              ),
            ),
          ),
          // ── 커뮤니티 ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '커뮤니티 미리보기',
              subtitle: '메이커들의 최근 이야기를 가볍게 둘러보세요.',
              actionLabel: user == null ? '로그인 후 이어보기' : '커뮤니티로',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.community),
              child: postsAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (_, _) => const _LandingEmptyCard(icon: Icons.forum_outlined, title: '커뮤니티 글을 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
                data: (posts) => posts.isEmpty
                    ? const _LandingEmptyCard(icon: Icons.forum_outlined, title: '아직 등록된 글이 없어요', message: '첫 글부터 차곡차곡 커뮤니티가 채워질 예정이에요.')
                    : _LandingCardGrid(children: posts.take(6).map((post) => _PostPreviewCard(post: post)).toList()),
              ),
            ),
          ),
          // ── 뜨개백과 ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '뜨개백과사전',
              subtitle: '뜨개 용어와 기법을 언제든지 찾아보세요.',
              actionLabel: user == null ? '로그인 후 더 보기' : '사전으로',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.toolsEncyclopedia),
              child: encyclopediaAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (_, _) => const _LandingEmptyCard(icon: Icons.menu_book_outlined, title: '백과사전 데이터를 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
                data: (entries) => entries.isEmpty
                    ? const _LandingEmptyCard(icon: Icons.menu_book_outlined, title: '뜨개백과사전이 곧 채워집니다', message: '관리자가 등록한 뜨개 용어와 기법 설명이 여기에 표시됩니다.')
                    : _LandingCardGrid(children: entries.take(6).map((entry) => _EncyclopediaPreviewCard(entry: entry)).toList()),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _FeatureSection()),
          const SliverToBoxAdapter(child: _CtaSection()),
          const SliverToBoxAdapter(child: _LandingFooter()),
        ],
      ),
    );
  }
}

// ── 스파클 파티클 ─────────────────────────────────────────────────────────────
class _SparkleParticle {
  final AnimationController controller;
  final double x;   // 0.0 ~ 1.0 (비율)
  final String emoji;
  final double drift; // 좌우 흔들림
  final double size;

  _SparkleParticle({
    required this.controller,
    required this.x,
    required this.emoji,
    required this.drift,
    required this.size,
  });
}

// ── 탑바 ──────────────────────────────────────────────────────────────────────
class _LandingTopBar extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onOpenApp;

  const _LandingTopBar({required this.isLoggedIn, required this.onLogin, required this.onOpenApp});

  @override
  State<_LandingTopBar> createState() => _LandingTopBarState();
}

class _LandingTopBarState extends State<_LandingTopBar> with TickerProviderStateMixin {
  static const _emojis = ['❤️', '🩷', '♪', '♫', '✨', '💜', '🎵'];
  final _rng = Random();
  final _particles = <_SparkleParticle>[];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) => _spawnParticle());
  }

  void _spawnParticle() {
    if (!mounted) return;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    final p = _SparkleParticle(
      controller: ctrl,
      x: _rng.nextDouble(),
      emoji: _emojis[_rng.nextInt(_emojis.length)],
      drift: (_rng.nextDouble() - 0.5) * 20,
      size: 14 + _rng.nextDouble() * 10,
    );
    setState(() => _particles.add(p));
    ctrl.forward().then((_) {
      if (mounted) setState(() => _particles.remove(p));
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.96),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const MoriLogo(size: 32),
                    const SizedBox(width: 10),
                    const MoriKnitTitle(fontSize: 19),
                    const Spacer(),
                    if (!widget.isLoggedIn)
                      TextButton(onPressed: widget.onLogin, child: const Text('로그인')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: widget.isLoggedIn ? widget.onOpenApp : widget.onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.lv,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(widget.isLoggedIn ? '앱으로 이동' : '무료로 시작하기',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── 파티클 오버레이 ──────────────────────────────────────────────
          ..._particles.map((p) => AnimatedBuilder(
                animation: p.controller,
                builder: (context, _) {
                  final t = p.controller.value;
                  final opacity = t < 0.15 ? t / 0.15 : t > 0.65 ? (1 - t) / 0.35 : 1.0;
                  final barWidth = MediaQuery.of(context).size.width;
                  return Positioned(
                    left: p.x * barWidth + p.drift * t * 2,
                    bottom: 4 + 48 * t,
                    child: Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.7 + 0.5 * (1 - t),
                        child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
                      ),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}

// ── 방명록 활동 스트립 ──────────────────────────────────────────────────────────
class _ActivityStrip extends ConsumerStatefulWidget {
  const _ActivityStrip();

  @override
  ConsumerState<_ActivityStrip> createState() => _ActivityStripState();
}

class _ActivityStripState extends ConsumerState<_ActivityStrip> {
  int _index = 0;
  Timer? _timer;

  static const _fallback = ['뜨개 메이커', '새 메이커', '아리뜨개', '코바늘러', '대바늘장인'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_landingRecentUsersProvider);
    final names = usersAsync.valueOrNull ?? _fallback;
    if (names.isEmpty) return const SizedBox.shrink();

    final items = [
      ...names.map((n) => '🎉 $n님이 모리니트에 합류했어요!'),
      '🧶 오늘도 뜨개를 사랑하는 메이커들이 함께해요',
      '📁 새 프로젝트를 시작하고 기록해 보세요',
      '🛍 마켓에서 나만의 도안을 찾아보세요',
    ];

    final current = items[_index % items.length];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.lv.withValues(alpha: 0.10), C.pk.withValues(alpha: 0.08)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: C.lv.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            current,
            key: ValueKey(current),
            style: TextStyle(fontSize: 12.5, color: C.lvD, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// ── 프로모 배너 (activity strip 통합) ────────────────────────────────────────
class _PromoBanner extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _PromoBanner({required this.onTap});

  @override
  ConsumerState<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends ConsumerState<_PromoBanner> {
  int _index = 0;
  Timer? _timer;

  static const _fallback = ['뜨개 메이커', '새 메이커', '아리뜨개', '코바늘러', '대바늘장인'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_landingRecentUsersProvider);
    final names = usersAsync.valueOrNull ?? _fallback;
    final items = [
      ...names.map((n) => '✨ $n님이 모리니트에 합류했어요!'),
      '🧶 오늘도 뜨개를 사랑하는 메이커들이 함께해요',
      '📁 새 프로젝트를 시작하고 기록해 보세요',
    ];
    final current = items.isEmpty ? '' : items[_index % items.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 상단: 활동 스트립
        Container(
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [C.lv.withValues(alpha: 0.10), C.pk.withValues(alpha: 0.08)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(bottom: BorderSide(color: C.lv.withValues(alpha: 0.12))),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                current,
                key: ValueKey(current),
                style: TextStyle(fontSize: 12, color: C.lvD, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        // 하단: 프로모
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.pk, C.pkD], begin: Alignment.centerLeft, end: Alignment.centerRight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉 지금 가입하면 3개월 Pro 무료 사용!',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('무료로 시작하기', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 히어로 섹션 ───────────────────────────────────────────────────────────────
class _LandingHero extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onOpenApp;

  const _LandingHero({required this.isLoggedIn, required this.onLogin, required this.onOpenApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF7FB),
            C.pk.withValues(alpha: 0.10),
            C.lv.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 40),
            child: Column(
              children: [
                const MoriLogo(size: 96),
                const SizedBox(height: 12),
                const MoriKnitTitle(fontSize: 34, width: 240),
                const SizedBox(height: 16),
                Text(
                  '뜨개 프로젝트, 커뮤니티, 마켓, 백과사전을 한곳에 모은 작업 플랫폼',
                  style: T.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '웹에서는 크게 보고, 모바일에서는 가볍게 기록하고 이어가는 Moriknit의 흐름을 소개합니다.',
                  style: T.body.copyWith(color: C.tx2, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: isLoggedIn ? onOpenApp : onLogin,
                      child: Text(isLoggedIn ? '앱으로 이동' : '무료로 시작하기'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(Routes.market),
                      child: const Text('마켓 둘러보기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 앱 화면 목업 섹션 ──────────────────────────────────────────────────────────
class _AppScreensSection extends StatefulWidget {
  const _AppScreensSection();
  @override
  State<_AppScreensSection> createState() => _AppScreensSectionState();
}

class _AppScreensSectionState extends State<_AppScreensSection> {
  static const _screens = [
    (label: '홈', emoji: '🏠', highlight: false),
    (label: '프로젝트 목록', emoji: '📁', highlight: false),
    (label: '나의 니팅 코치 ★', emoji: '📋', highlight: true),
    (label: '카운터', emoji: '🔢', highlight: false),
    (label: '스와치', emoji: '🧶', highlight: false),
    (label: '도안 에디터', emoji: '✏️', highlight: false),
    (label: '마켓', emoji: '🛍️', highlight: false),
    (label: '내 도안 판매', emoji: '💰', highlight: false),
    (label: '커뮤니티', emoji: '💬', highlight: false),
    (label: '강의', emoji: '🎬', highlight: false),
    (label: '뜨개백과', emoji: '📚', highlight: false),
    (label: 'English', emoji: '🌐', highlight: false),
    (label: '테마 설정', emoji: '🎨', highlight: false),
    (label: 'Ravelry 실 검색', emoji: '🔍', highlight: false),
    (label: 'Ravelry 도안 검색', emoji: '📖', highlight: false),
  ];

  static const _frameW = 200.0;
  static const _frameGap = 20.0;
  static const _frameStep = _frameW + _frameGap;
  static const _sidePad = 24.0;

  final _scrollCtrl = ScrollController();
  Timer? _timer;
  int _currentIndex = 0;
  bool _userScrolling = false;
  double _viewportWidth = 600; // 초기값, LayoutBuilder로 갱신

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 2, milliseconds: 500), (_) {
      if (!mounted || _userScrolling) return;
      final next = (_currentIndex + 1) % _screens.length;
      _goTo(next);
    });
  }

  /// 뷰포트 중앙에 가장 가까운 프레임 인덱스 계산
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final viewCenter = _scrollCtrl.offset + _viewportWidth / 2;
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _screens.length; i++) {
      final frameCenter = _sidePad + i * _frameStep + _frameW / 2;
      final dist = (frameCenter - viewCenter).abs();
      if (dist < minDist) { minDist = dist; closestIdx = i; }
    }
    if (closestIdx != _currentIndex) setState(() => _currentIndex = closestIdx);
  }

  /// 프레임 i가 뷰포트 가운데 오도록 스크롤
  void _goTo(int index) {
    if (!_scrollCtrl.hasClients) return;
    setState(() => _currentIndex = index);
    final frameCenter = _sidePad + index * _frameStep + _frameW / 2;
    final targetOffset = (frameCenter - _viewportWidth / 2)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onTapDot(int i) {
    _userScrolling = true;
    _goTo(i);
    Future.delayed(const Duration(seconds: 4), () { if (mounted) _userScrolling = false; });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF0EAFF),
            const Color(0xFFFFF0F8),
            const Color(0xFFEAF4FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 섹션 헤더 ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [C.lv, C.pk]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('✨ 함께 성장하는 뜨개 플랫폼', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 18),
                    Text('하나씩 따라하다 보면 완성돼요', style: T.h2, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      '니팅 코치가 처음부터 끝까지 안내해 드려요.\n완성 후엔 직접 도안을 만들어 판매까지.',
                      style: T.body.copyWith(color: C.tx2, height: 1.7),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    // 성장 흐름
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: C.lv.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: C.lv.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Wrap(
                        spacing: 8, runSpacing: 10,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _flowChip('📋 니팅 코치', C.lv),
                          _arrow(),
                          _flowChip('✅ 프로젝트 완성', C.pk),
                          _arrow(),
                          _flowChip('✏️ 도안 제작', C.lmD),
                          _arrow(),
                          _flowChip('🛒 마켓 판매', C.pkD),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // ── 가로 스크롤 캐러셀 ─────────────────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                // 뷰포트 너비 갱신
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_viewportWidth != constraints.maxWidth) {
                    _viewportWidth = constraints.maxWidth;
                  }
                });
                return SizedBox(
                  height: 600,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification) _userScrolling = true;
                      if (n is ScrollEndNotification) {
                        Future.delayed(const Duration(seconds: 3), () { if (mounted) _userScrolling = false; });
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(_sidePad, 50, _sidePad, 50),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _screens.length; i++) ...[
                            if (i > 0) const SizedBox(width: _frameGap),
                            _buildAnimatedFrame(i),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // ── 인디케이터 도트 ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_screens.length, (i) {
                    final isActive = i == _currentIndex;
                    return GestureDetector(
                      onTap: () => _onTapDot(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? C.lv : C.bd2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFrame(int i) {
    final isActive = i == _currentIndex;
    final s = _screens[i];
    return GestureDetector(
      onTap: () => _onTapDot(i),
      child: AnimatedScale(
        scale: isActive ? 1.18 : 0.82,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isActive ? 1.0 : 0.45,
          child: _PhoneFrame(
            label: s.label,
            emoji: s.emoji,
            highlight: s.highlight || isActive,
            isActive: isActive,
            child: _buildScreen(i),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(int i) {
    return switch (i) {
      0 => const _MockHomeScreen(),
      1 => const _MockProjectListScreen(),
      2 => const _MockStepLogScreen(),
      3 => const _MockCounterScreen(),
      4 => const _MockSwatchScreen(),
      5 => const _MockPatternEditorScreen(),
      6 => const _MockMarketScreen(),
      7 => const _MockSellerScreen(),
      8 => const _MockCommunityScreen(),
      9 => const _MockCourseScreen(),
      10 => const _MockEncyclopediaScreen(),
      11 => const _MockEnglishScreen(),
      12 => const _MockThemeScreen(),
      13 => const _MockRavelryYarnScreen(),
      _ => const _MockRavelryPatternScreen(),
    };
  }

  Widget _flowChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _arrow() => Icon(Icons.arrow_forward_rounded, size: 14, color: C.mu);
}

// ── 폰 프레임 ──────────────────────────────────────────────────────────────────
class _PhoneFrame extends StatelessWidget {
  final String label;
  final String emoji;
  final Widget child;
  final bool highlight;
  final bool isActive;

  const _PhoneFrame({required this.label, required this.emoji, required this.child, this.highlight = false, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final active = highlight || isActive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: 200,
          height: 420,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: active ? C.lv : C.bd2, width: active ? 2.5 : 1.5),
            boxShadow: active
                ? [BoxShadow(color: C.lv.withValues(alpha: 0.30), blurRadius: 40, offset: const Offset(0, 14))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              children: [
                Container(
                  height: 26,
                  color: C.gx,
                  child: Center(child: Container(width: 52, height: 5, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(3)))),
                ),
                Expanded(child: child),
                Container(
                  height: 20,
                  color: Colors.white,
                  child: Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: active ? C.lv : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$emoji $label',
            style: TextStyle(fontSize: 11, color: active ? Colors.white : C.tx2, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── 공통 헤더/탭 헬퍼 ─────────────────────────────────────────────────────────
Widget _mockHeader(String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.bd))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.tx)),
      Text(subtitle, style: TextStyle(fontSize: 8, color: C.tx2)),
    ]),
  );
}

Widget _mockBottomNav(int selected) {
  const tabs = [(Icons.home_rounded, '홈'), (Icons.folder_special_rounded, '프로젝트'), (Icons.people_alt_rounded, '커뮤니티'), (Icons.grid_view_rounded, '스와치'), (Icons.person_rounded, '마이')];
  final colors = [C.pk, C.lv, C.pkD, C.lmD, C.mu];
  return Container(
    height: 44,
    decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.bd))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(tabs.length, (i) {
        final sel = i == selected;
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(tabs[i].$1, size: 14, color: sel ? colors[i] : C.mu),
          Text(tabs[i].$2, style: TextStyle(fontSize: 7, color: sel ? colors[i] : C.mu, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ]);
      }),
    ),
  );
}

// ── 1. 홈 화면 ────────────────────────────────────────────────────────────────
class _MockHomeScreen extends StatelessWidget {
  const _MockHomeScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('홈', '오늘도 즐거운 뜨개질! 🧡'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.lv.withValues(alpha: 0.12), C.pk.withValues(alpha: 0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.lv.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat('프로젝트', '3', C.lv),
                  _stat('스와치', '12', C.lmD),
                  _stat('커뮤니티', '48', C.pkD),
                ]),
              ),
              const SizedBox(height: 9),
              _sectionLabel('인기도안 TOP5'),
              const SizedBox(height: 5),
              _itemRow('탑다운 스웨터 도안', '₩3,500', C.lv),
              const SizedBox(height: 3),
              _itemRow('케이블 목도리 도안', '₩2,000', C.pk),
              const SizedBox(height: 3),
              _itemRow('아란 손모아 장갑', '₩4,000', C.lmD),
              const SizedBox(height: 9),
              _sectionLabel('커뮤니티 하이라이트'),
              const SizedBox(height: 5),
              _postRow('완성작 공유해요 🧶', '모리메이커'),
              const SizedBox(height: 3),
              _postRow('실 추천 부탁드려요', '뜨개고수'),
            ]),
          ),
        ),
        _mockBottomNav(0),
      ]),
    );
  }
}

// ── 2. 프로젝트 목록 ──────────────────────────────────────────────────────────
class _MockProjectListScreen extends StatelessWidget {
  const _MockProjectListScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('프로젝트', '나의 뜨개 작업실'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _projectCard('탑다운 스웨터', '진행 중', 0.8, C.lv),
              const SizedBox(height: 7),
              _projectCard('손모아 장갑', '완성', 1.0, C.pk),
              const SizedBox(height: 7),
              _projectCard('케이블 목도리', '시작 전', 0.0, C.lmD),
              const SizedBox(height: 7),
              _projectCard('래글런 가디건', '진행 중', 0.35, C.lv),
            ]),
          ),
        ),
        _mockBottomNav(1),
      ]),
    );
  }
}

// ── 3. 단계로그 (HIGHLIGHT) ───────────────────────────────────────────────────
class _MockStepLogScreen extends StatelessWidget {
  const _MockStepLogScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [C.lv.withValues(alpha: 0.15), C.pk.withValues(alpha: 0.08)]),
            border: Border(bottom: BorderSide(color: C.lv.withValues(alpha: 0.3))),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('탑다운 스웨터', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.tx)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: C.lv, borderRadius: BorderRadius.circular(10)), child: const Text('진행 중', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 3),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: 0.6, minHeight: 5, backgroundColor: C.lvL, valueColor: AlwaysStoppedAnimation<Color>(C.lv))),
            const SizedBox(height: 2),
            Text('3/5 단계 완료', style: TextStyle(fontSize: 8, color: C.tx2)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('단계로그'),
              const SizedBox(height: 6),
              _stepRow(1, '코잡기 & 요크 시작', true),
              const SizedBox(height: 5),
              _stepRow(2, '래글런 증코 (코 늘리기)', true),
              const SizedBox(height: 5),
              _stepRow(3, '몸통 분리 & 원통뜨기', true),
              const SizedBox(height: 5),
              _stepRow(4, '몸통 길이 조절하기', false, isCurrent: true),
              const SizedBox(height: 5),
              _stepRow(5, '밑단 & 마무리', false),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lv.withValues(alpha: 0.25))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.flag_rounded, size: 11, color: C.lv),
                    const SizedBox(width: 4),
                    Text('현재 단계 가이드', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.lv)),
                  ]),
                  const SizedBox(height: 4),
                  Text('몸통을 원통으로 22cm 뜨세요. 겉뜨기로만 진행합니다.', style: TextStyle(fontSize: 8, color: C.tx2, height: 1.5)),
                ]),
              ),
            ]),
          ),
        ),
        _mockBottomNav(1),
      ]),
    );
  }
}

// ── 4. 카운터 ─────────────────────────────────────────────────────────────────
class _MockCounterScreen extends StatelessWidget {
  const _MockCounterScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.bd))),
          child: Row(children: [
            Text('탑다운 스웨터 카운터', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.tx)),
            const Spacer(),
            Icon(Icons.more_vert, size: 16, color: C.mu),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              // 단위 칩
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final u in ['1', '5', '10'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: u == '1' ? C.lv : C.lvL,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: u == '1' ? C.lv : C.lv.withValues(alpha: 0.2)),
                      ),
                      child: Text(u, style: TextStyle(fontSize: 10, color: u == '1' ? Colors.white : C.lvD, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              // 코 카운터
              _counterPanel('코 (Stitches)', 42, C.lv),
              const SizedBox(height: 10),
              // 단 카운터
              _counterPanel('단 (Rows)', 18, C.pk),
              const SizedBox(height: 10),
              // 마크 저장 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.bookmark_add_rounded, size: 12, color: C.lv),
                  label: Text('현재 위치 저장', style: TextStyle(fontSize: 9, color: C.lv)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), side: BorderSide(color: C.lv.withValues(alpha: 0.4))),
                ),
              ),
              const SizedBox(height: 8),
              // 최근 마크
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.bd)),
                child: Row(children: [
                  Icon(Icons.bookmark_rounded, size: 10, color: C.lv),
                  const SizedBox(width: 5),
                  Text('코 38 · 단 14', style: TextStyle(fontSize: 8, color: C.tx)),
                  const Spacer(),
                  Text('어제', style: TextStyle(fontSize: 7, color: C.mu)),
                ]),
              ),
            ]),
          ),
        ),
        _mockBottomNav(1),
      ]),
    );
  }
}

// ── 5. 스와치 ─────────────────────────────────────────────────────────────────
class _MockSwatchScreen extends StatelessWidget {
  const _MockSwatchScreen();
  static const _swatches = [
    (Color(0xFFB39DDB), '170m', '3.5mm'),
    (Color(0xFFF48FB1), '320m', '4.0mm'),
    (Color(0xFF80CBC4), '210m', '3.0mm'),
    (Color(0xFFFFCC80), '450m', '4.5mm'),
    (Color(0xFF90CAF9), '180m', '3.5mm'),
    (Color(0xFFA5D6A7), '240m', '4.0mm'),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('스와치', '나의 실 라이브러리'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.lmD.withValues(alpha: 0.1), C.lmG.withValues(alpha: 0.06)]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.lmD.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('보유 스와치', style: TextStyle(fontSize: 9, color: C.tx2)),
                  Text('6개', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.lmD)),
                ]),
              ),
              const SizedBox(height: 9),
              _sectionLabel('스와치 목록'),
              const SizedBox(height: 7),
              GridView.count(
                crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 0.82,
                children: _swatches.map((s) => Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.bd)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(color: s.$1, shape: BoxShape.circle, boxShadow: [BoxShadow(color: s.$1.withValues(alpha: 0.4), blurRadius: 5)])),
                    const SizedBox(height: 4),
                    Text(s.$2, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: C.tx)),
                    Text(s.$3, style: TextStyle(fontSize: 6, color: C.mu)),
                  ]),
                )).toList(),
              ),
            ]),
          ),
        ),
        _mockBottomNav(3),
      ]),
    );
  }
}

// ── 6. 도안 에디터 ───────────────────────────────────────────────────────────
class _MockPatternEditorScreen extends StatelessWidget {
  const _MockPatternEditorScreen();
  @override
  Widget build(BuildContext context) {
    const cellSize = 13.0;
    const gridW = 11;
    const gridH = 10;
    // 간단한 패턴 데이터 (1=겉뜨기, 2=안뜨기, 0=빈칸)
    const pattern = [
      [0,0,1,1,1,1,1,1,1,0,0],
      [0,1,1,2,1,1,1,2,1,1,0],
      [1,1,2,2,2,1,2,2,2,1,1],
      [1,2,2,2,2,2,2,2,2,2,1],
      [1,2,2,2,2,2,2,2,2,2,1],
      [0,1,2,2,2,2,2,2,2,1,0],
      [0,0,1,2,2,2,2,2,1,0,0],
      [0,0,0,1,2,2,2,1,0,0,0],
      [0,0,0,0,1,2,1,0,0,0,0],
      [0,0,0,0,0,1,0,0,0,0,0],
    ];
    return Container(
      color: const Color(0xFFF0EDF8),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.bd))),
          child: Row(children: [
            Text('도안 에디터', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.tx)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.lv, borderRadius: BorderRadius.circular(10)), child: const Text('저장', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
        Expanded(
          child: Column(children: [
            // 캔버스
            Expanded(
              child: Container(
                color: const Color(0xFFF8F5FF),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...List.generate(gridH, (r) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(gridW, (c) {
                        final v = pattern[r][c];
                        return Container(
                          width: cellSize, height: cellSize,
                          decoration: BoxDecoration(
                            color: v == 0 ? Colors.transparent : v == 1 ? C.lv.withValues(alpha: 0.7) : C.pk.withValues(alpha: 0.6),
                            border: Border.all(color: C.bd2, width: 0.5),
                          ),
                          child: v == 2 ? Center(child: Text('−', style: TextStyle(fontSize: 7, color: C.pkD, fontWeight: FontWeight.w900, height: 1))) : null,
                        );
                      }),
                    )),
                  ]),
                ),
              ),
            ),
            // 툴바
            Container(
              height: 44,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _toolBtn(Icons.edit_rounded, C.lv, true),
                _toolBtn(Icons.auto_fix_high_rounded, C.mu, false),
                _toolBtn(Icons.color_lens_rounded, C.pk, false),
                _toolBtn(Icons.grid_on_rounded, C.lmD, false),
                _toolBtn(Icons.undo_rounded, C.mu, false),
                _toolBtn(Icons.picture_as_pdf_rounded, C.og, false),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _toolBtn(IconData icon, Color color, bool active) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: active ? color.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: active ? color : C.mu),
    );
  }
}

// ── 7. 마켓 ──────────────────────────────────────────────────────────────────
class _MockMarketScreen extends StatelessWidget {
  const _MockMarketScreen();
  static const _items = [
    ('탑다운 스웨터', '₩3,500', Color(0xFFB39DDB)),
    ('케이블 목도리', '₩2,000', Color(0xFFF48FB1)),
    ('아란 장갑', '₩4,000', Color(0xFF80CBC4)),
    ('래글런 가디건', '무료', Color(0xFFFFCC80)),
    ('비니 도안', '₩1,500', Color(0xFF90CAF9)),
    ('양말 도안', '₩2,500', Color(0xFFA5D6A7)),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('마켓', '실 · 도안 · 뜨개 도구'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              // 검색바
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 13, color: C.mu),
                  const SizedBox(width: 5),
                  Text('도안, 실 검색...', style: TextStyle(fontSize: 9, color: C.mu)),
                ]),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1.0,
                children: _items.map((item) => Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bd)),
                  child: Column(children: [
                    Expanded(child: Container(
                      decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.18), borderRadius: const BorderRadius.vertical(top: Radius.circular(9))),
                      child: Center(child: Icon(Icons.menu_book_rounded, color: item.$3, size: 24)),
                    )),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.$1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx), overflow: TextOverflow.ellipsis),
                        Text(item.$2, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: item.$3)),
                      ]),
                    ),
                  ]),
                )).toList(),
              ),
            ]),
          ),
        ),
        _mockBottomNav(4),
      ]),
    );
  }
}

// ── 8. 내 도안 판매 (셀러) ───────────────────────────────────────────────────
class _MockSellerScreen extends StatelessWidget {
  const _MockSellerScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [C.lmD.withValues(alpha: 0.15), C.pk.withValues(alpha: 0.08)]),
            border: Border(bottom: BorderSide(color: C.lmD.withValues(alpha: 0.3))),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('내 판매 도안', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.tx)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.lmD, borderRadius: BorderRadius.circular(10)), child: const Text('+ 등록', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _saleStat('총 수익', '₩48,500', C.lmD),
              const SizedBox(width: 12),
              _saleStat('판매 수', '23건', C.pkD),
              const SizedBox(width: 12),
              _saleStat('도안 수', '5개', C.lv),
            ]),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _saleItemRow('탑다운 스웨터 도안', '12건 · ₩42,000', C.lv),
              const SizedBox(height: 6),
              _saleItemRow('케이블 목도리', '8건 · ₩16,000', C.pk),
              const SizedBox(height: 6),
              _saleItemRow('아란 장갑 도안', '3건 · ₩12,000', C.lmD),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.lmD.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.lmD.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.tips_and_updates_rounded, size: 13, color: C.lmD),
                  const SizedBox(width: 6),
                  Expanded(child: Text('도안 에디터로 만든 도안을\n바로 마켓에 올릴 수 있어요', style: TextStyle(fontSize: 8, color: C.tx2, height: 1.5))),
                ]),
              ),
            ]),
          ),
        ),
        _mockBottomNav(4),
      ]),
    );
  }

  Widget _saleStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 7, color: C.mu)),
    ]);
  }

  Widget _saleItemRow(String name, String stat, Color color) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx)),
          Text(stat, style: TextStyle(fontSize: 8, color: C.mu)),
        ])),
        Icon(Icons.chevron_right_rounded, size: 13, color: C.mu),
      ]),
    );
  }
}

// ── 9. 커뮤니티 ──────────────────────────────────────────────────────────────
class _MockCommunityScreen extends StatelessWidget {
  const _MockCommunityScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('커뮤니티', '메이커들의 이야기'),
        // 카테고리 탭
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
            children: [
              _catChip('전체', true),
              _catChip('완성작', false),
              _catChip('질문', false),
              _catChip('도안공유', false),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _communityPost('탑다운 드디어 완성했어요! 🎉', '모리메이커', '완성작', 24, C.pk),
              const SizedBox(height: 6),
              _communityPost('마지막 단 줄이기가 어려워요', '뜨개초보', '질문', 8, C.lv),
              const SizedBox(height: 6),
              _communityPost('무료 비니 도안 공유합니다 🧢', '니트장인', '도안공유', 31, C.lmD),
              const SizedBox(height: 6),
              _communityPost('실 구매 후기 — 코코도리 추천', '실마니아', '후기', 15, C.pkD),
            ]),
          ),
        ),
        _mockBottomNav(2),
      ]),
    );
  }

  Widget _catChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? C.lvD : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? C.lvD : C.bd),
        ),
        child: Text(label, style: TextStyle(fontSize: 8, color: selected ? Colors.white : C.tx2, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _communityPost(String title, String author, String cat, int likes, Color catColor) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(cat, style: TextStyle(fontSize: 7, color: catColor, fontWeight: FontWeight.w700))),
          const Spacer(),
          Icon(Icons.favorite_rounded, size: 9, color: C.pk),
          const SizedBox(width: 2),
          Text('$likes', style: TextStyle(fontSize: 8, color: C.mu)),
        ]),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(author, style: TextStyle(fontSize: 7, color: C.mu)),
      ]),
    );
  }
}

// ── 10. 강의 ─────────────────────────────────────────────────────────────────
class _MockCourseScreen extends StatelessWidget {
  const _MockCourseScreen();
  static const _courses = [
    ('탑다운 스웨터 입문', '뜨개선생님', Color(0xFFB39DDB)),
    ('케이블 뜨기 마스터', '케이블장인', Color(0xFFF48FB1)),
    ('양말 뜨개 완강', '삭스마니아', Color(0xFF80CBC4)),
    ('코잡기 A to Z', '베이직뜨개', Color(0xFFFFCC80)),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('클라스', '유튜브 강의 모음'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(9),
            child: Column(children: [
              // 검색바
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(9)),
                child: Row(children: [Icon(Icons.search_rounded, size: 12, color: C.mu), const SizedBox(width: 5), Text('강의 검색...', style: TextStyle(fontSize: 9, color: C.mu))]),
              ),
              const SizedBox(height: 8),
              ..._courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
                  child: Row(children: [
                    Container(
                      width: 60, height: 44,
                      decoration: BoxDecoration(color: c.$3.withValues(alpha: 0.25), borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))),
                      child: Center(child: Icon(Icons.play_circle_filled_rounded, color: c.$3, size: 22)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.$1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx), overflow: TextOverflow.ellipsis),
                      Text(c.$2, style: TextStyle(fontSize: 7, color: C.mu)),
                    ])),
                  ]),
                ),
              )),
            ]),
          ),
        ),
        _mockBottomNav(0),
      ]),
    );
  }
}

// ── 11. 뜨개백과 ─────────────────────────────────────────────────────────────
class _MockEncyclopediaScreen extends StatelessWidget {
  const _MockEncyclopediaScreen();
  static const _entries = [
    ('겉뜨기 (Knit)', '기본 뜨기 기법. 앞에서 뒤로 바늘을 넣어 뜹니다.', '기법'),
    ('안뜨기 (Purl)', '겉뜨기의 반대. 뒤에서 앞으로 바늘을 넣습니다.', '기법'),
    ('코잡기', '뜨개를 시작할 때 실을 바늘에 거는 방법입니다.', '기초'),
    ('게이지', '10cm×10cm 안에 들어가는 코와 단의 수입니다.', '용어'),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('뜨개백과사전', '언제든지 찾아보세요'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(9),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(9)),
                child: Row(children: [Icon(Icons.search_rounded, size: 12, color: C.mu), const SizedBox(width: 5), Text('용어 검색...', style: TextStyle(fontSize: 9, color: C.mu))]),
              ),
              const SizedBox(height: 8),
              ..._entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.tx))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(e.$3, style: TextStyle(fontSize: 7, color: C.lv, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 3),
                    Text(e.$2, style: TextStyle(fontSize: 8, color: C.tx2, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              )),
            ]),
          ),
        ),
        _mockBottomNav(0),
      ]),
    );
  }
}

// ── 12. English (다국어) ──────────────────────────────────────────────────────
class _MockEnglishScreen extends StatelessWidget {
  const _MockEnglishScreen();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.bd))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Home', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.tx)),
              Text('Happy knitting today! 🧡', style: TextStyle(fontSize: 8, color: C.tx2)),
            ]),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lv.withValues(alpha: 0.3))), child: Row(children: [Text('🌐 EN', style: TextStyle(fontSize: 9, color: C.lv, fontWeight: FontWeight.w700))])),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [C.lv.withValues(alpha: 0.12), C.pk.withValues(alpha: 0.08)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.lv.withValues(alpha: 0.2))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat('Projects', '3', C.lv),
                  _stat('Swatches', '12', C.lmD),
                  _stat('Community', '48', C.pkD),
                ]),
              ),
              const SizedBox(height: 9),
              _sectionLabel('Top 5 Patterns'),
              const SizedBox(height: 5),
              _itemRow('Top-down Sweater', '₩3,500', C.lv),
              const SizedBox(height: 3),
              _itemRow('Cable Scarf', '₩2,000', C.pk),
              const SizedBox(height: 9),
              _sectionLabel('Community Highlights'),
              const SizedBox(height: 5),
              _postRow('Finished my sweater! 🧶', 'MoriMaker'),
              const SizedBox(height: 3),
              _postRow('Yarn recommendation?', 'KnitPro'),
            ]),
          ),
        ),
        _mockBottomNav(0),
      ]),
    );
  }
}

// ── 13. 테마 설정 ─────────────────────────────────────────────────────────────
class _MockThemeScreen extends StatelessWidget {
  const _MockThemeScreen();
  static const _themes = [
    ('모리냥이', Color(0xFFB39DDB), Color(0xFFF48FB1)),
    ('라벤더', Color(0xFF9C89C5), Color(0xFFC8B8E8)),
    ('주위청이', Color(0xFF4DB6AC), Color(0xFF80CBC4)),
    ('초코냥이', Color(0xFF8D6E63), Color(0xFFBCAAA4)),
    ('핑크토끼', Color(0xFFEC407A), Color(0xFFF48FB1)),
    ('크림달팽이', Color(0xFFFFB74D), Color(0xFFFFCC80)),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        _mockHeader('테마 설정', '나만의 컬러로 꾸미기'),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 미리보기 카드
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFFB39DDB).withValues(alpha: 0.2), const Color(0xFFF48FB1).withValues(alpha: 0.15)]),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB39DDB).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('미리보기', style: TextStyle(fontSize: 9, color: C.tx2)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFB39DDB), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('모리냥이 테마', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.tx)),
                      Text('현재 적용 중', style: TextStyle(fontSize: 8, color: const Color(0xFFB39DDB), fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              _sectionLabel('테마 선택'),
              const SizedBox(height: 7),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 2.2,
                children: _themes.map((t) {
                  final isSelected = t.$1 == '모리냥이';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? t.$2.withValues(alpha: 0.18) : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: isSelected ? t.$2 : C.bd, width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Container(width: 18, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: [t.$2, t.$3]), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t.$1, style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? t.$2 : C.tx))),
                      if (isSelected) Icon(Icons.check_circle_rounded, size: 11, color: t.$2),
                    ]),
                  );
                }).toList(),
              ),
            ]),
          ),
        ),
        _mockBottomNav(4),
      ]),
    );
  }
}

// ── Ravelry 실 검색 목업 ──────────────────────────────────────────────────────
class _MockRavelryYarnScreen extends StatelessWidget {
  const _MockRavelryYarnScreen();

  static const _results = [
    (name: 'Malabrigo Rios', brand: 'Malabrigo', weight: 'Worsted', color: Color(0xFFB39DDB)),
    (name: 'Cascade 220', brand: 'Cascade Yarns', weight: 'Aran', color: Color(0xFF80CBC4)),
    (name: 'Drops Karisma', brand: 'Garnstudio', weight: 'DK', color: Color(0xFFF48FB1)),
    (name: 'Knit Picks Wool', brand: 'Knit Picks', weight: 'Fingering', color: Color(0xFFFFCC80)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFFE8424F).withValues(alpha: 0.1), const Color(0xFFE8424F).withValues(alpha: 0.05)]),
            border: Border(bottom: BorderSide(color: C.bd)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFE8424F), shape: BoxShape.circle), child: const Center(child: Text('R', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 7),
              Text('Ravelry 실 검색', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.tx)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 12, color: const Color(0xFFE8424F)),
                const SizedBox(width: 6),
                Text('Malabrigo...', style: TextStyle(fontSize: 9, color: C.mu)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE8424F), borderRadius: BorderRadius.circular(8)), child: const Text('검색', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('검색 결과 4개'),
              const SizedBox(height: 7),
              ..._results.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bd)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: r.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: r.color.withValues(alpha: 0.3))),
                      child: Center(child: Container(width: 20, height: 20, decoration: BoxDecoration(color: r.color, shape: BoxShape.circle))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx)),
                      Text(r.brand, style: TextStyle(fontSize: 8, color: C.mu)),
                      Container(margin: const EdgeInsets.only(top: 3), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)), child: Text(r.weight, style: TextStyle(fontSize: 7, color: C.lmD, fontWeight: FontWeight.w600))),
                    ])),
                    Column(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lv.withValues(alpha: 0.3))), child: Text('내 라이브러리\n추가', style: TextStyle(fontSize: 7, color: C.lv, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                    ]),
                  ]),
                ),
              )),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lv.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: C.lv),
                  const SizedBox(width: 6),
                  Expanded(child: Text('선택하면 스와치 정보가\n자동으로 채워져요', style: TextStyle(fontSize: 8, color: C.tx2, height: 1.5))),
                ]),
              ),
            ]),
          ),
        ),
        _mockBottomNav(3),
      ]),
    );
  }
}

// ── Ravelry 도안 검색 목업 ─────────────────────────────────────────────────────
class _MockRavelryPatternScreen extends StatelessWidget {
  const _MockRavelryPatternScreen();

  static const _results = [
    (name: 'Hermione\'s Everyday Socks', designer: 'Hermione Buccleigh', cat: '양말', color: Color(0xFFB39DDB)),
    (name: 'Crochet Ribbed Beanie', designer: 'PurlsAndPixels', cat: '모자', color: Color(0xFFF48FB1)),
    (name: 'Simple Ribbed Sweater', designer: 'TinCanKnits', cat: '스웨터', color: Color(0xFF80CBC4)),
    (name: 'Cavendish Cowl', designer: 'Churchmouse Yarns', cat: '넥워머', color: Color(0xFFFFCC80)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFFE8424F).withValues(alpha: 0.1), const Color(0xFFE8424F).withValues(alpha: 0.05)]),
            border: Border(bottom: BorderSide(color: C.bd)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFE8424F), shape: BoxShape.circle), child: const Center(child: Text('R', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 7),
              Text('Ravelry 도안 검색', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.tx)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bd)),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 12, color: const Color(0xFFE8424F)),
                  const SizedBox(width: 5),
                  Text('sweater...', style: TextStyle(fontSize: 9, color: C.mu)),
                ]),
              )),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFE8424F), borderRadius: BorderRadius.circular(9)), child: const Text('검색', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('검색 결과 4개'),
              const SizedBox(height: 7),
              ..._results.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bd)),
                  child: Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: r.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Icon(Icons.menu_book_rounded, color: r.color, size: 20)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.tx), overflow: TextOverflow.ellipsis),
                      Text(r.designer, style: TextStyle(fontSize: 7, color: C.mu), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: r.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)), child: Text(r.cat, style: TextStyle(fontSize: 7, color: r.color, fontWeight: FontWeight.w600))),
                    ])),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.lmD.withValues(alpha: 0.3))), child: Text('내 도안\n추가', style: TextStyle(fontSize: 7, color: C.lmD, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  ]),
                ),
              )),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lmD.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: C.lmD),
                  const SizedBox(width: 6),
                  Expanded(child: Text('선택하면 도안 정보가\n자동으로 채워져요', style: TextStyle(fontSize: 8, color: C.tx2, height: 1.5))),
                ]),
              ),
            ]),
          ),
        ),
        _mockBottomNav(1),
      ]),
    );
  }
}

// ── 공통 UI 헬퍼 ──────────────────────────────────────────────────────────────
Widget _sectionLabel(String text) => Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.tx));

Widget _stat(String label, String value, Color color) => Column(children: [
  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
  Text(label, style: TextStyle(fontSize: 7, color: C.tx2)),
]);

Widget _itemRow(String title, String price, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.bd)),
  child: Row(children: [
    Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Expanded(child: Text(title, style: TextStyle(fontSize: 9, color: C.tx), overflow: TextOverflow.ellipsis)),
    Text(price, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color)),
  ]),
);

Widget _postRow(String title, String author) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.bd)),
  child: Row(children: [
    Icon(Icons.forum_outlined, size: 9, color: C.pkD),
    const SizedBox(width: 5),
    Expanded(child: Text(title, style: TextStyle(fontSize: 9, color: C.tx), overflow: TextOverflow.ellipsis)),
    Text(author, style: TextStyle(fontSize: 8, color: C.mu)),
  ]),
);

Widget _projectCard(String name, String status, double progress, Color color) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bd)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.tx))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600))),
    ]),
    const SizedBox(height: 6),
    ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: color.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation<Color>(color))),
    const SizedBox(height: 3),
    Text('${(progress * 100).toInt()}% 완료', style: TextStyle(fontSize: 7, color: C.mu)),
  ]),
);

Widget _stepRow(int num, String title, bool done, {bool isCurrent = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
  decoration: BoxDecoration(
    color: isCurrent ? C.lv.withValues(alpha: 0.08) : done ? C.gx : Colors.white,
    borderRadius: BorderRadius.circular(9),
    border: Border.all(color: isCurrent ? C.lv.withValues(alpha: 0.4) : done ? C.bd : C.bd),
  ),
  child: Row(children: [
    Container(
      width: 18, height: 18,
      decoration: BoxDecoration(color: done ? C.lv : isCurrent ? C.lv.withValues(alpha: 0.15) : C.gx, shape: BoxShape.circle),
      child: Center(child: done
          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
          : Text('$num', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isCurrent ? C.lv : C.mu))),
    ),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500, color: done ? C.mu : C.tx), overflow: TextOverflow.ellipsis)),
    if (isCurrent) Icon(Icons.arrow_forward_ios_rounded, size: 9, color: C.lv),
  ]),
);

Widget _counterPanel(String label, int value, Color color) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.04)]),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.withValues(alpha: 0.25)),
  ),
  child: Column(children: [
    Text(label, style: TextStyle(fontSize: 8, color: C.tx2)),
    const SizedBox(height: 4),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.remove_rounded, size: 16, color: color)),
      const SizedBox(width: 16),
      Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w200, color: color, height: 1)),
      const SizedBox(width: 16),
      Container(width: 30, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]), child: const Icon(Icons.add_rounded, size: 16, color: Colors.white)),
    ]),
  ]),
);

// ── 통계 바 ───────────────────────────────────────────────────────────────────
class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_landingStatsProvider).valueOrNull;
    final items = [
      (Icons.people_alt_rounded, '${stats?['users'] ?? '—'}+', '메이커 활동 중', C.lv),
      (Icons.folder_special_rounded, '${stats?['projects'] ?? '—'}+', '프로젝트 기록됨', C.pk),
      (Icons.storefront_rounded, '${stats?['market'] ?? '—'}+', '마켓 상품 등록', C.pkD),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.lv.withValues(alpha: 0.08), C.pk.withValues(alpha: 0.06)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((e) {
                final (icon, count, label, color) = e;
                return Expanded(
                  child: Column(
                    children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(height: 6),
                      Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                      Text(label, style: T.caption.copyWith(color: C.tx2)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 섹션 프레임 ───────────────────────────────────────────────────────────────
class _LandingSectionFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  const _LandingSectionFrame({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: T.h2),
                        const SizedBox(height: 5),
                        Text(subtitle, style: T.body.copyWith(color: C.tx2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: C.lv),
                      foregroundColor: C.lvD,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── 카드 그리드 ───────────────────────────────────────────────────────────────
class _LandingCardGrid extends StatelessWidget {
  final List<Widget> children;
  const _LandingCardGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 260,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _LandingLoadingGrid extends StatelessWidget {
  const _LandingLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return const _LandingCardGrid(children: [_LandingSkeletonCard(), _LandingSkeletonCard(), _LandingSkeletonCard()]);
  }
}

class _LandingSkeletonCard extends StatelessWidget {
  const _LandingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd),
      ),
    );
  }
}

class _LandingEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _LandingEmptyCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: C.lvD),
          const SizedBox(height: 12),
          Text(title, style: T.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: T.body.copyWith(color: C.tx2, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── 썸네일 헬퍼 ───────────────────────────────────────────────────────────────
Widget _thumb({String? url, IconData icon = Icons.image_outlined, Color color = const Color(0xFFC084FC)}) {
  return SizedBox(
    height: 130,
    width: double.infinity,
    child: url != null && url.isNotEmpty
        ? Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _thumbIcon(icon, color))
        : _thumbIcon(icon, color),
  );
}

Widget _thumbIcon(IconData icon, Color color) {
  return Container(
    color: color.withValues(alpha: 0.10),
    child: Center(child: Icon(icon, size: 40, color: color.withValues(alpha: 0.55))),
  );
}

// ── 마켓 카드 ─────────────────────────────────────────────────────────────────
class _MarketPreviewCard extends StatelessWidget {
  final MarketItem item;
  const _MarketPreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: _thumb(url: item.imageUrl.isNotEmpty ? item.imageUrl : null, icon: Icons.storefront_rounded, color: C.pkD),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(item.description, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(20)),
                        child: Text(item.category, style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w600, fontSize: 11)),
                      ),
                      const Spacer(),
                      Text('${item.price}원', style: T.bodyBold.copyWith(color: C.pkD, fontSize: 14)),
                    ],
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

// ── 커뮤니티 카드 ─────────────────────────────────────────────────────────────
class _PostPreviewCard extends StatelessWidget {
  final PostModel post;
  const _PostPreviewCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final thumb = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: _thumb(url: thumb, icon: Icons.forum_rounded, color: C.lvD),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(post.content, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 13, color: C.mu),
                      const SizedBox(width: 4),
                      Expanded(child: Text(post.authorName, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Icon(Icons.favorite_rounded, size: 13, color: C.pk),
                      const SizedBox(width: 3),
                      Text('${post.likeCount}', style: T.caption.copyWith(color: C.tx2)),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_rounded, size: 13, color: C.lv),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}', style: T.caption.copyWith(color: C.tx2)),
                    ],
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

// ── 백과사전 카드 ─────────────────────────────────────────────────────────────
class _EncyclopediaPreviewCard extends StatelessWidget {
  final EncyclopediaEntry entry;
  const _EncyclopediaPreviewCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [C.lv.withValues(alpha: 0.15), C.lmD.withValues(alpha: 0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 36, color: C.lv.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.lvL,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(entry.category, style: TextStyle(fontSize: 11, color: C.lvD, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(entry.term, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (entry.termEn.isNotEmpty)
                        Text(entry.termEn, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(entry.description, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
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

// ── 기능 소개 섹션 ────────────────────────────────────────────────────────────
class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.folder_special_rounded, '프로젝트 기록', '진행 중인 뜨개 프로젝트를 체계적으로 관리하세요', Color(0xFFC084FC)),
      (Icons.grid_view_rounded, '스와치 보관함', '게이지 기록과 실 정보를 저장해두세요', Color(0xFF22D3EE)),
      (Icons.storefront_rounded, '도안 마켓', '도안을 구매하거나 직접 판매할 수 있어요', Color(0xFFF472B6)),
      (Icons.people_alt_rounded, '커뮤니티', '뜨개인들과 작업물을 나누고 소통해요', Color(0xFFA3E635)),
      (Icons.menu_book_rounded, '뜨개백과사전', '뜨개 용어와 기법을 언제든 찾아보세요', Color(0xFFFB923C)),
      (Icons.calculate_rounded, '게이지 계산기', '게이지에 맞는 코수와 단수를 계산해요', Color(0xFF34D399)),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 3 : 2;

    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Column(
            children: [
              const Text('모리니트의 모든 기능', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('뜨개질의 모든 과정을 한 곳에서', style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 36),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 3 ? 1.6 : 1.4,
                ),
                itemBuilder: (_, i) {
                  final (icon, title, desc, color) = features[i];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252540),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(height: 14),
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12.5, height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CTA 섹션 ──────────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  const _CtaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.lv.withValues(alpha: 0.90), C.pk.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: C.lv.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                const Text('지금 바로 시작해보세요', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('무료로 시작하고, 내 뜨개 여정을 기록해보세요.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.6), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.login),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('무료 계정 만들기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: C.lvD,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 푸터 ──────────────────────────────────────────────────────────────────────
class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MoriKnitTitle(fontSize: 22),
                          const SizedBox(height: 10),
                          const Text('뜨개 기록의 모든 것', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          const Text('스와치, 프로젝트, 커뮤니티, 마켓까지\n뜨개질의 모든 과정을 한 곳에서.',
                              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.6)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('회사 정보', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          const _FooterInfoRow(label: '서비스명', value: 'MoriKnit (모리니트)'),
                          const _FooterInfoRow(label: '운영', value: '1인 개발 서비스'),
                          const _FooterInfoRow(label: '이메일', value: 'support@moriknit.app'),
                          const _FooterInfoRow(label: '버전', value: '1.0.0'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            children: [
                              TextButton(
                                onPressed: () => launchUrl(Uri.parse('https://www.moriknit.com/terms')),
                                style: TextButton.styleFrom(foregroundColor: Colors.white54, padding: EdgeInsets.zero),
                                child: const Text('이용약관', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () => launchUrl(Uri.parse('https://www.moriknit.com/privacy')),
                                style: TextButton.styleFrom(foregroundColor: Colors.white54, padding: EdgeInsets.zero),
                                child: const Text('개인정보처리방침', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                const Text('© 2024 MoriKnit. All rights reserved.',
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _FooterInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}
