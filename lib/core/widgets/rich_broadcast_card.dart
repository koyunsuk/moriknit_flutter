// 이슈 #848 — 어드민 브로드캐스트 풍부한 카드 메시지 위젯.
//
// @moriknit DM 룸에 누적되는 어드민 발송 메시지 중 imageUrl / bodyDelta(Quill JSON) /
// linkUrl 가 하나라도 있는 경우, 일반 텍스트 버블 대신 본 카드 위젯으로 렌더링.
//
// 사용 위치:
//   - lib/features/dm/presentation/dm_chat_screen.dart (사용자 측 채팅)
//   - lib/features/admin/presentation/widgets/inbox/inbox_chat_panel.dart (어드민 측 채팅)
//
// 구조:
//   ┌────────────────────────┐
//   │ [이미지 16:9]           │ ← imageUrl 있을 때만
//   ├────────────────────────┤
//   │ 본문 텍스트 (message.text)│
//   │                         │
//   │ [Quill 본문]            │ ← bodyDelta 있을 때만 (read-only)
//   │                         │
//   │ [🛒 자세히 보기 →]      │ ← linkUrl 있을 때만
//   └────────────────────────┘
//
// CLAUDE.md 원칙 준수:
//   - 색상은 토큰(C) 만 사용 (Color(0xFF...) 금지)
//   - 타이포는 T.h3 / T.body / T.caption 사용 (인라인 TextStyle 금지)
//   - Quill embed 빌더는 popupQuillEmbedBuilders 재사용 (#835)

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'popup_image_embed.dart';

class RichBroadcastCard extends StatefulWidget {
  /// 메시지 본문 텍스트 (DmMessage.text). 비어있어도 됨.
  final String text;
  /// 카드 상단 이미지 URL. 비어있으면 이미지 영역 미표시.
  final String imageUrl;
  /// Quill Delta JSON 문자열. 비어있거나 파싱 실패 시 미표시.
  final String bodyDelta;
  /// "자세히 보기" 버튼 링크. 비어있으면 버튼 미표시.
  final String linkUrl;
  /// 한국어 UI 여부 (버튼 라벨 등).
  final bool isKorean;
  /// 카드 배경/텍스트 톤. true 면 라벤더 배경(어드민/시스템 측 버블), false 면 회색.
  final bool useAccentBackground;
  /// 카드 최대 너비 (기본 320).
  final double maxWidth;

  const RichBroadcastCard({
    super.key,
    required this.text,
    required this.imageUrl,
    required this.bodyDelta,
    required this.linkUrl,
    this.isKorean = true,
    this.useAccentBackground = false,
    this.maxWidth = 320,
  });

  @override
  State<RichBroadcastCard> createState() => _RichBroadcastCardState();
}

class _RichBroadcastCardState extends State<RichBroadcastCard> {
  fq.QuillController? _quillCtrl;

  @override
  void initState() {
    super.initState();
    _initQuillIfRich();
  }

  @override
  void didUpdateWidget(covariant RichBroadcastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bodyDelta != widget.bodyDelta) {
      _quillCtrl?.dispose();
      _quillCtrl = null;
      _initQuillIfRich();
    }
  }

  void _initQuillIfRich() {
    if (widget.bodyDelta.isEmpty) return;
    try {
      final decoded = jsonDecode(widget.bodyDelta);
      if (decoded is List) {
        final doc = fq.Document.fromJson(decoded);
        // plain text 만 있는 빈 도큐먼트(\n 한 줄)는 fallback 처리.
        if (doc.toPlainText().trim().isEmpty) return;
        _quillCtrl = fq.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      }
    } catch (_) {
      // 잘못된 JSON → null 유지 → 일반 텍스트만 표시.
    }
  }

  @override
  void dispose() {
    _quillCtrl?.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final url = widget.linkUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.useAccentBackground;
    final cardColor = accent ? C.lv : C.gx;
    final borderColor = accent ? Colors.transparent : C.bd;
    final textColor = accent ? Colors.white : C.tx;
    final bodyTextColor =
        accent ? Colors.white.withValues(alpha: 0.92) : C.tx2;
    final hasImage = widget.imageUrl.isNotEmpty;
    final hasText = widget.text.trim().isNotEmpty;
    final hasQuill = _quillCtrl != null;
    final hasLink = widget.linkUrl.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage) _buildImage(),
              if (hasText || hasQuill || hasLink)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasText)
                        Text(
                          widget.text,
                          style: T.body.copyWith(
                            color: textColor,
                            height: 1.45,
                          ),
                        ),
                      if (hasText && hasQuill) const SizedBox(height: 10),
                      if (hasQuill)
                        DefaultTextStyle.merge(
                          style: TextStyle(color: bodyTextColor),
                          child: fq.QuillEditor.basic(
                            controller: _quillCtrl!,
                            config: fq.QuillEditorConfig(
                              showCursor: false,
                              autoFocus: false,
                              expands: false,
                              padding: EdgeInsets.zero,
                              embedBuilders: popupQuillEmbedBuilders,
                              customStyles: accent
                                  ? fq.DefaultStyles(
                                      paragraph: fq.DefaultTextBlockStyle(
                                        T.body.copyWith(
                                          color: bodyTextColor,
                                          height: 1.55,
                                        ),
                                        fq.HorizontalSpacing.zero,
                                        fq.VerticalSpacing.zero,
                                        fq.VerticalSpacing.zero,
                                        null,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if ((hasText || hasQuill) && hasLink)
                        const SizedBox(height: 12),
                      if (hasLink) _buildLinkButton(accent),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        placeholder: (ctx, _) => ColoredBox(
          color: C.bd,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (ctx, _, _) => ColoredBox(
          color: C.bd,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: C.tx2, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkButton(bool accent) {
    // 라벤더 배경 카드에서는 흰색 버튼, 회색 배경에서는 라벤더 버튼.
    final bg = accent ? Colors.white : C.lv;
    final fg = accent ? C.lvD : Colors.white;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openLink,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
        label: Text(
          widget.isKorean ? '자세히 보기' : 'View details',
          style: T.bodyBold.copyWith(color: fg),
        ),
      ),
    );
  }
}
