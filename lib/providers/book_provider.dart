import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/my/data/book_repository.dart';
import '../features/my/domain/book_model.dart';
import 'auth_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final bookListProvider = StreamProvider<List<BookModel>>((ref) {
  ref.keepAlive();
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(bookRepositoryProvider).watchBooks();
});

final bookDetailProvider =
    FutureProvider.family<BookModel?, String>((ref, id) async {
  if (id.isEmpty) return null;
  return ref.read(bookRepositoryProvider).getBook(id);
});
