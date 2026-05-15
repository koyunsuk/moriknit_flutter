// @Deprecated (Phase E3, #687) — 옛 templates / builtin_templates 컬렉션 전용 provider.
// step_blueprints/kind=template 로 마이그레이션 완료. 신규 호출자는
// blueprintsByKindProvider(BlueprintKind.template) 사용. Phase E4에서 삭제 예정.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/project/data/template_repository.dart';
import '../features/project/domain/builtin_template.dart';
import '../features/project/domain/user_template.dart';

@Deprecated('Phase E3 (#687) — StepBlueprintRepository 사용. Phase E4에서 삭제 예정.')
final templateRepositoryProvider =
    Provider<TemplateRepository>((ref) => TemplateRepository());

@Deprecated('Phase E3 (#687) — blueprintsByKindProvider(BlueprintKind.template) 사용. Phase E4에서 삭제 예정.')
final userTemplateListProvider = StreamProvider<List<UserTemplate>>((ref) {
  ref.keepAlive();
  return ref.watch(templateRepositoryProvider).watchTemplates();
});

@Deprecated('Phase E3 (#687) — blueprintsByKindProvider(BlueprintKind.template) 사용. Phase E4에서 삭제 예정.')
final builtinTemplateListProvider = StreamProvider<List<BuiltinTemplate>>((ref) {
  final repo = ref.watch(templateRepositoryProvider);
  // #637/#639 — 신규 프리셋 자동 보완 (기존 seed된 환경에서도 누락된 것만 추가)
  // fire-and-forget: Stream 구독 중 비동기 체크. 중복 호출되어도 내부에서 skip.
  repo.ensureCropRaglanSeeded();
  repo.ensureDollPresetsSeeded();
  return repo.watchBuiltinTemplates();
});
