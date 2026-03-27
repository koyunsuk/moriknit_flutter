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
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchAsync = ref.watch(swatchByIdProvider(swatchId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '스와치 상세' : 'Swatch Details', style: T.h3),
        actions: [
          swatchAsync.whenOrNull(
                data: (swatch) => swatch == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: C.lv),
                            onPressed: () => _navigateToEdit(context, swatch),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: C.og),
                            onPressed: () => _confirmDelete(context, ref, swatch, isKorean),
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
            return Center(child: Text(isKorean ? '스와치를 찾을 수 없어요.' : 'Swatch not found.', style: T.body.copyWith(color: C.mu)));
          }
          return _SwatchDetailBody(swatch: swatch, isKorean: isKorean);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
        error: (error, _) => Center(
          child: Text(isKorean ? '스와치를 불러오지 못했어요: $error' : 'Failed to load swatch: $error', style: T.body.copyWith(color: C.og)),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, SwatchModel swatch, bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKorean ? '스와치 삭제' : 'Delete swatch', style: T.h3),
        content: Text(
          isKorean ? '이 스와치를 삭제할까요? 삭제한 뒤에는 되돌릴 수 없어요.' : 'Delete this swatch? This action cannot be undone.',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(isKorean ? '취소' : 'Cancel')),
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
                    content: Text(isKorean ? '삭제에 실패했어요: $error' : 'Failed to delete swatch: $error'),
                    backgroundColor: C.og,
                  ),
                );
              }
            },
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _SwatchDetailBody extends StatelessWidget {
  final SwatchModel swatch;
  final bool isKorean;

  const _SwatchDetailBody({required this.swatch, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            MoriBrandHeader(
              logoSize: 76,
              titleSize: 24,
              subtitle: isKorean ? '게이지와 재료 기록을 나중에도 다시 비교해볼 수 있어요.' : 'Compare your gauge and materials whenever you need them again.',
            ),
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
                          _SyncPendingBadge(isKorean: isKorean),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          isKorean ? '${swatch.beforeStitchCount}코 x ${swatch.beforeRowCount}단' : '${swatch.beforeStitchCount} stitches x ${swatch.beforeRowCount} rows',
                          style: T.h2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          swatch.yarnBrandName.isEmpty
                              ? (isKorean ? '실 브랜드 미설정' : 'Yarn brand not set')
                              : swatch.yarnBrandName,
                          style: T.body.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GaugeCard(swatch: swatch, isKorean: isKorean),
            const SizedBox(height: 12),
            if (swatch.needleSize > 0 || swatch.needleBrandName.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.circle_outlined,
                title: isKorean ? '바늘 정보' : 'Needle',
                rows: [
                  if (swatch.needleSize > 0) _InfoRowData(isKorean ? '사이즈' : 'Size', swatch.needleSizeDisplay),
                  if (swatch.needleBrandName.isNotEmpty) _InfoRowData(isKorean ? '브랜드' : 'Brand', swatch.needleBrandName),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (swatch.yarnBrandName.isNotEmpty || swatch.yarnWeight.isNotEmpty || swatch.yarnColor.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.texture,
                title: isKorean ? '실 정보' : 'Yarn',
                rows: [
                  if (swatch.yarnBrandName.isNotEmpty) _InfoRowData(isKorean ? '브랜드' : 'Brand', swatch.yarnBrandName),
                  if (swatch.yarnWeight.isNotEmpty) _InfoRowData(isKorean ? '굵기' : 'Weight', swatch.yarnWeight),
                  if (swatch.yarnColor.isNotEmpty) _InfoRowData(isKorean ? '색상' : 'Color', swatch.yarnColor),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (swatch.memo.isNotEmpty) ...[
              _MemoCard(title: isKorean ? '메모' : 'Memo', memo: swatch.memo),
              const SizedBox(height: 12),
            ],
            if (swatch.createdAt != null)
              Text(
                isKorean ? '기록일 ${_formatDate(swatch.createdAt!)}' : 'Saved on ${_formatDate(swatch.createdAt!)}',
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
        child: const Center(child: Icon(Icons.texture, color: C.lv, size: 48)),
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
  final bool isKorean;

  const _SyncPendingBadge({required this.isKorean});

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
          const Icon(Icons.sync, size: 12, color: C.og),
          const SizedBox(width: 4),
          Text(isKorean ? '동기화 대기 중' : 'Pending sync', style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final SwatchModel swatch;
  final bool isKorean;

  const _GaugeCard({required this.swatch, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '게이지' : 'Gauge', style: T.captionBold.copyWith(color: C.mu)),
          const SizedBox(height: 12),
          _GaugeRow(
            label: isKorean ? '전' : 'Before',
            stitchCount: swatch.beforeStitchCount,
            rowCount: swatch.beforeRowCount,
            color: C.lv,
            isKorean: isKorean,
          ),
          if (swatch.hasAfterWash) ...[
            const SizedBox(height: 10),
            _GaugeRow(
              label: isKorean ? '후' : 'After',
              stitchCount: swatch.afterStitchCount,
              rowCount: swatch.afterRowCount,
              color: C.pk,
              isKorean: isKorean,
            ),
            const SizedBox(height: 12),
            MoriChip(
              label: isKorean ? '수축률 ${swatch.shrinkageRate.toStringAsFixed(1)}%' : 'Shrinkage ${swatch.shrinkageRate.toStringAsFixed(1)}%',
              type: ChipType.lime,
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugeRow extends StatelessWidget {
  final String label;
  final int stitchCount;
  final int rowCount;
  final Color color;
  final bool isKorean;

  const _GaugeRow({
    required this.label,
    required this.stitchCount,
    required this.rowCount,
    required this.color,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 52, child: Text(label, style: T.caption.copyWith(color: C.mu))),
        Expanded(
          child: Text(
            isKorean ? '$stitchCount코 / $rowCount단 (10cm)' : '$stitchCount stitches / $rowCount rows (10cm)',
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
