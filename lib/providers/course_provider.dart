import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/course/data/course_repository.dart';
import '../features/course/domain/course_item.dart';

final courseRepositoryProvider = Provider<CourseRepository>((_) => CourseRepository());

final courseProvider = StreamProvider<List<CourseItem>>((ref) {
  return ref.watch(courseRepositoryProvider).watchPublished();
});

final allCoursesAdminProvider = StreamProvider<List<CourseItem>>((ref) {
  return ref.watch(courseRepositoryProvider).watchAll();
});

final randomCoursePicksProvider = FutureProvider<List<CourseItem>>((ref) async {
  final all = await ref.read(courseRepositoryProvider).fetchAllPublished();
  all.shuffle();
  return all.take(4).toList();
});
