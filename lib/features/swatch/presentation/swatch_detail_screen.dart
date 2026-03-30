import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/swatch_provider.dart';
import '../domain/swatch_model.dart';
import 'swatch_input_screen.dart';

class SwatchDetailScreen extends ConsumerWidget {
  final String swatchId;

  const SwatchDetailScreen({super.key, required this.swatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final swatchAsync = ref.watch(swatchByIdProvider(swatchId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t.swatchDetails, style: T.h3),
        actions: [
          swatchAsync.whenOrNull(
                data: (swatch) => swatch == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: C.lv),
                            onPressed: () => _navigateToEdit(context, swatch),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: C.og),
                            onPressed: () => _confirmDelete(context, ref, swatch),
                          ),
                        ],
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: swatchAsync.when(
        data: (swatch) {
          if (swatch == null) {
            return Center(child: Text(t.swatchNotFound, style: T.body.copyWith(color: C.mu)));
          }
          return _SwatchDetailBody(swatch: swatch);
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (error, _) => Center(
          child: Text(t.failedToLoadSwatch(error.toString()), style: T.body.copyWith(color: C.og)),
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, SwatchModel swatch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SwatchInputScreen(swatchId: swatch.id, initialSwatch: swatch),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SwatchModel swatch) {
    final t = ref.read(appStringsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.deleteSwatch, style: T.h3),
        content: Text(t.deleteSwatchConfirm, style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(swatchRepositoryProvider).deleteSwatch(swatch.id);
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.failedToDeleteSwatch(error.toString())),
                    backgroundColor: C.og,
                  ),
                );
              }
            },
            child: Text(t.deleteSwatch),
          ),
        ],
      ),
    );
  }
}

class _SwatchDetailBody extends ConsumerWidget {
  final SwatchModel swatch;

  const _SwatchDetailBody({required this.swatch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);

    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            MoriBrandHeader(subtitle: t.swatchDetailSubtitle),
            const SizedBox(height: 16),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoHeader(photoUrl: swatch.beforePhotoUrl),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (swatch.isDirty) ...[
                          _SyncPendingBadge(label: t.pendingSync),
                          const SizedBox(height: 12),
                        ],
                        if (swatch.yarnName.isNotEmpty) ...[
                          Text(swatch.yarnName, style: T.h2),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          t.stitchesRows(swatch.beforeStitchCount, swatch.beforeRowCount),
                          style: T.h2.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          swatch.yarnBrandName.isEmpty ? t.yarnBrandNotSet : swatch.yarnBrandName,
                          style: T.body.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GaugeCard(swatch: swatch),
            const SizedBox(height: 12),
            if (swatch.needleSize > 0 || swatch.needleBrandName.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.circle_outlined,
                title: t.needleInfo,
                rows: [
                  if (swatch.needleSize > 0) _InfoRowData(t.size, swatch.needleSizeDisplay),
                  if (swatch.needleBrandName.isNotEmpty) _InfoRowData(t.brand, swatch.needleBrandName),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (swatch.yarnBrandName.isNotEmpty || swatch.yarnWeight.isNotEmpty || swatch.yarnColor.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.texture,
                title: t.yarnInfo,
                rows: [
                  if (swatch.yarnBrandName.isNotEmpty) _InfoRowData(t.brand, swatch.yarnBrandName),
                  if (swatch.yarnWeight.isNotEmpty) _InfoRowData(t.weight, swatch.yarnWeight),
                  if (swatch.yarnColor.isNotEmpty) _InfoRowData(t.color, swatch.yarnColor),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (swatch.memo.isNotEmpty) ...[
              _MemoCard(title: t.memo, memo: swatch.memo),
              const SizedBox(height: 12),
            ],
            if (swatch.createdAt != null)
              Text(
                t.savedOn(_formatDate(swatch.createdAt!)),
                style: T.caption.copyWith(color: C.mu),
              ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _PhotoHeader extends StatelessWidget {
  final String photoUrl;

  const _PhotoHeader({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(18)),
        child: Center(child: Icon(Icons.texture, color: C.lv, size: 48)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Image.network(photoUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _SyncPendingBadge extends StatelessWidget {
  final String label;

  const _SyncPendingBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.og.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 12, color: C.og),
          const SizedBox(width: 4),
          Text(label, style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GaugeCard extends ConsumerWidget {
  final SwatchModel swatch;

  const _GaugeCard({required this.swatch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.gaugeResult, style: T.captionBold.copyWith(color: C.mu)),
          const SizedBox(height: 12),
          _GaugeRow(label: t.beforeAfterLabel(true), stitchCount: swatch.beforeStitchCount, rowCount: swatch.beforeRowCount, color: C.lv),
          if (swatch.hasAfterWash) ...[
            const SizedBox(height: 10),
            _GaugeRow(label: t.beforeAfterLabel(false), stitchCount: swatch.afterStitchCount, rowCount: swatch.afterRowCount, color: C.pk),
            const SizedBox(height: 12),
            MoriChip(label: t.shrinkageLabel(swatch.shrinkageRate), type: ChipType.lime),
          ],
        ],
      ),
    );
  }
}

class _GaugeRow extends ConsumerWidget {
  final String label;
  final int stitchCount;
  final int rowCount;
  final Color color;

  const _GaugeRow({
    required this.label,
    required this.stitchCount,
    required this.rowCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 52, child: Text(label, style: T.caption.copyWith(color: C.mu))),
        Expanded(
          child: Text(
            t.gauge10cm(stitchCount, rowCount),
            style: T.bodyBold.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_InfoRowData> rows;

  const _InfoCard({required this.icon, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: C.mu),
              const SizedBox(width: 6),
              Text(title, style: T.captionBold.copyWith(color: C.mu)),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 70, child: Text(row.label, style: T.caption)),
                  Expanded(child: Text(row.value, style: T.body)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  final String title;
  final String memo;

  const _MemoCard({required this.title, required this.memo});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.captionBold.copyWith(color: C.mu)),
          const SizedBox(height: 8),
          Text(memo, style: T.body),
        ],
      ),
    );
  }
}
