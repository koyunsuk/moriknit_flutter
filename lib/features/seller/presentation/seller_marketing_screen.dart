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
// CLAUDE.md 토큰 의무: C / T / placeholder 패턴은 main_seller_mobile.dart _PlaceholderCard 동일.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class SellerMarketingScreen extends StatelessWidget {
  const SellerMarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: const [
                _MarketingPlaceholder(
                  icon: Icons.auto_awesome_rounded,
                  title: '큐레이션 신청',
                  subtitle: '편집자 추천 픽 등록 요청 (Phase 3 예정)',
                ),
                SizedBox(height: 12),
                _MarketingPlaceholder(
                  icon: Icons.article_rounded,
                  title: '에디토리얼 노출 신청',
                  subtitle: '뜨개소식·모리채널 콘텐츠 협업 (Phase 3 예정)',
                ),
                SizedBox(height: 12),
                _MarketingPlaceholder(
                  icon: Icons.group_add_rounded,
                  title: '함께뜨기 그룹 홍보',
                  subtitle: '진행 중인 함께뜨기를 메인 노출 (Phase 3 예정)',
                ),
                SizedBox(height: 12),
                _MarketingPlaceholder(
                  icon: Icons.notifications_active_rounded,
                  title: '신규 도안 푸시',
                  subtitle: '팔로워에게 신규 도안 푸시 알림 (Phase 3 예정)',
                ),
                SizedBox(height: 12),
                _MarketingPlaceholder(
                  icon: Icons.campaign_rounded,
                  title: '광고',
                  subtitle: '유료 노출 슬롯 구매 (Phase 3+ 예정)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketingPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _MarketingPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.lm.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: C.lm.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: C.lmD, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold.copyWith(color: C.tx)),
                const SizedBox(height: 4),
                Text(subtitle, style: T.caption.copyWith(color: C.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
