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

/// 탭 공통 셸 — `MoriPageHeaderShell` + `MoriWideHeader` + 스크롤 본문.
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
        MoriPageHeaderShell(
          child: MoriWideHeader(title: title, subtitle: subtitle, compact: true),
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
                  style: T.sm,
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

/// `/legacy-admin`으로 보내는 공용 헬퍼.
void _openLegacyAdmin(BuildContext context) {
  context.push('/legacy-admin');
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
          onOpenBugReports: () => _openLegacyAdmin(context),
          onOpenInquiries: () => _openLegacyAdmin(context),
          onOpenPendingPatterns: () => _openLegacyAdmin(context),
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
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '사용자 통합 관리',
          icon: Icons.account_circle_rounded,
          accent: C.lv,
          description: '계정 통합·중복 정리·이메일 변경 이력',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '사용자 통계',
          icon: Icons.insights_rounded,
          accent: C.lm,
          description: 'DAU/MAU·등급별 분포·신규 가입 추이',
          onTap: () => _openLegacyAdmin(context),
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
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '스와치',
          icon: Icons.grid_view_rounded,
          accent: C.lv,
          description: '스와치 신고 처리·기준 스와치 관리',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '프로젝트',
          icon: Icons.assignment_rounded,
          accent: C.pk,
          description: '프로젝트 통계·이상 데이터 점검',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '마켓',
          icon: Icons.storefront_rounded,
          accent: C.lmD,
          description: '마켓 상품 검수·정산·일괄등록',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '백과',
          icon: Icons.school_rounded,
          accent: C.lv,
          description: '백과 항목 검수·일괄등록',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '게시판',
          icon: Icons.forum_rounded,
          accent: kAdminMobileAccent,
          description: '커뮤니티·랜딩 보드(리뷰/릴리즈/Q&A) 관리',
          onTap: () => _openLegacyAdmin(context),
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
      subtitle: '버그·문의·팝업·문구·에디토리얼',
      children: [
        _AdminCard(
          label: '119 버그리포트',
          icon: Icons.bug_report_rounded,
          accent: C.og,
          description: '미해결 버그 우선 처리',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '1:1 문의',
          icon: Icons.mail_rounded,
          accent: kAdminMobileAccent,
          description: '미응답 문의 답변',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '팝업 설정',
          icon: Icons.campaign_rounded,
          accent: C.lv,
          description: '홈/공지/이벤트 팝업 노출 설정',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '문구 관리',
          icon: Icons.text_snippet_rounded,
          accent: C.lmD,
          description: '앱 내 안내 문구·UI 카피 변경',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '에디토리얼',
          icon: Icons.article_rounded,
          accent: C.pk,
          description: '홈 에디토리얼 보드(뜨개소식/모리채널)',
          onTap: () => _openLegacyAdmin(context),
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
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '#687 마이그레이션',
          icon: Icons.sync_alt_rounded,
          accent: C.lv,
          description: 'Blueprint 마이그레이션 도구',
          onTap: () => _openLegacyAdmin(context),
        ),
        _AdminCard(
          label: '설정',
          icon: Icons.settings_rounded,
          accent: C.lmD,
          description: '구독·정책·앱 설정',
          onTap: () => _openLegacyAdmin(context),
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
