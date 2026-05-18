// 이슈 — 랜딩 CMS: CmsAwareWrapper.
//
// 기존 랜딩 위젯을 fallback으로 받고, Firestore에 published 페이지가 있으면 CMS 렌더로 덮어씀.
// CMS 데이터 없거나 published 아니거나 알 수 없는 섹션만 있으면 → fallback 그대로 노출 (안전망).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/landing_cms_repository.dart';
import '../domain/landing_page.dart';
import 'cms_section_renderer.dart';

class CmsAwareWrapper extends ConsumerWidget {
  /// Firestore 문서 ID (예: 'home', 'pricing').
  final String pageId;

  /// CMS 데이터 없을 때 노출할 기존 위젯.
  final Widget fallback;

  /// true면 draft 도 렌더 (어드민 미리보기). 기본 false (published만).
  final bool allowDraft;

  const CmsAwareWrapper({
    super.key,
    required this.pageId,
    required this.fallback,
    this.allowDraft = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(landingCmsPageProvider(pageId));
    return async.when(
      // 첫 로드 중에는 기존 위젯을 그대로 표시 (FOUC 방지).
      loading: () => fallback,
      error: (_, _) => fallback,
      data: (page) {
        if (page == null) return fallback;
        if (!allowDraft && page.status != PublishStatus.published) {
          return fallback;
        }
        if (page.sections.isEmpty) return fallback;
        return CmsSectionRenderer(page: page, fallback: fallback);
      },
    );
  }
}
