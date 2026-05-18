// 이슈 #815 — 메인앱 어드민 알림 카드 (E안)
//
// 마이페이지 등 메인앱 화면에서 어드민 계정에만 노출되는 알림 위젯.
// - 미응답 버그리포트 / 미응답 1:1문의 / 7일 신규가입 카운트 표시
// - "전체 어드민 열기" 버튼:
//     · 모바일: deep link `moriknitadmin://` 시도 → 실패 시 https://admin.moriknit.com
//     · 웹: 새 탭으로 https://admin.moriknit.com
//
// 게이트:
//   - isAdminProvider (Custom Claims) == true 일 때만 노출
//   - 위 조건 미충족 시 SizedBox.shrink() — 가드용이므로 플레이스홀더 원칙 예외
//
// 토큰: C / T / MoriBlockShell / FilledButton 만 사용 (CLAUDE.md 강제 규칙).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../providers/auth_provider.dart';

// ── 도메인 상수 ──────────────────────────────────────────────────────────────
const _adminWebUrl = 'https://admin.moriknit.com';
const _adminDeepLink = 'moriknitadmin://';

// ── 알림 데이터 모델 ─────────────────────────────────────────────────────────
class AdminAlertCounts {
  final int pendingBugReports;
  final int pendingInquiries;
  final int newSignups7d;

  const AdminAlertCounts({
    required this.pendingBugReports,
    required this.pendingInquiries,
    required this.newSignups7d,
  });

  int get total => pendingBugReports + pendingInquiries + newSignups7d;
}

// ── Providers (어드민 카운트 집계) ───────────────────────────────────────────

/// 미응답 버그리포트 수 — `bug_reports` 컬렉션에서 `isResolved != true` 항목.
/// (현재 스키마상 status='new'/'pending' 등 명시 필드가 없어 isResolved 기준)
final _pendingBugReportsCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bug_reports')
      .where('isResolved', isEqualTo: false)
      .snapshots()
      .map((s) => s.size);
});

/// 미응답 1:1 문의 수 — `landing_boards/qa/posts` 에서 답글이 0인 항목 추정.
/// 정확한 'unanswered' 플래그가 도입되기 전까지는 최근 100건 중 답글 미보유 카운트로 근사.
final _pendingInquiriesCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('landing_boards')
      .doc('qa')
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) {
    return s.docs.where((d) {
      final data = d.data();
      final replyCount = (data['replyCount'] as num?)?.toInt() ?? 0;
      final answered = data['answered'] == true || data['isAnswered'] == true;
      return !answered && replyCount == 0;
    }).length;
  });
});

/// 7일 내 신규 가입자 수 — users.createdAt 기반.
final _recentSignupsCountProvider = StreamProvider<int>((ref) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  return FirebaseFirestore.instance
      .collection('users')
      .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
      .snapshots()
      .map((s) => s.size);
});

/// 3개 카운트를 묶어 단일 모델로 노출.
final adminAlertCountsProvider = Provider<AsyncValue<AdminAlertCounts>>((ref) {
  final bugs = ref.watch(_pendingBugReportsCountProvider);
  final inquiries = ref.watch(_pendingInquiriesCountProvider);
  final signups = ref.watch(_recentSignupsCountProvider);

  if (bugs.isLoading || inquiries.isLoading || signups.isLoading) {
    return const AsyncValue.loading();
  }
  if (bugs.hasError) return AsyncValue.error(bugs.error!, StackTrace.current);
  if (inquiries.hasError) {
    return AsyncValue.error(inquiries.error!, StackTrace.current);
  }
  if (signups.hasError) {
    return AsyncValue.error(signups.error!, StackTrace.current);
  }

  return AsyncValue.data(AdminAlertCounts(
    pendingBugReports: bugs.value ?? 0,
    pendingInquiries: inquiries.value ?? 0,
    newSignups7d: signups.value ?? 0,
  ));
});

// ── 메인 위젯 ────────────────────────────────────────────────────────────────

class AdminAlertCard extends ConsumerWidget {
  const AdminAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.valueOrNull ?? false;
    if (!isAdmin) return const SizedBox.shrink();

    final countsAsync = ref.watch(adminAlertCountsProvider);

    return MoriBlockShell(
      label: '어드민 알림',
      icon: Icons.admin_panel_settings_rounded,
      accent: C.og,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          countsAsync.when(
            loading: () => const _AdminAlertSkeleton(),
            error: (_, _) => Text(
              '알림 카운트를 불러오지 못했습니다.',
              style: T.caption.copyWith(color: C.og),
            ),
            data: (counts) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AlertRow(
                  emoji: '🔔',
                  label: '미응답 버그리포트',
                  count: counts.pendingBugReports,
                  accent: C.og,
                ),
                const SizedBox(height: 8),
                _AlertRow(
                  emoji: '📩',
                  label: '미응답 1:1 문의',
                  count: counts.pendingInquiries,
                  accent: C.lvD,
                ),
                const SizedBox(height: 8),
                _AlertRow(
                  emoji: '👤',
                  label: '신규 가입 (7일)',
                  count: counts.newSignups7d,
                  accent: C.lmD,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAdmin,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('전체 어드민 열기'),
              style: FilledButton.styleFrom(
                backgroundColor: C.og,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 모바일: deep link 시도 → 실패 시 웹.
  /// 웹: 새 탭으로 웹 어드민.
  Future<void> _openAdmin() async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(_adminWebUrl), webOnlyWindowName: '_blank');
      return;
    }
    final deepLink = Uri.parse(_adminDeepLink);
    try {
      final launched = await launchUrl(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // canLaunchUrl 미지원/실패 시 무시하고 웹 폴백.
    }
    await launchUrl(
      Uri.parse(_adminWebUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

// ── 내부 위젯 ────────────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color accent;

  const _AlertRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted = count > 0;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: T.body)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHighlighted
                ? accent.withValues(alpha: 0.15)
                : C.tx.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count건',
            style: T.bodyBold.copyWith(
              color: isHighlighted ? accent : C.tx,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminAlertSkeleton extends StatelessWidget {
  const _AdminAlertSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == 2 ? 0 : 8),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: C.tx.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: C.tx.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 18,
                decoration: BoxDecoration(
                  color: C.tx.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
