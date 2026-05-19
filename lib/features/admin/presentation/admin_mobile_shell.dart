// 이슈 #815 Phase 2 — 어드민 모바일 셸.
//
// 모바일유저 앱의 모리 디자인 시스템(라이트 톤 + 오렌지 액센트)을 베이스로
// BottomNavigationBar 5탭 구조로 어드민 콘솔을 재구성한다.
//
// 본 파일은 Phase 2 placeholder 단계 — 각 탭에서 기존 어드민 콘솔
// (`/legacy-admin`)으로 이동하는 카드들을 제공한다.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'screens/admin_activity_log_screen.dart';
import 'screens/admin_mobile_inbox_screen.dart';
import 'screens/admin_users_management_screen.dart';
import 'widgets/dashboard/ops_metrics_section.dart';

/// 어드민 모바일 오렌지 액센트 — 어드민 정체성.
/// 모리유저 앱의 C.lv/C.pk와 명확히 구분된다.
const Color kAdminMobileAccent = Color(0xFFFF8A00);

class AdminMobileShell extends ConsumerStatefulWidget {
  const AdminMobileShell({super.key});

  @override
  ConsumerState<AdminMobileShell> createState() => _AdminMobileShellState();
}

class _AdminMobileShellState extends ConsumerState<AdminMobileShell> {
  int _idx = 0;

  static const List<_TabSpec> _tabs = [
    _TabSpec(icon: Icons.dashboard_rounded, label: '홈'),
    _TabSpec(icon: Icons.people_rounded, label: '사용자'),
    _TabSpec(icon: Icons.folder_copy_rounded, label: '콘텐츠'),
    _TabSpec(icon: Icons.support_agent_rounded, label: '운영'),
    _TabSpec(icon: Icons.more_horiz_rounded, label: '더보기'),
  ];

