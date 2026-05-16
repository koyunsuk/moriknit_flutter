import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/yarn_provider.dart';
import '../../ravelry/data/ravelry_auth_provider.dart';
import '../../ravelry/data/ravelry_repository.dart';
import '../../ravelry/domain/ravelry_models.dart';
import 'yarn_detail_screen.dart';
import 'yarn_input_screen.dart';

class YarnListScreen extends ConsumerStatefulWidget {
  const YarnListScreen({super.key});

  @override
  ConsumerState<YarnListScreen> createState() => _YarnListScreenState();
}

class _YarnListScreenState extends ConsumerState<YarnListScreen> {
  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final yarnListAsync = ref.watch(yarnListProvider);
    final count = ref.watch(yarnCountProvider);

    return AppShellScaffold(
      title: isKorean ? '나의 실 라이브러리' : 'My Yarn Library',
      subtitle: isKorean ? '보유 중인 실을 기록하세요' : 'Track your yarn stash',
      body: Column(
              children: [
                // 요약카드 틀고정
                Consumer(
                  builder: (ctx, ref2, _) {
                    final stashAsync = ref2.watch(ravelryStashProvider);
                    final ravelryCount = stashAsync.maybeWhen(data: (s) => '${s.length}', orElse: () => '-');
                    final yarnCount = yarnListAsync.maybeWhen(data: (y) => '${y.length}', orElse: () => '$count');
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: SummaryCard_Detail(
                        headers: ['MoriKnit', 'Ravelry'],
                        rows: [
                          LibrarySummaryRowData(
                            badge: isKorean ? '나의 실' : 'My Yarn',
                            badgeColor: C.pkD,
                            values: [yarnCount, ravelryCount],
                            valueColors: [C.pkD, C.lv],
                          ),
                        ],
                        addLabel: isKorean ? '추가' : 'Add',
                        onAdd: () => _showYarnStartSheet(context),
                      ),
                    );
                  },
                ),
                // 스크롤 바디
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      // 모리니트 실 목록
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Text('MoriKnit', style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Text(isKorean ? '🧵 나의 실' : '🧵 My Yarns', style: T.bodyBold),
                              ],
                            ),
                            const SizedBox(height: 12),
                            yarnListAsync.when(
                          loading: () => AsyncLoadingFriendly(
                            isKorean: isKorean,
                            onRetry: () => ref.invalidate(yarnListProvider),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          ),
                          error: (e, _) => AsyncDelayedFriendly(
                            isKorean: isKorean,
                            onRetry: () => ref.invalidate(yarnListProvider),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          ),
                          data: (yarns) {
                            if (yarns.isEmpty) {
                              return MoriEmptyState(
                                icon: Icons.layers_rounded,
                                iconColor: C.lmD,
                                title: isKorean ? '아직 실이 없어요' : 'No yarns yet',
                                subtitle: isKorean
                                    ? '보유 중인 실을 추가해서 나만의 실 라이브러리를 만들어 보세요.'
                                    : 'Add your yarns to build your personal yarn library.',
                                buttonLabel: isKorean ? '실 추가' : 'Add yarn',
                                onAction: () => _showYarnStartSheet(context),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...yarns.map(
                                  (yarn) => _YarnCard(
                                    brandName: yarn.brandName,
                                    name: yarn.name,
                                    color: yarn.color,
                                    weight: yarn.weight,
                                    amountGrams: yarn.amountGrams,
                                    photoUrl: yarn.photoUrl,
                                    // 이슈 #644 — Ravelry 연결 배지
                                    ravelryLinked: yarn.ravelryStashId != null,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => YarnDetailScreen(yarnId: yarn.id),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Ravelry 스태시 섹션
                      _RavelryStashSection(isKorean: isKorean),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _navigateToInput() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const YarnInputScreen()));
  }

  void _showYarnStartSheet(BuildContext context) {
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
              child: Row(children: [Text(isKorean ? '실 추가' : 'Add yarn', style: T.h3)]),
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
                      _navigateToInput();
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '새 실 추가' : 'Add new yarn', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '새 실 정보를 직접 입력해요' : 'Enter yarn info manually', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopyYarnSheet(context);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.pkD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.pkD)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 실 복사로 시작' : 'Copy existing yarn', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 실을 복사해서 시작해요' : 'Duplicate an existing yarn', style: T.caption.copyWith(color: C.mu)),
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

  void _showCopyYarnSheet(BuildContext context) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final yarns = ref.read(yarnListProvider).valueOrNull ?? [];
    if (yarns.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 실이 없어요.' : 'No yarns to copy.');
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 실 선택' : 'Select yarn to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: yarns.length,
                itemBuilder: (_, i) {
                  final y = yarns[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () {
                        // 이슈 #698 — 즉시 duplicate 호출 금지. 입력화면 진입 + prefill.
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => YarnInputScreen(copyFrom: y)),
                        );
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.pkD.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.water_drop_rounded, color: C.pkD, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${y.brandName} ${y.name}'.trim(), style: T.bodyBold),
                            if (y.color.isNotEmpty) Text(y.color, style: T.caption.copyWith(color: C.mu)),
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

}

// ── Ravelry 스태시 섹션 ──────────────────────────────────
class _RavelryStashSection extends ConsumerWidget {
  final bool isKorean;
  const _RavelryStashSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(ravelryAuthProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('Ravelry', style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(isKorean ? '📦 나의 스태시' : '📦 My Stash', style: T.bodyBold),
            ],
          ),
          const SizedBox(height: 12),
          if (!auth.isLoggedIn)
            _RavelryConnectBanner(isKorean: isKorean)
          else
            _RavelryStashList(isKorean: isKorean),
        ],
      ),
    );
  }
}

class _RavelryStashList extends ConsumerWidget {
  final bool isKorean;
  const _RavelryStashList({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashAsync = ref.watch(ravelryStashProvider);
    return stashAsync.when(
      loading: () => AsyncLoadingFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(ravelryStashProvider),
        padding: const EdgeInsets.all(16),
        compact: true,
      ),
      error: (e, _) => AsyncDelayedFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(ravelryStashProvider),
        padding: const EdgeInsets.all(16),
        compact: true,
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Text(isKorean ? 'Ravelry 스태시가 비어있어요.' : 'Your Ravelry stash is empty.',
              style: T.body.copyWith(color: C.mu));
        }
        return Column(
          children: entries.map((e) => _RavelryStashCard(entry: e, isKorean: isKorean)).toList(),
        );
      },
    );
  }
}

