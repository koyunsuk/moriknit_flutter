import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/data/editorial_repository.dart';
import '../features/home/domain/editorial_post.dart';

final editorialRepositoryProvider =
    Provider((ref) => EditorialRepository());

final editorialLatestProvider =
    StreamProvider.family<List<EditorialPost>, String>((ref, type) {
  return ref.watch(editorialRepositoryProvider).watchLatestByType(type);
});

final editorialByTypeProvider =
    StreamProvider.family<List<EditorialPost>, String>((ref, type) {
  return ref.watch(editorialRepositoryProvider).watchByType(type);
});

final editorialAllAdminProvider =
    StreamProvider<List<EditorialPost>>((ref) {
  return ref.watch(editorialRepositoryProvider).watchAll();
});
