import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/needle_provider.dart';
import '../domain/needle_model.dart';
import 'needle_input_screen.dart';

class NeedleListScreen extends ConsumerWidget {
  const NeedleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needlesAsync = ref.watch(needleListProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '내 바늘' : 'My Needles', style: T.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: C.lv),
            onPressed: () => _navigateToInput(context),
          ),
        ],
      ),
      body: needlesAsync.when(
        data: (needles) {
          if (needles.isEmpty) {
            return _EmptyState(
              isKorean: isKorean,
              onAdd: () => _navigateToInput(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: needles.length,
            itemBuilder: (_, index) => _NeedleCard(
              needle: needles[index],
              isKorean: isKorean,
              onTap: () => _navigateToInput(context, needle: needles[index]),
              onDelete: () => _confirmDelete(context, ref, needles[index], isKorean),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
        error: (error, _) => Center(
          child: Text(
            isKorean ? '오류: $error' : 'Error: $error',
            style: T.body,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.lv,
        onPressed: () => _navigateToInput(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _navigateToInput(BuildContext context, {NeedleModel? needle}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NeedleInputScreen(initialNeedle: needle)),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NeedleModel needle,
    bool isKorean,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKorean ? '바늘 삭제' : 'Delete Needle', style: T.h3),
        content: Text(
          isKorean
              ? '${needle.sizeDisplay} ${needle.localizedMaterialLabel(true)} 바늘을 삭제할까요?'
              : 'Delete this ${needle.sizeDisplay} ${needle.localizedMaterialLabel(false)} needle?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              isKorean ? '취소' : 'Cancel',
              style: T.body.copyWith(color: C.mu),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(needleRepositoryProvider).deleteNeedle(needle.id);
            },
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _NeedleCard extends StatelessWidget {
  final NeedleModel needle;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NeedleCard({
    required this.needle,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: C.glassCard,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    needle.sizeDisplay.replaceAll('mm', ''),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: C.lv,
                    ),
                  ),
                  Text('mm', style: T.caption.copyWith(color: C.mu, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(needle.localizedTypeLabel(isKorean), style: T.bodyBold),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: C.pkL,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          needle.localizedMaterialLabel(isKorean),
                          style: const TextStyle(fontSize: 11, color: C.pkD),
                        ),
                      ),
                    ],
                  ),
                  if (needle.brandName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(needle.brandName, style: T.caption.copyWith(color: C.mu)),
                  ],
                  if (needle.quantity > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      isKorean ? '${needle.quantity}개' : '${needle.quantity}',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline, color: C.mu, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.isKorean,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: C.lvL,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.circle_outlined, color: C.lv, size: 36),
          ),
          const SizedBox(height: 16),
          Text(isKorean ? '아직 바늘이 없어요' : 'No needles yet', style: T.bodyBold),
          const SizedBox(height: 6),
          Text(
            isKorean
                ? '바늘을 등록하면 다음 프로젝트에서 바로 선택할 수 있어요.'
                : 'Add your needles now so you can pick them quickly in projects later.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(isKorean ? '바늘 추가' : 'Add Needle'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
