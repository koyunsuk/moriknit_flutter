// 이슈 #814 — 어드민 대시보드 지표 카드 공통 위젯.
//
// 사용 패턴:
//   MetricCard(title: 'DAU', value: '128', unit: '명', icon: Icons.people)
//   MetricCard.placeholder(title: 'Hosting', icon: Icons.cloud)
//
// 플레이스홀더 모드 (CLAUDE.md 플레이스홀더 원칙):
// - value 가 null → 회색 "—" + "데이터 수집 중" 안내문
// - 절대 카드 자체를 숨기지 않음. 공간은 항상 고정 표시.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/block_theme.dart';

enum MetricTrend { up, down, flat }

class MetricCard extends StatelessWidget {
  /// 카드 라벨 (예: "DAU", "신규 가입").
  final String title;

  /// 값. null이면 플레이스홀더 모드.
  final String? value;

  /// 단위 (예: "명", "원", "MB"). value 옆에 표시.
  final String? unit;

  /// 아이콘 (좌상단 작은 박스).
  final IconData icon;

  /// 강조 색 (아이콘/뱃지). null이면 C.lv.
  final Color? color;

  /// 보조 설명 (값 아래 작게).
  final String? subtitle;

  /// 추세 (선택). 우상단 작은 칩으로 표시.
  final MetricTrend? trend;
  final String? trendLabel;

  /// 우상단 빨간 카운트 뱃지 (운영 지표용). 0이면 미표시.
  final int? badgeCount;

  /// 클릭 콜백.
  final VoidCallback? onTap;

  /// 플레이스홀더 안내 문구. value 가 null일 때 표시 (기본: '데이터 수집 중').
  final String placeholderMessage;

  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    this.value,
    this.unit,
    this.color,
    this.subtitle,
    this.trend,
    this.trendLabel,
    this.badgeCount,
    this.onTap,
    this.placeholderMessage = '데이터 수집 중',
  });

  /// 데이터가 아직 없을 때 사용.
  const MetricCard.placeholder({
    super.key,
    required this.title,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
    this.placeholderMessage = '데이터 수집 중',
  })  : value = null,
        unit = null,
        trend = null,
        trendLabel = null,
        badgeCount = null;

  bool get _isPlaceholder => value == null;

  @override
  Widget build(BuildContext context) {
    final tokens = BlockTheme.of(context);
    final accent = color ?? C.lv;
    final borderTone = accent.withValues(alpha: tokens.borderAlpha);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.containerRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: C.gx,
            borderRadius: BorderRadius.circular(tokens.containerRadius),
            border: Border.all(color: borderTone, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  icon: icon,
                  accent: accent,
                  title: title,
                  trend: trend,
                  trendLabel: trendLabel,
                  badgeCount: badgeCount,
                ),
                const SizedBox(height: 10),
                _Value(
                  value: value,
                  unit: unit,
                  accent: accent,
                  placeholder: _isPlaceholder,
                ),
                if (subtitle != null || _isPlaceholder) ...[
                  const SizedBox(height: 6),
                  Text(
                    _isPlaceholder ? placeholderMessage : subtitle!,
                    style: T.caption.copyWith(
                      color: _isPlaceholder ? C.mu : C.tx2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final MetricTrend? trend;
  final String? trendLabel;
  final int? badgeCount;

  const _Header({
    required this.icon,
    required this.accent,
    required this.title,
    this.trend,
    this.trendLabel,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BlockTheme.of(context);
    return Row(
      children: [
        Container(
          width: tokens.iconBoxSize,
          height: tokens.iconBoxSize,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: tokens.iconBoxBgAlpha),
            borderRadius: BorderRadius.circular(tokens.iconBoxRadius),
          ),
          child: Icon(icon, color: accent, size: tokens.iconSize),
        ),
        SizedBox(width: tokens.iconLabelGap),
        Expanded(
          child: Text(
            title,
            style: T.captionBold.copyWith(color: C.tx2, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          _Badge(count: badgeCount!, color: C.og)
        else if (trend != null)
          _TrendChip(trend: trend!, label: trendLabel),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  final String? value;
  final String? unit;
  final Color accent;
  final bool placeholder;

  const _Value({
    required this.value,
    required this.unit,
    required this.accent,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (placeholder) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '—',
            style: T.h2.copyWith(
              color: C.mu,
              fontWeight: FontWeight.w400,
              fontSize: 26,
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value!,
            style: T.h2.copyWith(color: C.tx, fontSize: 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (unit != null && unit!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              unit!,
              style: T.caption.copyWith(color: C.tx2),
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      constraints: const BoxConstraints(minWidth: 22),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: T.captionBold.copyWith(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final MetricTrend trend;
  final String? label;
  const _TrendChip({required this.trend, this.label});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trend) {
      MetricTrend.up => (Icons.trending_up_rounded, C.lm),
      MetricTrend.down => (Icons.trending_down_rounded, C.og),
      MetricTrend.flat => (Icons.trending_flat_rounded, C.mu),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              label!,
              style: T.caption.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 그래프 자리용 플레이스홀더 박스. 카드 본문 안에 넣어 사용.
class MetricGraphPlaceholder extends StatelessWidget {
  final double height;
  final String message;
  const MetricGraphPlaceholder({
    super.key,
    this.height = 80,
    this.message = '그래프 데이터 수집 중',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: C.bd.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.bd, width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, size: 16, color: C.mu),
          const SizedBox(width: 6),
          Text(
            message,
            style: T.caption.copyWith(color: C.mu),
          ),
        ],
      ),
    );
  }
}

/// 카드 세트를 감싸는 반응형 그리드. 너비에 맞춰 1~4열 자동 분배.
class MetricGrid extends StatelessWidget {
  final List<Widget> children;

  /// 카드 한 개 최소 너비. 이 값을 기준으로 열 수를 결정.
  final double minCardWidth;
  final double spacing;

  const MetricGrid({
    super.key,
    required this.children,
    this.minCardWidth = 200,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = (available / minCardWidth).floor().clamp(1, 4);
        final cardWidth =
            (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }
}
