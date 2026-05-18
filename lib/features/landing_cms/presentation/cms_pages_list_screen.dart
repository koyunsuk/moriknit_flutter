// 이슈 — 랜딩 CMS: 페이지 목록 (어드민 진입점).
//
// AdminListShell 사용 (어드민 콘솔 통일 UI).
// 페이지 행 클릭 시 CmsPageEditorScreen 로 이동.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/presentation/widgets/admin_list_shell.dart';
import '../data/landing_cms_repository.dart';
import '../domain/landing_page.dart';
import 'cms_page_editor_screen.dart';

class CmsPagesListScreen extends ConsumerStatefulWidget {
  const CmsPagesListScreen({super.key});

  @override
  ConsumerState<CmsPagesListScreen> createState() => _CmsPagesListScreenState();
}

class _CmsPagesListScreenState extends ConsumerState<CmsPagesListScreen> {
  String? _openPageId;
  String? _openPageTitle;

  @override
  Widget build(BuildContext context) {
    if (_openPageId != null) {
      return CmsPageEditorScreen(
        pageId: _openPageId!,
        pageTitle: _openPageTitle ?? _openPageId!,
        onBack: () => setState(() {
          _openPageId = null;
          _openPageTitle = null;
        }),
      );
    }

    final pagesAsync = ref.watch(landingCmsPageListProvider);

    return pagesAsync.when(
      loading: () => _shell(items: const [], isLoading: true),
      error: (e, _) => _shell(items: const [], errorMessage: e.toString()),
      data: (firestorePages) {
        // 카탈로그(기본 페이지)와 Firestore에 저장된 페이지를 머지.
        final byId = <String, LandingPage>{};
        for (final entry in LandingPageCatalog.defaults) {
          byId[entry.id] = LandingPage.empty(entry.id, title: entry.label);
        }
        for (final p in firestorePages) {
          byId[p.id] = p;
        }
        final items = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
        return _shell(items: items);
      },
    );
  }

  Widget _shell({
    required List<LandingPage> items,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return AdminListShell<LandingPage>(
      title: '랜딩 페이지',
      icon: Icons.web_rounded,
      countFormat: '페이지 전체 ({n})',
      isLoading: isLoading,
      errorMessage: errorMessage,
      columns: const [
        AdminColumn(label: 'ID', flex: 2),
        AdminColumn(label: '제목', flex: 3),
        AdminColumn(label: '상태', flex: 1),
        AdminColumn(label: '섹션', flex: 1),
        AdminColumn(label: '업데이트', flex: 2),
      ],
      items: items,
      emptyMessage: '랜딩 페이지 데이터가 없습니다.',
      rowBuilder: (context, page) {
        final published = page.status == PublishStatus.published;
        return AdminRow(
          accent: published
              ? const Color(0xFF22C55E)
              : const Color(0xFFFBBF24),
          onTap: () => setState(() {
            _openPageId = page.id;
            _openPageTitle = page.title;
          }),
          cells: [
            AdminCellText(page.id, bold: true),
            AdminCellText(page.title),
            AdminBadge(
              label: published ? '발행' : '초안',
              color: published
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFFBBF24),
            ),
            AdminCellText('${page.sections.length}'),
            AdminCellText(
              page.updatedAt == null ? '-' : _fmt(page.updatedAt!),
              muted: true,
            ),
          ],
        );
      },
    );
  }

  String _fmt(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}
