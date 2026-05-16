import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/book_provider.dart';
import '../domain/book_model.dart';
import 'book_detail_screen.dart';
import 'book_input_screen.dart';

class BookListScreen extends ConsumerWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookListProvider);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final books = booksAsync.valueOrNull ?? const <BookModel>[];

    return AppShellScaffold(
      title: isKorean ? '나의 도서' : 'My Books',
      subtitle: isKorean ? '참고 도서 라이브러리' : 'Reference book library',
      aboveBody: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SummaryCard_Detail(
          headers: [isKorean ? '전체' : 'Total'],
          rows: [
            LibrarySummaryRowData(
              badge: isKorean ? '도서' : 'Books',
              badgeColor: C.lvD,
              values: ['${books.length}'],
              valueColors: [C.tx],
            ),
          ],
          addLabel: isKorean ? '추가' : 'Add',
          onAdd: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookInputScreen()),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (booksAsync.isLoading)
                          AsyncLoadingFriendly(
                            isKorean: isKorean,
                            onRetry: () => ref.invalidate(bookListProvider),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          )
                        else if (booksAsync.hasError)
                          AsyncDelayedFriendly(
                            isKorean: isKorean,
                            onRetry: () => ref.invalidate(bookListProvider),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
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
                                  builder: (_) => BookDetailScreen(book: book),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

}

class _BookCard extends StatelessWidget {
  final BookModel book;
  final bool isKorean;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.isKorean,
    required this.onTap,
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
            Icon(Icons.chevron_right, color: C.mu, size: 20),
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
