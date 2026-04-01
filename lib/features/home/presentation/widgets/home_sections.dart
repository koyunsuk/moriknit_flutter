import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

class HomeAppBarTitle extends StatelessWidget {
  const HomeAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(colors: [C.pk, C.lv]),
          ),
          child: const Center(
            child: Text('M', style: TextStyle(fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        const MoriKnitTitle(fontSize: 16),
      ],
    );
  }
}

class HomeWipSection extends ConsumerWidget {
  const HomeWipSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Work in Progress'),
        const SizedBox(height: 10),
        GlassCard(
          onTap: () => context.go(Routes.projectList),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cozy Pullover', style: T.bodyBold),
                        const SizedBox(height: 2),
                        Text('Merino wool · 3.5mm needles', style: T.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('62%', style: T.numLG.copyWith(fontSize: 28, color: C.lv)),
                      Text('Progress', style: T.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: 0.62, minHeight: 5, backgroundColor: C.bd2, valueColor: AlwaysStoppedAnimation(C.lm)),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('62 rows finished', style: T.caption),
                  Text('Goal 100 rows', style: T.caption.copyWith(color: C.tx2)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeRecentSwatches extends StatelessWidget {
  final List<dynamic> swatches;
  const HomeRecentSwatches({super.key, required this.swatches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Recent Swatches',
          trailing: GestureDetector(
            onTap: () => context.go(Routes.swatchList),
            child: Text('See all', style: T.caption.copyWith(color: C.lvD)),
          ),
        ),
        const SizedBox(height: 10),
        if (swatches.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text('SW', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text('Save your first swatch to start building your library.', style: T.sm.copyWith(color: C.mu), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: swatches.length.clamp(0, 3),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final swatch = swatches[i];
                return GestureDetector(
                  onTap: () => context.push('/swatch/${swatch.id}'),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd)),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MoriChip(label: swatch.needleSizeDisplay, type: ChipType.lavender),
                        Text(swatch.gaugeDisplay, style: T.bodyBold.copyWith(fontSize: 13)),
                        Text(swatch.yarnBrandName.isEmpty ? 'Brand not set' : swatch.yarnBrandName, style: T.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class HomeCommunityFeed extends StatelessWidget {
  const HomeCommunityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    const titles = ['Finished a beanie', 'Need help with cables'];
    const subtitles = ['Used 4.0mm needles', 'Looking for softer yarn'];
    const initials = ['H', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: 'Community', trailing: Text('See all', style: T.caption.copyWith(color: C.lvD))),
        const SizedBox(height: 10),
        ...List.generate(2, (i) => GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: [C.pkL, C.lvL][i], borderRadius: BorderRadius.circular(12)), child: Center(child: Text(initials[i], style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titles[i], style: T.bodyBold.copyWith(fontSize: 14)), Text(subtitles[i], style: T.caption)])),
              Column(children: [Icon(Icons.favorite_border, color: C.pk, size: 16), Text(['24', '8'][i], style: T.caption)]),
            ],
          ),
        )),
      ],
    );
  }
}
