import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../providers/app_config_provider.dart';

const double _landingMaxWidth = 1160;

/// 랜딩 공통 푸터
class LandingFooter extends ConsumerWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialIntegrationsProvider).valueOrNull;
    final youtubeUrl = social?.youtubeUrl ?? 'https://www.youtube.com/@moriknit';
    final instagramUrl = social?.instagramUrl ?? 'https://instagram.com/moriknit_official';
    final blogUrl = social?.blogUrl ?? 'https://blog.naver.com/moriknit';
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MoriKnitTitle(fontSize: 22),
                          const SizedBox(height: 10),
                          const Text('뜨개 기록의 모든 것',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          const Text(
                              '스와치, 프로젝트, 커뮤니티, 마켓까지\n뜨개질의 모든 과정을 한 곳에서.',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  height: 1.6)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('회사 정보',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 12),
                          const _FooterInfoRow(
                              label: '서비스명', value: 'MoriKnit (모리니트)'),
                          const _FooterInfoRow(label: '운영', value: '1인 개발 서비스'),
                          const _FooterInfoRow(
                              label: '이메일', value: 'support@moriknit.app'),
                          const _FooterInfoRow(label: '버전', value: '1.0.0'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            children: [
                              TextButton(
                                onPressed: () => launchUrl(
                                    Uri.parse('https://www.moriknit.com/terms')),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white54,
                                    padding: EdgeInsets.zero),
                                child: const Text('이용약관',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () => launchUrl(Uri.parse(
                                    'https://www.moriknit.com/privacy')),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white54,
                                    padding: EdgeInsets.zero),
                                child: const Text('개인정보처리방침',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('© 2024 MoriKnit. All rights reserved.',
                          style: TextStyle(color: Colors.white30, fontSize: 12)),
                    ),
                    _FooterSnsIconButton(
                      icon: Icons.camera_alt_outlined,
                      tooltip: 'Instagram',
                      url: instagramUrl,
                    ),
                    const SizedBox(width: 6),
                    _FooterSnsIconButton(
                      icon: Icons.play_circle_outline_rounded,
                      tooltip: 'YouTube',
                      url: youtubeUrl,
                    ),
                    const SizedBox(width: 6),
                    _FooterSnsIconButton(
                      icon: Icons.article_outlined,
                      tooltip: 'Blog',
                      url: blogUrl,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _FooterInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

class _FooterSnsIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String url;

  const _FooterSnsIconButton({
    required this.icon,
    required this.tooltip,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 17, color: Colors.white60),
        ),
      ),
    );
  }
}
