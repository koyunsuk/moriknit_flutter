// lib/features/knit_along/presentation/knit_along_group_screen.dart
//
// 이슈 #791 — 함께 뜨기(Knit-Along) 그룹 화면.
// 같은 원본 도안을 fork 한 사용자들의 사본 목록 + 각자 진행률 표시.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/step_run_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';

class KnitAlongGroupScreen extends ConsumerWidget {
  final String originBlueprintId;

  const KnitAlongGroupScreen({super.key, required this.originBlueprintId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final originAsync = ref.watch(blueprintByIdProvider(originBlueprintId));
    final participantsAsync =
        ref.watch(knitAlongParticipantsProvider(originBlueprintId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          isKorean ? '함께 뜨기' : 'Knit-Along',
          style: T.h3,
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AsyncDataView<StepBlueprint?>(
                    async: originAsync,
                    builder: (origin) => origin == null
                        ? _OriginUnavailable(isKorean: isKorean)
                        : _OriginCard(origin: origin, isKorean: isKorean),
                  ),
                  const SizedBox(height: 16),
                  MoriBlockShell(
                    label: isKorean ? '참여 중인 니터' : 'Participants',
                    icon: Icons.people_rounded,
                    accent: C.lvD,
                    child: AsyncDataView<List<StepBlueprint>>(
                      async: participantsAsync,
                      isEmpty: (list) => list.isEmpty,
                      emptyBuilder: () =>
                          _ParticipantsEmptyState(isKorean: isKorean),
                      builder: (list) => _ParticipantsList(
                        participants: list,
                        isKorean: isKorean,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  final StepBlueprint origin;
  final bool isKorean;

  const _OriginCard({required this.origin, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: isKorean ? '원본 도안' : 'Origin Pattern',
      icon: Icons.menu_book_rounded,
      accent: C.lv,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(origin.localizedTitle(isKorean), style: T.bodyBold),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.call_split_rounded, size: 14, color: C.lvD),
              const SizedBox(width: 4),
              Text(
                isKorean
                    ? '${origin.forkCount}명이 함께 뜨고 있어요'
                    : '${origin.forkCount} knitters joined',
                style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (origin.description != null && origin.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(origin.description!,
                style: T.caption.copyWith(color: C.mu, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _OriginUnavailable extends StatelessWidget {
  final bool isKorean;
  const _OriginUnavailable({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: isKorean ? '원본 도안' : 'Origin Pattern',
      icon: Icons.menu_book_rounded,
      accent: C.lv,
      child: Text(
        isKorean
            ? '원본 도안을 불러올 수 없어요.'
            : 'Could not load origin pattern.',
        style: T.body.copyWith(color: C.mu),
      ),
    );
  }
}

class _ParticipantsList extends StatelessWidget {
  final List<StepBlueprint> participants;
  final bool isKorean;

  const _ParticipantsList({
    required this.participants,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in participants) ...[
          _ParticipantRow(participant: p, isKorean: isKorean),
          if (p != participants.last) const Divider(height: 14, thickness: 0.5),
        ],
      ],
    );
  }
}

class _ParticipantRow extends ConsumerWidget {
  final StepBlueprint participant;
  final bool isKorean;

  const _ParticipantRow({required this.participant, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stepBlueprintRepositoryProvider);
    final runsAsync = ref.watch(stepRunsByBlueprintProvider(participant.id));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final isMine = participant.ownerUid == currentUid;

    return FutureBuilder<Map<String, String>?>(
      future: repo.getUserProfile(participant.ownerUid),
      builder: (context, snap) {
        final profile = snap.data;
        final displayName =
            (profile?['displayName'] ?? '').toString();
        final fallback = displayName.isNotEmpty
            ? displayName
            : participant.ownerUid.substring(
                0,
                participant.ownerUid.length.clamp(0, 6),
              );
        // 진행률은 첫 번째 run의 summary.percentComplete 로 표시.
        final runs = runsAsync.valueOrNull ?? const [];
        final pct =
            runs.isEmpty ? 0.0 : runs.first.summary.percentComplete;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: C.lvL,
                child: Icon(Icons.person_rounded, size: 18, color: C.lvD),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fallback,
                            style: T.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.og.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isKorean ? '나' : 'You',
                              style: T.caption.copyWith(
                                color: C.og,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: C.bd,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(C.lvD),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: T.caption.copyWith(
                            color: C.lvD,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticipantsEmptyState extends StatelessWidget {
  final bool isKorean;
  const _ParticipantsEmptyState({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: C.bd.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: C.bd,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          isKorean
              ? '아직 함께 뜨고 있는 사람이 없어요.\n첫 참여자가 되어 보세요!'
              : 'No one has joined yet.\nBe the first knitter!',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
      ],
    );
  }
}
