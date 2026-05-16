// lib/core/widgets/offline_image_placeholder.dart
//
// #704 Phase 2 — 오프라인 이미지 플레이스홀더.
// 깨진 이미지 X 표시 대신 모리니트 라벤더 톤 + 도안 아이콘 + 우하단 와이파이 끊김 배지.
// "종이 도안 대체성" 컨셉을 해치지 않는 거부감 최소화 UI.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OfflineImagePlaceholder extends StatelessWidget {
  const OfflineImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.icon = Icons.menu_book_rounded,
    this.iconSize = 32,
    this.showOfflineBadge = true,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData icon;
  final double iconSize;
  final bool showOfflineBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              color: C.lv.withValues(alpha: 0.6),
              size: iconSize,
            ),
          ),
          if (showOfflineBadge)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: C.og.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.signal_wifi_off_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
