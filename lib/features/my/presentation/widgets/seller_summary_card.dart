// 이슈 #816 Phase 2 — 유저 마이페이지의 셀러 요약 카드
//
// 노출 조건:
//   - isSellerProvider == true 인 사용자에게만 노출 (Pro/Business 등급)
//   - 비-셀러는 SizedBox.shrink() — 가드용이므로 플레이스홀더 원칙 예외.
//
// 메트릭:
//   - 미응답 테스터 피드백 / 신규 주문 / 진행 중 함께뜨기
//   - loading/error 시에도 플레이스홀더(빈 행 3개) 노출 — 카드 자체는 숨기지 않음.
//
// "셀러 앱 열기" 버튼:
//   - 모바일: deep link `moriknitseller://` 시도 → 실패 시 설치 안내 다이얼로그
//   - 웹: 동일 deep link 시도 → 실패 시 설치 안내 다이얼로그
//     (별도 셀러 웹 도메인이 없는 상태이므로 안내로 통일)
//
// 토큰: C / T / MoriBlockShell / FilledButton 만 사용 (CLAUDE.md 강제 규칙).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../seller/data/is_seller_provider.dart';
import '../../../seller/data/seller_metrics_provider.dart';

// ── 도메인 상수 ──────────────────────────────────────────────────────────────
const _sellerDeepLink = 'moriknitseller://';
const Color _sellerAccent = Color(0xFF7CB342); // 라임 (셀러 컬러)

// ── 메인 위젯 ────────────────────────────────────────────────────────────────

class SellerSummaryCard extends ConsumerWidget {
  const SellerSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSeller = ref.watch(isSellerProvider);
    if (!isSeller) return const SizedBox.shrink();

    final metricsAsync = ref.watch(sellerMetricsProvider);

    return MoriBlockShell(
      label: '셀러 활동',
      icon: Icons.storefront_rounded,
      accent: _sellerAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          metricsAsync.when(
            loading: () => const _MetricsSkeleton(),
            error: (_, _) => const _MetricsSkeleton(),
            data: (m) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricRow(
                  icon: Icons.chat_bubble_outline,
                  label: '미응답 피드백',
                  value: m.pendingFeedbacks,
                  accent: C.lv,
                ),
                const SizedBox(height: 8),
                _MetricRow(
                  icon: Icons.shopping_bag_outlined,
                  label: '신규 주문',
                  value: m.newOrders,
                  accent: C.pk,
                ),
                const SizedBox(height: 8),
                _MetricRow(
                  icon: Icons.group_outlined,
                  label: '진행 중 함께뜨기',
                  value: m.activeKnitAlongs,
                  accent: _sellerAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openSellerApp(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('셀러 앱 열기'),
              style: FilledButton.styleFrom(
                backgroundColor: _sellerAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSellerApp(BuildContext context) async {
    final uri = Uri.parse(_sellerDeepLink);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      _showInstallGuide(context);
    }
  }

  void _showInstallGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모리니트 셀러 앱'),
        content: const Text(
          '상세 셀러 기능은 별도 셀러 앱에서 사용 가능합니다.\n'
          '앱 설치 후 다시 시도해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

// ── 내부 위젯 ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted = value > 0;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
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
            '$value건',
            style: T.bodyBold.copyWith(
              color: isHighlighted ? accent : C.tx,
            ),
          ),
        ),
      ],
    );
  }
}

/// 로딩/에러 공통 스켈레톤 (빈 행 3개) — 카드 자체를 숨기지 않기 위한 플레이스홀더.
class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

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
