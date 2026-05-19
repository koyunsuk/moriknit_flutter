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
import '../../blueprint/presentation/tester_group_screen.dart';
import 'seller_dashboard_screen.dart' show openSellerPlaceholder;

/// Phase 2 폴리시:
///   - SellerDashboardScreen 컨테이너 안에서 호출되므로 자체 Scaffold/BgOrbs/SafeArea 제거.
///   - 빈 상태: "도안 등록하기" 큰 버튼 + 안내 placeholder.
class SellerPatternManagementScreen extends ConsumerWidget {
  const SellerPatternManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(myBlueprintsWithLegacyProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _NewPatternCard(onTap: () => _openNewPattern(context)),
        const SizedBox(height: 16),
        MoriBlockShell(
          label: '나의 도안',
          icon: Icons.grid_on_rounded,
          accent: C.lv,
          child: AsyncDataView<List<StepBlueprint>>(
            async: patternsAsync,
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: () => _MyPatternsEmptyPlaceholder(
              onCreate: () => _openNewPattern(context),
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
    );
  }

  /// 도안 등록 — 셀러 앱 라우트 미등록 → 와이어프레임 페이지 진입.
  void _openNewPattern(BuildContext context) {
    openSellerPlaceholder(
      context,
      title: '신규 도안 등록',
      subtitle: 'Pro 셀러 본인 도안 등록·검수·발행',
      icon: Icons.add_circle_outline_rounded,
      features: [
        '도안 파일 업로드 (PDF / 이미지 / JSON)',
        'AI 자동 변환 (PDF → 차트 + 서술형)',
        '도안 메타 입력 (제목 / 카테고리 / 게이지 / 실 / 바늘)',
        '미리보기 + 단계별 섹션 분할',
        '가격 책정 (무료 / 유료)',
        '검수 대기 큐로 제출',
        '본인 테스터 모집 연동',
      ],
      note: 'Pro 셀러 핵심 워크플로우. 검수 통과 시 마켓 출시.',
    );
  }
}

/// 빈 상태 placeholder — "도안 등록하기" 큰 버튼 + 안내.
/// CLAUDE.md 플레이스홀더 원칙: 빈 행 + 안내 문구로 공간 고정.
class _MyPatternsEmptyPlaceholder extends StatelessWidget {
  final VoidCallback onCreate;
  const _MyPatternsEmptyPlaceholder({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyBlockPlaceholder(
          message: '아직 등록한 도안이 없어요.\n첫 도안을 등록하고 마켓에 발행해 보세요.',
          rows: 3,
          rowHeight: 60,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text(
              '도안 등록하기',
              style: T.bodyBold.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lm,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
            // #792 후속 — 셀러앱 진입점. 도안 작성자(셀러)가 본인 도안의 테스터 그룹을 직접 관리.
            IconButton(
              tooltip: '테스터 그룹 관리',
              icon: Icon(Icons.group_rounded, color: C.lvD, size: 20),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TesterGroupScreen(blueprintId: pattern.id),
                  ),
                );
              },
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
