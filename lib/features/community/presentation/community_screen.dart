import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/community_channel_repository.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final channels = CommunityChannelRepository.channels(isKorean);
    final highlights = CommunityChannelRepository.highlights(isKorean);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              children: [
                MoriBrandHeader(
                  logoSize: 86,
                  titleSize: 26,
                  subtitle: isKorean ? '인스타그램, 유튜브, 블로그를 한 화면에서 탐색하는 MoriKnit 콘텐츠 허브' : 'A MoriKnit content hub for Instagram, YouTube, and blog.',
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x33F472B6), Color(0x33C084FC), Color(0x33A3E635)]),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: C.bd),
                    boxShadow: [BoxShadow(color: C.pk.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isKorean ? 'MoriKnit 커뮤니티 허브' : 'MoriKnit Channel Hub', style: T.h2),
                      const SizedBox(height: 8),
                      Text(isKorean ? '짧은 릴스, 긴 영상, 정리된 글을 오가며 모리니트 콘텐츠를 다각도로 체험해보세요.' : 'Move between quick reels, deep videos, and readable posts.', style: T.body.copyWith(color: C.tx2)),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: const [MoriChip(label: 'Instagram', type: ChipType.pink), MoriChip(label: 'YouTube', type: ChipType.lavender), MoriChip(label: 'Blog', type: ChipType.lime)]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '공식 채널 바로가기' : 'Official channels'),
                const SizedBox(height: 10),
                ...channels.map((channel) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ChannelCard(channel: channel))),
                const SizedBox(height: 14),
                SectionTitle(title: isKorean ? '콘텐츠 체험 하이라이트' : 'Highlights'),
                const SizedBox(height: 10),
                ...highlights.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _HighlightCard(item: item))),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isKorean ? '활용 제안' : 'Ways to explore', style: T.bodyBold),
                      const SizedBox(height: 10),
                      _IdeaRow(icon: Icons.play_circle_outline_rounded, text: isKorean ? '인스타 릴스로 빠르게 훑어보기' : 'Use reels for quick browsing'),
                      _IdeaRow(icon: Icons.ondemand_video_rounded, text: isKorean ? '유튜브로 프로젝트 흐름 자세히 보기' : 'Use YouTube for deeper walkthroughs'),
                      _IdeaRow(icon: Icons.menu_book_rounded, text: isKorean ? '블로그에서 팁과 기록 글 읽기' : 'Read blog posts for tips and records'),
                      _IdeaRow(icon: Icons.open_in_new_rounded, text: isKorean ? '원하는 채널을 앱 밖으로 바로 열기' : 'Open the channel outside the app'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final CommunityChannelLink channel;
  const _ChannelCard({required this.channel});
  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(channel.title);
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)), child: Icon(_icon(channel.title), color: accent)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.title, style: T.bodyBold),
                const SizedBox(height: 4),
                Text(channel.handle, style: T.caption.copyWith(color: accent)),
                const SizedBox(height: 6),
                Text(channel.summary, style: T.body.copyWith(color: C.tx2)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _open(channel.url),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(channel.cta),
                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(String title) {
    if (title.contains('Instagram')) return Icons.photo_camera_back_rounded;
    if (title.contains('YouTube')) return Icons.ondemand_video_rounded;
    return Icons.edit_note_rounded;
  }

  Color _accentColor(String title) {
    if (title.contains('Instagram')) return C.pkD;
    if (title.contains('YouTube')) return C.lvD;
    return C.lmD;
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _HighlightCard extends StatelessWidget {
  final CommunityContentItem item;
  const _HighlightCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final accent = _accent(item.badge);
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(22), border: Border.all(color: C.bd), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 12))]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [MoriChip(label: item.badge, type: _chipType(item.badge)), const SizedBox(width: 8), Text(item.section, style: T.captionBold.copyWith(color: accent))]),
          const SizedBox(height: 12),
          Text(item.title, style: T.bodyBold.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          Text(item.caption, style: T.body.copyWith(color: C.tx2)),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: () => _open(item.url), icon: Icon(Icons.arrow_outward_rounded, color: accent), label: Text(item.actionLabel, style: T.bodyBold.copyWith(color: accent))),
        ],
      ),
    );
  }
  ChipType _chipType(String badge) => badge == 'Quick' ? ChipType.pink : badge == 'Deep Dive' ? ChipType.lavender : ChipType.lime;
  Color _accent(String badge) => badge == 'Quick' ? C.pkD : badge == 'Deep Dive' ? C.lvD : C.lmD;
  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _IdeaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IdeaRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [Icon(icon, size: 18, color: C.lvD), const SizedBox(width: 10), Expanded(child: Text(text, style: T.body.copyWith(color: C.tx2)))]),
    );
  }
}
