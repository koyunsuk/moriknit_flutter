import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '인기 마켓',
              subtitle: '지금 등록된 실, 도안, 뜨개 도구를 미리 살펴보세요.',
              actionLabel: user == null ? '로그인 후 더 보기' : '앱으로 이동',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.market),
              child: marketAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (e, st) => const _LandingEmptyCard(
                  icon: Icons.storefront_outlined,
                  title: '마켓 데이터를 불러오지 못했어요',
                  message: '잠시 후 다시 확인해 주세요.',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _LandingEmptyCard(
                      icon: Icons.storefront_outlined,
                      title: '등록된 상품이 아직 없어요',
                      message: '관리자와 판매자가 등록한 상품이 여기에 표시됩니다.',
                    );
                  }
                  return _LandingCardGrid(
                    children: items.take(6).map((item) => _MarketPreviewCard(item: item)).toList(),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '커뮤니티 미리보기',
              subtitle: '최근 게시글 흐름을 가볍게 둘러볼 수 있어요.',
              actionLabel: user == null ? '로그인 후 이어보기' : '커뮤니티로 이동',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.community),
              child: postsAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (e, st) => const _LandingEmptyCard(
                  icon: Icons.forum_outlined,
                  title: '커뮤니티 글을 불러오지 못했어요',
                  message: '잠시 후 다시 확인해 주세요.',
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const _LandingEmptyCard(
                      icon: Icons.forum_outlined,
                      title: '아직 등록된 글이 없어요',
                      message: '첫 글부터 차곡차곡 커뮤니티가 채워질 예정이에요.',
                    );
                  }
                  return _LandingCardGrid(
                    children: posts.take(6).map((post) => _PostPreviewCard(post: post)).toList(),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _LandingSectionFrame(
              title: '뜨개백과사전',
              subtitle: 'DB에 등록된 뜨개 용어와 기법을 미리 볼 수 있어요.',
              actionLabel: user == null ? '로그인 후 더 보기' : '사전으로 이동',
              onAction: () => user == null ? context.go(Routes.login) : context.go(Routes.toolsEncyclopedia),
              child: encyclopediaAsync.when(
                loading: () => const _LandingLoadingGrid(),
                error: (e, st) => const _LandingEmptyCard(
                  icon: Icons.menu_book_outlined,
                  title: '백과사전 데이터를 불러오지 못했어요',
                  message: '잠시 후 다시 확인해 주세요.',
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const _LandingEmptyCard(
                      icon: Icons.menu_book_outlined,
                      title: '뜨개백과사전이 곧 채워집니다',
                      message: '관리자가 등록한 뜨개 용어와 기법 설명이 여기에 표시됩니다.',
                    );
                  }
                  return _LandingCardGrid(
                    children: entries.take(6).map((entry) => _EncyclopediaPreviewCard(entry: entry)).toList(),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _FeatureSection()),
          const SliverToBoxAdapter(child: _LandingFooter()),
        ],
      ),
    );
  }
}

class _LandingTopBar extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onOpenApp;

  const _LandingTopBar({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onOpenApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const MoriLogo(size: 34),
                const SizedBox(width: 10),
                const MoriKnitTitle(fontSize: 20),
                const Spacer(),
                TextButton(
                  onPressed: isLoggedIn ? onOpenApp : onLogin,
                  child: Text(isLoggedIn ? '앱으로 이동' : '로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onOpenApp;

  const _LandingHero({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onOpenApp,
  });

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
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
                        const SizedBox(height: 6),
                        Text(subtitle, style: T.body.copyWith(color: C.tx2, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingCardGrid extends StatelessWidget {
  final List<Widget> children;

  const _LandingCardGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 3 : width >= 720 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.8,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _LandingLoadingGrid extends StatelessWidget {
  const _LandingLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return const _LandingCardGrid(
      children: [
        _LandingSkeletonCard(),
        _LandingSkeletonCard(),
        _LandingSkeletonCard(),
      ],
    );
  }
}

class _LandingSkeletonCard extends StatelessWidget {
  const _LandingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.bd),
      ),
    );
  }
}

class _LandingEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _LandingEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: C.lvD),
          const SizedBox(height: 12),
          Text(title, style: T.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: T.body.copyWith(color: C.tx2, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MarketPreviewCard extends StatelessWidget {
  final MarketItem item;

  const _MarketPreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: T.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(item.description, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text('${item.price}원', style: T.bodyBold.copyWith(color: C.pkD)),
        ],
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  final PostModel post;

  const _PostPreviewCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: T.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(post.content, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(post.authorName, style: T.captionBold.copyWith(color: C.lvD)),
        ],
      ),
    );
  }
}

class _EncyclopediaPreviewCard extends StatelessWidget {
  final EncyclopediaEntry entry;

  const _EncyclopediaPreviewCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.term, style: T.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(entry.category, style: T.captionBold.copyWith(color: C.lvD)),
          const SizedBox(height: 8),
          Text(entry.description, style: T.caption.copyWith(color: C.tx2, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.pk, C.pkD],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🎉 지금 가입하면 3개월 Pro 무료 사용!',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
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
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '모리니트의 모든 기능',
                style: T.h2.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '뜨개질의 모든 과정을 한 곳에서',
                style: T.body.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 13, height: 1.5),
                        ),
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
                    // 브랜드
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MoriKnitTitle(fontSize: 22),
                          const SizedBox(height: 10),
                          const Text(
                            '뜨개 기록의 모든 것',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '스와치, 프로젝트, 커뮤니티, 마켓까지\n뜨개질의 모든 과정을 한 곳에서.',
                            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // 회사 정보
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
                                onPressed: () => launchUrl(Uri.parse('https://www.moriknit.com/terms'), mode: LaunchMode.externalApplication),
                                style: TextButton.styleFrom(foregroundColor: Colors.white54, padding: EdgeInsets.zero),
                                child: const Text('이용약관', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () => launchUrl(Uri.parse('https://www.moriknit.com/privacy'), mode: LaunchMode.externalApplication),
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
                const Text(
                  '© 2024 MoriKnit. All rights reserved.',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
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
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
