import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/post_repository.dart';
import '../features/community/domain/post_model.dart';

const String communityAllCategory = 'all';

final postRepositoryProvider = Provider<PostRepository>((ref) => PostRepository());

final selectedCategoryProvider = StateProvider<String>((ref) => communityAllCategory);

final postsProvider = StreamProvider.family<List<PostModel>, String>((ref, category) {
  return ref.watch(postRepositoryProvider).watchPosts(category: category);
});