class _RavelryStashCard extends StatelessWidget {
  final RavelryStashEntry entry;
  final bool isKorean;
  const _RavelryStashCard({required this.entry, required this.isKorean});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: C.lmG,
                      borderRadius: BorderRadius.circular(12),
                      image: entry.thumbnailUrl != null
                          ? DecorationImage(image: NetworkImage(entry.thumbnailUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: entry.thumbnailUrl == null
                        ? Icon(Icons.layers_rounded, color: C.lmD, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name, style: T.h3),
                        if (entry.brandName != null)
                          Text(entry.brandName!, style: T.caption.copyWith(color: C.mu)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (entry.colorName != null)
                _StashDetailRow(label: isKorean ? '색상' : 'Color', value: entry.colorName!),
              if (entry.weightName != null)
                _StashDetailRow(label: isKorean ? '굵기' : 'Weight', value: entry.weightName!),
              if (entry.gramsTotal != null)
                _StashDetailRow(label: isKorean ? '총 무게' : 'Total weight', value: '${entry.gramsTotal!.toStringAsFixed(0)}g'),
              if (entry.yardsTotal != null)
                _StashDetailRow(label: isKorean ? '총 야드' : 'Total yards', value: '${entry.yardsTotal!.toStringAsFixed(0)} yds'),
              if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(isKorean ? '메모' : 'Notes', style: T.caption.copyWith(color: C.mu)),
                const SizedBox(height: 4),
                Text(entry.notes!, style: T.body),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bd)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: C.lmG, borderRadius: BorderRadius.circular(10),
                image: entry.thumbnailUrl != null
                    ? DecorationImage(image: NetworkImage(entry.thumbnailUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: entry.thumbnailUrl == null ? Icon(Icons.layers_rounded, color: C.lmD, size: 22) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: T.bodyBold, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (entry.brandName != null) ...[
                      Text(entry.brandName!, style: T.caption.copyWith(color: C.mu)),
                      const SizedBox(width: 6),
                    ],
                    if (entry.colorName != null) ...[
                      Text(entry.colorName!, style: T.caption.copyWith(color: C.mu)),
                      const SizedBox(width: 6),
                    ],
                    if (entry.weightName != null)
                      Text(entry.weightName!, style: T.caption.copyWith(color: C.lmD)),
                  ]),
                  if (entry.gramsTotal != null || entry.yardsTotal != null)
                    Row(children: [
                      if (entry.gramsTotal != null)
                        Text('${entry.gramsTotal!.toStringAsFixed(0)}g', style: T.caption.copyWith(color: C.mu)),
                      if (entry.gramsTotal != null && entry.yardsTotal != null)
                        Text('  ·  ', style: T.caption.copyWith(color: C.mu)),
                      if (entry.yardsTotal != null)
                        Text('${entry.yardsTotal!.toStringAsFixed(0)}yds', style: T.caption.copyWith(color: C.mu)),
                    ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RavelryConnectBanner extends StatelessWidget {
  final bool isKorean;
  const _RavelryConnectBanner({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: C.lv, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            isKorean ? 'Ravelry 연결 시 스태시가 표시돼요' : 'Connect Ravelry to see your stash',
            style: T.caption.copyWith(color: C.mu),
          )),
        ],
      ),
    );
  }
}

// ── 통계 셀 ──────────────────────────────────────────────
// ignore: unused_element
class _YarnStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _YarnStatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 4),
          Text(value, style: T.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── 실 카드 ──────────────────────────────────────────────
class _YarnCard extends StatelessWidget {
  final String brandName;
  final String name;
  final String color;
  final String weight;
  final int amountGrams;
  final String photoUrl;
  final VoidCallback onTap;
  // 이슈 #644 — Ravelry 연결 여부 배지
  final bool ravelryLinked;

  const _YarnCard({
    required this.brandName,
    required this.name,
    required this.color,
    required this.weight,
    required this.amountGrams,
    required this.onTap,
    this.photoUrl = '',
    this.ravelryLinked = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = [brandName, name].where((s) => s.isNotEmpty).join(' · ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.lmG,
                borderRadius: BorderRadius.circular(10),
                image: photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl.isEmpty
                  ? Icon(Icons.layers_rounded, color: C.lmD, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty ? '이름 없음' : displayName,
                          style: T.bodyBold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ravelryLinked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.lv.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ravelry',
                            style: T.caption.copyWith(
                              color: C.lvD,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (color.isNotEmpty) ...[
                        Text(color, style: T.caption.copyWith(color: C.mu)),
                        const SizedBox(width: 6),
                      ],
                      if (weight.isNotEmpty) ...[
                        Text(weight, style: T.caption.copyWith(color: C.mu)),
                        const SizedBox(width: 6),
                      ],
                      if (amountGrams > 0)
                        Text('${amountGrams}g', style: T.caption.copyWith(color: C.lmD)),
                    ],
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

// ── 스태시 상세 행 ─────────────────────────────────────────
class _StashDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _StashDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const Spacer(),
          Text(value, style: T.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
