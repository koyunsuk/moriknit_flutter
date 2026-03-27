import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class EncyclopediaScreen extends ConsumerWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    final terms = isKorean
        ? const ['메리야스', '가터', '고무단', '코잡기', '겉뜨기']
        : const ['Stockinette', 'Garter', 'Ribbing', 'Cast On', 'Knit Stitch'];

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text(isKorean ? '뜨개 사전' : 'Encyclopedia', style: T.h3),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              MoriBrandHeader(
                logoSize: 84,
                titleSize: 26,
                subtitle: isKorean
                    ? '영문 약어, 뜨개 용어, 기법 설명을 한곳에서 정리할 사전 공간이에요.'
                    : 'This will become the place for stitch terms, abbreviations, and knitting technique notes.',
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: C.pk.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: C.pkD),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isKorean ? '뜨개 사전 준비 중' : 'Knitting encyclopedia is in progress',
                            style: T.bodyBold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isKorean
                          ? '자주 찾는 용어와 약어부터 먼저 정리해두고, 이후 도안 해석과 기법 설명까지 확장할 수 있게 구성했어요.'
                          : 'The first version will focus on common terms and abbreviations, then expand into pattern interpretation and technique references.',
                      style: T.body.copyWith(color: C.tx2),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: terms.map((term) => MoriChip(label: term, type: ChipType.white)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
