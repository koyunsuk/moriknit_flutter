import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/ravelry_repository.dart';
import '../domain/ravelry_models.dart';

/// #658 — Ravelry 스태시 상세 화면.
/// 1) 사용자 stash 정보 (그램/야드/메모) 표시
/// 2) yarnId 있으면 Ravelry yarn DB에서 풀스펙 가져와서 표시
///    - 굵기, 권장 바늘, 게이지(코·단), 섬유 구성, 세탁법, 평점, 사진 등
class RavelryStashDetailScreen extends ConsumerWidget {
  final RavelryStashEntry item;
  final bool isKorean;

  const RavelryStashDetailScreen({
    super.key,
    required this.item,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yarnAsync = item.yarnId != null
        ? ref.watch(_yarnDetailProvider(item.yarnId!))
        : const AsyncValue<RavelryYarnDetail?>.data(null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '스태시 상세' : 'Stash Detail',
                    subtitle: isKorean ? 'Ravelry 스태시 정보' : 'Ravelry stash info',
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(item: item),
                  const SizedBox(height: 20),

                  // ── 1) 사용자 stash 보유 정보 ───────────────────────────
                  SectionTitle(title: isKorean ? '내 보관함 정보' : 'My Stash'),
                  const SizedBox(height: 8),
                  _InfoCard(rows: [
                    _InfoRow(
                      label: isKorean ? '총 그램' : 'Grams',
                      value: item.gramsTotal != null
                          ? '${item.gramsTotal!.toStringAsFixed(0)} g'
                          : '—',
                    ),
                    _InfoRow(
                      label: isKorean ? '총 야드' : 'Yards',
                      value: item.yardsTotal != null
                          ? '${item.yardsTotal!.toStringAsFixed(0)} yd'
                          : '—',
                    ),
                    _InfoRow(
                      label: isKorean ? '색상' : 'Color',
                      value: item.colorName ?? '—',
                    ),
                    if (item.updatedAt != null)
                      _InfoRow(
                        label: isKorean ? '업데이트' : 'Updated',
                        value:
                            '${item.updatedAt!.year}-${item.updatedAt!.month.toString().padLeft(2, '0')}-${item.updatedAt!.day.toString().padLeft(2, '0')}',
                      ),
                  ]),
                  if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SectionTitle(title: isKorean ? '내 메모' : 'My Notes'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.gx,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.bd),
                      ),
                      child: Text(item.notes!,
                          style: T.body.copyWith(color: C.tx, height: 1.5)),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── 2) Ravelry Yarn DB 상세 ─────────────────────────────
                  SectionTitle(
                      title: isKorean ? 'Ravelry 실 정보' : 'Ravelry Yarn Info'),
                  const SizedBox(height: 8),
                  if (item.yarnId == null)
                    _NoYarnIdCard(isKorean: isKorean)
                  else
                    yarnAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => _ErrorCard(
                        message: '$e',
                        isKorean: isKorean,
                        onRetry: () =>
                            ref.invalidate(_yarnDetailProvider(item.yarnId!)),
                      ),
                      data: (yarn) => yarn == null
                          ? _NoYarnIdCard(isKorean: isKorean)
                          : _RavelryYarnCard(yarn: yarn, isKorean: isKorean),
                    ),
                ],
              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final _yarnDetailProvider =
    FutureProvider.family<RavelryYarnDetail, int>((ref, yarnId) {
  final repo = ref.watch(ravelryRepositoryProvider);
  if (repo == null) throw Exception('Ravelry 연결이 필요합니다.');
  return repo.getYarn(yarnId);
});

// ── 헤더 ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final RavelryStashEntry item;
  const _Header({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: item.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                        color: C.lvL,
                        child: Icon(Icons.texture, color: C.lv, size: 48)),
                  )
                : Container(
                    color: C.lvL,
                    child: Icon(Icons.texture, color: C.lv, size: 48)),
          ),
        ),
        const SizedBox(height: 14),
        Text(item.name, style: T.h2),
        if (item.brandName != null) ...[
          const SizedBox(height: 4),
          Text(item.brandName!, style: T.body.copyWith(color: C.mu)),
        ],
        if (item.yarnName != null && item.yarnName != item.name) ...[
          const SizedBox(height: 2),
          Text(item.yarnName!, style: T.caption.copyWith(color: C.mu)),
        ],
      ],
    );
  }
}

