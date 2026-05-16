import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/handle_validator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 이슈 #771 — `@handle` 멘션 패턴을 chip 스타일로 렌더링하는 텍스트 위젯.
///
/// 게시글 본문(plain) 또는 일반 텍스트에서 `@xxx` 패턴을 발견하면
/// 해당 부분을 작은 chip 형태로 강조해 표시한다.
/// 탭하면 [onTapMention] 또는 기본 동작(해당 사용자 모리톡 화면 이동)을 수행한다.
///
/// 풀-fledged 멘션 시스템(자동완성)은 후속 — 본 위젯은 표시·해소만 담당.
class HandleMentionText extends StatefulWidget {
  final String text;
  final TextStyle? baseStyle;
  /// 멘션 chip을 탭했을 때 콜백. null이면 기본 동작(모리톡으로 이동) 수행.
  final void Function(String handle)? onTapMention;

  const HandleMentionText({
    super.key,
    required this.text,
    this.baseStyle,
    this.onTapMention,
  });

  @override
  State<HandleMentionText> createState() => _HandleMentionTextState();
}

class _HandleMentionTextState extends State<HandleMentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 멘션 패턴: 단어 시작에서 @ + [a-z0-9_]{3,20}.
    final pattern = RegExp(r'(^|[\s\n])@([a-z0-9_]{3,20})');
    final base = widget.baseStyle ?? T.body;
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in pattern.allMatches(widget.text)) {
      // 멘션 앞 일반 텍스트
      final prefix = m.group(1) ?? '';
      final handle = m.group(2) ?? '';
      final mentionStart = m.start + prefix.length;
      if (mentionStart > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, mentionStart), style: base));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _handleTap(handle);
      _recognizers.add(recognizer);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _MentionChip(handle: handle, onTap: () => _handleTap(handle)),
      ));
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor), style: base));
    }
    if (spans.isEmpty) {
      return Text(widget.text, style: base);
    }
    return RichText(text: TextSpan(children: spans, style: base));
  }

  Future<void> _handleTap(String handle) async {
    final cb = widget.onTapMention;
    if (cb != null) {
      cb(handle);
      return;
    }
    // 기본 동작: 핸들로 uid 조회 후 모리톡(DM 리스트) 화면으로 이동.
    final uid = await HandleValidator().resolveUidByHandle(handle);
    if (!mounted) return;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@$handle 사용자를 찾을 수 없어요.')),
      );
      return;
    }
    if (!mounted) return;
    context.push('/dm');
  }
}

class _MentionChip extends StatelessWidget {
  final String handle;
  final VoidCallback onTap;
  const _MentionChip({required this.handle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: C.lvL,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.lv.withValues(alpha: 0.25)),
        ),
        child: Text(
          '@$handle',
          style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
