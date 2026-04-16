import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/book_provider.dart';
import '../domain/book_model.dart';
import 'book_input_screen.dart';

class BookListScreen extends ConsumerWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookListProvider);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final books = booksAsync.valueOrNull ?? const <BookModel>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '나의 도서' : 'My Books',
                subtitle: isKorean ? '참고 도서 라이브러리' : 'Reference book library',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  WorkspaceSummaryBar(
                    stats: [
                      WorkStat('${books.length}', isKorean ? '전체' : 'Total',
                          color: C.lvD),
                    ],
                    addLabel: isKorean ? '추가' : 'Add',
                    onAdd: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BookInputScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (booksAsync.isLoading)
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                              child:
                                  CircularProgressIndicator(color: C.lv),
                            ),
                          )
                        else if (books.isEmpty)
                          MoriEmptyState(
                            icon: Icons.menu_book_rounded,
                            iconColor: C.lmD,
                            title: isKorean
                                ? '아직 도서가 없어요'
                                : 'No books yet',
                            subtitle: isKorean
                                ? 'ISBN으로 도서를 추가해 보세요'
                                : 'Add a book using ISBN',
                            buttonLabel: isKorean ? '도서 추가' : 'Add Book',
                            onAction: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BookInputScreen()),
                            ),
                          )
                        else ...[
                          Text(
                            isKorean ? '내 도서 목록' : 'My Book List',
                            style: T.bodyBold,
                          ),
                          const SizedBox(height: 8),
                          ...books.map(
                            (book) => _BookCard(
                              book: book,
                              isKorean: isKorean,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookInputScreen(initialBook: book),
                                ),
                              ),
                              onDelete: () =>
                                  _confirmDelete(context, ref, book, isKorean),
                            ),
                          ),
                        ],
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      BookModel book, bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isKorean ? '도서 삭제' : 'Delete Book', style: T.h3),
        content: Text(
          isKorean
              ? '"${book.title}" 을 삭제할까요?'
              : 'Delete "${book.title}"?',
          style: T.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: C.og),
            child: Text(isKorean ? '삭제' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(bookRepositoryProvider).deleteBook(book.id),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '삭제됐어요.' : 'Deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context),
            message: '$e');
      }
    }
  }
}

class _BookCard extends StatelessWidget {
  final BookModel book;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: C.glassCard,
        child: Row(
          children: [
            // 표지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 72,
                child: book.coverUrl.isNotEmpty
                    ? Image.network(
                        book.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _BookCoverPlaceholder(),
                      )
                    : _BookCoverPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title.isNotEmpty
                        ? book.title
                        : (isKorean ? '(제목 없음)' : '(No title)'),
                    style: T.bodyBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(book.author,
                        style: T.caption.copyWith(color: C.mu),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (book.publisher.isNotEmpty ||
                      book.publishYear.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (book.publisher.isNotEmpty) book.publisher,
                        if (book.publishYear.isNotEmpty) book.publishYear,
                      ].join(' · '),
                      style: T.caption.copyWith(color: C.mu, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'ISBN: ${book.isbn}',
                    style: T.caption
                        .copyWith(color: C.mu, fontSize: 10),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: C.mu, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                if (value == 'edit') onTap();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(isKorean ? '수정' : 'Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(isKorean ? '삭제' : 'Delete',
                      style: TextStyle(color: C.og)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.lvL,
      child: Icon(Icons.menu_book_rounded, color: C.lv, size: 28),
    );
  }
}
