import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/post_provider.dart';
import '../domain/post_model.dart';
import '../domain/youtube_embed.dart';
import 'widgets/youtube_embed_card.dart';

/// 이슈 #747 — 커뮤니티 글쓰기 풀스크린 에디터.
/// 이슈 #748 — 유튜브 링크 첨부 (썸네일 임베드).
///
/// 사용 진입점: [pushCommunityPostEditor].
class CommunityPostEditorScreen extends ConsumerStatefulWidget {
  final String uid;
  final String authorName;
  /// 이슈 #771 — 작성자 핸들(@아이디) 스냅샷.
  final String authorHandle;
  final String authorPhotoUrl;
  /// #761 — 작성자 등급 스냅샷 ('free' | 'pro' | 'business').
  final String authorTier;
  final Map<String, String>? authorSocialSnapshot;

  /// 카테고리 초기값. 비어 있으면 `daily`.
  final String initialCategory;

  const CommunityPostEditorScreen({
    super.key,
    required this.uid,
    required this.authorName,
    this.authorHandle = '',
    this.authorPhotoUrl = '',
    this.authorTier = 'free',
    this.authorSocialSnapshot,
    this.initialCategory = 'daily',
  });

  @override
  ConsumerState<CommunityPostEditorScreen> createState() =>
      _CommunityPostEditorScreenState();
}

const _editorCategoryKeys = ['daily', 'showcase', 'questions', 'pattern_share'];

