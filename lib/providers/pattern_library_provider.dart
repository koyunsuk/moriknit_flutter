import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pattern_library/data/pattern_file_repository.dart';
import '../features/pattern_library/domain/pattern_file.dart';

final patternFileRepositoryProvider = Provider<PatternFileRepository>(
  (ref) => PatternFileRepository(),
);

final patternFilesProvider = StreamProvider<List<PatternFile>>(
  (ref) => ref.watch(patternFileRepositoryProvider).watchFiles(),
);
