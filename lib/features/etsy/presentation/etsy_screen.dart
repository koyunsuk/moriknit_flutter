import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/etsy_auth_provider.dart';
import '../data/etsy_repository.dart';
import '../domain/etsy_models.dart';

class EtsyScreen extends ConsumerWidget {
  const EtsyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(etsyAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: 'Etsy',
                subtitle: isKorean ? '내 Etsy 샵 리스팅을 확인해요' : 'View your Etsy shop listings',
                trailing: auth.isLoggedIn
                    ? [
                        TextButton(
                          onPressed: () => ref.read(etsyAuthProvider.notifier).logout(),
                          child: Text(
                            isKorean ? '연결 해제' : 'Disconnect',
                            style: T.caption.copyWith(color: C.og),
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            Expanded(
              child: auth.isLoggedIn
                  ? _LoggedInBody(isKorean: isKorean)
                  : _LoginPrompt(isKorean: isKorean),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 로그인 전 ──────────────────────────────────────────────────────────────────
class _LoginPrompt extends ConsumerWidget {
  const _LoginPrompt({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(etsyAuthProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, size: 56, color: Color(0xFFF16521)),
            const SizedBox(height: 20),
            Text(
              isKorean ? 'Etsy 계정 연결' : 'Connect Etsy Account',
              style: T.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isKorean
                  ? 'Etsy 판매자 계정을 연결하면\n내 샵의 리스팅을 앱에서 확인할 수 있어요.'
                  : 'Connect your Etsy seller account\nto view your shop listings in the app.',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Text(auth.error!, style: T.caption.copyWith(color: C.og), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () => ref.read(etsyAuthProvider.notifier).login(),
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(isKorean ? 'Etsy로 로그인' : 'Login with Etsy'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF16521)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 로그인 후 ──────────────────────────────────────────────────────────────────
class _LoggedInBody extends ConsumerWidget {
  const _LoggedInBody({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(etsyShopProvider);
    final listingsAsync = ref.watch(etsyListingsProvider);

    return RefreshIndicator(
      color: C.lv,
      onRefresh: () async {
        ref.invalidate(etsyShopProvider);
        ref.invalidate(etsyListingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // 샵 정보 카드
          shopAsync.when(
            data: (shop) => shop != null
                ? GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF16521).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: shop.iconUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(imageUrl: shop.iconUrl!, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.storefront_rounded, color: Color(0xFFF16521)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shop.shopName, style: T.bodyBold),
                              if (shop.title != null)
                                Text(
                                  shop.title!,
                                  style: T.caption.copyWith(color: C.mu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                isKorean
                                    ? '활성 리스팅 ${shop.listingActiveCount}개 · 판매 ${shop.transactionSoldCount}건'
                                    : '${shop.listingActiveCount} active · ${shop.transactionSoldCount} sold',
                                style: T.caption.copyWith(color: C.lv),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : GlassCard(
                    child: Text(
                      isKorean ? '샵 정보를 불러오지 못했어요.' : 'Could not load shop info.',
                      style: T.body.copyWith(color: C.mu),
                    ),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
          ),
          const SizedBox(height: 16),
          Text(isKorean ? '활성 리스팅' : 'Active Listings', style: T.bodyBold),
          const SizedBox(height: 8),
          listingsAsync.when(
            data: (listings) => listings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        isKorean ? '활성 리스팅이 없어요.' : 'No active listings.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    ),
                  )
                : Column(
                    children: listings.map((l) => _ListingTile(listing: l, isKorean: isKorean)).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
          ),
        ],
      ),
    );
  }
}

// ── 리스팅 카드 ───────────────────────────────────────────────────────────────
class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.listing, required this.isKorean});
  final EtsyListing listing;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: listing.listingUrl.isNotEmpty
            ? () => launchUrl(Uri.parse(listing.listingUrl), mode: LaunchMode.externalApplication)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: listing.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: listing.thumbnailUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _PlaceholderThumb(),
                    )
                  : _PlaceholderThumb(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, style: T.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(listing.priceDisplay, style: T.bodyBold.copyWith(color: const Color(0xFFF16521))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 12, color: C.mu),
                      const SizedBox(width: 3),
                      Text(
                        isKorean ? '재고 ${listing.quantity}개' : 'Qty ${listing.quantity}',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                    ],
                  ),
                  if (listing.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: listing.tags.take(3).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.gx,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tag, style: T.caption.copyWith(fontSize: 10, color: C.mu)),
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFF16521), size: 18),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: C.gx,
      child: Icon(Icons.image_outlined, color: C.mu, size: 28),
    );
  }
}
