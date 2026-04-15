import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/template_provider.dart';
import '../project_input_screen.dart';

/// 새 프로젝트 시작 시트 — 어디서든 호출 가능한 공통 함수
/// FAB, 홈화면 추가 카드, 프로젝트 라이브러리 모두 이 함수 사용
void showProjectStartSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ProjectStartSheetContent(outerContext: context),
  );
}

/// 바텀시트 내부 콘텐츠 — Consumer로 직접 watch하여 템플릿 로드 타이밍 문제 해소
class _ProjectStartSheetContent extends ConsumerWidget {
  final BuildContext outerContext;
  const _ProjectStartSheetContent({required this.outerContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builtinTemplates =
        ref.watch(builtinTemplateListProvider).valueOrNull ?? [];
    final userTemplates =
        ref.watch(userTemplateListProvider).valueOrNull ?? [];
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: C.bd2, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(isKorean ? '새 프로젝트' : 'New Project', style: T.h3),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // ① 빈 프로젝트로 시작
                GlassCard(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      outerContext,
                      MaterialPageRoute(
                          builder: (_) => const ProjectInputScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: C.bd2,
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.add_rounded, color: C.tx2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isKorean
                                  ? '빈 프로젝트로 시작'
                                  : 'Start blank',
                              style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                              isKorean
                                  ? '처음부터 직접 구성해요'
                                  : 'Build from scratch',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ② 프로젝트 복사로 시작
                GlassCard(
                  onTap: () {
                    // ref에서 값을 먼저 읽고 팝 (팝 후 ref 무효화 방지)
                    final projectsSnapshot = ref.read(projectListProvider).valueOrNull ?? [];
                    final korean = isKorean;
                    Navigator.pop(context);
                    _showCopyProjectSheet(outerContext, korean, projectsSnapshot);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.copy_rounded, color: C.lv),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isKorean
                                  ? '프로젝트 복사로 시작'
                                  : 'Copy from existing',
                              style: T.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                              isKorean
                                  ? '기존 프로젝트를 복사해서 시작해요'
                                  : 'Start from a copy',
                              style: T.caption.copyWith(color: C.mu)),
                        ],
                      )),
                      Icon(Icons.chevron_right_rounded, color: C.mu),
                    ],
                  ),
                ),
                // ③ 커스텀 템플릿
                if (userTemplates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      isKorean
                          ? '내 커스텀 템플릿'
                          : 'My Custom Templates',
                      style: T.bodyBold.copyWith(color: C.tx2),
                    ),
                  ),
                  ...userTemplates.map((tpl) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              outerContext,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProjectInputScreen(userTemplate: tpl)),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: C.lvL,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.folder_special_rounded,
                                    color: C.lvD),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tpl.title, style: T.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    isKorean
                                        ? '${tpl.stepTitles.length}개 단계'
                                        : '${tpl.stepTitles.length} steps',
                                    style:
                                        T.caption.copyWith(color: C.mu),
                                  ),
                                ],
                              )),
                              Icon(Icons.chevron_right_rounded, color: C.mu),
                            ],
                          ),
                        ),
                      )),
                ],
                // ④ 기본 템플릿
                if (builtinTemplates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      isKorean ? '기본 템플릿' : 'Built-in Templates',
                      style: T.bodyBold.copyWith(color: C.tx2),
                    ),
                  ),
                  ...builtinTemplates.map((tpl) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              outerContext,
                              MaterialPageRoute(
                                  builder: (_) => ProjectInputScreen(
                                      builtinTemplate: tpl)),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _colorFromHex(tpl.colorHex)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_iconFromName(tpl.iconName),
                                    color: _colorFromHex(tpl.colorHex)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      isKorean ? tpl.titleKo : tpl.titleEn,
                                      style: T.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    isKorean ? tpl.descKo : tpl.descEn,
                                    style: T.caption.copyWith(color: C.mu),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )),
                              Icon(Icons.chevron_right_rounded, color: C.mu),
                            ],
                          ),
                        ),
                      )),
                ],
                // ⑤ 템플릿 로딩 중
                if (builtinTemplates.isEmpty && userTemplates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: C.lv),
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

void _showCopyProjectSheet(BuildContext context, bool isKorean, List<dynamic> projects) {
  if (projects.isEmpty) {
    showSavedSnackBar(
      ScaffoldMessenger.of(context),
      message: isKorean ? '복사할 프로젝트가 없어요.' : 'No projects to copy.',
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isKorean ? '복사할 프로젝트 선택' : 'Select project to copy',
              style: T.h3,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: projects.length,
              itemBuilder: (_, i) {
                final p = projects[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _duplicateProjectFromSheet(context, p, isKorean);
                    },
                    child: Row(
                      children: [
                        if (p.coverPhotoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              p.coverPhotoUrl,
                              width: 48, height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, e) => _ProjectIconPlaceholder(),
                            ),
                          )
                        else
                          _ProjectIconPlaceholder(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title, style: T.bodyBold),
                              if (p.yarnBrandName.isNotEmpty || p.yarnName.isNotEmpty)
                                Text(
                                  '${p.yarnBrandName} ${p.yarnName}'.trim(),
                                  style: T.caption.copyWith(color: C.mu),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.copy_rounded, color: C.mu, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _duplicateProjectFromSheet(BuildContext context, dynamic project, bool isKorean) async {
  try {
    final container = ProviderScope.containerOf(context);
    await runWithMoriLoadingDialog<void>(
      context,
      message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
      task: () => container.read(projectRepositoryProvider).duplicateProject(project),
    );
    if (context.mounted) {
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    }
  } catch (e) {
    if (context.mounted) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }
}

class _ProjectIconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.folder_rounded, color: C.lv, size: 24),
    );
  }
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'dry_cleaning': return Icons.dry_cleaning_rounded;
    case 'hiking': return Icons.hiking_rounded;
    case 'ac_unit': return Icons.ac_unit_rounded;
    case 'back_hand': return Icons.back_hand_rounded;
    case 'face': return Icons.face_rounded;
    default: return Icons.article_rounded;
  }
}

Color _colorFromHex(String hex) {
  try {
    final v = hex.replaceFirst('#', '');
    return Color(int.parse('FF$v', radix: 16));
  } catch (_) {
    return C.lv;
  }
}
