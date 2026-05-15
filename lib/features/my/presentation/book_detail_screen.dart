import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/book_provider.dart';
import '../../../providers/project_provider.dart';
import '../../project/domain/project_model.dart';
import '../domain/book_model.dart';
import 'book_input_screen.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  late BookModel _book;
  bool _fetchingDescription = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  Future<void> _delete() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isKorean ? '도서 삭제' : 'Delete Book', style: T.h3),
        content: Text(
          isKorean ? '"${_book.title}" 을 삭제할까요?' : 'Delete "${_book.title}"?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            child: Text(isKorean ? '삭제' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(bookRepositoryProvider).deleteBook(_book.id),
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '삭제됐어요.' : 'Deleted.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final friendly = (msg.contains('인터넷') || msg.contains('TimeoutException'))
          ? (isKorean ? '인터넷 연결을 확인해 주세요' : 'Check your internet connection')
          : msg;
      showSaveErrorSnackBar(messenger, message: friendly);
    }
  }

  Future<void> _showProjectPicker() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final projects = ref.read(projectListProvider).valueOrNull ?? [];

    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean ? '연결할 프로젝트가 없어요.' : 'No projects to link.'),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProjectPickerSheet(
        book: _book,
        projects: projects,
        isKorean: isKorean,
      ),
    );
  }

  void _showPhotoFull(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카카오 API로 서평 불러오기
  Future<void> _fetchDescription() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    if (_book.isbn.isEmpty) return;
    setState(() => _fetchingDescription = true);

    try {
      final uri = Uri.https(
        'dapi.kakao.com',
        '/v3/search/book',
        {'target': 'isbn', 'query': _book.isbn},
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK d4cbe1245d9164d1c948fda1b8eedbc3'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final documents = data['documents'] as List<dynamic>?;
        if (documents != null && documents.isNotEmpty) {
          final bookData = documents.first as Map<String, dynamic>;
          final description = bookData['contents'] as String? ?? '';
          if (description.isNotEmpty && mounted) {
            final updated = _book.copyWith(description: description);
            await ref.read(bookRepositoryProvider).updateBook(updated);
            setState(() => _book = updated);
            if (mounted) {
              showSavedSnackBar(
                ScaffoldMessenger.of(context),
                message: isKorean ? '서평을 불러왔어요.' : 'Description fetched.',
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isKorean ? '서평 정보가 없어요.' : 'No description available.')),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isKorean ? '서평을 불러오지 못했어요.' : 'Failed to fetch description.')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingDescription = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showProjectPicker,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(isKorean ? '프로젝트 연결' : 'Link to Project'),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '도서 상세' : 'Book Detail',
                    subtitle: isKorean ? '참고 도서 정보' : 'Book reference details',
                    trailing: [
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: C.tx),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final updated = await Navigator.push<BookModel>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookInputScreen(initialBook: _book),
                              ),
                            );
                            if (updated != null && mounted) {
                              setState(() => _book = updated);
                            }
                          } else if (value == 'delete') {
                            await _delete();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(isKorean ? '수정' : 'Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              isKorean ? '삭제' : 'Delete',
                              style: TextStyle(color: C.og),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // 표지 이미지 (크게)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _book.coverUrl.isNotEmpty
                      ? Image.network(
                          _book.coverUrl,
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (_, _, _) => _CoverPlaceholder(),
                        )
                      : _CoverPlaceholder(),
                ),
                const SizedBox(height: 20),

                // 제목
                Text(
                  _book.title.isNotEmpty
                      ? _book.title
                      : (isKorean ? '(제목 없음)' : '(No title)'),
                  style: T.h2.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),

                // 저자 / 출판사 / 연도
                if (_book.author.isNotEmpty || _book.publisher.isNotEmpty || _book.publishYear.isNotEmpty)
                  Text(
                    [
                      if (_book.author.isNotEmpty) _book.author,
                      if (_book.publisher.isNotEmpty) _book.publisher,
                      if (_book.publishYear.isNotEmpty) _book.publishYear,
                    ].join(' · '),
                    style: T.body.copyWith(color: C.mu, fontSize: 14),
                  ),
                const SizedBox(height: 4),

                // ISBN
                Text(
                  'ISBN: ${_book.isbn}',
                  style: T.caption.copyWith(color: C.mu, fontSize: 11),
                ),
                const SizedBox(height: 24),

                // 책 소개 (description)
                if (_book.description.isNotEmpty) ...[
                  SectionTitle(title: isKorean ? '책 소개' : 'Description'),
                  const SizedBox(height: 8),
                  _ScrollableTextBox(text: _book.description, maxHeight: 400),
                  const SizedBox(height: 20),
                ] else if (_book.isbn.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: _fetchingDescription ? null : _fetchDescription,
                    icon: _fetchingDescription
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(isKorean ? '책 소개 불러오기' : 'Fetch Description'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.lvD,
                      side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 목차 (tableOfContents)
                if (_book.tableOfContents.isNotEmpty) ...[
                  SectionTitle(title: isKorean ? '목차' : 'Table of Contents'),
                  const SizedBox(height: 8),
                  _ScrollableTextBox(text: _book.tableOfContents, maxHeight: 360),
                  const SizedBox(height: 20),
                ],

                // 메모
                if (_book.memo.isNotEmpty) ...[
                  SectionTitle(title: isKorean ? '메모' : 'Memo'),
                  const SizedBox(height: 8),
                  _ScrollableTextBox(text: _book.memo, maxHeight: 160),
                  const SizedBox(height: 20),
                ],

                // 메모 사진
                if (_book.photoUrls.isNotEmpty) ...[
                  SectionTitle(title: isKorean ? '사진 메모' : 'Photo Memo'),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: _book.photoUrls.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _showPhotoFull(_book.photoUrls[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _book.photoUrls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: C.lvL,
                            child: Icon(Icons.broken_image_rounded, color: C.mu),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 빈 placeholder (설명/목차/메모 없을 때)
                if (_book.description.isEmpty &&
                    _book.tableOfContents.isEmpty &&
                    _book.memo.isEmpty &&
                    _book.photoUrls.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.bd),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_rounded, color: C.mu, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          isKorean ? '수정에서 설명과 메모를 추가할 수 있어요.' : 'Add description and notes in Edit.',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 스크롤 가능한 텍스트 박스 ─────────────────────────────────────────────────

class _ScrollableTextBox extends StatelessWidget {
  final String text;
  final double maxHeight;

  const _ScrollableTextBox({required this.text, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Text(
            text,
            style: T.body.copyWith(height: 1.8, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ── 표지 플레이스홀더 ─────────────────────────────────────────────────────────

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.menu_book_rounded, color: C.lv, size: 72),
    );
  }
}

// ── 프로젝트 연결 BottomSheet ────────────────────────────────────────────────

class _ProjectPickerSheet extends ConsumerWidget {
  final BookModel book;
  final List<ProjectModel> projects;
  final bool isKorean;

  const _ProjectPickerSheet({
    required this.book,
    required this.projects,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              isKorean ? '연결할 프로젝트 선택' : 'Select Project to Link',
              style: T.h3,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: projects.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (_, i) {
                final project = projects[i];
                final isLinked = project.referenceBookId == book.id;
                return ListTile(
                  leading: Icon(
                    Icons.folder_copy_rounded,
                    color: isLinked ? C.lv : C.mu,
                  ),
                  title: Text(
                    project.title,
                    style: T.body.copyWith(
                      fontWeight: isLinked ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: isLinked
                      ? Icon(Icons.check_circle_rounded, color: C.lv)
                      : null,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await runWithMoriLoadingDialog<void>(
                        context,
                        message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                        task: () => ref
                            .read(projectRepositoryProvider)
                            .updateProject(
                              project.copyWith(
                                referenceBookId: isLinked ? '' : book.id,
                              ),
                            ),
                      );
                      if (context.mounted) {
                        showSavedSnackBar(
                          messenger,
                          message: isLinked
                              ? (isKorean ? '연결이 해제됐어요.' : 'Unlinked.')
                              : (isKorean ? '프로젝트에 연결됐어요.' : 'Linked to project.'),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showSaveErrorSnackBar(messenger, message: '$e');
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