// ── Ravelry yarn DB 정보 카드 ────────────────────────────────────────────────
class _RavelryYarnCard extends StatelessWidget {
  final RavelryYarnDetail yarn;
  final bool isKorean;
  const _RavelryYarnCard({required this.yarn, required this.isKorean});

  String _formatGauge(double? st, double? rows, bool ko) {
    final parts = <String>[];
    if (st != null) parts.add(ko ? '${st.toStringAsFixed(1)}코' : '${st.toStringAsFixed(1)} sts');
    if (rows != null) parts.add(ko ? '${rows.toStringAsFixed(1)}단' : '${rows.toStringAsFixed(1)} rows');
    return parts.join(' × ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사진
        if (yarn.photoUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
                  imageUrl: yarn.photoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Container(color: C.lvL, child: Icon(Icons.texture, color: C.lv)),
                ),
              ),
            ),
          ),

        // 평점 + 단종 뱃지
        Row(
          children: [
            if (yarn.ratingAverage != null) ...[
              Icon(Icons.star_rounded, color: C.og, size: 18),
              const SizedBox(width: 4),
              Text(yarn.ratingAverage!.toStringAsFixed(1), style: T.bodyBold),
              const SizedBox(width: 12),
            ],
            if (yarn.discontinued)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: C.og.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isKorean ? '단종' : 'Discontinued',
                  style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        if (yarn.ratingAverage != null || yarn.discontinued)
          const SizedBox(height: 12),

        // 핵심 스펙
        _InfoCard(rows: [
          if (yarn.yarnCompanyName != null)
            _InfoRow(label: isKorean ? '브랜드' : 'Brand', value: yarn.yarnCompanyName!),
          if (yarn.yarnWeight != null)
            _InfoRow(label: isKorean ? '굵기' : 'Weight', value: yarn.yarnWeight!),
          if (yarn.gaugeStitches != null || yarn.gaugeRows != null)
            _InfoRow(
              label: isKorean ? '게이지 (10cm)' : 'Gauge (10cm)',
              value: _formatGauge(yarn.gaugeStitches, yarn.gaugeRows, isKorean),
            ),
          if (yarn.recommendedNeedle != null)
            _InfoRow(
                label: isKorean ? '권장 바늘' : 'Needle',
                value: yarn.recommendedNeedle!),
          if (yarn.fiberContent != null)
            _InfoRow(
                label: isKorean ? '섬유 구성' : 'Fiber',
                value: yarn.fiberContent!),
          if (yarn.grams != null)
            _InfoRow(
                label: isKorean ? '1볼 그램' : 'Per skein g',
                value: '${yarn.grams!.toStringAsFixed(0)} g'),
          if (yarn.yardage != null)
            _InfoRow(
                label: isKorean ? '1볼 야드' : 'Per skein yd',
                value: '${yarn.yardage!.toStringAsFixed(0)} yd'),
          if (yarn.machineWashable != null)
            _InfoRow(
              label: isKorean ? '세탁기' : 'Machine wash',
              value: yarn.machineWashable!
                  ? (isKorean ? '가능' : 'Yes')
                  : (isKorean ? '불가' : 'No'),
            ),
        ]),

        // Ravelry에서 보기
        if (yarn.ravelryUrl != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(isKorean ? 'Ravelry에서 보기' : 'View on Ravelry'),
              onPressed: () => launchUrl(
                Uri.parse(yarn.ravelryUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 공통 카드 ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Column(children: rows),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: T.caption.copyWith(color: C.mu)),
          ),
          Expanded(child: Text(value, style: T.body)),
        ],
      ),
    );
  }
}

class _NoYarnIdCard extends StatelessWidget {
  final bool isKorean;
  const _NoYarnIdCard({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: C.mu, size: 20),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? '이 스태시는 Ravelry yarn DB에 연결돼 있지 않아요.'
                : 'This stash entry is not linked to a Ravelry yarn DB record.',
            style: T.caption.copyWith(color: C.mu, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final bool isKorean;
  final VoidCallback onRetry;
  const _ErrorCard({
    required this.message,
    required this.isKorean,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.og.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: C.og, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isKorean
                      ? 'Ravelry 정보를 불러오지 못했어요'
                      : 'Failed to load Ravelry info',
                  style: T.bodyBold.copyWith(color: C.og),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: T.caption.copyWith(color: C.mu, height: 1.5)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isKorean ? '다시 시도' : 'Retry'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
