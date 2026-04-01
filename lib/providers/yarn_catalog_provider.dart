import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/yarn/data/yarn_catalog_repository.dart';

final yarnCatalogRepositoryProvider = Provider<YarnCatalogRepository>((ref) => YarnCatalogRepository());

final yarnMaterialsProvider = StreamProvider<List<YarnMaterialItem>>((ref) {
  return ref.watch(yarnCatalogRepositoryProvider).watchMaterials();
});

final yarnColorsProvider = StreamProvider<List<YarnColorItem>>((ref) {
  return ref.watch(yarnCatalogRepositoryProvider).watchColors();
});
