import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/project/data/template_repository.dart';
import '../features/project/domain/builtin_template.dart';
import '../features/project/domain/user_template.dart';

final templateRepositoryProvider =
    Provider<TemplateRepository>((ref) => TemplateRepository());

final userTemplateListProvider = StreamProvider<List<UserTemplate>>((ref) {
  return ref.watch(templateRepositoryProvider).watchTemplates();
});

final builtinTemplateListProvider = StreamProvider<List<BuiltinTemplate>>((ref) {
  return ref.watch(templateRepositoryProvider).watchBuiltinTemplates();
});
