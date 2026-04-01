import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/admin/data/admin_config_repository.dart';
import '../features/admin/domain/admin_config.dart';

final adminConfigRepositoryProvider = Provider<AdminConfigRepository>(
  (ref) => AdminConfigRepository(),
);

final adminConfigProvider = StreamProvider<AdminConfig>((ref) {
  return ref.watch(adminConfigRepositoryProvider).watchConfig();
});
