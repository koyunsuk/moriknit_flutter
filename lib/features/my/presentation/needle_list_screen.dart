import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/needle_provider.dart';
import '../domain/needle_model.dart';
import 'needle_detail_screen.dart';
import 'needle_input_screen.dart';

class NeedleListScreen extends ConsumerWidget {
  const NeedleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needlesAsync = ref.watch(needleListProvider);
    final t = ref.watch(appStringsProvider);
    final needles = needlesAsync.valueOrNull ?? const <NeedleModel>[];
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    final straightCount = needles.where((n) => n.type == 'straight').length;
    final circularCount = needles.where((n) => n.type == 'circular').length;
    final dpnCount = needles.where((n) => n.type == 'dpn').length;
    final cableCount = needles.where((n) => n.type == 'cable').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.lv,
        onPressed: () => _showNeedleStartSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.needles,
                subtitle: t.manageNeedles,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  // 1단: 통계
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NeedleStatCell(
                            label: isKorean ? '보유 바늘' : 'Total',
                            value: '${needles.length}',
                            color: C.lvD,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NeedleStatCell(
                            label: isKorean ? '일반' : 'Straight',
                            value: '$straightCount',
                            color: C.lv,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NeedleStatCell(
                            label: isKorean ? '줄바늘' : 'Circular',
                            value: '$circularCount',
                            color: C.pk,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NeedleStatCell(
                            label: isKorean ? '기타' : 'Other',
                            value: '${dpnCount + cableCount}',
                            color: C.mu,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 2단: 리스트 or 빈상태
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (needlesAsync.isLoading)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: C.lv),
                            ),
                          )
                        else if (needles.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: C.lvL,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.noNeedlesYet,
                                  style: T.bodyBold.copyWith(color: C.lvD),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.noNeedlesDescription,
                                  style: T.caption.copyWith(color: C.lvD, height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _showNeedleStartSheet(context, ref),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(t.addNeedle),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: C.lv,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isKorean ? '내 바늘 목록' : 'My Needles',
                                  style: T.bodyBold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showNeedleStartSheet(context, ref),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: Text(t.addNeedle),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...needles.map(
                            (needle) => _NeedleCard(
                              needle: needle,
                              isKorean: isKorean,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NeedleDetailScreen(needleId: needle.id),
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
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToInput(BuildContext context, {NeedleModel? needle}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NeedleInputScreen(initialNeedle: needle)),
    );
  }

  void _showNeedleStartSheet(BuildContext context, WidgetRef ref) {
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
              child: Row(children: [Text(isKorean ? '바늘 추가' : 'Add needle', style: T.h3)]),
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
                      _navigateToInput(context);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.add_rounded, color: C.tx2)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '새 바늘 추가' : 'Add new needle', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '새 바늘 정보를 직접 입력해요' : 'Enter needle info manually', style: T.caption.copyWith(color: C.mu)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: C.mu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCopyNeedleSheet(context, ref);
                    },
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.copy_rounded, color: C.lv)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isKorean ? '기존 바늘 복사로 시작' : 'Copy existing needle', style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(isKorean ? '기존 바늘을 복사해서 시작해요' : 'Duplicate an existing needle', style: T.caption.copyWith(color: C.mu)),
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

  void _showCopyNeedleSheet(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final needles = ref.read(needleListProvider).valueOrNull ?? [];
    if (needles.isEmpty) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사할 바늘이 없어요.' : 'No needles to copy.');
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isKorean ? '복사할 바늘 선택' : 'Select needle to copy', style: T.h3)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: needles.length,
                itemBuilder: (_, i) {
                  final n = needles[i];
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
                            task: () => ref.read(needleRepositoryProvider).duplicateNeedle(n),
                          );
                          if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
                        } catch (e) {
                          if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.straighten_rounded, color: C.lv, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${n.brandName} ${n.name}'.trim(), style: T.bodyBold),
                            Text('${n.size}mm', style: T.caption.copyWith(color: C.mu)),
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

class _NeedleCard extends StatelessWidget {
  final NeedleModel needle;
  final bool isKorean;
  final VoidCallback onTap;

  const _NeedleCard({
    required this.needle,
    required this.isKorean,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: C.glassCard,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(14),
                image: needle.photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(needle.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: needle.photoUrl.isNotEmpty
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          needle.sizeDisplay.replaceAll('mm', ''),
                          style: TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: C.lv,
                          ),
                        ),
                        Text('mm', style: T.caption.copyWith(color: C.mu, fontSize: 9)),
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(needle.localizedTypeLabel(isKorean), style: T.bodyBold),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          needle.localizedMaterialLabel(isKorean),
                          style: TextStyle(fontSize: 11, color: C.pkD),
                        ),
                      ),
                    ],
                  ),
                  if (needle.brandName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(needle.brandName, style: T.caption.copyWith(color: C.mu)),
                  ],
                  if (needle.quantity > 1) ...[
                    const SizedBox(height: 2),
                    Text('${needle.quantity}', style: T.caption.copyWith(color: C.mu)),
                  ],
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

class _NeedleStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NeedleStatCell({required this.label, required this.value, required this.color});

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
