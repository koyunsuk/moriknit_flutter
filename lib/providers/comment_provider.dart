import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/comment_repository.dart';
import '../features/community/domain/comment_model.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

final commentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  return ref.watch(commentRepositoryProvider).watchComments(postId);
});
