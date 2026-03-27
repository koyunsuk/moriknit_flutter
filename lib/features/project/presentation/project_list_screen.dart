import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moriknit_flutter/core/localization/app_language.dart';
import 'package:moriknit_flutter/core/theme/app_colors.dart';
import 'package:moriknit_flutter/core/theme/app_theme.dart';
import 'package:moriknit_flutter/core/widgets/common_widgets.dart';
import 'package:moriknit_flutter/providers/auth_provider.dart';
import 'package:moriknit_flutter/providers/project_provider.dart';
import 'package:moriknit_flutter/features/project/presentation/project_detail_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_input_screen.dart';
import 'package:moriknit_flutter/features/project/presentation/project_list_sections.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final projectsAsync = ref.watch(projectListProvider);
    final gates = ref.watch(featureGatesProvider);
    final count = ref.watch(projectCountProvider);
    final limitReached = ref.watch(projectLimitReachedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: MoriBrandHeader(
                    logoSize: 78,
                    titleSize: 24,
                    subtitle: isKorean ? '계획부터 완성까지 프로젝트를 한곳에서 정리하세요.' : 'Organize every knit from planning to finish.',
                  ),
                ),
                if (gates.isFree)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: LimitBar(label: isKorean ? '프로젝트' : 'Projects', current: count, max: 3, isReached: limitReached, onUpgrade: () {}),
                  ),
                Expanded(
                  child: projectsAsync.when(
                    data: (projects) {
                      if (projects.isEmpty) {
                        return ProjectEmptyState(onAdd: () => _onAddTap(context, ref, limitReached, gates, count, isKorean));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: projects.length,
                        itemBuilder: (_, i) => ProjectCard(
                          project: projects[i],
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: projects[i].id))),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Center(child: Text('Error: $e', style: T.body)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: limitReached ? C.mu : C.lv,
        onPressed: () => _onAddTap(context, ref, limitReached, gates, count, isKorean),
        child: Icon(limitReached ? Icons.lock : Icons.add, color: Colors.white),
      ),
    );
  }

  void _onAddTap(BuildContext context, WidgetRef ref, bool limitReached, FeatureGates gates, int count, bool isKorean) {
    if (limitReached) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isKorean ? '프로젝트 한도 도달' : 'Project limit reached', style: T.h3),
          content: Text(gates.projectLimitMessage(count), style: T.body),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '닫기' : 'Close'))],
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectInputScreen()));
  }
}

