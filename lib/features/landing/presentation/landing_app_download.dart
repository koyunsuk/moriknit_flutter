import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

const double _kMaxWidth = 1160;

/// 푸터1 — 앱 다운로드 섹션 (모든 기능 페이지 하단에 공통 표시)
class LandingAppDownload extends StatelessWidget {
  const LandingAppDownload({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF5FB),
            C.pk.withValues(alpha: 0.08),
            C.lv.withValues(alpha: 0.10),
            const Color(0xFFF5F0FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: C.lv.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: C.lv.withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: C.lv.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      'APP DOWNLOAD',
                      style: TextStyle(
                        color: C.lvD,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '모리니트를 앱으로\n더 편하게 사용해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1E1B4B),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '웹에서 크게 보고, 앱에서 빠르게 기록하세요.\n프로젝트, 스와치, 커뮤니티를 어디서든 이어갈 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5F4E99), fontSize: 15, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _AppDownloadButton(
                        iconWidget: const FaIcon(
                          FontAwesomeIcons.googlePlay,
                          size: 18,
                          color: Color(0xFF34A853),
                        ),
                        title: 'Google Play',
                        subtitle: '다운로드',
                        iconColor: const Color(0xFF34A853),
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://play.google.com/store/apps/details?id=com.moriknit.app'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _AppDownloadButton(
                        iconWidget: const FaIcon(
                          FontAwesomeIcons.appStoreIos,
                          size: 18,
                          color: Color(0xFF007AFF),
                        ),
                        title: 'App Store',
                        subtitle: '다운로드',
                        iconColor: const Color(0xFF007AFF),
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://apps.apple.com/app/moriknit/id6743618555'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _AppDownloadButton(
                        iconWidget: const Icon(
                          Icons.language_rounded,
                          size: 20,
                          color: Color(0xFF6BA800),
                        ),
                        title: '웹에서 시작',
                        subtitle: '로그인 후 바로 사용',
                        iconColor: const Color(0xFFA78BFA),
                        onTap: () => context.go('/login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDownloadButton extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _AppDownloadButton({
    required this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: C.lv.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.lv.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFF8B7ABB), fontSize: 10)),
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF1E1B4B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
