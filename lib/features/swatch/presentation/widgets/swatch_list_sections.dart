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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final String? projectName;

  const SwatchCard({
    super.key,
    required this.swatch,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bd), boxShadow: C.glowShadow(C.lv)),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)), child: swatch.beforePhotoUrl.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(swatch.beforePhotoUrl, fit: BoxFit.cover)) : Icon(Icons.texture, color: C.lv, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (swatch.yarnName.isNotEmpty) ...[Text(swatch.yarnName, style: T.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700)), const SizedBox(height: 2)], Text(swatch.gaugeDisplay, style: T.h3.copyWith(fontSize: 16)), const SizedBox(height: 4), if (swatch.needleSize > 0) Text(swatch.needleSizeDisplay, style: T.sm.copyWith(color: C.lvD)), if (swatch.yarnBrandName.isNotEmpty) Text(swatch.yarnBrandName, style: T.caption.copyWith(color: C.mu)), if (projectName != null && projectName!.isNotEmpty) ...[const SizedBox(height: 6), _SwatchProjectBadge(name: projectName!)]])),
          if (swatch.hasAfterWash) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: C.lmG, borderRadius: BorderRadius.circular(20)), child: Text(isKorean ? '세탁 후 ${swatch.shrinkageRate.toStringAsFixed(1)}%' : 'After wash ${swatch.shrinkageRate.toStringAsFixed(1)}%', style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w600))),
          const SizedBox(width: 4),
          if (onEdit != null || onDelete != null || onDuplicate != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 22),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
                if (value == 'duplicate') onDuplicate?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), Text(isKorean ? '수정' : 'Edit')])),
                if (onDuplicate != null)
                  PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lmD), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')])),
                if (onDelete != null)
                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: const TextStyle(color: Colors.red))])),
              ],
            )
          else
            Icon(Icons.chevron_right, color: C.mu),
        ]),
      ),
    );
  }
}

class _SwatchProjectBadge extends StatelessWidget {
  final String name;
  const _SwatchProjectBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: C.lmD.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.lmD.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, color: C.lmD, size: 12),
          const SizedBox(width: 4),
          Text(name, style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
