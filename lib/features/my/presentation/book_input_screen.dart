import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/book_provider.dart';
import '../domain/book_model.dart';

class BookInputScreen extends ConsumerStatefulWidget {
  final BookModel? initialBook;

  const BookInputScreen({super.key, this.initialBook});

  @override
  ConsumerState<BookInputScreen> createState() => _BookInputScreenState();
}

class _BookInputScreenState extends ConsumerState<BookInputScreen> {
  late final TextEditingController _isbnCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _publisherCtrl;
  late final TextEditingController _publishYearCtrl;
  late final TextEditingController _memoCtrl;

  String _coverUrl = '';
  bool _isFetching = false;
  bool _fetchFailed = false;

  @override
  void initState() {
    super.initState();
    final book = widget.initialBook;
    _isbnCtrl = TextEditingController(text: book?.isbn ?? '');
    _titleCtrl = TextEditingController(text: book?.title ?? '');
    _authorCtrl = TextEditingController(text: book?.author ?? '');
    _publisherCtrl = TextEditingController(text: book?.publisher ?? '');
    _publishYearCtrl = TextEditingController(text: book?.publishYear ?? '');
    _memoCtrl = TextEditingController(text: book?.memo ?? '');
    _coverUrl = book?.coverUrl ?? '';
  }

  @override
  void dispose() {
    _isbnCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _publisherCtrl.dispose();
    _publishYearCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBookInfo() async {
    final isbn = _isbnCtrl.text.trim().replaceAll('-', '').replaceAll(' ', '');
    if (isbn.isEmpty) return;

    setState(() {
      _isFetching = true;
      _fetchFailed = false;
    });

    try {
      final url =
          'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final key = 'ISBN:$isbn';
        if (data.containsKey(key)) {
          final bookData = data[key] as Map<String, dynamic>;

          final title = bookData['title'] as String? ?? '';

          // 저자
          final authorsList = bookData['authors'] as List<dynamic>?;
          final author = authorsList != null && authorsList.isNotEmpty
              ? (authorsList.first as Map<String, dynamic>)['name'] as String? ?? ''
              : '';

          // 출판사
          final publishersList = bookData['publishers'] as List<dynamic>?;
          final publisher = publishersList != null && publishersList.isNotEmpty
              ? (publishersList.first as Map<String, dynamic>)['name'] as String? ?? ''
              : '';

          // 출판연도
          final publishDate = bookData['publish_date'] as String? ?? '';
          // 연도만 추출 (예: "2020" or "March 2020" -> "2020")
          final yearMatch = RegExp(r'\d{4}').firstMatch(publishDate);
          final publishYear = yearMatch?.group(0) ?? publishDate;

          // 표지
          final covers = bookData['cover'] as Map<String, dynamic>?;
          final coverUrl = covers?['large'] as String? ??
              covers?['medium'] as String? ??
              covers?['small'] as String? ??
              '';

          setState(() {
            _titleCtrl.text = title;
            _authorCtrl.text = author;
            _publisherCtrl.text = publisher;
            _publishYearCtrl.text = publishYear;
            _coverUrl = coverUrl;
            _fetchFailed = false;
          });
        } else {
          setState(() => _fetchFailed = true);
        }
      } else {
        setState(() => _fetchFailed = true);
      }
    } catch (_) {
      setState(() => _fetchFailed = true);
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _save(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final isbn = _isbnCtrl.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isKorean ? 'ISBN을 입력해주세요.' : 'Please enter ISBN.')),
      );
      return;
    }
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isKorean ? '도서 제목을 입력해주세요.' : 'Please enter book title.')),
      );
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final isEdit = widget.initialBook != null;
    final book = (isEdit ? widget.initialBook! : BookModel.empty(uid: uid))
        .copyWith(
      isbn: isbn,
      title: title,
      author: _authorCtrl.text.trim(),
      publisher: _publisherCtrl.text.trim(),
      publishYear: _publishYearCtrl.text.trim(),
      coverUrl: _coverUrl,
      memo: _memoCtrl.text.trim(),
    );

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(bookRepositoryProvider);
          if (isEdit) {
            await repo.updateBook(book);
          } else {
            await repo.createBook(book);
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '저장됐어요.' : 'Saved.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialBook == null
              ? (isKorean ? '도서 추가' : 'Add Book')
              : (isKorean ? '도서 수정' : 'Edit Book'),
          style: T.h3,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _save(context),
              child: Text(isKorean ? '저장' : 'Save'),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ISBN 입력 + 검색
                SectionTitle(
                    title: isKorean ? 'ISBN *' : 'ISBN *'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _isbnCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean
                              ? '예: 9788991987012'
                              : 'e.g. 9788991987012',
                          hintText: isKorean
                              ? 'ISBN-10 또는 ISBN-13'
                              : 'ISBN-10 or ISBN-13',
                          fillColor: C.gx,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isFetching ? null : _fetchBookInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isFetching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isKorean ? '검색' : 'Search',
                                style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (_fetchFailed) ...[
                  const SizedBox(height: 6),
                  Text(
                    isKorean
                        ? 'ISBN으로 도서 정보를 찾을 수 없어요. 직접 입력해주세요.'
                        : 'Book not found. Please enter manually.',
                    style: T.caption.copyWith(color: C.og),
                  ),
                ],
                const SizedBox(height: 20),

                // 표지 미리보기
                if (_coverUrl.isNotEmpty) ...[
                  SectionTitle(
                      title: isKorean ? '표지 미리보기' : 'Cover Preview'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _coverUrl,
                      height: 160,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 제목
                SectionTitle(title: isKorean ? '제목 *' : 'Title *'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '도서 제목' : 'Book title',
                    hintText: isKorean ? '예: 쉬운 코바늘 뜨개질' : 'e.g. The Art of Knitting',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 저자
                SectionTitle(title: isKorean ? '저자 (선택)' : 'Author (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _authorCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '저자명' : 'Author name',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 출판사
                SectionTitle(
                    title: isKorean ? '출판사 (선택)' : 'Publisher (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _publisherCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '출판사명' : 'Publisher name',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 출판연도
                SectionTitle(
                    title: isKorean ? '출판연도 (선택)' : 'Publish Year (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _publishYearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '예: 2020' : 'e.g. 2020',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 메모
                SectionTitle(
                    title: isKorean ? '메모 (선택)' : 'Memo (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText:
                        isKorean ? '참고 페이지, 활용 방법...' : 'Reference pages, usage notes...',
                    fillColor: C.gx,
                    filled: true,
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
