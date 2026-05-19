// lib/providers/blueprint_provider.dart
//
// 이슈 #687 (Phase G) — StepBlueprint Provider.
// 이슈 #687 (Phase I-A) — Legacy pattern_charts fallback provider 추가.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/system_users.dart';
import '../features/blueprint/data/step_blueprint_repository.dart';
import '../features/blueprint/domain/step_blueprint.dart';
import '../features/blueprint/domain/step_blueprint_unit.dart';
import '../features/pattern/data/pattern_repository.dart';
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

/// #853 — 모리니트 공식 청사진 (ownerUid == moriknit_system).
///
/// 어드민 콘솔에서 "시스템 자산으로 전환"한 도안/템플릿이 표시됨.
/// 사용자 라이브러리의 "모리니트 공식" 섹션에서 사용.
final moriknitOfficialBlueprintsProvider =
    StreamProvider<List<StepBlueprint>>((ref) {
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchByOwner(SystemUsers.moriknitUid);
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

// ── Phase I-A : 신규 컬렉션 + 기존 pattern_charts fallback 합쳐 노출 ────────

/// 단일 청사진 — 신규 컬렉션 우선 + 기존 pattern_charts 어댑터 fallback.
///
/// 도안 라이브러리·상세 화면에서 사용. 마이그레이션 안 한 데이터도 동일하게 표시.
/// 어댑터 변환된 결과는 메모리 전용 — Firestore에 저장되지 않음.
final blueprintByIdWithLegacyProvider =
    FutureProvider.family<StepBlueprint?, String>((ref, id) async {
  final repo = ref.watch(stepBlueprintRepositoryProvider);
  final patternRepo = ref.watch(patternRepositoryProvider);
  return repo.getOrAdaptLegacy(id, patternRepo: patternRepo);
});

/// 내 청사진 목록 — step_blueprints + pattern_charts 어댑터 보충 (중복 제거).
///
/// 도안 라이브러리 화면에서 사용. step_blueprints의 청사진과 마이그레이션 안 된
/// pattern_charts의 어댑터를 합쳐 단일 리스트로 노출한다. 같은 id는 신규가 우선.
/// 협업자(members) 로 참여중인 청사진도 함께 포함된다(#687).
final myBlueprintsWithLegacyProvider =
    StreamProvider<List<StepBlueprint>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  final repo = ref.watch(stepBlueprintRepositoryProvider);
  final patternRepo = ref.watch(patternRepositoryProvider);
  return repo.watchMyBlueprintsWithLegacy(
    ownerUid: user.uid,
    patternRepo: patternRepo,
  );
});

/// 협업자 본인이 들어가 있는 청사진 (members 키에 uid).
///
/// 라이브러리 노출 검증·디버그용. myBlueprintsWithLegacyProvider 가 이미 포함하지만
/// 별도 화면(예: 협업 도안 모음)에서 호출 가능.
final blueprintsAsMemberProvider =
    StreamProvider<List<StepBlueprint>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(stepBlueprintRepositoryProvider).watchByMember(user.uid);
});

/// 협업자 본인의 역할 조회 — 도안 상세에서 편집 가능 여부 판별.
///
/// 작자(ownerUid == self) → null 반환 (역할 개념 외, 모든 권한 보유).
/// 협업자 → BlueprintMemberRole.
/// 비참여자 → null.
final blueprintMyRoleProvider =
    FutureProvider.family<BlueprintMemberRole?, String>(
        (ref, blueprintId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final bp = await ref
      .watch(stepBlueprintRepositoryProvider)
      .get(blueprintId);
  if (bp == null) return null;
  if (bp.ownerUid == user.uid) return null; // owner — 별도 처리
  return bp.members[user.uid];
});

// ── #791 함께 뜨기(Knit-Along) providers ─────────────────────────────────

/// 함께 뜨기 그룹 — forkCount > 0 인 원본 도안 목록 (커뮤니티 _ForkSection 노출).
final knitAlongGroupsProvider = StreamProvider<List<StepBlueprint>>((ref) {
  return ref.watch(stepBlueprintRepositoryProvider).watchKnitAlongGroups();
});

/// 내가 참여 중인 함께 뜨기(= fork 한 청사진) — 홈 "내 함께뜨기" 블록.
final myKnitAlongsProvider = StreamProvider<List<StepBlueprint>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <StepBlueprint>[]);
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchMyKnitAlongs(user.uid);
});

/// 특정 원본 도안에 대해 함께 뜨고 있는 사용자들의 청사진(참여자 목록).
final knitAlongParticipantsProvider =
    StreamProvider.family<List<StepBlueprint>, String>((ref, originId) {
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchKnitAlongParticipants(originId);
});

// ── #792 테스터 그룹 권한 providers ──────────────────────────────────────

/// 내가 작성한 도안 — 테스터 대시보드용.
final myAuthoredBlueprintsProvider = StreamProvider<List<StepBlueprint>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <StepBlueprint>[]);
  return ref
      .watch(stepBlueprintRepositoryProvider)
      .watchMyAuthoredBlueprints(user.uid);
});
