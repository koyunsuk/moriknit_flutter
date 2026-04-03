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
          // ── 방명록 스트립 ──────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _ActivityStrip()),
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
                error: (_, __) => const _LandingEmptyCard(icon: Icons.storefront_outlined, title: '마켓 데이터를 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
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
                error: (_, __) => const _LandingEmptyCard(icon: Icons.forum_outlined, title: '커뮤니티 글을 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
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
                error: (_, __) => const _LandingEmptyCard(icon: Icons.menu_book_outlined, title: '백과사전 데이터를 불러오지 못했어요', message: '잠시 후 다시 확인해 주세요.'),
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

// ── 프로모 배너 ───────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.pk, C.pkD], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉 지금 가입하면 3개월 Pro 무료 사용!',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('무료로 시작하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFF7FB), C.pk.withValues(alpha: 0.08), C.lv.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 48),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _heroText(context)),
                      const SizedBox(width: 48),
                      Expanded(flex: 4, child: _appMockup()),
                    ],
                  )
                : Column(
                    children: [
                      _heroText(context),
                      const SizedBox(height: 36),
                      _appMockup(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const MoriLogo(size: 48),
          const SizedBox(width: 12),
          const MoriKnitTitle(fontSize: 30, width: 180),
        ]),
        const SizedBox(height: 20),
        Text('뜨개 프로젝트·커뮤니티·\n마켓·백과사전을 한곳에', style: T.h1.copyWith(height: 1.35)),
        const SizedBox(height: 14),
        Text(
          '웹에서 크게 보고, 모바일에서 가볍게 기록하며 이어가는\n뜨개 메이커를 위한 올인원 플랫폼',
          style: T.body.copyWith(color: C.tx2, height: 1.7),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: isLoggedIn ? onOpenApp : onLogin,
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: Text(isLoggedIn ? '앱으로 이동' : '무료로 시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.market),
              icon: const Icon(Icons.storefront_rounded, size: 16),
              label: const Text('마켓 둘러보기'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _appMockup() {
    // 앱 UI 모형 — 실제 스크린샷 준비 시 Image.asset으로 교체
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: C.lv.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 12)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: C.bd, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // 상단 상태바 모형
            Container(
              height: 32,
              color: C.gx,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: C.lv, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('MoriKnit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.tx)),
                const Spacer(),
                Icon(Icons.notifications_rounded, size: 14, color: C.mu),
                const SizedBox(width: 10),
                Icon(Icons.person_rounded, size: 14, color: C.mu),
              ]),
            ),
            // 앱 콘텐츠 모형
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('나의 프로젝트', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.tx)),
                    const SizedBox(height: 8),
                    _mockProjectCard('탑다운 스웨터', '진행 중 · 80%', C.lv),
                    const SizedBox(height: 6),
                    _mockProjectCard('손모아 장갑', '완성 · 100%', C.pk),
                    const SizedBox(height: 6),
                    _mockProjectCard('케이블 목도리', '시작 전 · 0%', C.lmD),
                    const SizedBox(height: 12),
                    Text('최근 활동', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.tx)),
                    const SizedBox(height: 8),
                    _mockActivityRow(Icons.grid_view_rounded, '스와치 3개 기록됨', C.lmD),
                    const SizedBox(height: 4),
                    _mockActivityRow(Icons.storefront_rounded, '도안 1개 구매 완료', C.pkD),
                  ],
                ),
              ),
            ),
            // 하단 탭바 모형
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: C.bd)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _mockTab(Icons.home_rounded, '홈', C.pk, true),
                  _mockTab(Icons.folder_special_rounded, '프로젝트', C.lv, false),
                  _mockTab(Icons.people_alt_rounded, '커뮤니티', C.pkD, false),
                  _mockTab(Icons.storefront_rounded, '마켓', C.lvD, false),
                  _mockTab(Icons.person_rounded, '마이', C.mu, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockProjectCard(String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.tx))),
        Text(sub, style: TextStyle(fontSize: 10, color: C.mu)),
      ]),
    );
  }

  Widget _mockActivityRow(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 11, color: C.tx2)),
    ]);
  }

  Widget _mockTab(IconData icon, String label, Color color, bool selected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: selected ? color : C.mu),
        Text(label, style: TextStyle(fontSize: 9, color: selected ? color : C.mu, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}

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
            errorBuilder: (_, __, ___) => _thumbIcon(icon, color))
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
