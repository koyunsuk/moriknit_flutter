// 이슈 #816 Phase 2 — 셀러 모바일 콘솔 메인 화면.
//
// 5개 BottomNavigationBar 탭으로 구성된 셀러 콘솔.
//  0: 대시보드 (_SellerHomeTab — 본 파일 인라인)
//  1: 테스터 피드백 (SellerTesterFeedbackScreen)
//  2: 도안 관리 (SellerPatternManagementScreen)
//  3: 함께뜨기 (SellerKnitAlongScreen)
//  4: 마케팅 (SellerMarketingScreen)
//
// Phase 2 폴리시:
//   - 모바일유저 앱 UI 시스템 베이스 적용 (BgOrbs + MoriPageHeaderShell + MoriWideHeader)
//   - 셀러 정체성 액센트: 라임 #7CB342 (BottomNav selected + 헤더 강조)
//   - 모든 탭 본문은 별도 화면(이미 BgOrbs/SafeArea 자체 포함)
//   - 대시보드 탭은 본 파일에 인라인 정의 — 실사용 가능한 placeholder 강화.
//
// CLAUDE.md 토큰 의무 — C / T / MoriBlockShell / BgOrbs / MoriPageHeaderShell / MoriWideHeader.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/seller_metrics_provider.dart';
import 'seller_knit_along_screen.dart';
import 'seller_marketing_screen.dart';
import 'seller_pattern_management_screen.dart';
import 'seller_tester_feedback_screen.dart';

