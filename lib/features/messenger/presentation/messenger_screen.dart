import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/ui_copy_provider.dart';

class MessengerScreen extends ConsumerStatefulWidget {
  const MessengerScreen({super.key});

  @override
  ConsumerState<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends ConsumerState<MessengerScreen> {
  final _controller = TextEditingController();
  late List<_AiBubble> _messages;

  static const _initialMessage = _AiBubble(
    role: _BubbleRole.ai,
    text: '안녕, 오늘 뜨개 기분은 어때? 용어 설명이나 가벼운 대화도 도와줄게.',
  );

  @override
  void initState() {
    super.initState();
    _messages = [_initialMessage];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'messenger_header_subtitle',
      fallback: t.messengerHeaderSubtitle,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: Row(
                children: [
                  Expanded(
                    child: MoriWideHeader(
                      title: t.messengerTabLabel,
                      subtitle: subtitle,
                    ),
                  ),
                  if (_messages.length > 1)
                    IconButton(
                      icon: Icon(Icons.delete_sweep_rounded, color: C.mu, size: 22),
                      tooltip: '대화 초기화',
                      onPressed: () => setState(() => _messages = [_initialMessage]),
                    ),
                ],
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
                            Text('Member Messenger', style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(
                              t.memberMessagesSoon,
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.talkWithMoriknitAi, style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(
                              t.moriknitAiHint,
                              style: T.caption.copyWith(color: C.mu, height: 1.5),
                            ),
                            const SizedBox(height: 14),
                            ..._messages.map(
                              (message) => Align(
                                alignment: message.role == _BubbleRole.user ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  decoration: BoxDecoration(
                                    color: message.role == _BubbleRole.user ? C.lv : Colors.white.withValues(alpha: 0.84),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: message.role == _BubbleRole.user ? C.lv : C.bd),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: T.body.copyWith(
                                      color: message.role == _BubbleRole.user ? Colors.white : C.tx2,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                16, 8, 16,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 8
                    : 88,
              ),
              decoration: BoxDecoration(
                color: C.bg,
                border: Border(top: BorderSide(color: C.bd)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: t.askMoriknitAi,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.pk,
                      foregroundColor: Colors.white,
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_AiBubble(role: _BubbleRole.user, text: text));
      _messages.add(_AiBubble(role: _BubbleRole.ai, text: _reply(text)));
      _controller.clear();
    });
  }

  String _reply(String input) {
    final q = input.toLowerCase();
    if (q.contains('게이지')) return '게이지는 스와치로 먼저 재고, 도구 안의 게이지 계산기에서 치수 환산까지 같이 확인해보자.';
    if (q.contains('기분') || q.contains('힘들')) return '오늘은 가벼운 스와치나 메모부터 시작해도 충분해. 한 줄만 떠도 흐름이 다시 돌아올 수 있어.';
    if (q.contains('겉뜨기') || q.contains('knit')) return '겉뜨기는 보통 knit, 기호로는 K를 많이 써. 뜨개사전에도 같은 키로 정리해두면 좋아.';
    if (q.contains('안뜨기') || q.contains('purl')) return '안뜨기는 purl, 기호로는 P를 많이 써. 영어·한국어·일본어를 함께 묶어두면 백과사전에 잘 맞아.';
    return '좋아. 지금 말한 내용은 나만의 메모장이나 뜨개사전에 함께 정리해두면 다음 작업에서 훨씬 편해질 거야.';
  }
}

enum _BubbleRole { ai, user }

class _AiBubble {
  final _BubbleRole role;
  final String text;

  const _AiBubble({
    required this.role,
    required this.text,
  });
}
