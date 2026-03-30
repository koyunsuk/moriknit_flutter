import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/needle_provider.dart';
import '../domain/needle_model.dart';
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
        onPressed: () => _navigateToInput(context),
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
                                      onPressed: () => _navigateToInput(context),
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
                                onPressed: () => _navigateToInput(context),
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
                              onTap: () => _navigateToInput(context, needle: needle),
                              onDelete: () => _confirmDelete(context, ref, needle, t),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, NeedleModel needle, AppStrings t) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete needle', style: T.h3),
        content: Text(
          'Delete ${needle.sizeDisplay} ${needle.localizedMaterialLabel(false)} needle?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(needleRepositoryProvider).deleteNeedle(needle.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _NeedleCard extends StatelessWidget {
  final NeedleModel needle;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NeedleCard({
    required this.needle,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
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
              ),
              child: Column(
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
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline, color: C.mu, size: 18),
            ),
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
