import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/swatch_provider.dart';
import 'swatch_detail_screen.dart';
import 'swatch_input_screen.dart';
import 'swatch_list_sections.dart';

class SwatchListScreen extends ConsumerWidget {
  const SwatchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final swatchListAsync = ref.watch(swatchListProvider);
    final isLimitReached = ref.watch(swatchLimitReachedProvider);
    final progress = ref.watch(swatchLimitProgressProvider);
    final gates = ref.watch(featureGatesProvider);
    final count = ref.watch(swatchCountProvider);

    return Scaffold(
      backgroundColor: C.bg,
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
                    subtitle: isKorean ? '스와치 라이브러리를 쌓아두고 게이지를 비교해보세요.' : 'Save your gauge library and compare it later.',
                  ),
                ),
                if (gates.isFree)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SwatchLimitBar(current: count, max: 5, progress: progress, isReached: isLimitReached, onUpgrade: () {}),
                  ),
                Expanded(
                  child: swatchListAsync.when(
                    data: (swatches) {
                      if (swatches.isEmpty) {
                        return SwatchEmptyState(onAdd: isLimitReached ? null : () => _navigateToInput(context));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: swatches.length,
                        itemBuilder: (context, index) {
                          return SwatchCard(
                            swatch: swatches[index],
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwatchDetailScreen(swatchId: swatches[index].id))),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Center(child: Text('Failed to load swatches: $e', style: T.body.copyWith(color: C.mu))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLimitReached ? () => _showLimitDialog(context, ref, isKorean) : () => _navigateToInput(context),
        backgroundColor: isLimitReached ? C.mu : C.lm,
        child: isLimitReached ? const Icon(Icons.lock, color: Colors.white) : const Icon(Icons.add, color: Color(0xFF1a3000)),
      ),
    );
  }

  void _navigateToInput(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SwatchInputScreen()));
  }

  void _showLimitDialog(BuildContext context, WidgetRef ref, bool isKorean) {
    final gates = ref.read(featureGatesProvider);
    final count = ref.read(swatchCountProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '스와치 한도 도달' : 'Swatch limit reached', style: T.h3),
        content: Text(gates.swatchLimitMessage(count), style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '닫기' : 'Close')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: C.lm, foregroundColor: const Color(0xFF1a3000)), onPressed: () { Navigator.pop(ctx); }, child: Text(isKorean ? '업그레이드' : 'Upgrade')),
        ],
      ),
    );
  }
}
