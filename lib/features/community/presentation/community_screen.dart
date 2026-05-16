import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/app_config_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';
import '../../../providers/dm_provider.dart';
import '../../../providers/guestbook_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/ui_copy_provider.dart';
import '../../my/data/mori_service.dart';
import '../../project/data/public_project_service.dart';
import '../domain/comment_model.dart';
import '../domain/guestbook_entry.dart';
import 'gallery_detail_page.dart';
import '../domain/post_model.dart';

const _categoryKeys = ['all', 'daily', 'showcase', 'questions', 'pattern_share'];

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'community_header_subtitle',
      fallback: t.communityHeaderSubtitle,
    );
    final user = ref.watch(authStateProvider).valueOrNull;
    final currentUserModel = ref.watch(currentUserProvider).valueOrNull;
    final resolvedDisplayName = (currentUserModel?.displayName.isNotEmpty == true)
        ? currentUserModel!.displayName
        : (user?.displayName?.isNotEmpty == true ? user!.displayName! : '');
    final communityWriteEnabled =
        ref.watch(appConfigProvider).valueOrNull?.communityWriteEnabled ?? true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '커뮤니티' : 'Community',
                subtitle: subtitle,
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GuestbookSection(isKorean: isKorean),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GalleryPreviewSection(isKorean: isKorean),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // 이슈 #722 — 카테고리 칩 가로 스크롤 삭제 → 게시글 블록 내부 TabBar로 통합.
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CommunityPostsBlock(
                        isKorean: isKorean,
                        communityWriteEnabled: communityWriteEnabled,
                        user: user,
                        resolvedDisplayName: resolvedDisplayName,
                        onWriteSheet: (ctx, uid, name) =>
                            _showWriteSheet(ctx, ref, uid, name),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // 이슈 #725 — 함께뜨기 블록 (FORK 한국식). complete 도안 게이트 미구현 → 플레이스홀더.
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                    sliver: SliverToBoxAdapter(
                      child: _ForkSection(isKorean: isKorean),
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

  Future<void> _showWriteSheet(BuildContext context, WidgetRef ref, String uid, String authorName) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final authorPhotoUrl = ref.read(currentUserProvider).valueOrNull?.photoURL ?? '';
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = _categoryKeys.first;
    final images = <Uint8List>[];
    final files = <Map<String, dynamic>>[];
    var loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isKorean ? '새 글쓰기' : 'New post', style: T.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '제목' : 'Title')),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: isKorean ? '내용' : 'Content')),
              const SizedBox(height: 10),
              Text(isKorean ? '카테고리' : 'Category', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 6),
              MoriOptionChips<String>(
                options: _categoryKeys
                    .where((k) => k != 'all')
                    .map((k) => (value: k, label: _categoryLabel(k, isKorean)))
                    .toList(),
                selected: category,
                onSelected: (v) => setState(() => category = v),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: images.length >= 4
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 80, limit: 4 - images.length);
                        for (final file in picked) {
                          images.add(await file.readAsBytes());
                        }
                        setState(() {});
                      },
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(isKorean
                  ? (images.isEmpty ? '사진 추가' : '사진 추가 +${images.length}')
                  : (images.isEmpty ? 'Add photo' : 'Add photo +${images.length}')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
                  if (result == null) return;
                  for (final file in result.files) {
                    if (file.bytes != null) {
                      files.add({'name': file.name, 'bytes': file.bytes!});
                    }
                  }
                  setState(() {});
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text('${isKorean ? '파일 추가' : 'Attach file'} (${files.length})'),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(images[index], width: 76, height: 76, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
              if (files.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: files.map((file) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: C.bd),
                      ),
                      child: Text(file['name'] as String, style: T.caption.copyWith(color: C.tx2)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final missing = <String>[];
                          if (titleCtrl.text.trim().isEmpty) missing.add(isKorean ? '제목' : 'Title');
                          if (contentCtrl.text.trim().isEmpty) missing.add(isKorean ? '내용' : 'Content');
                          if (missing.isNotEmpty) {
                            await showMissingFieldsDialog(ctx, missing: missing, isKorean: isKorean);
                            return;
                          }
                          setState(() => loading = true);
                          try {
                            await runWithMoriLoadingDialog<void>(
                              ctx,
                              message: isKorean ? '게시하는 중입니다.' : 'Posting...',
                              subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                              task: () async {
                                final repo = ref.read(postRepositoryProvider);
                                final imageUrls = images.isEmpty ? <String>[] : await repo.uploadImages(uid, images);
                                final attachmentUrls = files.isEmpty ? <String>[] : await repo.uploadFiles(uid, files);
                                await repo.createPost(
                                  PostModel(
                                    id: '',
                                    uid: uid,
                                    authorName: authorName.isEmpty ? (isKorean ? '익명' : 'Anonymous') : authorName,
                                    authorPhotoUrl: authorPhotoUrl,
                                    category: category,
                                    title: titleCtrl.text.trim(),
                                    content: contentCtrl.text.trim(),
                                    imageUrls: imageUrls,
                                    attachmentUrls: attachmentUrls,
                                    attachmentNames: files.map((file) => file['name'] as String).toList(),
                                    createdAt: DateTime.now(),
                                  ),
                                );
                              },
                            );
                            if (ctx.mounted) {
                              showSavedSnackBar(ctx, message: isKorean ? '게시되었습니다.' : 'Posted.');
                              Navigator.pop(ctx);
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              showSaveErrorSnackBar(ctx, message: isKorean ? '게시에 실패했습니다.' : 'Failed to post.');
                              setState(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isKorean ? '게시하기' : 'Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

// 이슈 #722 — 게시글 블록 + 4탭 (전체/일상/작품자랑/질문) + 내부 ListView 스크롤.
class _CommunityPostsBlock extends ConsumerWidget {
  final bool isKorean;
  final bool communityWriteEnabled;
  final dynamic user;
  final String resolvedDisplayName;
  final void Function(BuildContext, String, String) onWriteSheet;

  const _CommunityPostsBlock({
    required this.isKorean,
    required this.communityWriteEnabled,
    required this.user,
    required this.resolvedDisplayName,
    required this.onWriteSheet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onWrite = !communityWriteEnabled
        ? () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isKorean
                    ? '현재 글쓰기가 제한됐어요.'
                    : 'Writing is currently restricted.'),
              ),
            )
        : user == null
            ? () => showLoginRequiredDialog(context,
                isKorean: isKorean, fromRoute: '/community')
            : () => onWriteSheet(context, user.uid as String, resolvedDisplayName);

    // 4개 탭: 전체 / 일상 / 작품자랑(완성=showcase) / 질문
    final tabKeys = const ['all', 'daily', 'showcase', 'questions'];
    final tabLabels = isKorean
        ? const ['전체', '일상', '작품자랑', '질문']
        : const ['All', 'Daily', 'Showcase', 'Questions'];

    return MoriBlockShell(
      label: isKorean ? '게시글' : 'Posts',
      icon: Icons.forum_rounded,
      accent: C.pkD,
      moreLabel: isKorean ? '글쓰기' : 'Write',
      onMoreTap: onWrite,
      bodyPadding: EdgeInsets.zero,
      child: DefaultTabController(
        length: tabKeys.length,
        child: Column(
          children: [
            TabBar(
              tabs: [for (final l in tabLabels) Tab(text: l)],
              indicatorColor: C.pkD,
              labelColor: C.pkD,
              unselectedLabelColor: C.mu,
              labelStyle: T.sm.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: T.sm.copyWith(fontWeight: FontWeight.w500),
              isScrollable: false,
              dividerColor: C.bd.withValues(alpha: 0.4),
            ),
            SizedBox(
              height: 480,
              child: TabBarView(
                children: [
                  for (final key in tabKeys)
                    _PostsList(
                      filter: key,
                      isKorean: isKorean,
                      onWrite: onWrite,
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

// 이슈 #722 — 탭별 게시글 ListView + 내부 스크롤 + 빈 상태 플레이스홀더.
class _PostsList extends ConsumerWidget {
  final String filter;
  final bool isKorean;
  final VoidCallback onWrite;

  const _PostsList({
    required this.filter,
    required this.isKorean,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider(filter));
    return postsAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: C.lv),
        ),
      ),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            isKorean ? '게시글을 불러오지 못했어요.' : 'Unable to load posts.',
            style: T.body,
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: _CommunityPostsPlaceholder(
                isKorean: isKorean, onWrite: onWrite),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: _PostRow(post: posts[i], isKorean: isKorean),
          ),
        );
      },
    );
  }
}

// 이슈 #715 — 게시글 블록 플레이스홀더 (빈 행 2~3개 + 안내 + 글쓰기 버튼).
class _CommunityPostsPlaceholder extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onWrite;
  const _CommunityPostsPlaceholder({required this.isKorean, required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: C.bd2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 8,
                        width: 200,
                        decoration: BoxDecoration(
                          color: C.bd2.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          isKorean ? '아직 게시글이 없어요. 첫 글을 남겨보세요.' : 'No posts yet. Be the first to write.',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu),
        ),
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton.icon(
            onPressed: onWrite,
            icon: Icon(Icons.edit_rounded, size: 16, color: C.lvD),
            label: Text(
              isKorean ? '글 작성하기' : 'Write a post',
              style: T.sm.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────
// 방명록 섹션
// ────────────────────────────────────────────

// 이슈 #722 — 방명록 MoriBlockShell + 자동 세로 스크롤 (Timer.periodic).
// 이슈 #717 추가 — 가로 → 세로 스크롤 전환.
class _GuestbookSection extends ConsumerStatefulWidget {
  final bool isKorean;
  const _GuestbookSection({required this.isKorean});

  @override
  ConsumerState<_GuestbookSection> createState() => _GuestbookSectionState();
}

class _GuestbookSectionState extends ConsumerState<_GuestbookSection> {
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _autoTimer;
  Timer? _resumeTimer;
  bool _userInteracting = false;

  static const Duration _tickInterval = Duration(seconds: 3);
  static const Duration _resumeDelay = Duration(seconds: 5);
  // 세로 스크롤: 한 줄 높이(약 36) + separator(약 13) ≈ 한 행 점프
  static const double _stepPixels = 48;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_tickInterval, (_) {
      if (!mounted || _userInteracting) return;
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.maxScrollExtent <= 0) return;
      final next = pos.pixels + _stepPixels;
      final target = next >= pos.maxScrollExtent ? 0.0 : next;
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onUserInteract() {
    _userInteracting = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (!mounted) return;
      _userInteracting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(guestbookListProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final currentUserModel = ref.watch(currentUserProvider).valueOrNull;
    final isKorean = widget.isKorean;

    return MoriBlockShell(
      label: isKorean ? '방명록 · 한 줄 인사' : 'Guestbook',
      icon: Icons.auto_awesome_rounded,
      accent: C.pkD,
      moreLabel: isKorean ? '작성하기' : 'Write',
      onMoreTap: () {
        if (user == null) {
          showLoginRequiredDialog(
            context,
            isKorean: isKorean,
            fromRoute: '/community',
          );
          return;
        }
        _showWriteSheet(context, ref, user.uid, currentUserModel);
      },
      bodyPadding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: entriesAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: CircularProgressIndicator(color: C.lv, strokeWidth: 2),
          ),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            isKorean ? '불러오지 못했어요.' : 'Unable to load.',
            style: T.caption.copyWith(color: C.mu),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Text(
                isKorean ? '첫 번째 인사를 남겨보세요!' : 'Leave the first greeting!',
                style: T.caption.copyWith(color: C.mu),
              ),
            );
          }
          // 이슈 #717 — 세로 스크롤 (블록 내부 고정 높이, 자동 세로 스크롤)
          return SizedBox(
            height: 180,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is UserScrollNotification ||
                    n is ScrollStartNotification) {
                  _onUserInteract();
                }
                return false;
              },
              child: ListView.separated(
                controller: _scrollCtrl,
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: entries.length,
                separatorBuilder: (_, _) => Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: C.bd2.withValues(alpha: 0.6),
                ),
                itemBuilder: (_, i) => _GuestbookEntryChip(
                  entry: entries[i],
                  isKorean: isKorean,
                  isOwn: user?.uid == entries[i].uid,
                  onDelete: () async {
                    await ref
                        .read(guestbookRepositoryProvider)
                        .deleteEntry(entries[i].id);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWriteSheet(
    BuildContext context,
    WidgetRef ref,
    String uid,
    dynamic userModel,
  ) {
    final isKoreanLocal = widget.isKorean;
    final displayName = (userModel?.displayName as String?) ?? '';
    final avatarUrl = (userModel?.photoURL as String?) ?? '';
    final ctrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GuestbookWriteSheet(
        uid: uid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isKorean: isKoreanLocal,
        ctrl: ctrl,
        ref: ref,
      ),
    );
  }
}

// 이슈 #717 — 세로 스크롤 한 줄 행 (가로 칩에서 전환).
class _GuestbookEntryChip extends StatelessWidget {
  final GuestbookEntry entry;
  final bool isKorean;
  final bool isOwn;
  final VoidCallback onDelete;

  const _GuestbookEntryChip({
    required this.entry,
    required this.isKorean,
    required this.isOwn,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: C.lvL,
            backgroundImage: entry.avatarUrl.isNotEmpty
                ? NetworkImage(entry.avatarUrl)
                : null,
            child: entry.avatarUrl.isEmpty
                ? Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName.characters.first.toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 10,
                      color: C.lvD,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${entry.displayName.isNotEmpty ? entry.displayName : (isKorean ? '익명' : 'Anonymous')}: ',
                    style: T.captionBold.copyWith(color: C.tx),
                  ),
                  TextSpan(
                    text: entry.message,
                    style: T.body.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            entry.timeAgoLocalized(isKorean: isKorean),
            style: T.caption.copyWith(color: C.mu, fontSize: 11),
          ),
          if (isOwn) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close, size: 14, color: C.mu),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestbookWriteSheet extends ConsumerStatefulWidget {
  final String uid;
  final String displayName;
  final String avatarUrl;
  final bool isKorean;
  final TextEditingController ctrl;
  final WidgetRef ref;

  const _GuestbookWriteSheet({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.isKorean,
    required this.ctrl,
    required this.ref,
  });

  @override
  ConsumerState<_GuestbookWriteSheet> createState() => _GuestbookWriteSheetState();
}

class _GuestbookWriteSheetState extends ConsumerState<_GuestbookWriteSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    await runWithMoriLoadingDialog<void>(
      context,
      message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
      subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
      task: () async {
        final entry = GuestbookEntry(
          id: '',
          uid: widget.uid,
          displayName: widget.displayName.isNotEmpty
              ? widget.displayName
              : (widget.isKorean ? '익명' : 'Anonymous'),
          avatarUrl: widget.avatarUrl,
          message: text.length > 100 ? text.substring(0, 100) : text,
          createdAt: DateTime.now(),
        );
        await ref.read(guestbookRepositoryProvider).addEntry(entry);
     
      },
    );

    if (!mounted) return;

    showSavedSnackBar(ScaffoldMessenger.of(context), message: widget.isKorean ? '방명록이 등록되었어요!' : 'Added to guestbook!');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: C.bd),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: C.bd2,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: C.pkD),
                const SizedBox(width: 8),
                Text(
                  widget.isKorean ? '방명록 작성' : 'Write in Guestbook',
                  style: T.h3,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: C.mu),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 100,
              maxLines: 2,
              style: T.body,
              decoration: InputDecoration(
                hintText: widget.isKorean
                    ? '한 줄 인사를 남겨보세요 (최대 100자)'
                    : 'Leave a short greeting (max 100 chars)',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: C.bd),
                ),
              ),
            ),
            const SizedBox(height: 14),
            MoriSaveButton(
              label: widget.isKorean ? '등록하기' : 'Submit',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────

String _categoryLabel(String key, bool isKorean) {
  switch (key) {
    case 'all':
      return isKorean ? '전체' : 'All';
    case 'daily':
      return isKorean ? '일상' : 'Daily';
    case 'showcase':
      return isKorean ? '작품자랑' : 'Showcase';
    case 'questions':
      return isKorean ? '질문' : 'Questions';
    case 'pattern_share':
      return isKorean ? '도안공유' : 'Pattern Share';
    default:
      return key;
  }
}

class _PostRow extends ConsumerStatefulWidget {
  final PostModel post;
  final bool isKorean;
  const _PostRow({required this.post, required this.isKorean});

  @override
  ConsumerState<_PostRow> createState() => _PostRowState();
}

class _PostRowState extends ConsumerState<_PostRow> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    _liked = user != null && widget.post.likedBy.contains(user.uid);
    _likeCount = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(_PostRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id || oldWidget.post.likeCount != widget.post.likeCount) {
      final user = ref.read(authStateProvider).valueOrNull;
      _liked = user != null && widget.post.likedBy.contains(user.uid);
      _likeCount = widget.post.likeCount;
    }
  }

  PostModel get post => widget.post;
  bool get isKorean => widget.isKorean;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(post.category);
    return InkWell(
      onTap: () => _showDetail(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _categoryLabel(post.category, isKorean),
                          style: T.caption.copyWith(color: categoryColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(post.title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(post.content, style: T.caption.copyWith(color: C.mu), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Builder(builder: (ctx) {
                        final me = ref.watch(authStateProvider).valueOrNull;
                        final isOther = me != null && me.uid != post.uid;
                        final hasPhoto = post.authorPhotoUrl.isNotEmpty;
                        final authorWidget = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasPhoto) ...[
                              ClipOval(
                                child: Image.network(
                                  post.authorPhotoUrl,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(width: 20, height: 20),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(post.authorName, style: T.caption.copyWith(
                              color: isOther ? C.lv : C.tx2,
                              fontWeight: FontWeight.w700,
                            )),
                            if (isOther) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.send_rounded, size: 12, color: C.lv),
                            ],
                          ],
                        );
                        if (isOther) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openDmFromListRow(ctx),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: authorWidget,
                            ),
                          );
                        }
                        return authorWidget;
                      }),
                      const SizedBox(width: 8),
                      Text(post.timeAgo, style: T.caption.copyWith(color: C.mu)),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final user = ref.read(authStateProvider).valueOrNull;
                          if (user == null) return;
                          setState(() {
                            _liked = !_liked;
                            _likeCount = _liked ? _likeCount + 1 : _likeCount - 1;
                          });
                          ref.read(postRepositoryProvider).toggleLike(post.id, user.uid);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: _liked ? C.pk : C.mu.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 3),
                            Text('$_likeCount', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline_rounded, size: 13, color: C.mu.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}', style: T.caption.copyWith(color: C.mu)),
                      Builder(builder: (ctx) {
                        final u = ref.watch(authStateProvider).valueOrNull;
                        if (u == null || u.uid != post.uid) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => _showAuthorMenu(ctx, ref),
                            child: Icon(Icons.more_vert_rounded, size: 14, color: C.mu),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrls.first,
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'showcase':
        return C.pkD;
      case 'questions':
        return C.lvD;
      case 'pattern_share':
        return C.lmD;
      default:
        return C.mu;
    }
  }

  Future<void> _openDmFromListRow(BuildContext context) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      showLoginRequiredDialog(context, isKorean: isKorean, fromRoute: '/community');
      return;
    }
    if (post.uid == user.uid) return;
    final profile = ref.read(currentUserProvider).valueOrNull;
    final myName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user.displayName ?? user.email ?? '');
    final roomId = await ref.read(dmRepositoryProvider).getOrCreateRoom(
      uid1: user.uid, name1: myName,
      uid2: post.uid, name2: post.authorName,
    );
    if (!context.mounted) return;
    context.push('/dm/$roomId');
  }

  void _showAuthorMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: C.lvD),
              title: Text(isKorean ? '수정' : 'Edit'),
              onTap: () { Navigator.pop(ctx); _editPost(context, ref); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              title: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: Colors.red.shade400)),
              onTap: () async {
                Navigator.pop(ctx);
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                  task: () async {
                    await ref.read(postRepositoryProvider).deletePost(post.id);
                  },
                );
                if (context.mounted) showSavedSnackBar(context, message: isKorean ? '삭제되었습니다.' : 'Deleted.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editPost(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: post.title);
    final contentCtrl = TextEditingController(text: post.content);
    final existingUrls = List<String>.from(post.imageUrls);
    final newImages = <Uint8List>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isKorean ? '게시글 수정' : 'Edit post', style: T.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isKorean ? '제목' : 'Title')),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: isKorean ? '내용' : 'Content')),
              const SizedBox(height: 10),
              if (existingUrls.isNotEmpty || newImages.isNotEmpty) ...[
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...existingUrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(e.value, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 152, cacheHeight: 152, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => existingUrls.removeAt(e.key)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      ...newImages.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(e.value, width: 76, height: 76, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => newImages.removeAt(e.key)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: (existingUrls.length + newImages.length) >= 4
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final limit = 4 - existingUrls.length - newImages.length;
                        final picked = await picker.pickMultiImage(imageQuality: 80, limit: limit);
                        for (final f in picked) { newImages.add(await f.readAsBytes()); }
                        setState(() {});
                      },
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(() { final count = existingUrls.length + newImages.length; return isKorean ? (count > 0 ? '사진 추가 +$count' : '사진 추가') : (count > 0 ? 'Add photo +$count' : 'Add photo'); }()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final t = titleCtrl.text.trim();
                    final c = contentCtrl.text.trim();
                    if (t.isEmpty || c.isEmpty) return;
                    await runWithMoriLoadingDialog<void>(
                      ctx,
                      message: isKorean ? '수정하는 중입니다.' : 'Updating...',
                      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                      task: () async {
                        final repo = ref.read(postRepositoryProvider);
                        final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
                        final uploaded = newImages.isEmpty ? <String>[] : await repo.uploadImages(uid, newImages);
                        await repo.updatePost(post.id, title: t, content: c, imageUrls: [...existingUrls, ...uploaded]);
                      },
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(isKorean ? '수정 완료' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (kIsWeb && user == null) {
      showLoginRequiredDialog(
        context,
        isKorean: isKorean,
        title: isKorean ? '게시글 상세는 로그인 후 볼 수 있어요' : 'Post details require login',
        fromRoute: '/community',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PostDetailSheet(post: post, categoryColor: _categoryColor(post.category), isKorean: isKorean),
    );
  }
}

class _PostDetailSheet extends ConsumerStatefulWidget {
  final PostModel post;
  final Color categoryColor;
  final bool isKorean;
  const _PostDetailSheet({required this.post, required this.categoryColor, required this.isKorean});

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  final _commentCtrl = TextEditingController();
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // Will be initialized after we have the user — use a placeholder here;
    // actual init happens in build where we have the user reference.
    _liked = false;
    _likeCount = widget.post.likeCount;
  }

  bool _likeInitialized = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sharePost() async {
    final post = widget.post;
    final isKorean = widget.isKorean;
    final lines = <String>[
      isKorean ? '[모리니트] 커뮤니티 게시글' : '[MoriKnit] Community Post',
      '${isKorean ? '제목' : 'Title'}: ${post.title}',
      '',
      post.content.length > 200 ? '${post.content.substring(0, 200)}...' : post.content,
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _openDm(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    // Don't DM yourself
    if (widget.post.uid == user.uid) return;
    final profile = ref.read(currentUserProvider).valueOrNull;
    final myName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user.displayName ?? user.email ?? '');
    final roomId = await ref.read(dmRepositoryProvider).getOrCreateRoom(
          uid1: user.uid,
          name1: myName,
          uid2: widget.post.uid,
          name2: widget.post.authorName,
        );
    if (!context.mounted) return;
    Navigator.pop(context); // close post detail sheet
    context.push('/dm/$roomId');
  }

  void _editPost(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: widget.post.title);
    final contentCtrl = TextEditingController(text: widget.post.content);
    final existingUrls = List<String>.from(widget.post.imageUrls);
    final newImages = <Uint8List>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.isKorean ? '게시글 수정' : 'Edit post', style: T.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: widget.isKorean ? '제목' : 'Title')),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: widget.isKorean ? '내용' : 'Content')),
              const SizedBox(height: 10),
              if (existingUrls.isNotEmpty || newImages.isNotEmpty) ...[
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...existingUrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(e.value, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 152, cacheHeight: 152, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => existingUrls.removeAt(e.key)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      ...newImages.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(e.value, width: 76, height: 76, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => newImages.removeAt(e.key)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: (existingUrls.length + newImages.length) >= 4
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final limit = 4 - existingUrls.length - newImages.length;
                        final picked = await picker.pickMultiImage(imageQuality: 80, limit: limit);
                        for (final f in picked) { newImages.add(await f.readAsBytes()); }
                        setState(() {});
                      },
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(() { final count = existingUrls.length + newImages.length; return widget.isKorean ? (count > 0 ? '사진 추가 +$count' : '사진 추가') : (count > 0 ? 'Add photo +$count' : 'Add photo'); }()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final t = titleCtrl.text.trim();
                    final c = contentCtrl.text.trim();
                    if (t.isEmpty || c.isEmpty) return;
                    await runWithMoriLoadingDialog<void>(
                      ctx,
                      message: widget.isKorean ? '수정하는 중입니다.' : 'Updating...',
                      subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                      task: () async {
                        final repo = ref.read(postRepositoryProvider);
                        final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
                        final uploaded = newImages.isEmpty ? <String>[] : await repo.uploadImages(uid, newImages);
                        await repo.updatePost(widget.post.id, title: t, content: c, imageUrls: [...existingUrls, ...uploaded]);
                      },
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(widget.isKorean ? '수정 완료' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final currentUserModel = ref.watch(currentUserProvider).valueOrNull;
    final resolvedName = (currentUserModel?.displayName.isNotEmpty == true)
        ? currentUserModel!.displayName
        : (user?.displayName?.isNotEmpty == true ? user!.displayName! : (widget.isKorean ? '익명' : 'Anonymous'));
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));
    final isMyPost = user?.uid == widget.post.uid;

    // Initialize like state once we have the user
    if (!_likeInitialized && user != null) {
      _liked = widget.post.likedBy.contains(user.uid);
      _likeCount = widget.post.likeCount;
      _likeInitialized = true;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                // ── 헤더: 카테고리 + 액션 버튼 ──────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _categoryLabel(widget.post.category, widget.isKorean),
                        style: T.caption.copyWith(color: widget.categoryColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.share_rounded, color: C.mu, size: 20),
                      onPressed: () => _sharePost(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (isMyPost)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 20),
                        onSelected: (val) async {
                          if (val == 'edit') {
                            _editPost(context, ref);
                          } else if (val == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(widget.isKorean ? '게시글 삭제' : 'Delete Post'),
                                content: Text(widget.isKorean ? '정말 삭제할까요? 복구할 수 없어요.' : 'Are you sure? This cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(widget.isKorean ? '취소' : 'Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(widget.isKorean ? '삭제' : 'Delete', style: const TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            if (!context.mounted) return;
                            await runWithMoriLoadingDialog<void>(
                              context,
                              message: widget.isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                              task: () async {
                                await ref.read(postRepositoryProvider).deletePost(widget.post.id);
                              },
                            );
                            if (context.mounted) {
                              showSavedSnackBar(context, message: widget.isKorean ? '삭제되었습니다.' : 'Deleted.');
                              Navigator.pop(context);
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Text(widget.isKorean ? '수정' : 'Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(widget.isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og)),
                          ),
                        ],
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, color: C.mu, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── 제목 ─────────────────────────────────────────
                Text(widget.post.title, style: T.h2),
                const SizedBox(height: 10),
                // ── 작성자 정보 ───────────────────────────────────
                if (!isMyPost)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.lv.withValues(alpha: 0.13)),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: widget.post.authorPhotoUrl.isNotEmpty
                                ? Image.network(widget.post.authorPhotoUrl, width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 80, cacheHeight: 80,
                                    errorBuilder: (_, _, _) => Container(color: C.lvL, child: Icon(Icons.person_rounded, color: C.lvD, size: 20)))
                                : Container(color: C.lvL, child: Icon(Icons.person_rounded, color: C.lvD, size: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.post.authorName, style: T.bodyBold),
                              Text(widget.post.timeAgo, style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openDm(context, ref),
                          icon: const Icon(Icons.send_rounded, size: 13),
                          label: Text(widget.isKorean ? '메시지' : 'Message', style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.lv,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: C.lvL,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? Icon(Icons.person_rounded, size: 14, color: C.lvD) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.post.authorName, style: T.caption.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('·', style: T.caption.copyWith(color: C.mu)),
                    const SizedBox(width: 6),
                    Text(widget.post.timeAgo, style: T.caption.copyWith(color: C.mu)),
                  ]),
                const Divider(height: 20),
                Text(widget.post.content, style: T.body),
                if (widget.post.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.post.imageUrls
                        .map(
                          (url) => GestureDetector(
                            onTap: () => _showFullImage(context, url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(url, width: 140, height: 140, fit: BoxFit.cover, cacheWidth: 280, cacheHeight: 280),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: user == null
                      ? null
                      : () async {
                          setState(() {
                            _liked = !_liked;
                            _likeCount += _liked ? 1 : -1;
                          });
                          await ref.read(postRepositoryProvider).toggleLike(widget.post.id, user.uid);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _liked ? C.pk.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _liked ? C.pk : C.bd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: C.pk),
                        const SizedBox(width: 6),
                        Text('$_likeCount', style: T.captionBold.copyWith(color: C.pk)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('${widget.isKorean ? '댓글' : 'Comments'} ${widget.post.commentCount}', style: T.captionBold.copyWith(color: C.mu)),
                const SizedBox(height: 8),
                commentsAsync.when(
                  data: (comments) => comments.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(widget.isKorean ? '첫 댓글을 남겨보세요.' : 'Be the first to comment.', style: T.caption.copyWith(color: C.mu)),
                        )
                      : Column(
                          children: comments
                              .map(
                                (comment) => _CommentTile(
                                  comment: comment,
                                  isMyComment: user?.uid == comment.uid,
                                  onDelete: () => ref.read(commentRepositoryProvider).deleteComment(widget.post.id, comment.id),
                                ),
                              )
                              .toList(),
                        ),
                  loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                  error: (error, _) => Text('$error', style: T.caption.copyWith(color: C.og)),
                ),
              ],
            ),
          ),
          if (user != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.bd))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: widget.isKorean ? '댓글을 입력해주세요...' : 'Write a comment...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: C.bd)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final text = _commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      final comment = CommentModel(
                        id: '',
                        uid: user.uid,
                        authorName: resolvedName,
                        content: text,
                        createdAt: DateTime.now(),
                      );
                      _commentCtrl.clear();
                      await ref.read(commentRepositoryProvider).addComment(widget.post.id, comment);
                      MoriService.earn(user.uid, amount: 100, reason: 'comment_post');
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: C.lvD, borderRadius: BorderRadius.circular(99)),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isMyComment;
  final VoidCallback onDelete;
  const _CommentTile({required this.comment, required this.isMyComment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: C.lvL,
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName.characters.first.toUpperCase() : '?',
              style: TextStyle(fontSize: 12, color: C.lvD, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.authorName, style: T.captionBold),
                    const SizedBox(width: 6),
                    Text(comment.timeAgo, style: T.caption.copyWith(color: C.mu)),
                    const Spacer(),
                    if (isMyComment) GestureDetector(onTap: onDelete, child: Icon(Icons.close, size: 14, color: C.mu)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: T.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
// 완성 갤러리 섹션
// ───────────────────────────────────────────

class _PublicProjectsSection extends ConsumerStatefulWidget {
  final bool isKorean;
  const _PublicProjectsSection({required this.isKorean});

  @override
  ConsumerState<_PublicProjectsSection> createState() => _PublicProjectsSectionState();
}

class _PublicProjectsSectionState extends ConsumerState<_PublicProjectsSection> {
  List<PublicProjectEntry>? _picks;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(publicProjectsProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: C.lvD, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.isKorean ? '지금 진행중인 프로젝트' : "Others' Projects",
                  style: T.bodyBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          projectsAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (entries) {
              if (entries.isEmpty) {
                return Text(
                  widget.isKorean ? '아직 공개된 프로젝트가 없어요.' : 'No projects yet.',
                  style: T.caption.copyWith(color: C.mu),
                );
              }
              // 최초 1회만 셔플 (리빌드 시 랜덤 변경 방지)
              if (_picks == null || _picks!.length != entries.length) {
                _picks = (List.of(entries)..shuffle(Random())).take(6).toList();
              }
              final picks = _picks!;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: picks.length,
                itemBuilder: (_, i) {
                  final entry = picks[i];
                  // coverPhotoUrl 우선, 없으면 단계로그 첫번째 사진, 없으면 placeholder
                  final imgUrl = entry.coverPhotoUrl.isNotEmpty
                      ? entry.coverPhotoUrl
                      : entry.photoUrls.firstWhere((u) => u.isNotEmpty, orElse: () => '');
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GalleryDetailPage(
                          entry: entry,
                          currentUid: ref.read(authStateProvider).valueOrNull?.uid ?? '',
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: C.gx,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.bd),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: imgUrl.isNotEmpty
                                  ? Image.network(
                                      imgUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: C.lvL,
                                        child: Icon(Icons.grid_view_rounded, color: C.lv),
                                      ),
                                    )
                                  : Container(
                                      color: C.lvL,
                                      child: Icon(Icons.grid_view_rounded, color: C.lv),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title,
                                  style: T.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 9, color: C.mu),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        entry.ownerName,
                                        style: T.caption.copyWith(fontSize: 9, color: C.mu),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// 이슈 #722 — 완성 갤러리 MoriBlockShell + 확장된 플레이스홀더.
class _GalleryPreviewSection extends ConsumerWidget {
  final bool isKorean;
  const _GalleryPreviewSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(publicProjectsProvider);
    final count = projectsAsync.maybeWhen(
      data: (p) => p.length,
      orElse: () => 0,
    );

    return MoriBlockShell(
      label: isKorean ? '완성 갤러리 $count' : '$count Gallery',
      icon: Icons.photo_library_rounded,
      accent: C.lv,
      bodyPadding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: projectsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.mu)),
        data: (entries) {
          if (entries.isEmpty) {
            return _GalleryEmptyPlaceholder(isKorean: isKorean);
          }
          return SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) =>
                  _GalleryCard(entry: entries[i], isKorean: isKorean),
            ),
          );
        },
      ),
    );
  }
}

// 이슈 #722 — 완성 갤러리 빈 플레이스홀더 (확장된 영역 + 풍부 안내).
class _GalleryEmptyPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _GalleryEmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, _) => Container(
              width: 110,
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 90,
                    decoration: BoxDecoration(
                      color: C.lvL,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: C.lv.withValues(alpha: 0.6),
                      size: 28,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 8,
                          width: 70,
                          decoration: BoxDecoration(
                            color: C.bd2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          width: 40,
                          decoration: BoxDecoration(
                            color: C.bd2.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            color: C.lv.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isKorean ? '아직 공개된 작품이 없어요' : 'No public projects yet',
          textAlign: TextAlign.center,
          style: T.bodyBold.copyWith(color: C.tx2),
        ),
        const SizedBox(height: 4),
        Text(
          isKorean
              ? '프로젝트를 완성하면 갤러리에 자랑할 수 있어요.\n첫 작품의 주인공이 되어보세요!'
              : 'Complete a project to showcase it here.\nBe the first to share!',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// 이슈 #725 — 함께뜨기 블록 (FORK 한국식). #629 게이트 미구현 → 임시 플레이스홀더.
class _ForkSection extends StatelessWidget {
  final bool isKorean;
  const _ForkSection({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: isKorean ? '함께뜨기' : 'Knit Together',
      icon: Icons.call_split_rounded,
      accent: C.lvD,
      moreLabel: isKorean ? '전체 보기' : 'See all',
      onMoreTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isKorean
              ? '함께뜨기 전체 보기는 곧 열려요.'
              : 'Knit-together gallery coming soon.'),
          duration: const Duration(seconds: 2),
        ));
      },
      bodyPadding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: _ForkEmptyPlaceholder(isKorean: isKorean),
    );
  }
}

class _ForkEmptyPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _ForkEmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, _) => Container(
              width: 110,
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 90,
                    decoration: BoxDecoration(
                      color: C.lvL,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: C.lvD.withValues(alpha: 0.6),
                      size: 28,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 8,
                          width: 70,
                          decoration: BoxDecoration(
                            color: C.bd2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          width: 40,
                          decoration: BoxDecoration(
                            color: C.bd2.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Icon(
            Icons.call_split_rounded,
            color: C.lvD.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isKorean ? '함께 뜰 도안이 곧 열려요' : 'Knit-together patterns coming soon',
          textAlign: TextAlign.center,
          style: T.bodyBold.copyWith(color: C.tx2),
        ),
        const SizedBox(height: 4),
        Text(
          isKorean
              ? '다른 니터의 완성된 도안을 가져와\n나만의 버전으로 함께 떠보세요.'
              : 'Fork another knitter\'s pattern\nand make it your own.',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GalleryCard extends ConsumerStatefulWidget {
  final PublicProjectEntry entry;
  final bool isKorean;
  const _GalleryCard({required this.entry, required this.isKorean});

  @override
  ConsumerState<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends ConsumerState<_GalleryCard> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    _isLiked = user != null && widget.entry.likedBy.contains(user.uid);
    _likeCount = widget.entry.likeCount;
  }

  @override
  void didUpdateWidget(_GalleryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.likeCount != widget.entry.likeCount) {
      final user = ref.read(authStateProvider).valueOrNull;
      _isLiked = user != null && widget.entry.likedBy.contains(user.uid);
      _likeCount = widget.entry.likeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return GestureDetector(
      onTap: () => _showDetail(context, user?.uid ?? ''),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: widget.entry.coverPhotoUrl.isNotEmpty
                  ? Container(
                      width: 110,
                      height: 80,
                      color: C.lvL,
                      child: Image.network(
                        widget.entry.coverPhotoUrl,
                        width: 110,
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.grid_view_rounded, color: C.lv),
                      ),
                    )
                  : Container(
                      width: 110,
                      height: 80,
                      color: C.lvL,
                      child: Icon(Icons.grid_view_rounded, color: C.lv),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.title,
                    style: T.caption.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: _isLiked ? C.pk : C.mu,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$_likeCount',
                        style: T.caption.copyWith(fontSize: 9, color: C.mu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, String currentUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryDetailPage(
          entry: widget.entry,
          currentUid: currentUid,
        ),
      ),
    );
  }
}

