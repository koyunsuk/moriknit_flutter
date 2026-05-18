// lib/features/seller/presentation/seller_knit_along_screen.dart
//
// 이슈 #816 Phase 2 — 모바일셀러 앱 함께뜨기 통계 화면.
// 본인 도안에 대해 진행 중인 함께뜨기 그룹 + 참여자 카운트.
//
// 데이터 소스:
//   - 본인 도안: myAuthoredBlueprintsProvider (blueprint_provider.dart)
//   - 도안별 참여자: knitAlongParticipantsProvider(family: originId)
//
// 현 화면은 본인 도안 목록 + forkCount 기반 요약. 상세 참여자 진행률은
// KnitAlongGroupScreen(#791) 재사용으로 진입.
//
// CLAUDE.md 토큰 의무: C / T / MoriBlockShell / AsyncDataView / 플레이스홀더 원칙.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/blueprint_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../../knit_along/presentation/knit_along_group_screen.dart';

class SellerKnitAlongScreen extends ConsumerWidget {
  const SellerKnitAlongScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPatternsAsync = ref.watch(myAuthoredBlueprintsProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                MoriBlockShell(
                  label: '함께뜨기 그룹',
                  icon: Icons.group_rounded,
                  accent: C.lvD,
                  child: AsyncDataView<List<StepBlueprint>>(
                    async: myPatternsAsync,
                    isEmpty: (list) =>
                        list.where((p) => p.forkCount > 0).isEmpty,
                    emptyBuilder: () => const EmptyBlockPlaceholder(
                      message:
                          '아직 함께뜨기 참여자가 없어요.\n도안을 발행하고 fork 가 발생하면 여기에 표시돼요.',
                      rows: 3,
                      rowHeight: 60,
                    ),
                    builder: (list) {
                      final active =
                          list.where((p) => p.forkCount > 0).toList();
                      return Column(
                        children: [
                          for (final p in active) ...[
                            _KnitAlongRow(pattern: p),
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

class _KnitAlongRow extends StatelessWidget {
  final StepBlueprint pattern;
  const _KnitAlongRow({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // 기존 #791 화면 재사용 — 참여자 목록·진행률.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                KnitAlongGroupScreen(originBlueprintId: pattern.id),
          ),
        );
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: C.lvD.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.people_rounded, color: C.lvD, size: 20),
            ),
            const SizedBox(width: 12),
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
                    '참여자 ${pattern.forkCount}명',
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
}