/// 셀러 액센트 컬러 — 라임 톤. 다른 셀러 화면에서도 import 해 재사용.
/// Phase 2 — BottomNav selected, 헤더 trailing, 카드 강조 등 셀러 정체성 표시에 사용.
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

  String get _currentSubtitle {
    switch (_currentIndex) {
      case 0:
        return '셀러 - 대시보드';
      case 1:
        return '셀러 - 테스터 피드백';
      case 2:
        return '셀러 - 도안 관리';
      case 3:
        return '셀러 - 함께뜨기';
      case 4:
        return '셀러 - 마케팅';
      default:
        return '셀러 콘솔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: '모리니트 셀러',
                    subtitle: _currentSubtitle,
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.logout_rounded, color: kSellerAccent),
                        tooltip: '로그아웃',
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: C.bg,
        selectedItemColor: kSellerAccent,
        unselectedItemColor: C.mu,
        selectedLabelStyle: T.caption.copyWith(
          color: kSellerAccent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: T.caption.copyWith(color: C.mu),
        showUnselectedLabels: true,
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
//
// Phase 2 폴리시:
//   - sellerMetricsProvider 연결 (미응답 피드백 / 신규 주문 / 함께뜨기) — 즉시 사용 가능
//   - 매출/Fork/리뷰는 Phase 3에서 데이터 연결. 현재는 "데이터 수집 중" placeholder.
//   - 최근 활동 카드 — 빈 행 placeholder (CLAUDE.md 플레이스홀더 원칙).
//   - Scaffold 안 BgOrbs는 dashboard 컨테이너가 책임지므로 본 위젯은 본문만.

class _SellerHomeTab extends ConsumerWidget {
  const _SellerHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(sellerMetricsProvider);
    final metrics = metricsAsync.valueOrNull ?? SellerMetrics.empty;
    final loading = metricsAsync.isLoading;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // 1. 매출 요약 (오늘/이번주/이번달) — Phase 3 데이터 연결 대기
        MoriBlockShell(
          label: '매출 요약',
          icon: Icons.payments_rounded,
          accent: kSellerAccent,
          child: _SalesSummary(),
        ),
        const SizedBox(height: 12),

        // 2. 신규 주문 (sellerMetricsProvider.newOrders 연결)
        MoriBlockShell(
          label: '신규 주문',
          icon: Icons.shopping_bag_rounded,
          accent: C.lv,
          child: _MetricSingle(
            value: loading ? '…' : '${metrics.newOrders}',
            label: '응답 대기 중인 주문',
            note: metrics.newOrders == 0
                ? '신규 주문이 들어오면 여기에 표시돼요.'
                : '도안 관리 탭에서 주문을 확인해 주세요.',
            accent: C.lv,
          ),
        ),
        const SizedBox(height: 12),

        // 3. 미응답 피드백 (sellerMetricsProvider.pendingFeedbacks 연결)
        MoriBlockShell(
          label: '미응답 피드백',
          icon: Icons.chat_bubble_rounded,
          accent: C.pk,
          child: _MetricSingle(
            value: loading ? '…' : '${metrics.pendingFeedbacks}',
            label: '응답이 필요한 테스터 피드백',
            note: metrics.pendingFeedbacks == 0
                ? '받은 피드백 모두 응답 완료된 상태예요.'
                : '피드백 탭에서 응답해 주세요.',
            accent: C.pk,
          ),
        ),
        const SizedBox(height: 12),

        // 4. 진행 중 함께뜨기 (Phase 2.5 schema 확정 후 활성화)
        MoriBlockShell(
          label: '진행 중 함께뜨기',
          icon: Icons.group_rounded,
          accent: C.lvD,
          child: _MetricSingle(
            value: loading ? '…' : '${metrics.activeKnitAlongs}',
            label: '진행 중인 그룹 수',
            note: '함께뜨기 탭에서 본인 도안의 그룹 통계를 확인할 수 있어요.',
            accent: C.lvD,
          ),
        ),
        const SizedBox(height: 12),

        // 5. Fork 통계 — Phase 3 데이터 연결 대기
        MoriBlockShell(
          label: 'Fork 통계',
          icon: Icons.call_split_rounded,
          accent: C.og,
          child: _MetricRow(
            primary: '—',
            primaryLabel: '이번 주 Fork',
            secondary: '—',
            secondaryLabel: '누적 Fork',
            note: '데이터 수집 중 — complete 도안만 집계돼요.',
          ),
        ),
        const SizedBox(height: 12),

        // 6. 리뷰 — Phase 3 데이터 연결 대기
        MoriBlockShell(
          label: '리뷰',
          icon: Icons.star_rounded,
          accent: C.lm,
          child: _MetricRow(
            primary: '—',
            primaryLabel: '신규 리뷰',
            secondary: '—',
            secondaryLabel: '평균 별점',
            note: '데이터 수집 중 — 리뷰 응답은 Phase 3에서 지원돼요.',
          ),
        ),
        const SizedBox(height: 12),

        // 7. 최근 활동 — placeholder (빈 행 안내)
        MoriBlockShell(
          label: '최근 활동',
          icon: Icons.history_rounded,
          accent: C.mu,
          child: const EmptyBlockPlaceholder(
            message: '최근 활동이 없어요.\n주문·피드백·Fork 가 발생하면 시간순으로 표시돼요.',
            rows: 3,
            rowHeight: 44,
          ),
        ),

        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '셀러 정체성 액센트: 라임 · 매출/리뷰/Fork 는 Phase 3 데이터 연결 예정',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 매출 요약 — 오늘/이번주/이번달 3분할. 데이터 미연결 시 "—" placeholder.
class _SalesSummary extends StatelessWidget {
  const _SalesSummary();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Metric(value: '—', label: '오늘')),
            Expanded(child: _Metric(value: '—', label: '이번 주')),
            Expanded(child: _Metric(value: '—', label: '이번 달')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '데이터 수집 중 — Phase 3 마켓 주문 연결 시 자동 표시돼요.',
          style: T.caption.copyWith(color: C.mu),
        ),
      ],
    );
  }
}

/// 대시보드 카드 본문 — 좌/우 2분할 메트릭 + 하단 안내.
/// 플레이스홀더 원칙: 데이터 없어도 빈 행으로 공간 유지.
class _MetricRow extends StatelessWidget {
  final String primary;
  final String primaryLabel;
  final String secondary;
  final String secondaryLabel;
  final String note;
  const _MetricRow({
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

/// 단일 메트릭 카드 본문 — 큰 값 1개 + 라벨 + 안내.
/// sellerMetricsProvider 의 단일 수치 (신규 주문 / 미응답 피드백 등) 표시용.
class _MetricSingle extends StatelessWidget {
  final String value;
  final String label;
  final String note;
  final Color accent;
  const _MetricSingle({
    required this.value,
    required this.label,
    required this.note,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: T.h1.copyWith(color: accent, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(label, style: T.caption.copyWith(color: C.tx2)),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
