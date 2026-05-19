// lib/features/seller/presentation/seller_marketing_screen.dart
//
// 이슈 #816 Phase 2 — 모바일셀러 앱 마케팅 와이어프레임 화면.
// Phase 3+ 에서 본격 구현 예정. 카드 탭 시 와이어프레임 페이지 진입.
//
// 항목 (5개):
//   1) 큐레이션 신청
//   2) 에디토리얼 노출 신청
//   3) 함께뜨기 그룹 홍보
//   4) 신규 도안 푸시
//   5) 광고 (Phase 3+)
//
// CLAUDE.md 토큰 의무: C / T / MoriBlockShell.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'seller_dashboard_screen.dart' show openSellerPlaceholder;

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
          features: [
            '큐레이션 카테고리 선택 (신규/베스트/계절/난이도)',
            '본인 도안 선택 + 추천 사유 작성',
            '편집자 검수 대기 큐 표시',
            '승인/반려 결과 + 노출 기간',
            '노출 통계 (조회/Fork/판매)',
          ],
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.article_rounded,
          title: '에디토리얼 노출 신청',
          subtitle: '뜨개소식·모리채널 콘텐츠 협업',
          phase: 'Phase 3 예정',
          accent: C.pk,
          features: [
            '에디토리얼 보드 선택 (뜨개소식 / 모리채널)',
            '기획안 작성 (제목 / 주제 / 본인 도안 연결)',
            '편집자 의견 + 수정 요청',
            '발행 일정 협의',
            '발행 후 노출 통계',
          ],
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.group_add_rounded,
          title: '함께뜨기 그룹 홍보',
          subtitle: '진행 중인 함께뜨기를 메인 노출',
          phase: 'Phase 3 예정',
          accent: C.lvD,
          features: [
            '진행 중 본인 함께뜨기 그룹 목록',
            '메인 노출 신청 (위치/기간)',
            '예상 노출 수 + 참여 전환율 예상',
            '검수 통과 후 노출 시작',
            '실시간 참여자 증가 추이',
          ],
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.notifications_active_rounded,
          title: '신규 도안 푸시',
          subtitle: '팔로워에게 신규 도안 푸시 알림',
          phase: 'Phase 3 예정',
          accent: C.og,
          features: [
            '본인 팔로워 수 + 활성 비율',
            '푸시 메시지 작성 (제목/본문/딥링크)',
            '발송 대상 (전체/등급별/지역별)',
            '예약 발송 (즉시/시간 지정)',
            '발송 결과 (도달/오픈/클릭)',
            '월간 푸시 한도 (Pro / Business 차등)',
          ],
        ),
        const SizedBox(height: 12),
        _MarketingPlaceholder(
          icon: Icons.campaign_rounded,
          title: '광고',
          subtitle: '유료 노출 슬롯 구매',
          phase: 'Phase 3+ 예정',
          accent: C.lv,
          features: [
            '광고 슬롯 종류 (홈 배너 / 검색 상위 / 카테고리 상단)',
            '예산 설정 + 입찰가',
            '광고 크리에이티브 업로드 (이미지 / 카피)',
            '타깃팅 (등급/관심사/지역)',
            '실시간 노출/클릭/전환 대시보드',
            '결제 + 정산 (Business 등급 전용)',
          ],
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
  final List<String> features;
  const _MarketingPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.phase,
    required this.accent,
    required this.features,
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
      child: InkWell(
        onTap: () => openSellerPlaceholder(
          context,
          title: title,
          subtitle: subtitle,
          icon: icon,
          features: features,
          note: '$phase. 본 카드 탭 시 와이어프레임이 표시됩니다.',
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: T.caption.copyWith(color: C.tx2, height: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: accent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
