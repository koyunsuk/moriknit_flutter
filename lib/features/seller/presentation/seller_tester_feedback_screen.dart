// lib/features/seller/presentation/seller_tester_feedback_screen.dart
//
// 이슈 #816 Phase 2 — 모바일셀러 앱 통합 테스터 피드백 화면.
// 본인이 발행한 모든 도안의 tester_feedback 통합 조회.
//
// 데이터 소스:
//   - 본인 도안: myAuthoredBlueprintsProvider (blueprint_provider.dart)
//   - 각 도안의 피드백: testerFeedbackByBlueprintProvider (tester_feedback_repository)
//   - 통합 placeholder provider: sellerAllFeedbacksProvider (본 파일에 정의, 에이전트 C가 정식 신설)
//
// CLAUDE.md 토큰 의무: C / T / MoriBlockShell / AsyncDataView / 플레이스홀더 원칙.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../tester_feedback/domain/tester_feedback.dart';

/// 통합 피드백 항목 — 도안 메타 + 피드백 본문.
///
/// 에이전트 C 가 정식 모델 신설 시 본 클래스 대체 가능 (인터페이스 호환 유지).
class SellerFeedbackEntry {
  final String blueprintId;
  final String blueprintTitle;
  final TesterFeedback feedback;

  const SellerFeedbackEntry({
    required this.blueprintId,
    required this.blueprintTitle,
    required this.feedback,
  });
}

/// Placeholder provider — 에이전트 C가 정식 구현 예정.
///
/// 현재는 빈 리스트 반환 (UI 플레이스홀더 노출). 정식 구현 시:
///   1) myAuthoredBlueprintsProvider 로 본인 도안 수집
///   2) 각 blueprintId 의 tester_feedback subcollection 합산
///   3) updatedAt 내림차순 정렬 후 노출
final sellerAllFeedbacksProvider =
    StreamProvider<List<SellerFeedbackEntry>>((ref) {
  // TODO(agent-c, #816): 본인 도안 전체 피드백 통합 stream 구현.
  return Stream.value(const <SellerFeedbackEntry>[]);
});

class SellerTesterFeedbackScreen extends ConsumerWidget {
  const SellerTesterFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUserProvider).valueOrNull?.uid;
    if (currentUid == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: Text('로그인이 필요해요.', style: T.body.copyWith(color: C.mu)),
        ),
      );
    }

    final feedbacksAsync = ref.watch(sellerAllFeedbacksProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: AsyncDataView<List<SellerFeedbackEntry>>(
              async: feedbacksAsync,
              isEmpty: (list) => list.isEmpty,
              emptyBuilder: () => const _SellerFeedbackEmptyPlaceholder(),
              builder: (entries) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _SellerFeedbackCard(entry: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 통합 피드백 카드 — 도안 이름 + 테스터 + 본문 + 해결 토글(우측).
///
/// 해결 토글 동작은 에이전트 C가 sellerAllFeedbacksProvider 정식 구현 시 연결.
class _SellerFeedbackCard extends StatelessWidget {
  final SellerFeedbackEntry entry;
  const _SellerFeedbackCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final f = entry.feedback;
    return MoriBlockShell(
      label: entry.blueprintTitle,
      icon: _categoryIcon(f.category),
      accent: f.resolved ? C.mu : C.lvD,
      trailing: Icon(
        f.resolved
            ? Icons.check_circle_rounded
            : Icons.check_circle_outline_rounded,
        color: f.resolved ? C.lvD : C.mu,
        size: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.authorName, style: T.captionBold.copyWith(color: C.tx)),
              const SizedBox(width: 6),
              Text(
                f.category.label(true),
                style: T.caption.copyWith(color: C.lvD),
              ),
              const Spacer(),
              Text(
                '${f.createdAt.month}.${f.createdAt.day}',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(f.content, style: T.body.copyWith(height: 1.5)),
          if (f.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '응답 ${f.replies.length}건',
                style: T.caption.copyWith(color: C.tx2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(TesterFeedbackCategory c) {
    switch (c) {
      case TesterFeedbackCategory.bug:
        return Icons.bug_report_rounded;
      case TesterFeedbackCategory.unclear:
        return Icons.help_outline_rounded;
      case TesterFeedbackCategory.missing:
        return Icons.warning_amber_rounded;
      case TesterFeedbackCategory.suggestion:
        return Icons.lightbulb_outline_rounded;
      case TesterFeedbackCategory.other:
        return Icons.chat_bubble_outline_rounded;
    }
  }
}

/// 플레이스홀더 — 데이터 없어도 빈 카드 3개 + 안내 (CLAUDE.md 플레이스홀더 원칙).
class _SellerFeedbackEmptyPlaceholder extends StatelessWidget {
  const _SellerFeedbackEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const EmptyBlockPlaceholder(
          message: '아직 받은 피드백이 없어요.\n테스터가 본인 도안에 피드백을 남기면 여기에 표시돼요.',
          rows: 3,
          rowHeight: 60,
        ),
      ],
    );
  }
}
