// lib/features/pattern/presentation/widgets/chart_shape_picker.dart
//
// 이슈 #665 — 도안 형태 선택 모달 (사각/원형).
// 도안 라이브러리 + 도구함 양쪽에서 공통 사용.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

/// 도안 형태 선택 모달.
/// 결과: 'rect' / 'roundFull' / null(취소).
Future<String?> showChartShapePicker(BuildContext context, bool isKorean) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(isKorean ? '도안 형태 선택' : 'Chart Shape', style: T.h3),
          const SizedBox(height: 14),
          GlassCard(
            onTap: () => Navigator.pop(ctx, 'rect'),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: C.lvD.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.grid_on_rounded, color: C.lvD),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '사각 그리드' : 'Rect Grid', style: T.bodyBold),
                    const SizedBox(height: 4),
                    Text(
                      isKorean
                          ? '행/열 그리드 (대바늘/코바늘 심볼 모두 사용 가능)'
                          : 'Row/column grid (knit & crochet symbols both)',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.mu),
            ]),
          ),
          const SizedBox(height: 10),
          GlassCard(
            onTap: () => Navigator.pop(ctx, 'roundFull'),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.radio_button_unchecked_rounded, color: C.pk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '원형 도안' : 'Round Chart', style: T.bodyBold),
                    const SizedBox(height: 4),
                    Text(
                      isKorean
                          ? '라운드별 코수 자동 + 스냅 (대바늘/코바늘 심볼 모두 사용 가능)'
                          : 'Auto stitch count per round + snap (knit & crochet symbols both)',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.mu),
            ]),
          ),
          const SizedBox(height: 10),
          // 이슈 #668 — 자유 Path 도안 (왕관/꽃잎/Granny 등 비정형 코바늘 모티프).
          GlassCard(
            onTap: () => Navigator.pop(ctx, 'guidePath'),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: C.lv.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.timeline_rounded, color: C.lv),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean
                          ? '자유 path (코바늘 왕관/모티프)'
                          : 'Free Path (Crown/Motif)',
                      style: T.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isKorean
                          ? 'Pen Tool로 자유롭게 그리기 + 셀 자동 스냅'
                          : 'Free-draw path + auto-snap cells',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.mu),
            ]),
          ),
        ],
      ),
    ),
  );
}
