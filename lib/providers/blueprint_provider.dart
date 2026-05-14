// lib/providers/blueprint_provider.dart
//
// 이슈 #687 (Phase G) — StepBlueprint Provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/blueprint/data/step_blueprint_repository.dart';
import '../features/blueprint/domain/step_blueprint.dart';
import '../features/blueprint/domain/step_blueprint_unit.dart';
import 'auth_provider.dart';

final stepBlueprintRepositoryProvider = Provider<StepBlueprintRepository>(
  (ref) => StepBlueprintRepository(),
);

/// 단일 청사진 구독.
final blueprintByIdProvider =
    StreamProvider.family<StepBlueprint?, String>((ref, id) {
  return ref.watch(stepBlueprintRepositoryProvider).watch(id);
});

/// 청사진의 units subcollection.
final blueprintUnitsProvider =
    StreamProvider.family<List<StepBlueprintUnit>, String>((ref, blueprintId) {
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchUnits(blueprintId);
});

/// 내 청사진 (ownerUid == current user).
final myBlueprintsProvider = StreamProvider<List<StepBlueprint>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchByOwner(user.uid);
});

/// 마켓플레이스 노출 청사진.
final marketplaceBlueprintsProvider =
    StreamProvider<List<StepBlueprint>>((ref) {
  return ref.watch(stepBlueprintRepositoryProvider).watchMarketplace();
});

/// 종류별 청사진 (template / technique_guide 등).
final blueprintsByKindProvider =
    StreamProvider.family<List<StepBlueprint>, BlueprintKind>((ref, kind) {
  return ref.watch(stepBlueprintRepositoryProvider).watchByKind(kind);
});
