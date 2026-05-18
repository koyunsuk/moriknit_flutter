// 이슈 #816 Phase 2 — 셀러 모바일 콘솔 메인 화면.
//
// 5개 BottomNavigationBar 탭으로 구성된 셀러 콘솔.
//  0: 대시보드 (_SellerHomeTab — 본 파일 인라인)
//  1: 테스터 피드백 (에이전트 B가 SellerTesterFeedbackScreen 신설 후 교체)
//  2: 도안 관리 (에이전트 B가 SellerPatternManagementScreen 신설 후 교체)
//  3: 함께뜨기 (에이전트 B가 SellerKnitAlongScreen 신설 후 교체)
//  4: 마케팅 (에이전트 B가 SellerMarketingScreen 신설 후 교체)
//
// CLAUDE.md 토큰 의무 — C., T., MoriBlockShell 사용. 인라인 Container 최소화.
// 셀러 액센트 컬러: 라임 #7CB342 (다크) / #C0DC3C (배경).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'seller_knit_along_screen.dart';
import 'seller_marketing_screen.dart';
import 'seller_pattern_management_screen.dart';
import 'seller_tester_feedback_screen.dart';

/// 셀러 액센트 컬러 — 라임 톤. 다른 셀러 화면에서도 import 해 재사용.
const Color kSellerAccent = Color(0xFF7CB342); // 다크 (텍스트/아이콘)
const Color kSellerAccentBg = Color(0xFFC0DC3C); // 배경/하이라이트

class SellerDashboardScreen extends ConsumerStatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  ConsumerState<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends ConsumerState<SellerDashboardScreen> {
  int _currentIndex = 0;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.dashboard_rounded, label: '대시보드'),
    (icon: Icons.chat_bubble_rounded, label: '피드백'),
    (icon: Icons.upload_file_rounded, label: '도안'),
    (icon: Icons.group_rounded, label: '함께뜨기'),
    (icon: Icons.campaign_rounded, label: '마케팅'),
  ];

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _SellerHomeTab();
      case 1:
        return const SellerTesterFeedbackScreen();
      case 2:
        return const SellerPatternManagementScreen();
      case 3:
        return const SellerKnitAlongScreen();
      case 4:
        return const SellerMarketingScreen();
      default:
        return const _SellerHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('모리니트 셀러', style: T.h3.copyWith(color: C.tx)),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: C.mu),
            tooltip: '로그아웃',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kSellerAccent,
        unselectedItemColor: C.mu,
        items: _tabs
            .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

// ============================================================================
// Tab 0 — 대시보드 홈 (본 파일 인라인 정의)
// ============================================================================

class _SellerHomeTab extends StatelessWidget {
  const _SellerHomeTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        MoriBlockShell(
          label: '판매 현황',
          icon: Icons.payments_rounded,
          accent: C.lm,
          child: _DashboardMetricRow(
            primary: '—',
            primaryLabel: '오늘 매출',
            secondary: '—',
            secondaryLabel: '이번 달 매출',
            note: 'Phase 2: Firestore orders 집계 연결 예정',
          ),
        ),
        const SizedBox(height: 12),
        MoriBlockShell(
          label: '주문 / 구매자',
          icon: Icons.shopping_bag_rounded,
          accent: C.lv,
          child: _DashboardMetricRow(
            primary: '—',
            primaryLabel: '신규 주문',
            secondary: '—',
            secondaryLabel: '환불 요청',
            note: 'Phase 2: 신규 주문 · 환불 요청 · 메시지',
          ),
        ),
        const SizedBox(height: 12),
        MoriBlockShell(
          label: '미응답 피드백',
          icon: Icons.chat_bubble_rounded,
          accent: C.pk,
          child: _DashboardMetricRow(
            primary: '—',
            primaryLabel: '테스터 피드백',
            secondary: '—',
            secondaryLabel: '구매자 문의',
            note: 'Phase 2: 피드백 탭에서 응답 처리',
          ),
        ),
        const SizedBox(height: 12),
        MoriBlockShell(
          label: 'Fork 통계',
          icon: Icons.call_split_rounded,
          accent: C.og,
          child: _DashboardMetricRow(
            primary: '—',
            primaryLabel: '이번 주 Fork',
            secondary: '—',
            secondaryLabel: '누적 Fork',
            note: 'Phase 2: complete 도안만 집계',
          ),
        ),
        const SizedBox(height: 12),
        MoriBlockShell(
          label: '리뷰',
          icon: Icons.star_rounded,
          accent: C.lvD,
          child: _DashboardMetricRow(
            primary: '—',
            primaryLabel: '신규 리뷰',
            secondary: '—',
            secondaryLabel: '평균 별점',
            note: 'Phase 2: 리뷰 응답 워크플로우',
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '이슈 #816 Phase 2 — 대시보드 메트릭은 Phase 3에서 Firestore 연결 예정.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 대시보드 카드 본문 — 좌/우 메트릭 + 하단 안내.
/// 플레이스홀더 원칙: 데이터 없어도 빈 행으로 공간 유지.
class _DashboardMetricRow extends StatelessWidget {
  final String primary;
  final String primaryLabel;
  final String secondary;
  final String secondaryLabel;
  final String note;
  const _DashboardMetricRow({
    required this.primary,
    required this.primaryLabel,
    required this.secondary,
    required this.secondaryLabel,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Metric(value: primary, label: primaryLabel)),
            Expanded(child: _Metric(value: secondary, label: secondaryLabel)),
          ],
        ),
        const SizedBox(height: 10),
        Text(note, style: T.caption.copyWith(color: C.mu)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: T.h2.copyWith(color: C.tx)),
        const SizedBox(height: 2),
        Text(label, style: T.caption.copyWith(color: C.tx2)),
      ],
    );
  }
}

// Tab 1~4 위젯들은 에이전트 B가 신설한 별도 파일에 정의됨 (import 참조).
