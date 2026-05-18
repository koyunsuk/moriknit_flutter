// 이슈 — 랜딩 CMS: 섹션 동적 렌더러.
//
// LandingPage.sections 을 순회하며 타입별 위젯 매핑.
// 알 수 없는 타입(SectionType.custom 또는 매핑 없음)은 무시 → 모든 섹션이 무시되면 호출자 fallback 위임.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../landing/presentation/landing_scaffold.dart';
import '../domain/landing_page.dart';

class CmsSectionRenderer extends StatelessWidget {
  final LandingPage page;
  final Widget fallback;

  const CmsSectionRenderer({
    super.key,
    required this.page,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final s in page.sections) {
      final w = _buildSection(context, s);
      if (w != null) widgets.add(w);
    }
    if (widgets.isEmpty) return fallback;

    return Scaffold(
      backgroundColor: kLandingBg,
      body: CustomScrollView(
        slivers: [
          for (final w in widgets) SliverToBoxAdapter(child: w),
        ],
      ),
    );
  }

  Widget? _buildSection(BuildContext context, LandingSection s) {
    switch (s.type) {
      case SectionType.hero:
        return _CmsHero(content: s.content);
      case SectionType.featureGrid:
        return _CmsFeatureGrid(content: s.content);
      case SectionType.faq:
        return _CmsFaq(content: s.content);
      case SectionType.pricing:
        return _CmsPricing(content: s.content);
      case SectionType.cta:
        return _CmsCta(content: s.content);
      case SectionType.markdown:
        return _CmsMarkdown(content: s.content);
      case SectionType.imageGallery:
        return _CmsImageGallery(content: s.content);
      case SectionType.testimonial:
        return _CmsTestimonial(content: s.content);
      case SectionType.custom:
        return null; // 무시 (호출자 fallback).
    }
  }
}

// ── 공용 ──────────────────────────────────────────────────────────────────────

