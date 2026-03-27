import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../auth/domain/user_model.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: userAsync.when(
        data: (user) {
          final resolvedUser = user ?? UserModel(uid: authUser?.uid ?? '', email: authUser?.email ?? '', displayName: authUser?.displayName ?? '', photoURL: authUser?.photoURL ?? '');
          return _MyPageBody(user: resolvedUser);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('Failed to load profile: $e', style: T.body)),
      ),
    );
  }
}

class _MyPageBody extends ConsumerWidget {
  final UserModel user;
  const _MyPageBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
    final purchasesAsync = ref.watch(myPurchasesProvider);
    final marketItemsAsync = ref.watch(myMarketItemsProvider);
    final salesAsync = ref.watch(myMarketSalesProvider);
    final name = user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email.split('@').first : 'Maker');
    final photo = user.photoURL;
    final firstLetter = name.isNotEmpty ? name.characters.first.toUpperCase() : 'M';
    final joinedDate = user.createdAt ?? user.lastActiveAt;

    return Stack(
      children: [
        const BgOrbs(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoriBrandHeader(logoSize: 92, titleSize: 28, subtitle: t.yourKnittingIdentity),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: C.lvL,
                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty ? Text(firstLetter, style: const TextStyle(fontSize: 24, color: C.lvD, fontWeight: FontWeight.w700)) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: T.h2),
                              const SizedBox(height: 4),
                              Text(user.email.isEmpty ? t.noEmailConnected : user.email, style: T.body.copyWith(color: C.mu)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  MoriChip(label: _planLabel(t, user.subscription.planId), type: ChipType.lavender),
                                  MoriChip(label: photo.isEmpty ? t.defaultAvatar : t.socialPhoto, type: ChipType.pink),
                                  MoriChip(label: language.label, type: ChipType.white),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(14)),
                        child: Text(user.bio, style: T.body.copyWith(color: C.tx2)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(child: _ProfileStat(label: t.swatches, value: '$swatchCount', accent: C.lvD)),
                    Expanded(child: _ProfileStat(label: t.projects, value: '$projectCount', accent: C.pkD)),
                    Expanded(child: _ProfileStat(label: isKorean ? '카운터' : 'Counters', value: '$counterCount', accent: C.lmD)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.languageLabel, style: T.bodyBold),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AppLanguage>(
                      initialValue: language,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.84),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.bd)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.bd)),
                      ),
                      items: AppLanguage.values.map((option) => DropdownMenuItem(value: option, child: Text(option.label))).toList(),
                      onChanged: (value) {
                        if (value != null) ref.read(appLanguageProvider.notifier).setLanguage(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: purchasesAsync.when(
                      data: (items) => _SummaryCard(
                        title: isKorean ? '내 구매 요약' : 'Purchase summary',
                        countLabel: isKorean ? '구매 수' : 'Orders',
                        countValue: '${items.length}',
                        amountLabel: isKorean ? '구매 합계' : 'Spent',
                        amountValue: _formatWon(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
                        accent: C.pkD,
                      ),
                      loading: () => const _LoadingSummaryCard(color: C.pkD),
                      error: (e, _) => _ErrorCard(message: '$e'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: salesAsync.when(
                      data: (items) => _SummaryCard(
                        title: isKorean ? '내 마켓 수익' : 'Market earnings',
                        countLabel: isKorean ? '판매 수' : 'Sales',
                        countValue: '${items.length}',
                        amountLabel: isKorean ? '누적 수익' : 'Revenue',
                        amountValue: _formatWon(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
                        accent: C.lmD,
                      ),
                      loading: () => const _LoadingSummaryCard(color: C.lmD),
                      error: (e, _) => _ErrorCard(message: '$e'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '내 구매 목록' : 'My purchases', style: T.bodyBold),
                    const SizedBox(height: 6),
                    Text(isKorean ? '최근 구입한 상품과 지출 흐름을 한 번에 확인해요.' : 'See your latest purchases and spending at a glance.', style: T.caption.copyWith(color: C.mu)),
                    const SizedBox(height: 12),
                    purchasesAsync.when(
                      data: (items) => items.isEmpty
                          ? Text(isKorean ? '아직 구매한 상품이 없어요.' : 'No purchases yet.', style: T.caption.copyWith(color: C.mu))
                          : Column(children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWon(item.price, isKorean), accent: C.pkD)).toList()),
                      loading: () => const CircularProgressIndicator(color: C.lv),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '내 마켓 목록' : 'My market items', style: T.bodyBold),
                    const SizedBox(height: 6),
                    Text(isKorean ? '등록한 상품과 판매 수익 흐름을 따로 관리해요.' : 'Track your listings and seller revenue separately.', style: T.caption.copyWith(color: C.mu)),
                    const SizedBox(height: 12),
                    marketItemsAsync.when(
                      data: (items) => items.isEmpty
                          ? Text(isKorean ? '등록한 상품이 아직 없어요.' : 'No listed items yet.', style: T.caption.copyWith(color: C.mu))
                          : Column(
                              children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWon(item.price, isKorean), accent: C.lmD)).toList(),
                            ),
                      loading: () => const CircularProgressIndicator(color: C.lv),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.profileOverview, style: T.bodyBold), const SizedBox(height: 12), _InfoRow(label: t.displayName, value: name), _InfoRow(label: t.userId, value: user.uid.isEmpty ? t.notAvailable : user.uid), _InfoRow(label: t.email, value: user.email.isEmpty ? t.notConnected : user.email), _InfoRow(label: t.joined, value: joinedDate == null ? t.unknown : _formatDate(joinedDate)), _InfoRow(label: t.lastActive, value: user.lastActiveAt == null ? t.unknown : _formatDate(user.lastActiveAt!))])),
              const SizedBox(height: 16),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.accountConnections, style: T.bodyBold), const SizedBox(height: 12), _InfoRow(label: t.plan, value: _planLabel(t, user.subscription.planId)), _InfoRow(label: t.status, value: user.subscription.status), _InfoRow(label: t.profilePhoto, value: photo.isEmpty ? t.usingDefaultAvatar : t.importedFromSocial), _InfoRow(label: t.signInSync, value: _socialSyncLabel(t, photo: photo, displayName: user.displayName, email: user.email))])),
              const SizedBox(height: 16),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.usageSnapshot, style: T.bodyBold), const SizedBox(height: 12), _UsageRow(label: t.swatchLibrary, caption: t.liveSaved(swatchCount, user.usage.swatchCount), current: swatchCount, stored: user.usage.swatchCount, color: C.lv), const SizedBox(height: 10), _UsageRow(label: t.projectBoard, caption: t.liveSaved(projectCount, user.usage.projectCount), current: projectCount, stored: user.usage.projectCount, color: C.pk), const SizedBox(height: 10), _UsageRow(label: isKorean ? '카운터 기록' : 'Counter records', caption: t.liveSaved(counterCount, user.usage.counterCount), current: counterCount, stored: user.usage.counterCount, color: C.lmD)])),
              const SizedBox(height: 16),
              GlassCard(child: Column(children: [ListTile(leading: const Icon(Icons.circle_outlined, color: C.lvD), title: Text(t.needles), subtitle: Text(t.manageNeedles), onTap: () => context.go('/my/needles')), const Divider(height: 1), ListTile(leading: const Icon(Icons.logout, color: C.og), title: Text(t.logout), subtitle: Text(t.logoutDescription), onTap: () async { await ref.read(authRepositoryProvider).signOut(); if (context.mounted) context.go('/login'); })])),
            ],
          ),
        ),
      ],
    );
  }

  String _planLabel(AppStrings t, String planId) {
    switch (planId.toLowerCase()) {
      case 'starter':
        return t.starterPlan;
      case 'pro':
        return t.proPlan;
      case 'business':
        return t.businessPlan;
      default:
        return t.freePlan;
    }
  }

  String _socialSyncLabel(AppStrings t, {required String photo, required String displayName, required String email}) {
    if (photo.isNotEmpty || displayName.isNotEmpty) return t.importedProfile;
    if (email.isNotEmpty) return t.emailOnlyProfile;
    return t.noProviderProfile;
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String _formatWon(int amount, bool isKorean) => isKorean ? '$amount원' : '$amount KRW';
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _ProfileStat({required this.label, required this.value, required this.accent});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: T.numLG.copyWith(color: accent)), const SizedBox(height: 4), Text(label, style: T.caption)]);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String countLabel;
  final String countValue;
  final String amountLabel;
  final String amountValue;
  final Color accent;
  const _SummaryCard({required this.title, required this.countLabel, required this.countValue, required this.amountLabel, required this.amountValue, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.bodyBold),
          const SizedBox(height: 12),
          _SummaryMetric(label: countLabel, value: countValue, accent: accent),
          const SizedBox(height: 10),
          _SummaryMetric(label: amountLabel, value: amountValue, accent: accent),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _SummaryMetric({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withValues(alpha: 0.16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: T.caption.copyWith(color: C.mu)), const SizedBox(height: 4), Text(value, style: T.bodyBold.copyWith(color: accent))]),
    );
  }
}

class _LoadingSummaryCard extends StatelessWidget {
  final Color color;
  const _LoadingSummaryCard({required this.color});
  @override
  Widget build(BuildContext context) => GlassCard(child: SizedBox(height: 116, child: Center(child: CircularProgressIndicator(color: color))));
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => GlassCard(child: Text(message, style: T.caption.copyWith(color: C.og)));
}

class _LedgerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  const _LedgerRow({required this.title, required this.subtitle, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd)),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: T.body)),
          Text(subtitle, style: T.captionBold.copyWith(color: accent)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: T.captionBold.copyWith(color: C.mu))), Expanded(child: Text(value, style: T.body))]));
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String caption;
  final int current;
  final int stored;
  final Color color;
  const _UsageRow({required this.label, required this.caption, required this.current, required this.stored, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: T.captionBold.copyWith(color: C.mu)), Text(caption, style: T.caption.copyWith(color: color))]), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: current == 0 ? 0 : (stored == 0 ? 0.15 : (current / (stored > current ? stored : current)).clamp(0.0, 1.0)), minHeight: 6, backgroundColor: color.withValues(alpha: 0.14), valueColor: AlwaysStoppedAnimation(color)))]);
  }
}