String _editorCategoryLabel(String key, bool isKorean) {
  switch (key) {
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

class _CommunityPostEditorScreenState
    extends ConsumerState<CommunityPostEditorScreen> {
  final _titleCtrl = TextEditingController();
  final fq.QuillController _quillCtrl = fq.QuillController.basic();
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();

  late String _category;
  final List<Uint8List> _images = [];
  final List<Map<String, dynamic>> _files = [];
  final List<String> _youtubeUrls = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _category = _editorCategoryKeys.contains(widget.initialCategory)
        ? widget.initialCategory
        : _editorCategoryKeys.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  // ----- 사진/파일/유튜브 -----

  /// #780 — '사진 추가' 탭: 갤러리 직접 (카메라는 첨부 슬롯의 별도 아이콘으로 노출).
  Future<void> _addImages(bool isKorean) async {
    if (_images.length >= 4) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
      limit: 4 - _images.length,
    );
    for (final file in picked) {
      if (_images.length >= 4) break;
      _images.add(await file.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  /// #780 — 카메라 즉시 촬영 (첨부 슬롯의 카메라 아이콘에서 호출).
  Future<void> _captureImageFromCamera() async {
    if (_images.length >= 4) return;
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (shot == null) return;
    _images.add(await shot.readAsBytes());
    if (mounted) setState(() {});
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.bytes != null) {
        _files.add({'name': file.name, 'bytes': file.bytes!});
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _addYoutubeLink(bool isKorean) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isKorean ? '유튜브 링크 추가' : 'Add YouTube link',
            style: T.h3,
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: isKorean ? '유튜브 URL' : 'YouTube URL',
              hintText: 'https://www.youtube.com/watch?v=...',
              filled: true,
              fillColor: C.gx,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isKorean ? '취소' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(isKorean ? '추가' : 'Add'),
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty) return;
    final videoId = extractYoutubeVideoId(result);
    if (videoId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKorean
                ? '올바른 유튜브 링크가 아닙니다.'
                : 'Not a valid YouTube URL.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _youtubeUrls.add(youtubeWatchUrl(videoId));
    });
  }

  // ----- 미리보기 -----

  void _openPreview(bool isKorean) {
    final plainBody = _quillCtrl.document.toPlainText().trim();
    final title = _titleCtrl.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        isKorean ? '미리보기' : 'Preview',
                        style: T.h3,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty) ...[
                            Text(title, style: T.h2),
                            const SizedBox(height: 10),
                          ],
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: C.bd),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: plainBody.isEmpty
                                ? Text(
                                    isKorean
                                        ? '본문이 비어 있습니다.'
                                        : 'Body is empty.',
                                    style: T.caption.copyWith(color: C.mu),
                                  )
                                : fq.QuillEditor.basic(
                                    controller: _quillCtrl,
                                    config: const fq.QuillEditorConfig(
                                      showCursor: false,
                                      autoFocus: false,
                                      expands: false,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                          ),
                          if (_youtubeUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final url in _youtubeUrls)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: YoutubeEmbedCard(url: url),
                              ),
                          ],
                          if (_images.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _images
                                  .map(
                                    (b) => ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        b,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ----- 게시 -----

  Future<void> _submit(bool isKorean) async {
    final missing = <String>[];
    if (_titleCtrl.text.trim().isEmpty) {
      missing.add(isKorean ? '제목' : 'Title');
    }
    final plain = _quillCtrl.document.toPlainText().trim();
    if (plain.isEmpty) {
      missing.add(isKorean ? '본문' : 'Body');
    }
    if (missing.isNotEmpty) {
      await showMissingFieldsDialog(
        context,
        missing: missing,
        isKorean: isKorean,
      );
      return;
    }

    final delta = _quillCtrl.document.toDelta();
    final deltaJson = jsonEncode(delta.toJson());

    setState(() => _loading = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '게시하는 중입니다.' : 'Posting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          final repo = ref.read(postRepositoryProvider);
          final imageUrls = _images.isEmpty
              ? <String>[]
              : await repo.uploadImages(widget.uid, _images);
          final attachmentUrls = _files.isEmpty
              ? <String>[]
              : await repo.uploadFiles(widget.uid, _files);
          await repo.createPost(
            PostModel(
              id: '',
              uid: widget.uid,
              authorName: widget.authorName.isEmpty
                  ? (isKorean ? '익명' : 'Anonymous')
                  : widget.authorName,
              authorHandle: widget.authorHandle,
              authorPhotoUrl: widget.authorPhotoUrl,
              authorTier: widget.authorTier,
              category: _category,
              title: _titleCtrl.text.trim(),
              content: plain,
              bodyFormat: PostBodyFormat.quill,
              bodyDelta: deltaJson,
              imageUrls: imageUrls,
              attachmentUrls: attachmentUrls,
              attachmentNames:
                  _files.map((f) => f['name'] as String).toList(),
              youtubeUrls: List<String>.from(_youtubeUrls),
              authorSocialSnapshot: widget.authorSocialSnapshot,
              createdAt: DateTime.now(),
            ),
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        context,
        message: isKorean ? '게시되었습니다.' : 'Posted.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        context,
        message: isKorean ? '게시에 실패했습니다.' : 'Failed to post.',
      );
      setState(() => _loading = false);
    }
  }

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(isKorean ? '새 글쓰기' : 'Write Post', style: T.h3),
        actions: [
          IconButton(
            icon: Icon(Icons.preview_rounded, color: C.tx),
            tooltip: isKorean ? '미리보기' : 'Preview',
            onPressed: () => _openPreview(isKorean),
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  SectionTitle(title: isKorean ? '제목' : 'Title'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    style: T.h3.copyWith(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: isKorean
                          ? '제목을 입력해주세요'
                          : 'Enter a title',
                      filled: true,
                      fillColor: C.gx,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 카테고리
                  SectionTitle(title: isKorean ? '카테고리' : 'Category'),
                  const SizedBox(height: 6),
                  MoriOptionChips<String>(
                    options: _editorCategoryKeys
                        .map((k) => (
                              value: k,
                              label: _editorCategoryLabel(k, isKorean),
                            ))
                        .toList(),
                    selected: _category,
                    onSelected: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 18),

                  // 본문 — 리치 텍스트
                  SectionTitle(title: isKorean ? '본문' : 'Body'),
                  const SizedBox(height: 6),
                  _QuillToolbar(controller: _quillCtrl),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minHeight: 220),
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.bd),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: fq.QuillEditor(
                      controller: _quillCtrl,
                      focusNode: _editorFocus,
                      scrollController: _editorScroll,
                      config: fq.QuillEditorConfig(
                        placeholder: isKorean
                            ? '본문을 입력해주세요...'
                            : 'Write your post...',
                        scrollable: true,
                        autoFocus: false,
                        expands: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // #780 — 첨부 액션 1줄 컴팩트 (사진 / 파일 / 유튜브).
                  Row(
                    children: [
                      Expanded(
                        child: _CompactAttachButton(
                          icon: Icons.add_photo_alternate_rounded,
                          label: _images.isEmpty
                              ? (isKorean ? '사진' : 'Photo')
                              : '${isKorean ? '사진' : 'Photo'} +${_images.length}',
                          onTap: _images.length >= 4 ? null : () => _addImages(isKorean),
                          color: C.lv,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _CompactAttachButton(
                          icon: Icons.attach_file_rounded,
                          label: _files.isEmpty
                              ? (isKorean ? '파일' : 'File')
                              : '${isKorean ? '파일' : 'File'} ${_files.length}',
                          onTap: _addFiles,
                          color: C.lvD,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _CompactAttachButton(
                          icon: Icons.smart_display_rounded,
                          label: isKorean ? '유튜브' : 'YouTube',
                          onTap: () => _addYoutubeLink(isKorean),
                          color: C.pkD,
                        ),
                      ),
                    ],
                  ),

                  // #780 — 첨부 사진 그리드. 첫 슬롯은 카메라 즉시 촬영 버튼.
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // #780 (재수정) — 카메라 즉시 촬영 슬롯: 아이콘만 (텍스트 제거)
                      if (_images.length < 4)
                        GestureDetector(
                          onTap: _captureImageFromCamera,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: C.lvL,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: C.lv.withValues(alpha: 0.35)),
                            ),
                            child: Icon(Icons.photo_camera_rounded, color: C.lvD, size: 36),
                          ),
                        ),
                      // 첨부된 사진들
                      for (int index = 0; index < _images.length; index++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _images[index],
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(
                                    () => _images.removeAt(index),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // 첨부 파일 칩
                  if (_files.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_files.length, (index) {
                        final name = _files[index]['name'] as String;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: C.bd),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_rounded,
                                size: 14,
                                color: C.mu,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: T.caption.copyWith(color: C.tx2),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _files.removeAt(index),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: C.mu,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],

                  // 유튜브 임베드 미리보기
                  if (_youtubeUrls.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SectionTitle(title: isKorean ? '유튜브' : 'YouTube'),
                    const SizedBox(height: 6),
                    Column(
                      children: List.generate(_youtubeUrls.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: YoutubeEmbedCard(
                            url: _youtubeUrls[i],
                            onRemove: () => setState(
                              () => _youtubeUrls.removeAt(i),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _submit(isKorean),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isKorean ? '게시하기' : 'Post'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 도구바 — flutter_quill SimpleToolbar 기반.
/// 굵게/기울임/밑줄/헤딩/리스트/링크/색상.
class _QuillToolbar extends StatelessWidget {
  final fq.QuillController controller;
  const _QuillToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.bd),
      ),
      child: fq.QuillSimpleToolbar(
        controller: controller,
        config: const fq.QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          showAlignmentButtons: false,
          showBackgroundColorButton: true,
          showColorButton: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: false,
          showSmallButton: false,
          showInlineCode: false,
          showSubscript: false,
          showSuperscript: false,
          showHeaderStyle: true,
          showListBullets: true,
          showListNumbers: true,
          showListCheck: false,
          showCodeBlock: false,
          showQuote: false,
          showIndent: false,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showDirection: false,
          showSearchButton: false,
          showFontFamily: false,
          showFontSize: false,
          showDividers: true,
          showClearFormat: false,
        ),
      ),
    );
  }
}

/// #780 — 컴팩트 첨부 버튼 (사진/파일/유튜브 1줄 가로 배치용).
class _CompactAttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _CompactAttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: disabled ? C.bd.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled ? C.bd : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: disabled ? C.mu : color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: T.caption.copyWith(
                    color: disabled ? C.mu : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 풀스크린 에디터로 진입합니다. 기존 BottomSheet 진입점 대체.
Future<void> pushCommunityPostEditor(
  BuildContext context, {
  required String uid,
  required String authorName,
  String authorHandle = '',
  String authorPhotoUrl = '',
  String authorTier = 'free',
  Map<String, String>? authorSocialSnapshot,
  String initialCategory = 'daily',
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => CommunityPostEditorScreen(
        uid: uid,
        authorName: authorName,
        authorHandle: authorHandle,
        authorPhotoUrl: authorPhotoUrl,
        authorTier: authorTier,
        authorSocialSnapshot: authorSocialSnapshot,
        initialCategory: initialCategory,
      ),
    ),
  );
}
