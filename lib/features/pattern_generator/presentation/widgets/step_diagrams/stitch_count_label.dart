// lib/features/pattern_generator/presentation/widgets/step_diagrams/stitch_count_label.dart
//
// 이슈 #664 Phase 6 — 단계 5: 영역별 콧수 표.
// 앞 / 뒤 / 소매 콧수를 카드 3개로 시각화.

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';

/// 영역별 콧수 라벨 카드.
/// 앞판 / 뒷판(각) / 소매(각) 콧수를 가로 3개 카드로 표시.
class StitchCountLabel extends StatelessWidget {
  /// 앞판 콧수.
  final int frontStitches;

  /// 뒷판 한쪽 콧수.
  final int backStitches;

  /// 소매 한쪽 콧수.
  final int sleeveStitches;

  const StitchCountLabel({
    super.key,
    required this.frontStitches,
    required this.backStitches,
    required this.sleeveStitches,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('영역별 콧수', style: T.bodyBold),
          const SizedBox(height: 8),
          Row(
            children: [
              _StitchCard(label: '앞판', count: frontStitches),
              const SizedBox(width: 8),
              _StitchCard(label: '뒷판', count: backStitches),
              const SizedBox(width: 8),
              _StitchCard(label: '소매(각)', count: sleeveStitches),
            ],
          ),
        ],
      ),
    );
  }
}

class _StitchCard extends StatelessWidget {
  final String label;
  final int count;

  const _StitchCard({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.lv.withValues(alpha: 0.30)),
        ),
        child: Column(
          children: [
            Text(label, style: T.caption),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: T.bodyBold.copyWith(color: C.lvD, fontSize: 18),
            ),
            Text('코', style: T.caption),
          ],
        ),
      ),
    );
  }
}
