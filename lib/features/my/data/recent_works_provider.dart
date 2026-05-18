// 이슈 #769 후속 — 내 작업실 상단 "최근 작업" 블록 데이터.
//
// 사용자의 프로젝트/스와치/도안에서 이미지가 있는 항목을 모아 랜덤 셔플.
// 각 항목 탭 시 해당 콘텐츠 화면으로 이동.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../pattern/data/pattern_repository.dart';

enum RecentWorkType { project, swatch, pattern }

class RecentWorkItem {
  final RecentWorkType type;
  final String id;
  final String imageUrl;
  final String title;

  const RecentWorkItem({
    required this.type,
    required this.id,
    required this.imageUrl,
    required this.title,
  });

  String get routePath {
    switch (type) {
      case RecentWorkType.project:
        return '/project/$id';
      case RecentWorkType.swatch:
        return '/swatch/$id';
      case RecentWorkType.pattern:
        // #795 후속 — 유니버설 도안 뷰어로 분기 (PDF/차트/서술형 자동 결정)
        return '/pattern-view/$id';
    }
  }

  String typeLabel(bool isKorean) {
    switch (type) {
      case RecentWorkType.project:
        return isKorean ? '프로젝트' : 'Project';
      case RecentWorkType.swatch:
        return isKorean ? '스와치' : 'Swatch';
      case RecentWorkType.pattern:
        return isKorean ? '도안' : 'Pattern';
    }
  }
}

/// 모든 사용자 콘텐츠에서 이미지 있는 항목 추출 + 랜덤 셔플.
final recentWorksProvider = Provider<List<RecentWorkItem>>((ref) {
  final projects = ref.watch(projectListProvider).valueOrNull ?? const [];
  final swatches = ref.watch(swatchListProvider).valueOrNull ?? const [];
  final patterns = ref.watch(patternListProvider).valueOrNull ?? const [];

  final items = <RecentWorkItem>[];

  for (final p in projects) {
    if (p.photoUrls.isNotEmpty) {
      items.add(RecentWorkItem(
        type: RecentWorkType.project,
        id: p.id,
        imageUrl: p.photoUrls.first,
        title: p.title,
      ));
    }
  }
  for (final s in swatches) {
    final photo = s.beforePhotoUrl.isNotEmpty
        ? s.beforePhotoUrl
        : s.afterPhotoUrl;
    if (photo.isNotEmpty) {
      items.add(RecentWorkItem(
        type: RecentWorkType.swatch,
        id: s.id,
        imageUrl: photo,
        title: s.beforeStitchCount > 0
            ? '${s.beforeStitchCount}x${s.beforeRowCount}'
            : '',
      ));
    }
  }
  for (final c in patterns) {
    if (c.imageUrl.isNotEmpty) {
      items.add(RecentWorkItem(
        type: RecentWorkType.pattern,
        id: c.id,
        imageUrl: c.imageUrl,
        title: c.title,
      ));
    }
  }

  items.shuffle(Random());
  return items.take(10).toList();
});
