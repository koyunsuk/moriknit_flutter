import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text(isKorean ? '강의' : 'Courses', style: T.h3),
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
                    ? '기초부터 응용까지, 모리니트 학습 흐름을 곧 이곳에서 이어갈 수 있어요.'
                    : 'From basics to advanced techniques, MoriKnit learning paths will live here soon.',
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
                            color: C.lv.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school_rounded, color: C.lvD),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isKorean ? '온라인 강의 준비 중' : 'Online courses are in progress',
                            style: T.bodyBold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isKorean
                          ? '입문 강의, 스와치 실습, 도안 읽기, 게이지 이해처럼 실제 뜨개 흐름에 맞춘 학습 콘텐츠를 연결할 예정이에요.'
                          : 'Beginner lessons, swatch practice, pattern reading, and gauge lessons will be added here to match real knitting workflows.',
                      style: T.body.copyWith(color: C.tx2),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MoriChip(label: isKorean ? '입문 강의' : 'Beginner'),
                        MoriChip(label: isKorean ? '도안 읽기' : 'Pattern Reading', type: ChipType.pink),
                        MoriChip(label: isKorean ? '게이지' : 'Gauge', type: ChipType.lime),
                      ],
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
