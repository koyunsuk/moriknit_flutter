import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _tocCtrl;
  late final TextEditingController _memoCtrl;

  String _coverUrl = '';
  bool _isFetching = false;
  bool _fetchFailed = false;

  // 메모 사진 (기존 URL + 새 로컬 파일)
  late List<String> _existingPhotoUrls;
  final List<File> _newPhotoFiles = [];

  @override
  void initState() {
    super.initState();
    final book = widget.initialBook;
    _isbnCtrl = TextEditingController(text: book?.isbn ?? '');
    _titleCtrl = TextEditingController(text: book?.title ?? '');
    _authorCtrl = TextEditingController(text: book?.author ?? '');
    _publisherCtrl = TextEditingController(text: book?.publisher ?? '');
    _publishYearCtrl = TextEditingController(text: book?.publishYear ?? '');
    _descriptionCtrl = TextEditingController(text: book?.description ?? '');
    _tocCtrl = TextEditingController(text: book?.tableOfContents ?? '');
    _memoCtrl = TextEditingController(text: book?.memo ?? '');
    _coverUrl = book?.coverUrl ?? '';
    _existingPhotoUrls = List<String>.from(book?.photoUrls ?? []);
  }

  @override
  void dispose() {
    _isbnCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _publisherCtrl.dispose();
    _publishYearCtrl.dispose();
    _descriptionCtrl.dispose();
    _tocCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMemoPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('즉시 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newPhotoFiles.add(File(picked.path)));
  }

  Future<void> _fetchBookInfo() async {
    final isbn = _isbnCtrl.text.trim().replaceAll('-', '').replaceAll(' ', '');
    if (isbn.isEmpty) return;

    setState(() {
      _isFetching = true;
      _fetchFailed = false;
    });

    try {
      final uri = Uri.https(
        'dapi.kakao.com',
        '/v3/search/book',
        {'target': 'isbn', 'query': isbn},
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK d4cbe1245d9164d1c948fda1b8eedbc3'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final documents = data['documents'] as List<dynamic>?;
        if (documents != null && documents.isNotEmpty) {
          final book = documents.first as Map<String, dynamic>;

          final title = book['title'] as String? ?? '';

          final authorsList = book['authors'] as List<dynamic>?;
          final author = authorsList != null && authorsList.isNotEmpty
              ? authorsList.map((a) => a.toString()).join(', ')
              : '';

          final publisher = book['publisher'] as String? ?? '';

          final datetime = book['datetime'] as String? ?? '';
          final yearMatch = RegExp(r'\d{4}').firstMatch(datetime);
          final publishYear = yearMatch?.group(0) ?? '';

          final coverUrl = book['thumbnail'] as String? ?? '';
          final kakaoDescription = book['contents'] as String? ?? '';

          setState(() {
            _titleCtrl.text = title;
            _authorCtrl.text = author;
            _publisherCtrl.text = publisher;
            _publishYearCtrl.text = publishYear;
            _coverUrl = coverUrl;
            _descriptionCtrl.text = kakaoDescription;
            _fetchFailed = false;
          });

          // Google Books API로 전체 소개 + 목차 가져오기
          await _fetchGoogleBooks(isbn);
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

  Future<void> _fetchGoogleBooks(String isbn) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/books/v1/volumes',
        {'q': 'isbn:$isbn'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return;

      final volumeInfo = (items.first as Map<String, dynamic>)['volumeInfo']
          as Map<String, dynamic>?;
      if (volumeInfo == null) return;

      final fullDescription = volumeInfo['description'] as String? ?? '';
      final toc = volumeInfo['tableOfContents'] as String? ?? '';

      setState(() {
        if (fullDescription.isNotEmpty) {
          _descriptionCtrl.text = fullDescription;
        }
        if (toc.isNotEmpty && _tocCtrl.text.isEmpty) {
          _tocCtrl.text = toc;
        }
      });
    } catch (_) {
      // Google Books 실패 시 Kakao 정보 유지
    }
  }

  Future<void> _save(BuildContext context) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final isbn = _isbnCtrl.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? 'ISBN을 입력해주세요.' : 'Please enter ISBN.')),
      );
      return;
    }
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '도서 제목을 입력해주세요.' : 'Please enter book title.')),
      );
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final isEdit = widget.initialBook != null;
    final baseBook = (isEdit ? widget.initialBook! : BookModel.empty(uid: uid)).copyWith(
      isbn: isbn,
      title: title,
      author: _authorCtrl.text.trim(),
      publisher: _publisherCtrl.text.trim(),
      publishYear: _publishYearCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      tableOfContents: _tocCtrl.text.trim(),
      memo: _memoCtrl.text.trim(),
    );

    final navigator = Navigator.of(context);
    late BookModel savedBook;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(bookRepositoryProvider);
          final bookId = baseBook.id.isNotEmpty
              ? baseBook.id
              : FirebaseFirestore.instance.collection('books').doc().id;

          // 새 메모 사진 업로드
          final uploadedUrls = <String>[];
          for (int i = 0; i < _newPhotoFiles.length; i++) {
            final storageRef = FirebaseStorage.instance
                .ref('books/$uid/$bookId/memo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await storageRef.putFile(_newPhotoFiles[i]);
            uploadedUrls.add(await storageRef.getDownloadURL());
          }

          final allPhotoUrls = [..._existingPhotoUrls, ...uploadedUrls];
          savedBook = baseBook.copyWith(
            coverUrl: _coverUrl,
            photoUrls: allPhotoUrls,
          );
          if (isEdit) {
            await repo.updateBook(savedBook);
          } else {
            await repo.createBook(savedBook);
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '저장됐어요.' : 'Saved.');
      navigator.pop(savedBook);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
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
                SectionTitle(title: isKorean ? 'ISBN *' : 'ISBN *'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _isbnCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isKorean ? '예: 9788991987012' : 'e.g. 9788991987012',
                          hintText: isKorean ? 'ISBN-10 또는 ISBN-13' : 'ISBN-10 or ISBN-13',
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

                // 표지 미리보기 (Kakao에서 불러온 경우만)
                if (_coverUrl.isNotEmpty) ...[
                  SectionTitle(title: isKorean ? '표지' : 'Cover'),
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
                SectionTitle(title: isKorean ? '출판사 (선택)' : 'Publisher (optional)'),
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
                SectionTitle(title: isKorean ? '출판연도 (선택)' : 'Publish Year (optional)'),
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

                // 책 소개
                SectionTitle(title: isKorean ? '책 소개 (선택)' : 'Description (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: isKorean ? '책 소개, 서평...' : 'Book description...',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 목차
                SectionTitle(title: isKorean ? '목차 (선택)' : 'Table of Contents (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tocCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: isKorean ? '목차 내용...' : 'Table of contents...',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 메모 + 사진
                SectionTitle(title: isKorean ? '메모 (선택)' : 'Memo (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isKorean ? '참고 페이지, 활용 방법...' : 'Reference pages, usage notes...',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // 메모 사진 그리드
                _MemoPhotoGrid(
                  existingUrls: _existingPhotoUrls,
                  newFiles: _newPhotoFiles,
                  isKorean: isKorean,
                  onAdd: _pickMemoPhoto,
                  onRemoveExisting: (i) =>
                      setState(() => _existingPhotoUrls.removeAt(i)),
                  onRemoveNew: (i) =>
                      setState(() => _newPhotoFiles.removeAt(i)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoPhotoGrid extends StatelessWidget {
  final List<String> existingUrls;
  final List<File> newFiles;
  final bool isKorean;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;

  const _MemoPhotoGrid({
    required this.existingUrls,
    required this.newFiles,
    required this.isKorean,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final total = existingUrls.length + newFiles.length;
    final items = <Widget>[
      // 기존 URL 사진
      for (int i = 0; i < existingUrls.length; i++)
        _PhotoThumb(
          child: Image.network(existingUrls[i], fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded)),
          onRemove: () => onRemoveExisting(i),
        ),
      // 새 로컬 사진
      for (int i = 0; i < newFiles.length; i++)
        _PhotoThumb(
          child: Image.file(newFiles[i], fit: BoxFit.cover),
          onRemove: () => onRemoveNew(i),
        ),
      // 추가 버튼
      GestureDetector(
        onTap: onAdd,
        child: Container(
          decoration: BoxDecoration(
            color: C.lvL,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.lv.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: C.lv, size: 28),
              const SizedBox(height: 4),
              Text(isKorean ? '사진 추가' : 'Add Photo',
                  style: TextStyle(fontSize: 11, color: C.lvD)),
            ],
          ),
        ),
      ),
    ];

    if (total == 0 && items.length == 1) {
      // 추가 버튼만 있을 때 한 행에 표시
      return SizedBox(
        height: 90,
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: items.first,
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items,
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
