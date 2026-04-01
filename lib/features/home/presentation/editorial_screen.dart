import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/editorial_provider.dart';
import '../domain/editorial_post.dart';

class EditorialScreen extends ConsumerWidget {
  final String type; // 'letter' | 'tips' | 'trending' | 'youtube'
  final String title; // screen title
  final bool isKorean;

  const EditorialScreen({
    super.key,
    required this.type,
    required this.title,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(editorialByTypeProvider(type));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(title, style: T.h3),
        backgroundColor: C.bg,
        elevation: 0,
        foregroundColor: C.tx,
      ),
      body: postsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text(isKorean ? '게시된 글이 아직 없어요.' : 'No posts yet.', style: T.caption.copyWith(color: C.mu))),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                isKorean ? '게시된 글이 아직 없어요.' : 'No posts yet.',
                style: T.caption.copyWith(color: C.mu),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _EditorialPostCard(post: posts[i], isKorean: isKorean),
          );
        },
      ),
    );
  }
}

class _EditorialPostCard extends StatelessWidget {
  final EditorialPost post;
  final bool isKorean;

  const _EditorialPostCard({required this.post, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    if (post.type == 'youtube' && post.youtubeVideoId.isNotEmpty) {
      return _YoutubeCard(post: post, isKorean: isKorean);
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: T.bodyBold),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: T.body.copyWith(color: C.tx2, height: 1.6),
          ),
          if (post.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${post.createdAt!.year}.${post.createdAt!.month.toString().padLeft(2, '0')}.${post.createdAt!.day.toString().padLeft(2, '0')}',
              style: T.caption.copyWith(color: C.mu),
            ),
          ],
        ],
      ),
    );
  }
}

class _YoutubeCard extends StatelessWidget {
  final EditorialPost post;
  final bool isKorean;

  const _YoutubeCard({required this.post, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final thumbUrl =
        'https://img.youtube.com/vi/${post.youtubeVideoId}/mqdefault.jpg';
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=${post.youtubeVideoId}'),
        mode: LaunchMode.externalApplication,
      ),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    thumbUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: double.infinity,
                      height: 180,
                      color: C.og.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: C.og,
                        size: 48,
                      ),
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title, style: T.bodyBold),
                    if (post.content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.content,
                        style: T.caption.copyWith(color: C.mu),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
