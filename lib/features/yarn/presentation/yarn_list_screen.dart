import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/yarn_provider.dart';
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

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                // 고정 헤더
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '나의 실 라이브러리' : 'My Yarn Library',
                    subtitle: isKorean ? '보유 중인 실을 기록하세요' : 'Track your yarn stash',
                  ),
                ),
                // 스크롤 바디
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      // 통계 GlassCard
                      GlassCard(
                        child: _YarnStatCell(
                          label: isKorean ? '보유 실' : 'Total yarns',
                          value: yarnListAsync.maybeWhen(
                            data: (y) => '${y.length}',
                            orElse: () => '$count',
                          ),
                          color: C.lmD,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 목록 GlassCard
                      GlassCard(
                        child: yarnListAsync.when(
                          loading: () => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: C.lm),
                            ),
                          ),
                          error: (e, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Failed to load yarns: $e',
                                style: T.body.copyWith(color: C.mu),
                              ),
                            ),
                          ),
                          data: (yarns) {
                            if (yarns.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: C.lmG,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isKorean ? '아직 실이 없어요' : 'No yarns yet',
                                      style: T.bodyBold.copyWith(color: C.lmD),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isKorean
                                          ? '보유 중인 실을 추가해서 나만의 실 라이브러리를 만들어 보세요.'
                                          : 'Add your yarns to build your personal yarn library.',
                                      style: T.caption.copyWith(color: C.lmD, height: 1.5),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _showYarnStartSheet(context),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(isKorean ? '실 추가' : 'Add yarn'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isKorean ? '실 목록' : 'Yarn list',
                                        style: T.bodyBold,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showYarnStartSheet(context),
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                      label: Text(isKorean ? '실 추가' : 'Add yarn'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...yarns.map(
                                  (yarn) => _YarnCard(
                                    brandName: yarn.brandName,
                                    name: yarn.name,
                                    color: yarn.color,
                                    weight: yarn.weight,
                                    amountGrams: yarn.amountGrams,
                                    photoUrl: yarn.photoUrl,
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
                      ),
                    ],
                  ),
                ),
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
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await runWithMoriLoadingDialog<void>(
                            context,
                            message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                            task: () => ref.read(yarnRepositoryProvider).duplicateYarn(y),
                          );
                          if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
                        } catch (e) {
                          if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
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

// ── 통계 셀 ──────────────────────────────────────────────
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

  const _YarnCard({
    required this.brandName,
    required this.name,
    required this.color,
    required this.weight,
    required this.amountGrams,
    required this.onTap,
    this.photoUrl = '',
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
                  Text(
                    displayName.isEmpty ? '이름 없음' : displayName,
                    style: T.bodyBold,
                    overflow: TextOverflow.ellipsis,
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
