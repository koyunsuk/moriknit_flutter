import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/ui_copy_provider.dart';

class MessengerScreen extends ConsumerWidget {
  const MessengerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'messenger_header_subtitle',
      fallback: t.messengerHeaderSubtitle,
    );
    final isKorean = language.isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: t.messengerTabLabel,
                subtitle: subtitle,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.forum_rounded, color: C.lv, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isKorean ? '모리톡 DM' : 'MoriTalk DM',
                                style: T.bodyBold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isKorean
                              ? '커뮤니티에서 마음에 드는 작품의 작성자에게\n직접 메시지를 보내보세요.'
                              : 'Send a direct message to creators\nyou love in the community.',
                          style: T.caption.copyWith(color: C.mu, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push(Routes.dm),
                            icon: const Icon(Icons.mail_outline_rounded, size: 18),
                            label: Text(isKorean ? 'DM 목록 열기' : 'Open DMs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.lv,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