String? _s(Map content, String key) {
  final v = content[key];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

List<Map<String, dynamic>> _items(Map content) {
  final v = content['items'];
  if (v is List) {
    return v
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
  return const [];
}

List<String> _imageUrls(Map content) {
  final v = content['images'];
  if (v is List) {
    return v
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

Future<void> _openLink(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

const double _landingMaxWidth = 1160;

class _SectionFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _SectionFrame({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────
class _CmsHero extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsHero({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final subtitle = _s(content, 'subtitle');
    final imageUrl = _s(content, 'imageUrl');
    final ctaText = _s(content, 'ctaText');
    final ctaLink = _s(content, 'ctaLink');

    return _SectionFrame(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title, style: T.h1.copyWith(color: C.tx)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, style: T.body.copyWith(color: C.tx2)),
                ],
                if (ctaText != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _openLink(ctaLink),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(ctaText, style: T.bodyBold),
                  ),
                ],
              ],
            ),
          ),
          if (imageUrl != null) ...[
            const SizedBox(width: 32),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── FeatureGrid ──────────────────────────────────────────────────────────────
class _CmsFeatureGrid extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsFeatureGrid({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final subtitle = _s(content, 'subtitle');
    final items = _items(content);
    if (items.isEmpty && title == null) return const SizedBox.shrink();
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: T.body.copyWith(color: C.tx2)),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: items.map((it) {
                  final w = (c.maxWidth - 16 * (cols - 1)) / cols;
                  return SizedBox(
                    width: w,
                    child: _featureCard(it),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _featureCard(Map<String, dynamic> it) {
    final title = (it['title'] as String?) ?? '';
    final desc = (it['desc'] as String?) ?? '';
    final image = (it['image'] as String?);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null && image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: C.bg,
                ),
              ),
            ),
          if (image != null && image.isNotEmpty) const SizedBox(height: 12),
          if (title.isNotEmpty)
            Text(title, style: T.h3.copyWith(color: C.tx)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc, style: T.body.copyWith(color: C.tx2)),
          ],
        ],
      ),
    );
  }
}

// ── FAQ ──────────────────────────────────────────────────────────────────────
class _CmsFaq extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsFaq({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final items = _items(content);
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          const SizedBox(height: 16),
          ...items.map((it) {
            final q = (it['question'] as String?) ?? '';
            final a = (it['answer'] as String?) ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.bd),
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(q, style: T.bodyBold.copyWith(color: C.tx)),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(a, style: T.body.copyWith(color: C.tx2)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Pricing ──────────────────────────────────────────────────────────────────
class _CmsPricing extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsPricing({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final subtitle = _s(content, 'subtitle');
    final items = _items(content);
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: T.body.copyWith(color: C.tx2)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items.map((it) {
              final name = (it['name'] as String?) ?? '';
              final price = (it['price']?.toString()) ?? '';
              final features = (it['features'] is List)
                  ? (it['features'] as List)
                      .map((e) => e?.toString() ?? '')
                      .where((e) => e.isNotEmpty)
                      .toList()
                  : <String>[];
              return SizedBox(
                width: 280,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.bd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: T.h3.copyWith(color: C.tx)),
                      const SizedBox(height: 8),
                      Text(price, style: T.h2.copyWith(color: C.lvD)),
                      const SizedBox(height: 12),
                      ...features.map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check, size: 16, color: C.lv),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(f,
                                    style:
                                        T.body.copyWith(color: C.tx2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── CTA ──────────────────────────────────────────────────────────────────────
class _CmsCta extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsCta({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final subtitle = _s(content, 'subtitle');
    final ctaText = _s(content, 'ctaText');
    final ctaLink = _s(content, 'ctaLink');
    return _SectionFrame(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [C.lv.withValues(alpha: 0.10), C.pk.withValues(alpha: 0.10)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.lv.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title, style: T.h2.copyWith(color: C.tx)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle, style: T.body.copyWith(color: C.tx2)),
                  ],
                ],
              ),
            ),
            if (ctaText != null)
              ElevatedButton(
                onPressed: () => _openLink(ctaLink),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(ctaText, style: T.bodyBold),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Markdown ─────────────────────────────────────────────────────────────────
// 외부 markdown 패키지 의존 회피 — 단순 텍스트 렌더.
class _CmsMarkdown extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsMarkdown({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final body = _s(content, 'body');
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          if (title != null) const SizedBox(height: 12),
          if (body != null)
            Text(body, style: T.body.copyWith(color: C.tx, height: 1.6)),
        ],
      ),
    );
  }
}

// ── ImageGallery ─────────────────────────────────────────────────────────────
class _CmsImageGallery extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsImageGallery({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final caption = _s(content, 'caption');
    final urls = _imageUrls(content);
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption, style: T.body.copyWith(color: C.tx2)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: urls
                .map(
                  (u) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      u,
                      width: 240,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 240,
                        height: 160,
                        color: C.bg,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Testimonial ──────────────────────────────────────────────────────────────
class _CmsTestimonial extends StatelessWidget {
  final Map<String, dynamic> content;
  const _CmsTestimonial({required this.content});

  @override
  Widget build(BuildContext context) {
    final title = _s(content, 'title');
    final items = _items(content);
    return _SectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title, style: T.h2.copyWith(color: C.tx)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items.map((it) {
              final name = (it['name'] as String?) ?? '';
              final role = (it['role'] as String?) ?? '';
              final quote = (it['quote'] as String?) ?? '';
              final avatar = (it['avatar'] as String?);
              return SizedBox(
                width: 320,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.bd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"$quote"',
                          style:
                              T.body.copyWith(color: C.tx, height: 1.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (avatar != null && avatar.isNotEmpty)
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(avatar),
                            )
                          else
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: C.bg,
                              child: Icon(Icons.person,
                                  size: 18, color: C.mu),
                            ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: T.bodyBold
                                      .copyWith(color: C.tx)),
                              if (role.isNotEmpty)
                                Text(role,
                                    style: T.caption
                                        .copyWith(color: C.mu)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
