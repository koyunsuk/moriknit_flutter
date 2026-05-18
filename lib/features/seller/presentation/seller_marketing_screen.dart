// lib/features/seller/presentation/seller_marketing_screen.dart
//
// 이슈 #816 Phase 2 — 모바일셀러 앱 마케팅 placeholder 화면.
// Phase 3+ 에서 본격 구현 예정.
//
// 항목 (5개):
//   1) 큐레이션 신청
//   2) 에디토리얼 노출 신청
//   3) 함께뜨기 그룹 홍보
//   4) 신규 도안 푸시
//   5) 광고 (Phase 3+)
//
// Phase 2 폴리시:
//   - SellerDashboardScreen 컨테이너 안에서 호출되므로 자체 Scaffold/BgOrbs/SafeArea 제거.
//   - 인라인 Container → MoriBlockShell 토큰화. 카드별 accent 컬러 차별.
//
// CLAUDE.md 토큰 의무: C / T / MoriBlockShell.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class SellerMarketingScreen extends StatelessWidget {
  const SellerMarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _MarketingPlaceholder(
          icon: Icons.auto_awesome_rounded,
          title: '큐레이션 신청',
          subtitle: '편집자 추천 픽 등록 요청',
          phase: 'Phase 3 예정',
          accent: C.lm,
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.article_rounded,
          title: '에디토리얼 노출 신청',
          subtitle: '뜨개소식·모리채널 콘텐츠 협업',
          phase: 'Phase 3 예정',
          accent: C.pk,
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.group_add_rounded,
          title: '함께뜨기 그룹 홍보',
          subtitle: '진행 중인 함께뜨기를 메인 노출',
          phase: 'Phase 3 예정',
          accent: C.lvD,
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.notifications_active_rounded,
          title: '신규 도안 푸시',
          subtitle: '팔로워에게 신규 도안 푸시 알림',
          phase: 'Phase 3 예정',
          accent: C.og,
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.campaign_rounded,
          title: '광고',
          subtitle: '유료 노출 슬롯 구매',
          phase: 'Phase 3+ 예정',
          accent: C.lv,
        ),
      ],
    );
  }
}

class _MarketingPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String phase;
  final Color accent;
  const _MarketingPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.phase,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: title,
      icon: icon,
      accent: accent,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          phase,
          style: T.caption.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Text(
        subtitle,
        style: T.caption.copyWith(color: C.tx2, height: 1.5),
      ),
    );
  }
}