  Widget _body() {
    switch (_idx) {
      case 0:
        return const AdminHomeTab();
      case 1:
        return const AdminUsersTab();
      case 2:
        return const AdminContentTab();
      case 3:
        return const AdminOpsTab();
      case 4:
        return const AdminMoreTab();
      default:
        return const AdminHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(child: _body()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: C.gx,
        selectedItemColor: kAdminMobileAccent,
        unselectedItemColor: C.mu,
        selectedLabelStyle: T.caption.copyWith(
          color: kAdminMobileAccent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: T.caption,
        items: _tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final String label;
  const _TabSpec({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────────────────────────────────────────

/// 어드민 모바일 전용 탭 셸 — 오렌지 액센트 헤더 + 스크롤 본문.
///
/// 어드민 정체성(kAdminMobileAccent #FF8A00) 시각화를 위해 헤더에 오렌지 배경 적용.
/// 본문은 라이트 톤 카드 위에 가독성 좋은 어두운 글씨.
class _AdminMobileTabShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _AdminMobileTabShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 오렌지 헤더 — 어드민 정체성
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kAdminMobileAccent,
                kAdminMobileAccent.withValues(alpha: 0.82),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: kAdminMobileAccent.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: kAdminMobileAccent.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: T.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: T.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final w in children) ...[
                  w,
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 어드민 모바일 카드 — `MoriBlockShell`을 기반으로 한 placeholder 카드.
///
/// 클릭 시 [onTap] 실행 (대부분 기존 어드민 콘솔로 이동).
class _AdminCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final String? description;
  final VoidCallback? onTap;

  const _AdminCard({
    required this.label,
    required this.icon,
    required this.accent,
    this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: label,
      icon: icon,
      accent: accent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  description ?? '기존 어드민 콘솔에서 관리합니다.',
                  style: T.sm.copyWith(color: C.tx),
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

/// `/legacy-admin`으로 보내는 공용 헬퍼. (모바일에서 깊이 필요한 작업은 웹 콘솔로)
void _openLegacyAdmin(BuildContext context) {
  context.push('/legacy-admin');
}

/// 와이어프레임 placeholder 페이지로 push.
///
/// 모바일어드민 각 카드 진입 시 사용. 실데이터 미구현 단계에서도 카드를 누르면
/// "어떤 기능이 들어올 화면인지"를 보여주는 와이어프레임이 뜬다.
/// [features]는 해당 화면에 들어올 항목 리스트 (체크리스트로 렌더).
void _openPlaceholder(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accent,
  required List<String> features,
  String? note,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _AdminPlaceholderPage(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accent: accent,
        features: features,
        note: note,
      ),
    ),
  );
}

/// 어드민 모바일 와이어프레임 placeholder 페이지.
class _AdminPlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> features;
  final String? note;

  const _AdminPlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.features,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: C.tx),
        title: Text(title, style: T.h3.copyWith(color: C.tx)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                MoriBlockShell(
                  label: title,
                  icon: icon,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle, style: T.body.copyWith(color: C.tx2)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          '와이어프레임 (Phase 2 placeholder)',
                          style: T.caption.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MoriBlockShell(
                  label: '들어올 항목',
                  icon: Icons.checklist_rounded,
                  accent: C.lv,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: features
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.radio_button_unchecked,
                                  size: 16,
                                  color: C.mu,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: T.body.copyWith(color: C.tx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                MoriBlockShell(
                  label: '안내',
                  icon: Icons.info_outline_rounded,
                  accent: C.mu,
                  child: Text(
                    note ??
                        '본 화면은 와이어프레임 단계입니다. 실제 데이터·액션은 단계별로 구현되며, 깊이 필요한 작업은 [기존 어드민 콘솔]에서 가능합니다.',
                    style: T.body.copyWith(color: C.tx2),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openLegacyAdmin(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('기존 어드민 콘솔에서 열기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAdminMobileAccent,
                      side: BorderSide(
                        color: kAdminMobileAccent.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. 홈 탭 — 대시보드 카운트 + 운영 알림
// ─────────────────────────────────────────────────────────────────────────────

/// 운영 카운트 placeholder — Phase 2에서는 빈 맵을 반환하여 "—" 표시.
/// 추후 admin_screen.dart 의 `_adminCountsProvider` 를 public 으로 노출하면
/// 그대로 swap-in 가능한 구조.
final _adminMobileCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  return const <String, int>{};
});

class AdminHomeTab extends ConsumerWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_adminMobileCountsProvider);

    return _AdminMobileTabShell(
      title: '모리니트 어드민',
      subtitle: '한눈에 보는 운영 현황',
      children: [
        _CountsGridCard(counts: counts),
        OpsMetricsSection(
          onOpenBugReports: () => _openPlaceholder(
            context,
            title: '119 버그리포트',
            subtitle: '미해결 버그 우선 처리 · AI 자동 fix 트리거',
            icon: Icons.bug_report_rounded,
            accent: C.og,
            features: [
              '미해결 버그리포트 목록',
              'AI 분석 시작 / 수정 승인 / 거부',
              '단계 로그 실시간 시각화',
              'Pushover 발송 이력',
            ],
          ),
          onOpenInquiries: () => _openPlaceholder(
            context,
            title: '1:1 문의',
            subtitle: '미응답 문의 답변',
            icon: Icons.mail_rounded,
            accent: kAdminMobileAccent,
            features: [
              '미응답 문의 목록',
              '답변 작성 + 이메일 발송',
              '답변 템플릿',
              '미응답 SLA 알림',
            ],
          ),
          onOpenPendingPatterns: () => _openPlaceholder(
            context,
            title: '검수 대기 도안',
            subtitle: '도안 검수·승인·반려',
            icon: Icons.menu_book_rounded,
            accent: kAdminMobileAccent,
            features: [
              '검수 대기 도안 목록',
              '도안 상태 변경 (draft → complete)',
              '검수 의견 작성',
              '반려 사유 템플릿',
            ],
          ),
        ),
        _AdminCard(
          label: '기존 어드민 콘솔',
          icon: Icons.open_in_new_rounded,
          accent: kAdminMobileAccent,
          description: '회원·도안·마켓 등 세부 관리는 기존 콘솔에서 진행합니다.',
          onTap: () => _openLegacyAdmin(context),
        ),
      ],
    );
  }
}

class _CountsGridCard extends StatelessWidget {
  final AsyncValue<Map<String, int>> counts;
  const _CountsGridCard({required this.counts});

  static const List<({String key, String label, IconData icon})> _items = [
    (key: 'users', label: '회원', icon: Icons.person_rounded),
    (key: 'blueprints', label: '도안', icon: Icons.menu_book_rounded),
    (key: 'swatches', label: '스와치', icon: Icons.grid_view_rounded),
    (key: 'projects', label: '프로젝트', icon: Icons.assignment_rounded),
    (key: 'market', label: '마켓', icon: Icons.storefront_rounded),
    (key: 'encyclopedia', label: '백과', icon: Icons.school_rounded),
    (key: 'posts', label: '커뮤니티', icon: Icons.forum_rounded),
    (key: 'bugReports', label: '버그리포트', icon: Icons.bug_report_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: '운영 카운트',
      icon: Icons.bar_chart_rounded,
      accent: kAdminMobileAccent,
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: _items.map((item) {
          final value = counts.maybeWhen(
            data: (m) => m[item.key],
            orElse: () => null,
          );
          return _CountTile(label: item.label, icon: item.icon, value: value);
        }).toList(),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? value;

  const _CountTile({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: C.tint(kAdminMobileAccent, 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.tint(kAdminMobileAccent, 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kAdminMobileAccent, size: 18),
          const SizedBox(height: 4),
          Text(
            value == null ? '—' : '$value',
            style: T.bodyBold.copyWith(color: C.tx),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: T.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. 사용자 탭
// ─────────────────────────────────────────────────────────────────────────────

class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminMobileTabShell(
      title: '사용자',
      subtitle: '회원·통합 관리',
      children: [
        _AdminCard(
          label: '회원 관리',
          icon: Icons.people_rounded,
          accent: kAdminMobileAccent,
          description: '가입 회원 검색·등급·차단·관리자 권한 부여',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminUsersManagementScreen(),
            ),
          ),
        ),
        _AdminCard(
          label: '활동 로그',
          icon: Icons.history_rounded,
          accent: C.pk,
          description: '회원 관리 액션 audit log',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminActivityLogScreen(),
            ),
          ),
        ),
        _AdminCard(
          label: '사용자 통합 관리',
          icon: Icons.account_circle_rounded,
          accent: C.lv,
          description: '계정 통합·중복 정리·이메일 변경 이력',
          onTap: () => _openPlaceholder(
            context,
            title: '사용자 통합 관리',
            subtitle: '계정 통합·중복 정리·이메일 변경 이력',
            icon: Icons.account_circle_rounded,
            accent: C.lv,
            features: [
              '같은 이메일 중복 계정 병합',
              '소셜 계정 ↔ 이메일 계정 통합',
              '이메일 변경 이력',
              '탈퇴 회원 데이터 정리',
              '복원 가능 회원 목록',
            ],
          ),
        ),
        _AdminCard(
          label: '사용자 통계',
          icon: Icons.insights_rounded,
          accent: C.lm,
          description: 'DAU/MAU·등급별 분포·신규 가입 추이',
          onTap: () => _openPlaceholder(
            context,
            title: '사용자 통계',
            subtitle: 'DAU/MAU·등급별 분포·신규 가입 추이',
            icon: Icons.insights_rounded,
            accent: C.lm,
            features: [
              '오늘/이번주/이번달 DAU·MAU',
              '등급별 회원 분포 (free/pro/business)',
              '신규 가입 추이 (일간/주간)',
              '리텐션 코호트',
              '가입 경로 분포 (이메일/카카오/구글)',
              '활동 시간대 분포',
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. 콘텐츠 탭
// ─────────────────────────────────────────────────────────────────────────────

class AdminContentTab extends StatelessWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminMobileTabShell(
      title: '콘텐츠',
      subtitle: '도안·스와치·프로젝트·마켓·백과·게시판',
      children: [
        _AdminCard(
          label: '도안',
          icon: Icons.menu_book_rounded,
          accent: kAdminMobileAccent,
          description: '도안 검수·삭제·내장 템플릿 관리',
          onTap: () => _openPlaceholder(
            context,
            title: '도안 관리',
            subtitle: '도안 검수·삭제·내장 템플릿 관리',
            icon: Icons.menu_book_rounded,
            accent: kAdminMobileAccent,
            features: [
              '검수 대기 도안 목록',
              '도안 상태 변경 (draft → complete)',
              '신고된 도안 처리',
              '내장 템플릿 등록/수정/삭제',
              'AI 변환 도안 품질 점검',
            ],
          ),
        ),
        _AdminCard(
          label: '스와치',
          icon: Icons.grid_view_rounded,
          accent: C.lv,
          description: '스와치 신고 처리·기준 스와치 관리',
          onTap: () => _openPlaceholder(
            context,
            title: '스와치 관리',
            subtitle: '스와치 신고 처리·기준 스와치 관리',
            icon: Icons.grid_view_rounded,
            accent: C.lv,
            features: [
              '신고 접수된 스와치 목록',
              '기준 스와치 등록 (실/바늘별)',
              '이상 데이터 (게이지 0/극단값) 정리',
              '커뮤니티 공유 스와치 검수',
            ],
          ),
        ),
        _AdminCard(
          label: '프로젝트',
          icon: Icons.assignment_rounded,
          accent: C.pk,
          description: '프로젝트 통계·이상 데이터 점검',
          onTap: () => _openPlaceholder(
            context,
            title: '프로젝트 관리',
            subtitle: '프로젝트 통계·이상 데이터 점검',
            icon: Icons.assignment_rounded,
            accent: C.pk,
            features: [
              '진행 중/완료/보관 분포',
              '단계로그 평균 깊이',
              '카운터 폭증 프로젝트 (#821)',
              '이상 데이터 (단계 0개/카운터 N00개) 정리',
            ],
          ),
        ),
        _AdminCard(
          label: '마켓',
          icon: Icons.storefront_rounded,
          accent: C.lmD,
          description: '마켓 상품 검수·정산·일괄등록',
          onTap: () => _openPlaceholder(
            context,
            title: '마켓 관리',
            subtitle: '마켓 상품 검수·정산·일괄등록',
            icon: Icons.storefront_rounded,
            accent: C.lmD,
            features: [
              '검수 대기 상품',
              '신고된 상품 처리',
              '정산 대상 셀러 목록 (월별)',
              '카테고리/태그 관리',
              '일괄 등록 (CSV 업로드)',
              '베스트셀러 큐레이션',
            ],
          ),
        ),
        _AdminCard(
          label: '백과',
          icon: Icons.school_rounded,
          accent: C.lv,
          description: '백과 항목 검수·일괄등록',
          onTap: () => _openPlaceholder(
            context,
            title: '백과 관리',
            subtitle: '백과 항목 검수·일괄등록',
            icon: Icons.school_rounded,
            accent: C.lv,
            features: [
              '백과 항목 등록 (기법/실/바늘/용어)',
              '검수 대기 항목',
              '일괄 등록 (JSON/CSV)',
              '연관 항목 매핑',
            ],
          ),
        ),
        _AdminCard(
          label: '게시판',
          icon: Icons.forum_rounded,
          accent: kAdminMobileAccent,
          description: '커뮤니티·랜딩 보드(리뷰/릴리즈/Q&A) 관리',
          onTap: () => _openPlaceholder(
            context,
            title: '게시판 관리',
            subtitle: '커뮤니티·랜딩 보드(리뷰/릴리즈/Q&A) 관리',
            icon: Icons.forum_rounded,
            accent: kAdminMobileAccent,
            features: [
              '커뮤니티 신고 게시물 처리',
              '랜딩 리뷰 보드',
              '릴리즈노트 보드',
              'Q&A 답변 대기 목록',
              '인기 게시물 큐레이션',
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. 운영 탭
// ─────────────────────────────────────────────────────────────────────────────

class AdminOpsTab extends ConsumerWidget {
  const AdminOpsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminMobileTabShell(
      title: '운영',
      subtitle: '인박스·버그·문의·팝업·문구·에디토리얼',
      children: [
        // 이슈 #837 — @moriknit 인박스 (양방향 1:1 고객 지원). 오렌지 액센트.
        _AdminCard(
          label: '@moriknit 인박스',
          icon: Icons.inbox_rounded,
          accent: kAdminMobileAccent,
          description: '사용자가 보낸 메시지에 모리니트 명의로 답장',
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminMobileInboxScreen(),
            ),
          ),
        ),
        _AdminCard(
          label: '119 버그리포트',
          icon: Icons.bug_report_rounded,
          accent: C.og,
          description: '미해결 버그 우선 처리',
          onTap: () => _openPlaceholder(
            context,
            title: '119 버그리포트',
            subtitle: '미해결 버그 우선 처리 · AI 자동 fix 트리거',
            icon: Icons.bug_report_rounded,
            accent: C.og,
            features: [
              '미해결 버그리포트 목록',
              'AI 분석 시작 / 수정 승인 / 거부',
              '단계 로그 실시간 시각화',
              'PC 워커 상태 (singleton lock / 마지막 활동)',
              '실패 사유 + 재시도',
              'Pushover 발송 이력',
            ],
            note: 'PC 119 워커가 새 버그 접수 즉시 캐치 → Pushover 알림. AI 분석/수정은 어드민이 [AI 분석 시작] 누를 때만 실행.',
          ),
        ),
        _AdminCard(
          label: '1:1 문의',
          icon: Icons.mail_rounded,
          accent: kAdminMobileAccent,
          description: '미응답 문의 답변',
          onTap: () => _openPlaceholder(
            context,
            title: '1:1 문의',
            subtitle: '미응답 문의 답변',
            icon: Icons.mail_rounded,
            accent: kAdminMobileAccent,
            features: [
              '미응답 문의 목록 (오래된 순)',
              '답변 작성 + 이메일 발송',
              '카테고리별 분류',
              '답변 템플릿 (자주 묻는 답)',
              '미응답 SLA 알림',
            ],
          ),
        ),
        _AdminCard(
          label: '팝업 설정',
          icon: Icons.campaign_rounded,
          accent: C.lv,
          description: '홈/공지/이벤트 팝업 노출 설정',
          onTap: () => _openPlaceholder(
            context,
            title: '팝업 설정',
            subtitle: '홈/공지/이벤트 팝업 노출 설정',
            icon: Icons.campaign_rounded,
            accent: C.lv,
            features: [
              '신기능 안내 팝업 (다시보지않기 옵션)',
              '공지 팝업 (필수/선택)',
              '이벤트 팝업 (기간/타깃)',
              '플랫폼별 노출 (모바일/웹)',
              '노출 이력 + 클릭률',
            ],
          ),
        ),
        _AdminCard(
          label: '문구 관리',
          icon: Icons.text_snippet_rounded,
          accent: C.lmD,
          description: '앱 내 안내 문구·UI 카피 변경',
          onTap: () => _openPlaceholder(
            context,
            title: '문구 관리',
            subtitle: '앱 내 안내 문구·UI 카피 변경 (ui_copy 컬렉션)',
            icon: Icons.text_snippet_rounded,
            accent: C.lmD,
            features: [
              'UI 카피 검색 (key 기반)',
              '한/영/중/일 다국어 동시 편집',
              '빈 라벨 / 누락 키 점검',
              '변경 이력 + 롤백',
            ],
          ),
        ),
        _AdminCard(
          label: '에디토리얼',
          icon: Icons.article_rounded,
          accent: C.pk,
          description: '홈 에디토리얼 보드(뜨개소식/모리채널)',
          onTap: () => _openPlaceholder(
            context,
            title: '에디토리얼',
            subtitle: '홈 에디토리얼 보드 (뜨개소식/모리채널)',
            icon: Icons.article_rounded,
            accent: C.pk,
            features: [
              '홈 카드 발행 (뜨개소식/모리채널)',
              '발행 일정 예약',
              '카테고리/태그',
              '카드 순서 변경 (드래그)',
              '발행 이력 + 노출 수',
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. 더보기 탭
// ─────────────────────────────────────────────────────────────────────────────

class AdminMoreTab extends ConsumerWidget {
  const AdminMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminMobileTabShell(
      title: '더보기',
      subtitle: '랜딩·마이그레이션·설정·로그아웃',
      children: [
        _AdminCard(
          label: '랜딩 CMS',
          icon: Icons.web_rounded,
          accent: kAdminMobileAccent,
          description: '랜딩 페이지 공지·리뷰·릴리즈노트 관리',
          onTap: () => _openPlaceholder(
            context,
            title: '랜딩 CMS',
            subtitle: '랜딩 페이지 공지·리뷰·릴리즈노트 관리',
            icon: Icons.web_rounded,
            accent: kAdminMobileAccent,
            features: [
              '랜딩 공지 (배너/긴급)',
              '리뷰 보드 (사용자 후기 큐레이션)',
              '릴리즈노트 보드',
              '클래스/이벤트 페이지',
              '메타 태그 / OG 이미지',
            ],
          ),
        ),
        _AdminCard(
          label: '#687 마이그레이션',
          icon: Icons.sync_alt_rounded,
          accent: C.lv,
          description: 'Blueprint 마이그레이션 도구',
          onTap: () => _openPlaceholder(
            context,
            title: '#687 Blueprint 마이그레이션',
            subtitle: '도안 스키마 마이그레이션 도구',
            icon: Icons.sync_alt_rounded,
            accent: C.lv,
            features: [
              '마이그레이션 대상 도안 카운트',
              'draft → complete 일괄 승격',
              'aiSections 누락 도안 점검',
              '단계 미러링 재실행 (#627)',
              '드라이런 (변경 없이 시뮬레이션)',
            ],
            note: '데이터 변경 작업이므로 드라이런 후 실제 실행. 작업 이력 자동 백업.',
          ),
        ),
        _AdminCard(
          label: '설정',
          icon: Icons.settings_rounded,
          accent: C.lmD,
          description: '구독·정책·앱 설정',
          onTap: () => _openPlaceholder(
            context,
            title: '앱 설정',
            subtitle: '구독·정책·앱 설정 (app_config 컬렉션)',
            icon: Icons.settings_rounded,
            accent: C.lmD,
            features: [
              '구독 요금제 설정 (free/pro/business)',
              '결제 정책',
              '약관 / 개인정보처리방침',
              'GitHub PAT 관리 (버그리포트 이슈 자동등록)',
              '워커 설정 (PC 119 endpoint)',
              '버전별 강제 업데이트',
            ],
          ),
        ),
        _AdminCard(
          label: '로그아웃',
          icon: Icons.logout_rounded,
          accent: C.og,
          description: '현재 어드민 계정에서 로그아웃합니다.',
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
