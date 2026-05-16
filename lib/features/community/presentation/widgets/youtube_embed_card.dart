import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/youtube_embed.dart';

/// 이슈 #748 — 게시글 본문에 첨부된 유튜브 링크를 16:9 썸네일 카드로 표시합니다.
/// 탭하면 외부 브라우저(또는 유튜브 앱)로 시청 페이지를 엽니다.
class YoutubeEmbedCard extends StatelessWidget {
  final String url;
  final VoidCallback? onRemove;

  const YoutubeEmbedCard({
    super.key,
    required this.url,
    this.onRemove,
  });

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final videoId = extractYoutubeVideoId(url);
    if (videoId == null) {
      // 잘못된 URL은 일반 링크 표시로 폴백.
      return _InvalidUrlChip(url: url, onRemove: onRemove);
    }

    final thumbUrl = youtubeThumbnailUrl(videoId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: _open,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: C.bd,
                  border: Border.all(color: C.bd),
                ),
                child: Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: C.lvL,
                    child: Center(
                      child: Icon(
                        Icons.smart_display_rounded,
                        size: 48,
                        color: C.lvD,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 가운데 재생 아이콘 오버레이.
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // 하단 URL 라벨.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InvalidUrlChip extends StatelessWidget {
  final String url;
  final VoidCallback? onRemove;
  const _InvalidUrlChip({required this.url, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: C.mu),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.caption.copyWith(color: C.tx2),
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 16, color: C.mu),
            ),
        ],
      ),
    );
  }
}
