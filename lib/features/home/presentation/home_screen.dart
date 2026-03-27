import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../project/domain/project_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchesAsync = ref.watch(swatchListProvider);
    final projectsAsync = ref.watch(projectListProvider);
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _HomeBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoriBrandHeader(logoSize: 96, titleSize: 30, subtitle: t.homeHeroSubtitle),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(child: _StatTile(label: t.swatches, value: '$swatchCount', color: C.lvD)),
                        Expanded(child: _StatTile(label: t.projects, value: '$projectCount', color: C.pkD)),
                        Expanded(child: _StatTile(label: t.library, value: '${swatchCount + projectCount}', color: C.lmD)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(title: t.recentSwatches, trailing: Text(t.latest, style: T.caption.copyWith(color: C.lvD))),
                  const SizedBox(height: 10),
                  swatchesAsync.when(
                    data: (swatches) {
                      if (swatches.isEmpty) {
                        return _EmptyBlock(
                          icon: Icons.grid_view_rounded,
                          title: isKorean ? '최근 스와치가 아직 없어요' : 'No recent swatches yet',
                          caption: t.noSwatchesYet,
                          color: C.lv,
                        );
                      }
                      return Column(
                        children: swatches.take(3).map((swatch) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              child: SizedBox(
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.grid_view_rounded, color: C.lvD),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.stitchesRows(swatch.beforeStitchCount, swatch.beforeRowCount), style: T.bodyBold),
                                          const SizedBox(height: 4),
                                          Text(t.needleSize(swatch.needleSize), style: T.caption.copyWith(color: C.lvD)),
                                          Text(swatch.yarnBrandName.isEmpty ? t.brandNotSet : swatch.yarnBrandName, style: T.caption),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: C.mu),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Text(isKorean ? '홈 데이터를 불러오지 못했어요: $e' : 'Failed to load home data: $e', style: T.body.copyWith(color: C.og)),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(title: isKorean ? '최근 프로젝트' : 'Recent projects', trailing: Text(isKorean ? '기록 중심' : 'Record first', style: T.caption.copyWith(color: C.pkD))),
                  const SizedBox(height: 10),
                  projectsAsync.when(
                    data: (projects) {
                      if (projects.isEmpty) {
                        return _EmptyBlock(
                          icon: Icons.folder_rounded,
                          title: isKorean ? '최근 프로젝트가 아직 없어요' : 'No recent projects yet',
                          caption: isKorean ? '프로젝트를 만들면 진행률과 메모를 홈에서 바로 다시 확인할 수 있어요.' : 'Create a project to see progress and notes here.',
                          color: C.pk,
                        );
                      }
                      return Column(
                        children: projects.take(3).map((project) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              child: SizedBox(
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.folder_rounded, color: C.pkD),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(project.title.isEmpty ? (isKorean ? '이름 없는 프로젝트' : 'Untitled project') : project.title, style: T.bodyBold),
                                          const SizedBox(height: 4),
                                          Text(_projectStatusLabel(project.status, isKorean), style: T.caption.copyWith(color: C.pkD)),
                                          Text(project.progressDisplay, style: T.caption),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: C.mu),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: C.pk)),
                    error: (e, _) => Text(isKorean ? '프로젝트를 불러오지 못했어요: $e' : 'Failed to load projects: $e', style: T.body.copyWith(color: C.og)),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(title: isKorean ? '커뮤니티 최신글' : 'Community highlights'),
                  const SizedBox(height: 10),
                  const _PromoBlock(
                    icon: Icons.people_alt_rounded,
                    color: C.pkD,
                    titleKo: '모리니트 커뮤니티 최신글',
                    titleEn: 'Latest MoriKnit posts',
                    captionKo: '인스타그램, 유튜브, 블로그에서 최신 기록과 튜토리얼을 둘러보세요.',
                    captionEn: 'Browse the latest tutorials and updates from Instagram, YouTube, and blog.',
                    chips: ['Instagram', 'YouTube', 'Blog'],
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(title: isKorean ? '마켓 추천' : 'Market picks'),
                  const SizedBox(height: 10),
                  const _PromoBlock(
                    icon: Icons.storefront_rounded,
                    color: C.lmD,
                    titleKo: '오늘의 마켓 추천',
                    titleEn: 'Today''s market picks',
                    captionKo: '도안, 실, 도구를 기록 흐름과 함께 이어서 살펴볼 수 있어요.',
                    captionEn: 'Discover patterns, yarn, and tools that connect with your records.',
                    chips: ['Pattern', 'Yarn', 'Tools'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _projectStatusLabel(String status, bool isKorean) {
    if (!isKorean) return status.replaceAll('_', ' ');
    switch (status) {
      case 'planning':
        return '계획 중';
      case 'swatching':
        return '스와치 중';
      case 'in_progress':
        return '진행 중';
      case 'blocking':
        return '보류';
      case 'finished':
        return '완료';
      default:
        return '계획 중';
    }
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(top: -84, right: -90, child: Container(width: 228, height: 228, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.lv.withValues(alpha: 0.08), Colors.transparent])))),
            Positioned(bottom: 92, left: -28, child: Container(width: 158, height: 158, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.pk.withValues(alpha: 0.24), Colors.transparent])))),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: T.numLG.copyWith(color: color)), const SizedBox(height: 4), Text(label, style: T.caption)]);
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final Color color;
  const _EmptyBlock({required this.icon, required this.title, required this.caption, required this.color});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SizedBox(
        width: double.infinity,
        height: 158,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)),
              const SizedBox(height: 12),
              Text(title, style: T.bodyBold, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(caption, style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBlock extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String titleKo;
  final String titleEn;
  final String captionKo;
  final String captionEn;
  final List<String> chips;
  const _PromoBlock({required this.icon, required this.color, required this.titleKo, required this.titleEn, required this.captionKo, required this.captionEn, required this.chips});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return GlassCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isKorean ? titleKo : titleEn, style: T.bodyBold),
                  const SizedBox(height: 6),
                  Text(isKorean ? captionKo : captionEn, style: T.body.copyWith(color: C.tx2)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: chips.map((chip) => MoriChip(label: chip, type: ChipType.white)).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
