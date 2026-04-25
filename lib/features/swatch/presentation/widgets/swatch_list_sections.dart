import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/swatch_model.dart';

class SwatchLimitBar extends StatelessWidget {
  final int current;
  final int max;
  final double progress;
  final bool isReached;
  final VoidCallback onUpgrade;

  const SwatchLimitBar({super.key, required this.current, required this.max, required this.progress, required this.isReached, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isReached ? C.limitBar : BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bd2)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isKorean ? '무료 플랜 스와치 $current / $max' : 'Free plan swatches $current / $max', style: T.caption.copyWith(color: isReached ? C.og : C.mu, fontWeight: FontWeight.w600)),
            if (isReached) Text(isKorean ? '한도 도달' : 'Limit reached', style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, backgroundColor: C.bd2, valueColor: AlwaysStoppedAnimation<Color>(isReached ? C.og : C.lv), minHeight: 5)),
        ])),
        if (isReached) ...[
          const SizedBox(width: 10),
          GestureDetector(onTap: onUpgrade, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: C.lm, borderRadius: BorderRadius.circular(20)), child: Text(isKorean ? '업그레이드' : 'Upgrade', style: T.caption.copyWith(color: const Color(0xFF1a3000), fontWeight: FontWeight.w700)))),
        ],
      ]),
    );
  }
}

class SwatchEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const SwatchEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.grid_view_rounded, color: C.lv, size: 36)),
        const SizedBox(height: 16),
        Text(isKorean ? '첫 스와치를 기록해보세요' : 'Create your first swatch', style: T.h3.copyWith(color: C.tx)),
        const SizedBox(height: 8),
        Text(isKorean ? '게이지와 실, 바늘 정보를 기록해두면 다음 작업이 쉬워져요.' : 'Record gauge details so you can compare them later.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.mu)),
        const SizedBox(height: 24),
        if (onAdd != null)
          ElevatedButton.icon(onPressed: onAdd, icon: Icon(Icons.add), label: Text(isKorean ? '스와치 추가' : 'Add swatch'), style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)))),
      ]),
    );
  }
}

class SwatchCard extends StatelessWidget {
  final SwatchModel swatch;
  final VoidCallback onTap;
  final String? projectName;

  const SwatchCard({
    super.key,
    required this.swatch,
    required this.onTap,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl = swatch.afterPhotoUrl.isNotEmpty
        ? swatch.afterPhotoUrl
        : (swatch.beforePhotoUrl.isNotEmpty ? swatch.beforePhotoUrl : null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bd), boxShadow: C.glowShadow(C.lv)),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
              child: thumbUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.texture, color: C.lv, size: 28),
                      ),
                    )
                  : Icon(Icons.texture, color: C.lv, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (swatch.swatchName.isNotEmpty) ...[
                    Text(swatch.swatchName, style: T.bodyBold.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        swatch.hasAfterWash && swatch.afterStitchCount > 0
                            ? '${swatch.afterStitchCount} x ${swatch.afterRowCount}'
                            : '${swatch.beforeStitchCount} x ${swatch.beforeRowCount}',
                        style: T.bodyBold.copyWith(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        swatch.hasAfterWash && swatch.afterStitchCount > 0
                            ? '세탁후'
                            : '세탁전',
                        style: T.caption.copyWith(
                          fontSize: 10,
                          color: swatch.hasAfterWash && swatch.afterStitchCount > 0
                              ? C.lv
                              : C.mu,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // 실 브랜드 + 이름
                  if (swatch.yarnBrandName.isNotEmpty || swatch.yarnName.isNotEmpty) ...[
                    Text(
                      [swatch.yarnBrandName, swatch.yarnName]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: T.caption.copyWith(color: C.tx2, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (swatch.needleSize > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle_outlined, color: C.lvD, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          [
                            if (swatch.needleBrandName.isNotEmpty) swatch.needleBrandName,
                            swatch.needleSizeDisplay,
                          ].join(' '),
                          style: T.caption.copyWith(color: C.lvD),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu),
          ],
        ),
      ),
    );
  }
}

