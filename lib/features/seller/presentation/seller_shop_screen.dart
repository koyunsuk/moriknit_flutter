// 이슈 #816 Phase 2 — 셀러 샵/마이페이지.
//
// 사용자 요청: 셀러의 "샵"이 메인 컨셉 — BottomNav 5번째 탭에 노출.
// 모리유저 my_page_screen.dart 참조하여 일반적인 셀러 정보 표시.
//
// 카드 구성 (Phase 1 플레이스 홀더):
//   - 샵 프로필 (이름/소개/사진/팔로워)
//   - 샵 통계 (도안/판매/Fork/평점)
//   - 셀러 등급 (Pro/Business)
//   - 마케팅 (큐레이션/에디토리얼) — 기존 마케팅 placeholder 이관
//   - 설정 (테마/언어/로그아웃)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../data/is_seller_provider.dart';
import 'seller_dashboard_screen.dart' show kSellerAccent;
import 'seller_marketing_screen.dart';

class SellerShopScreen extends ConsumerWidget {
  const SellerShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final publishedCountAsync = ref.watch(myPublishedPatternsCountProvider);

    final shopName = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName
        : (user?.email.split('@').first ?? '셀러');
    final email = user?.email ?? '';
    final tier = user?.subscription.planId ?? 'free';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // 1) 샵 프로필 — 큰 카드
        MoriBlockShell(
          label: '내 샵',
          icon: Icons.storefront_rounded,
          accent: kSellerAccent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: kSellerAccent.withValues(alpha: 0.18),
                child: (user?.photoURL.isNotEmpty ?? false)
                    ? ClipOval(
                        child: Image.network(
                          user!.photoURL,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.storefront_rounded, color: kSellerAccent, size: 30),
                        ),
                      )
                    : Icon(Icons.storefront_rounded, color: kSellerAccent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName, style: T.h3.copyWith(color: C.tx)),
                    const SizedBox(height: 4),
                    Text(email, style: T.caption.copyWith(color: C.tx2)),
                    const SizedBox(height: 6),
                    _TierBadge(tier: tier),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2) 샵 통계
        MoriBlockShell(
          label: '샵 통계',
          icon: Icons.insights_rounded,
          accent: C.lv,
          child: Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: '발행 도안',
                  value: publishedCountAsync.valueOrNull?.toString() ?? '…',
                  accent: kSellerAccent,
                ),
              ),
              Container(width: 1, height: 40, color: C.bd),
              const Expanded(
                child: _StatCell(label: '누적 판매', value: '—', accent: Color(0xFF7CB342)),
              ),
              Container(width: 1, height: 40, color: C.bd),
              const Expanded(
                child: _StatCell(label: 'Fork', value: '—', accent: Color(0xFFC0DC3C)),
              ),
              Container(width: 1, height: 40, color: C.bd),
              const Expanded(
                child: _StatCell(label: '평점', value: '—', accent: Color(0xFFFFA726)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3) 셀러 등급 안내
        MoriBlockShell(
          label: '셀러 등급',
          icon: Icons.workspace_premium_rounded,
          accent: C.lvD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierRow(
                tier: 'free',
                current: tier == 'free',
                title: 'Free',
                desc: '마켓 구매만 가능',
              ),
              const SizedBox(height: 8),
              _TierRow(
                tier: 'pro',
                current: tier == 'pro',
                title: 'Pro',
                desc: '셀러 앱 + 도안 등록 + AI 변환',
              ),
              const SizedBox(height: 8),
              _TierRow(
                tier: 'business',
                current: tier == 'business',
                title: 'Business',
                desc: '광고 슬롯 + 큐레이션 우선 + 매출 분석',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4) 마케팅 — 기존 SellerMarketingScreen 5개 placeholder 통합
        const SellerMarketingScreen(),
        const SizedBox(height: 12),

        // 5) 설정
        MoriBlockShell(
          label: '설정',
          icon: Icons.settings_rounded,
          accent: C.mu,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MenuRow(icon: Icons.palette_rounded, label: '테마', note: '시스템'),
              const SizedBox(height: 6),
              _MenuRow(icon: Icons.translate_rounded, label: '언어', note: '한국어'),
              const SizedBox(height: 6),
              _MenuRow(icon: Icons.info_outline_rounded, label: '버전', note: '0.9.3'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('로그아웃'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.og,
                    side: BorderSide(color: C.og.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'pro' => ('Pro', kSellerAccent),
      'business' => ('Business', C.lvD),
      _ => ('Free', C.mu),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCell({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: T.h2.copyWith(color: accent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: T.caption.copyWith(color: C.tx2, fontSize: 11)),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  final String tier;
  final bool current;
  final String title;
  final String desc;
  const _TierRow({
    required this.tier,
    required this.current,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: current ? kSellerAccent.withValues(alpha: 0.10) : C.gx,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: current ? kSellerAccent : C.bd,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            current ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: current ? kSellerAccent : C.mu,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: T.bodyBold.copyWith(color: C.tx)),
                    if (current) ...[
                      const SizedBox(width: 6),
                      Text('(현재)', style: T.caption.copyWith(color: kSellerAccent)),
                    ],
                  ],
                ),
                Text(desc, style: T.caption.copyWith(color: C.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;
  const _MenuRow({required this.icon, required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: C.tx2),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: T.body.copyWith(color: C.tx))),
          Text(note, style: T.caption.copyWith(color: C.mu)),
        ],
      ),
    );
  }
}
