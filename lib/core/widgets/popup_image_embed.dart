// 이슈 #835 — 어드민 팝업/배너 본문 리치 텍스트 안에 삽입되는 이미지 임베드 빌더.
//
// flutter_quill_extensions 패키지를 추가하지 않고도 image embed 를 렌더링하기 위해
// EmbedBuilder 를 직접 구현합니다.
//
// - 어드민 편집기/미리보기 (read-only 가능)
// - 사용자 측 _MoriAnnouncementDialog (read-only Quill)
//
// 양쪽에서 동일한 빌더를 재사용하여 UI 일관성을 보장합니다.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;

import '../theme/app_colors.dart';

/// Quill 본문 image embed (`{"insert": {"image": "<url>"}}`) 렌더링 빌더.
///
/// CachedNetworkImage 를 사용하여 네트워크 이미지를 캐시하고
/// 로딩/에러 상태에 일관된 placeholder 를 표시합니다.
class PopupImageEmbedBuilder extends fq.EmbedBuilder {
  const PopupImageEmbedBuilder();

  @override
  String get key => fq.BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, fq.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    final url = raw is String ? raw : raw?.toString() ?? '';
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          width: double.infinity,
          placeholder: (ctx, _) => AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: C.bd,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          errorWidget: (ctx, _, _) => AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: C.bd,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: C.tx2, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 어드민/사용자 양쪽에서 공유하는 임베드 빌더 목록.
const List<fq.EmbedBuilder> popupQuillEmbedBuilders = <fq.EmbedBuilder>[
  PopupImageEmbedBuilder(),
];
