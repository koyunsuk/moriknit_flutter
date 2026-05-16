import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import 'swatch_detail_screen.dart';
import 'swatch_input_screen.dart';
import 'widgets/swatch_list_sections.dart';

enum _SwatchSort { recent, oldest, needleSize }

class SwatchListScreen extends ConsumerStatefulWidget {
  const SwatchListScreen({super.key});

  @override
  ConsumerState<SwatchListScreen> createState() => _SwatchListScreenState();
}

class _SwatchListScreenState extends ConsumerState<SwatchListScreen> {
  _SwatchSort _sortMode = _SwatchSort.recent;

  List _sorted(List swatches) {
    final list = [...swatches];
    switch (_sortMode) {
      case _SwatchSort.recent:
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case _SwatchSort.oldest:
        list.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      case _SwatchSort.needleSize:
        list.sort((a, b) => a.needleSize.compareTo(b.needleSize));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchListAsync = ref.watch(swatchListProvider);
    final projectListAsync = ref.watch(projectListProvider);
    final isLimitReached = ref.watch(swatchLimitReachedProvider);
    final progress = ref.watch(swatchLimitProgressProvider);
    final gates = ref.watch(featureGatesProvider);
    final count = ref.watch(swatchCountProvider);

    return AppShellScaffold(
      title: t.swatches,
      subtitle: t.swatchLibrary,
      trailing: [
        // 이슈 #723 — 스와치 그룹 진입점
        IconButton(
          tooltip: isKorean ? '스와치 그룹' : 'Swatch groups',
          icon: Icon(Icons.folder_rounded, color: C.lvD),
          onPressed: () => context.push(Routes.swatchGroups),
        ),
      ],
      body: swatchListAsync.when(
                loading: () => AsyncLoadingFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(swatchListProvider),
                ),
                error: (e, _) => AsyncDelayedFriendly(
                  isKorean: isKorean,
                  onRetry: () => ref.invalidate(swatchListProvider),
                ),
                data: (swatches) {
                  if (swatches.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: C.lmD.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.grid_view_rounded, color: C.lmD, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isKorean ? '아직 스와치가 없어요.' : 'No swatches yet.',
                              style: T.bodyBold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isKorean
                                  ? '게이지를 기록하면 나중에 같은 실을 쓸 때 참고할 수 있어요.'
                                  : 'Record your gauge to reference later.',
                              style: T.caption.copyWith(color: C.mu),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: isLimitReached ? null : () => _showSwatchStartSheet(context),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(isKorean ? '스와치 추가' : 'Add swatch'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sorted = _sorted(swatches);
                  final projects = projectListAsync.valueOrNull ?? [];
                  bool isSwatchDone(s) {
                    if (s.hasAfterWash) return true;
                    if (s.projectId.isNotEmpty) {
                      final proj = projects.where((p) => p.id == s.projectId).firstOrNull;
                      if (proj != null && proj.status == 'finished') return true;
                    }
                    return false;
                  }
                  final done = swatches.where(isSwatchDone).length;
                  final unset = swatches.where((s) => !isSwatchDone(s) && s.beforeStitchCount == 0).length;
                  final sortLabels = isKorean
                      ? ['최근순', '오래된순', '바늘크기순']
                      : ['Recent', 'Oldest', 'Needle size'];
                  final selectedIndex = _SwatchSort.values.indexOf(_sortMode);
                  final linkedProjects = projectListAsync.valueOrNull ?? [];
                  return Stack(
                    children: [
                      const BgOrbs(),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        children: [
                          // 요약카드
                          SummaryCard_Detail(
                            headers: [
                              isKorean ? '전체' : 'Total',
                              isKorean ? '완료' : 'Done',
                              isKorean ? '미지정' : 'Free',
                            ],
                            rows: [
                              LibrarySummaryRowData(
                                badge: 'MoriKnit',
                                badgeColor: C.pkD,
                                values: ['${swatches.length}', '$done', '$unset'],
                                valueColors: [C.tx, C.lmD, C.mu],
                              ),
                            ],
                            addLabel: isKorean ? '추가' : 'Add',
                            onAdd: isLimitReached
                                ? () => _showLimitDialog(isKorean)
                                : () => _showSwatchStartSheet(context),
                          ),
                          const SizedBox(height: 8),
                          if (gates.isFree) ...[
                            GlassCard(
                              child: SwatchLimitBar(
                                current: count,
                                max: 5,
                                progress: progress,
                                isReached: isLimitReached,
                                onUpgrade: () {},
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // 블록 안에 카드 목록 포함
                          MoriBlockShell(
                            label: isKorean ? '스와치 목록' : 'Swatches',
                            icon: Icons.texture,
                            accent: C.lv,
                            moreLabel: sortLabels[selectedIndex],
                            onMoreTap: () => _showSortMenu(context, sortLabels, selectedIndex),
                            child: Column(
                              children: [
                                // 헤더 카운트 배지
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: C.pkD.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('${swatches.length}',
                                          style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w700)),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                for (int i = 0; i < sorted.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  _NumberedItem(
                                    number: i + 1,
                                    child: SwatchCard(
                                      swatch: sorted[i],
                                      projectName: linkedProjects
                                          .where((p) => p.id == sorted[i].projectId)
                                          .firstOrNull
                                          ?.title,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SwatchDetailScreen(swatchId: sorted[i].id),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
    );
  }

  void _showSwatchStartSheet(BuildContext context) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        maxChildSize: 0.6,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [Text(isKorean ? '스와치 추가' : 'Add swatch', style: T.h3)]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SwatchInputScreen()));
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '새 스와치 만들기' : 'Create new swatch', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '처음부터 직접 게이지를 기록해요' : 'Record gauge from scratch', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopySwatchSheet(context);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.lmD)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 스와치 복사로 시작' : 'Copy existing swatch', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 스와치를 복사해서 시작해요' : 'Duplicate an existing swatch', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCopySwatchSheet(BuildContext context) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final swatches = ref.read(swatchListProvider).valueOrNull ?? [];
    if (swatches.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 스와치가 없어요.' : 'No swatches to copy.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 스와치 선택' : 'Select swatch to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: swatches.length,
                itemBuilder: (_, i) {
                  final s = swatches[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await runWithMoriLoadingDialog<void>(
                            context,
                            message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                            task: () async {
                              await ref.read(swatchRepositoryProvider).duplicateSwatch(s);
                            },
                          );
                          if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
                        } catch (e) {
                          if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lmD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.grid_view_rounded, color: C.lmD, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.swatchName, style: T.bodyBold),
                            if (s.yarnBrandName.isNotEmpty || s.yarnName.isNotEmpty)
                              Text('${s.yarnBrandName} ${s.yarnName}'.trim(), style: T.caption.copyWith(color: C.mu)),
                          ])),
                          Icon(Icons.copy_rounded, color: C.mu, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context, List<String> sortLabels, int selectedIndex) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ...sortLabels.asMap().entries.map(
                  (e) => ListTile(
                    leading: Icon(
                      Icons.sort_rounded,
                      color: e.key == selectedIndex ? C.lv : C.mu,
                    ),
                    title: Text(
                      e.value,
                      style: T.body.copyWith(
                        color: e.key == selectedIndex ? C.lv : C.tx,
                        fontWeight:
                            e.key == selectedIndex ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, e.key),
                  ),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _sortMode = _SwatchSort.values[result]);
  }

  void _showLimitDialog(bool isKorean) {
    final gates = ref.read(featureGatesProvider);
    final count = ref.read(swatchCountProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '스와치 한도 도달' : 'Swatch limit reached', style: T.h3),
        content: Text(gates.swatchLimitMessage(count), style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '닫기' : 'Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.lm, foregroundColor: const Color(0xFF1a3000)),
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '업그레이드' : 'Upgrade'),
          ),
        ],
      ),
    );
  }
}

// ── 번호 표시 래퍼 ──────────────────────────────────────────────────
class _NumberedItem extends StatelessWidget {
  final int number;
  final Widget child;

  const _NumberedItem({required this.number, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: C.bd2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$number',
              style: TextStyle(fontSize: 10, color: C.mu, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
