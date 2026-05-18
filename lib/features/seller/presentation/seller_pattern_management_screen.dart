// lib/features/seller/presentation/seller_pattern_management_screen.dart
//
// 이슈 #816 Phase 2 — 모바일셀러 앱 도안 관리 화면.
// 본인이 작성한 도안 목록 (draft + complete) + 신규 등록 진입.
//
// 데이터 소스:
//   - 본인 도안: myBlueprintsWithLegacyProvider (blueprint_provider.dart)
//     (step_blueprints + legacy pattern_charts 어댑터 통합)
//   - 신규 등록: GoRouter '/pattern/new' (또는 셀러 앱 라우트에 맞게 연결)
//   - publish: PatternPublishScreen (#793/#809) — complete 도안만
//
// 상태별 액션:
//   - draft : "수정/완성"
//   - complete : "마켓 발행/가격 변경"
//
// CLAUDE.md 토큰 의무: C / T / MoriBlockShell / AsyncDataView / 플레이스홀더 원칙.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/blueprint_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';

class SellerPatternManagementScreen extends ConsumerWidget {
  const SellerPatternManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(myBlueprintsWithLegacyProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _NewPatternCard(
                  onTap: () {
                    // GoRouter 라우트 정의 시 '/pattern/new' 로 연결.
                    // 셀러 앱 라우트 미정 시 placeholder snackbar.
                    final router = GoRouter.maybeOf(context);
                    if (router != null) {
                      try {
                        context.push('/pattern/new');
                        return;
                      } catch (_) {
                        // 라우트 미등록 시 fallback.
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '도안 등록 라우트 등록 예정',
                          style: T.body.copyWith(color: Colors.white),
                        ),
                        backgroundColor: C.lvD,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                MoriBlockShell(
                  label: '나의 도안',
                  icon: Icons.grid_on_rounded,
                  accent: C.lv,
                  child: AsyncDataView<List<StepBlueprint>>(
                    async: patternsAsync,
                    isEmpty: (list) => list.isEmpty,
                    emptyBuilder: () => const EmptyBlockPlaceholder(
                      message: '아직 등록한 도안이 없어요.\n위 "새 도안 등록"으로 첫 도안을 만들어보세요.',
                      rows: 3,
                      rowHeight: 60,
                    ),
                    builder: (list) {
                      return Column(
                        children: [
                          for (final p in list) ...[
                            _MyPatternCard(pattern: p),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
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

class _NewPatternCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewPatternCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.lm.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.lm.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.lm.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_circle_outline_rounded,
                  color: C.lmD, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('새 도안 등록', style: T.bodyBold.copyWith(color: C.tx)),
                  const SizedBox(height: 4),
                  Text(
                    '파일 / 클라우드 / 도안에디터 — 3가지 진입점',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: C.mu),
          ],
        ),
      ),
    );
  }
}

class _MyPatternCard extends StatelessWidget {
  final StepBlueprint pattern;
  const _MyPatternCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final isDraft = !_isComplete(pattern);
    final accent = isDraft ? C.og : C.lvD;
    final badgeLabel = isDraft ? '초안' : '완성';

    return InkWell(
      onTap: () {
        // 도안 상세 진입 — 셀러 앱 라우트 미정 시 snackbar fallback.
        try {
          context.push('/pattern/${pattern.id}');
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '도안 상세 라우트 등록 예정: ${pattern.title}',
                style: T.body.copyWith(color: Colors.white),
              ),
              backgroundColor: C.lvD,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeLabel,
                style: T.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern.title,
                    style: T.bodyBold.copyWith(color: C.tx),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDraft ? '수정/완성 진입' : '마켓 발행 · 가격 변경',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }

  /// complete 여부 판단 — groups(섹션 메타) 가 있으면 complete 로 간주.
  /// (정식 status 필드는 #626 에서 도입 예정. 그 전엔 groups 기준 폴백.)
  bool _isComplete(StepBlueprint bp) {
    return bp.groups.isNotEmpty;
  }
}
