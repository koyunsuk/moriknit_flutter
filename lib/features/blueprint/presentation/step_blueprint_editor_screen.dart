// lib/features/blueprint/presentation/step_blueprint_editor_screen.dart
//
// 이슈 #687 (Phase J) — 단계 편집 UI.
//
// 사용자가 청사진(StepBlueprint)의 그룹(섹션) + 단계(StepBlueprintUnit)를
// 직접 추가/수정/삭제/재배열 할 수 있는 통합 편집 화면.
//
// 진입 경로:
//   - pattern_detail_screen 점세개 메뉴 → "단계 편집"
//   - Routes.stepBlueprintEditor (`/blueprints/:id/edit`)
//
// 모드:
//   - 작자(ownerUid == self) 또는 admin/editor 협업자: 모든 편집 가능
//   - 그 외: 진입 차단 (안내 후 pop)
//
// 자동/수동 태그 보존:
//   - ChartToUnitsConverter 가 생성한 단계: tags = [auto:chart] / [auto:narrative]
//   - 사용자가 편집하면 tags 에서 auto:* 제거 후 [manual] 추가.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/step_unit/step_unit_tag.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../domain/step_blueprint.dart';
import '../domain/step_blueprint_unit.dart';
import '../domain/step_unit_groupmeta.dart';

class StepBlueprintEditorScreen extends ConsumerWidget {
  const StepBlueprintEditorScreen({
    super.key,
    required this.blueprintId,
  });

  final String blueprintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final blueprintAsync = ref.watch(blueprintByIdProvider(blueprintId));
    final unitsAsync = ref.watch(blueprintUnitsProvider(blueprintId));

    return AppShellScaffold(
      title: isKorean ? '단계 편집' : 'Edit steps',
      subtitle: isKorean
          ? '그룹과 단계를 직접 편집해요'
          : 'Edit groups and steps directly',
      showBackButton: true,
      body: blueprintAsync.when(
        loading: () => AsyncLoadingFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(blueprintByIdProvider(blueprintId)),
        ),
        error: (e, _) => AsyncDelayedFriendly(
          isKorean: isKorean,
          onRetry: () => ref.invalidate(blueprintByIdProvider(blueprintId)),
        ),
        data: (blueprint) {
          if (blueprint == null) {
            return _EmptyState(
              isKorean: isKorean,
              msg: isKorean ? '청사진을 찾을 수 없어요.' : 'Blueprint not found.',
            );
          }
          final isOwner =
              currentUid != null && blueprint.ownerUid == currentUid;
          final myRole = blueprint.members[currentUid];
          final canEdit = isOwner ||
              myRole == BlueprintMemberRole.admin ||
              myRole == BlueprintMemberRole.editor;
          if (!canEdit) {
            return _EmptyState(
              isKorean: isKorean,
              msg: isKorean
                  ? '편집 권한이 없어요.'
                  : 'You do not have edit permission.',
            );
          }

          return unitsAsync.when(
            loading: () => AsyncLoadingFriendly(
              isKorean: isKorean,
              onRetry: () =>
                  ref.invalidate(blueprintUnitsProvider(blueprintId)),
            ),
            error: (e, _) => AsyncDelayedFriendly(
              isKorean: isKorean,
              onRetry: () =>
                  ref.invalidate(blueprintUnitsProvider(blueprintId)),
            ),
            data: (units) => _EditorBody(
              blueprint: blueprint,
              units: units,
              isKorean: isKorean,
            ),
          );
        },
      ),
    );
  }
}

// ─── _EditorBody ──────────────────────────────────────────────────────────────

class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({
    required this.blueprint,
    required this.units,
    required this.isKorean,
  });

  final StepBlueprint blueprint;
  final List<StepBlueprintUnit> units;
  final bool isKorean;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  // 미할당(그룹 미지정) 그룹의 고정 id.
  static const String _unassignedGroupId = '__unassigned__';

  @override
  Widget build(BuildContext context) {
    final ko = widget.isKorean;
    final groups = widget.blueprint.groups;
    final units = widget.units;

    // 그룹별로 단계를 묶기. unitIds 순서 우선, 누락된 단계는 마지막에 추가.
    final unitMap = {for (final u in units) u.id: u};
    final assignedUnitIds = <String>{};

    final List<_GroupBucket> buckets = [];
    for (final g in groups) {
      final list = <StepBlueprintUnit>[];
      for (final uid in g.unitIds) {
        final u = unitMap[uid];
        if (u != null) {
          list.add(u);
          assignedUnitIds.add(uid);
        }
      }
      buckets.add(_GroupBucket(group: g, units: list));
    }
    // 미할당 단계 — 그룹에 속하지 않은 unit (auto-generated 또는 그룹 삭제 후 잔여).
    final unassigned =
        units.where((u) => !assignedUnitIds.contains(u.id)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (unassigned.isNotEmpty) {
      buckets.add(
        _GroupBucket(
          group: StepGroupMeta(
            id: _unassignedGroupId,
            title: ko ? '미할당' : 'Unassigned',
            order: 9999,
          ),
          units: unassigned,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        MoriBlockShell(
          label: ko ? '그룹' : 'Groups',
          icon: Icons.layers_outlined,
          accent: C.lv,
          onMoreTap: () => _addGroup(ko),
          moreLabel: ko ? '+ 그룹 추가' : '+ Add group',
          child: groups.isEmpty
              ? _Hint(
                  text: ko
                      ? '그룹이 없어요. + 그룹 추가로 시작해 보세요.'
                      : 'No groups yet. Tap + Add group to start.',
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  onReorder: _onGroupReorder,
                  itemBuilder: (ctx, idx) {
                    final g = groups[idx];
                    return _GroupRow(
                      key: ValueKey('group-${g.id}'),
                      index: idx,
                      group: g,
                      isKorean: ko,
                      onEdit: () => _editGroup(g, ko),
                      onDelete: () => _deleteGroup(g, ko),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        MoriBlockShell(
          label: ko ? '단계' : 'Steps',
          icon: Icons.format_list_numbered_rounded,
          accent: C.pk,
          onMoreTap: () => _addUnit(ko, groups),
          moreLabel: ko ? '+ 단계 추가' : '+ Add step',
          child: buckets.isEmpty || units.isEmpty
              ? _Hint(
                  text: ko
                      ? '아직 단계가 없어요. + 단계 추가 또는 그룹부터 만들어 보세요.'
                      : 'No steps yet. Tap + Add step or create a group first.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final bucket in buckets) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                        child: Row(
                          children: [
                            Icon(
                              bucket.group.id == _unassignedGroupId
                                  ? Icons.help_outline
                                  : Icons.folder_outlined,
                              size: 16,
                              color: C.tx2,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                bucket.group.localizedTitle(ko),
                                style: T.bodyBold.copyWith(color: C.tx),
                              ),
                            ),
                            Text(
                              '${bucket.units.length}',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ),
                      if (bucket.units.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                          child: Text(
                            ko ? '단계가 없어요.' : 'No steps.',
                            style: T.caption.copyWith(color: C.mu),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bucket.units.length,
                          onReorder: (oldIdx, newIdx) =>
                              _onUnitReorder(bucket, oldIdx, newIdx),
                          itemBuilder: (ctx, idx) {
                            final u = bucket.units[idx];
                            return _UnitRow(
                              key: ValueKey('unit-${u.id}'),
                              index: idx,
                              unit: u,
                              isKorean: ko,
                              onEdit: () => _editUnit(u, groups, ko),
                              onDelete: () => _deleteUnit(u, ko),
                              onMoveToGroup: (gid) =>
                                  _moveUnitToGroup(u, gid, ko),
                              availableGroups: groups,
                              currentGroupId: bucket.group.id ==
                                      _unassignedGroupId
                                  ? null
                                  : bucket.group.id,
                            );
                          },
                        ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ─── 그룹 액션 ───────────────────────────────────────────────────────────

  Future<void> _addGroup(bool ko) async {
    final name = await _promptName(
      ko ? '그룹 추가' : 'Add group',
      ko ? '그룹 이름' : 'Group name',
      ko,
    );
    if (name == null || name.isEmpty) return;
    final next = [
      ...widget.blueprint.groups,
      StepGroupMeta(
        id: _newId(),
        title: name,
        titleKo: ko ? name : null,
        order: widget.blueprint.groups.length,
        unitIds: const [],
      ),
    ];
    await _saveGroups(next, ko);
  }

  Future<void> _editGroup(StepGroupMeta g, bool ko) async {
    final name = await _promptName(
      ko ? '그룹 수정' : 'Edit group',
      ko ? '그룹 이름' : 'Group name',
      ko,
      initial: g.localizedTitle(ko),
    );
    if (name == null || name.isEmpty) return;
    final next = widget.blueprint.groups
        .map((e) => e.id == g.id
            ? e.copyWith(title: name, titleKo: ko ? name : e.titleKo)
            : e)
        .toList();
    await _saveGroups(next, ko);
  }

  Future<void> _deleteGroup(StepGroupMeta g, bool ko) async {
    final ok = await _confirm(
      ko
          ? '이 그룹을 삭제할까요?\n속한 단계는 미할당 상태로 남아요.'
          : 'Delete this group?\nIts steps will become unassigned.',
      ko,
    );
    if (ok != true) return;
    final next =
        widget.blueprint.groups.where((e) => e.id != g.id).toList();
    await _saveGroups(next, ko);
  }

  void _onGroupReorder(int oldIdx, int newIdx) {
    final list = [...widget.blueprint.groups];
    var ni = newIdx;
    if (ni > oldIdx) ni -= 1;
    final moved = list.removeAt(oldIdx);
    list.insert(ni, moved);
    // order 재계산.
    final ordered = <StepGroupMeta>[];
    for (var i = 0; i < list.length; i++) {
      ordered.add(list[i].copyWith(order: i));
    }
    final ko = widget.isKorean;
    unawaitedFuture(_saveGroups(ordered, ko, silent: true));
  }

  Future<void> _saveGroups(
    List<StepGroupMeta> groups,
    bool ko, {
    bool silent = false,
  }) async {
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      if (silent) {
        await repo.updateGroups(widget.blueprint.id, groups);
        return;
      }
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.updateGroups(widget.blueprint.id, groups),
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  // ─── 단계 액션 ───────────────────────────────────────────────────────────

  Future<void> _addUnit(bool ko, List<StepGroupMeta> groups) async {
    final draft = await _showUnitDialog(
      ko: ko,
      groups: groups,
      initial: const _UnitDraft(),
    );
    if (draft == null) return;
    if (!mounted) return;
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final now = DateTime.now();
          final saved = await repo.saveUnit(
            StepBlueprintUnit(
              id: '',
              blueprintId: widget.blueprint.id,
              order: widget.units.length,
              title: draft.title,
              titleKo: ko ? draft.title : null,
              instruction: draft.instruction,
              instructionKo: ko ? draft.instruction : null,
              targetRows: draft.targetRows,
              tags: const [
                StepUnitTag(StepUnitTagKind.custom, 'manual'),
              ],
              createdAt: now,
            ),
          );
          // 선택한 그룹이 있으면 unitIds 에 추가.
          if (draft.groupId != null && draft.groupId!.isNotEmpty) {
            final groups = widget.blueprint.groups
                .map((g) => g.id == draft.groupId
                    ? g.copyWith(unitIds: [...g.unitIds, saved.id])
                    : g)
                .toList();
            await repo.updateGroups(widget.blueprint.id, groups);
          }
          await repo.update(widget.blueprint.id, {
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _editUnit(
    StepBlueprintUnit u,
    List<StepGroupMeta> groups,
    bool ko,
  ) async {
    final currentGroupId = _findGroupIdOfUnit(u.id);
    final draft = await _showUnitDialog(
      ko: ko,
      groups: groups,
      initial: _UnitDraft(
        title: u.localizedTitle(ko),
        instruction: u.localizedInstruction(ko),
        targetRows: u.targetRows,
        groupId: currentGroupId,
      ),
    );
    if (draft == null) return;
    if (!mounted) return;
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 자동 태그 제거 + manual 추가 (중복 방지).
          final newTags = <StepUnitTag>[
            for (final t in u.tags)
              if (!(t.kind == StepUnitTagKind.custom &&
                  (t.value == 'auto:chart' ||
                      t.value == 'auto:narrative')))
                t,
          ];
          final hasManual = newTags.any((t) =>
              t.kind == StepUnitTagKind.custom && t.value == 'manual');
          if (!hasManual) {
            newTags.add(
              const StepUnitTag(StepUnitTagKind.custom, 'manual'),
            );
          }
          await repo.saveUnit(u.copyWith(
            title: draft.title,
            titleKo: ko ? draft.title : u.titleKo,
            instruction: draft.instruction,
            instructionKo: ko ? draft.instruction : u.instructionKo,
            targetRows: draft.targetRows,
            tags: newTags,
          ));
          // 그룹 변경 처리.
          if (draft.groupId != currentGroupId) {
            await _applyGroupAssignment(u.id, currentGroupId, draft.groupId);
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _deleteUnit(StepBlueprintUnit u, bool ko) async {
    final ok = await _confirm(
      ko
          ? '이 단계를 삭제할까요? 되돌릴 수 없어요.'
          : 'Delete this step? This cannot be undone.',
      ko,
    );
    if (ok != true) return;
    if (!mounted) return;
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await repo.deleteUnit(u.blueprintId, u.id);
          // 그룹 unitIds 에서도 제거.
          final groups = widget.blueprint.groups
              .map((g) => g.unitIds.contains(u.id)
                  ? g.copyWith(
                      unitIds:
                          g.unitIds.where((e) => e != u.id).toList(),
                    )
                  : g)
              .toList();
          await repo.updateGroups(u.blueprintId, groups);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '삭제됐어요.' : 'Deleted.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _moveUnitToGroup(
    StepBlueprintUnit u,
    String? targetGroupId,
    bool ko,
  ) async {
    final current = _findGroupIdOfUnit(u.id);
    if (current == targetGroupId) return;
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final groups = _computeGroupAssignment(
            u.id,
            current,
            targetGroupId,
          );
          await repo.updateGroups(widget.blueprint.id, groups);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _onUnitReorder(_GroupBucket bucket, int oldIdx, int newIdx) {
    // 같은 그룹 안에서만 재배열 (그룹 간 이동은 메뉴로).
    final ko = widget.isKorean;
    final isUnassigned = bucket.group.id == _unassignedGroupId;
    if (isUnassigned) {
      // 미할당 버킷은 그룹 unitIds 가 아니므로 unit.order 직접 재계산.
      final items = [...bucket.units];
      var ni = newIdx;
      if (ni > oldIdx) ni -= 1;
      final moved = items.removeAt(oldIdx);
      items.insert(ni, moved);
      unawaitedFuture(_saveUnitOrder(items, ko, silent: true));
      return;
    }
    final group = bucket.group;
    final ids = [...group.unitIds];
    var ni = newIdx;
    if (ni > oldIdx) ni -= 1;
    final moved = ids.removeAt(oldIdx);
    ids.insert(ni, moved);
    final groups = widget.blueprint.groups
        .map((g) => g.id == group.id ? g.copyWith(unitIds: ids) : g)
        .toList();
    unawaitedFuture(_saveGroups(groups, ko, silent: true));
  }

  Future<void> _saveUnitOrder(
    List<StepBlueprintUnit> ordered,
    bool ko, {
    bool silent = false,
  }) async {
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      final updates = <StepBlueprintUnit>[];
      for (var i = 0; i < ordered.length; i++) {
        updates.add(ordered[i].copyWith(order: i));
      }
      if (silent) {
        await repo.saveUnits(widget.blueprint.id, updates);
        return;
      }
      await runWithMoriLoadingDialog<void>(
        context,
        message: ko ? '저장하는 중입니다.' : 'Saving...',
        subtitle: ko ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.saveUnits(widget.blueprint.id, updates),
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: ko ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  // ─── helpers ─────────────────────────────────────────────────────────────

  String? _findGroupIdOfUnit(String unitId) {
    for (final g in widget.blueprint.groups) {
      if (g.unitIds.contains(unitId)) return g.id;
    }
    return null;
  }

  List<StepGroupMeta> _computeGroupAssignment(
    String unitId,
    String? from,
    String? to,
  ) {
    return widget.blueprint.groups.map((g) {
      if (g.id == from && g.id != to) {
        return g.copyWith(
          unitIds: g.unitIds.where((e) => e != unitId).toList(),
        );
      }
      if (g.id == to && g.id != from) {
        if (g.unitIds.contains(unitId)) return g;
        return g.copyWith(unitIds: [...g.unitIds, unitId]);
      }
      return g;
    }).toList();
  }

  Future<void> _applyGroupAssignment(
    String unitId,
    String? from,
    String? to,
  ) async {
    final repo = ref.read(stepBlueprintRepositoryProvider);
    final next = _computeGroupAssignment(unitId, from, to);
    await repo.updateGroups(widget.blueprint.id, next);
  }

  Future<String?> _promptName(
    String title,
    String label,
    bool ko, {
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(title, style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: C.gx,
            labelText: label,
            hintText: label,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ko ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ctrl.text.trim()),
            child: Text(ko ? '저장' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool?> _confirm(String message, bool ko) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bg,
        content: Text(message, style: T.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ko ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              ko ? '삭제' : 'Delete',
              style: TextStyle(color: C.og),
            ),
          ),
        ],
      ),
    );
  }

  Future<_UnitDraft?> _showUnitDialog({
    required bool ko,
    required List<StepGroupMeta> groups,
    required _UnitDraft initial,
  }) async {
    return showDialog<_UnitDraft>(
      context: context,
      builder: (_) => _UnitEditDialog(
        isKorean: ko,
        groups: groups,
        initial: initial,
      ),
    );
  }

  String _newId() =>
      'g_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  void unawaitedFuture(Future<void> f) {
    // 의도적으로 await 안 함. 에러는 내부 try/catch 또는 showSaveErrorSnackBar 가 처리.
  }
}

// ─── _GroupRow ────────────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.index,
    required this.group,
    required this.isKorean,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final StepGroupMeta group;
  final bool isKorean;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_indicator, size: 18, color: C.mu),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                group.localizedTitle(isKorean),
                style: T.bodyBold.copyWith(color: C.tx),
              ),
            ),
            Text(
              '${group.unitIds.length}',
              style: T.caption.copyWith(color: C.mu),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: C.mu, size: 20),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: C.lv),
                    const SizedBox(width: 8),
                    Text(isKorean ? '수정' : 'Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: C.og),
                    const SizedBox(width: 8),
                    Text(
                      isKorean ? '삭제' : 'Delete',
                      style: TextStyle(color: C.og),
                    ),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _UnitRow ─────────────────────────────────────────────────────────────────

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    super.key,
    required this.index,
    required this.unit,
    required this.isKorean,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToGroup,
    required this.availableGroups,
    required this.currentGroupId,
  });

  final int index;
  final StepBlueprintUnit unit;
  final bool isKorean;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String?> onMoveToGroup;
  final List<StepGroupMeta> availableGroups;
  final String? currentGroupId;

  bool get _isAuto => unit.tags.any((t) =>
      t.kind == StepUnitTagKind.custom &&
      (t.value == 'auto:chart' || t.value == 'auto:narrative'));

  bool get _isManual => unit.tags.any((t) =>
      t.kind == StepUnitTagKind.custom && t.value == 'manual');

  String _autoLabel(bool ko) {
    final hasChart = unit.tags.any((t) =>
        t.kind == StepUnitTagKind.custom && t.value == 'auto:chart');
    if (hasChart) return ko ? '자동(차트)' : 'auto(chart)';
    return ko ? '자동(서술형)' : 'auto(narrative)';
  }

  @override
  Widget build(BuildContext context) {
    final ko = isKorean;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        Icon(Icons.drag_indicator, size: 18, color: C.mu),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unit.order + 1}',
                    style: T.sm.copyWith(
                      color: C.lvD,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    unit.localizedTitle(ko),
                    style: T.bodyBold.copyWith(color: C.tx),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: C.mu, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit();
                      return;
                    }
                    if (v == 'delete') {
                      onDelete();
                      return;
                    }
                    if (v == 'move:__unassigned__') {
                      onMoveToGroup(null);
                      return;
                    }
                    if (v.startsWith('move:')) {
                      onMoveToGroup(v.substring('move:'.length));
                      return;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18, color: C.lv),
                        const SizedBox(width: 8),
                        Text(ko ? '수정' : 'Edit'),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        ko ? '그룹으로 이동' : 'Move to group',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                    ),
                    for (final g in availableGroups)
                      PopupMenuItem(
                        value: 'move:${g.id}',
                        child: Row(children: [
                          Icon(
                            g.id == currentGroupId
                                ? Icons.check
                                : Icons.folder_outlined,
                            size: 18,
                            color: g.id == currentGroupId ? C.lv : C.mu,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g.localizedTitle(ko))),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'move:__unassigned__',
                      child: Row(children: [
                        Icon(
                          currentGroupId == null
                              ? Icons.check
                              : Icons.help_outline,
                          size: 18,
                          color: currentGroupId == null ? C.lv : C.mu,
                        ),
                        const SizedBox(width: 8),
                        Text(ko ? '미할당' : 'Unassigned'),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: C.og),
                        const SizedBox(width: 8),
                        Text(
                          ko ? '삭제' : 'Delete',
                          style: TextStyle(color: C.og),
                        ),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            if (unit.localizedInstruction(ko).trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 4, 12, 0),
                child: Text(
                  unit.localizedInstruction(ko),
                  style: T.body.copyWith(color: C.tx2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 6, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (unit.targetRows > 0)
                    _Tag(
                      text: ko
                          ? '목표 ${unit.targetRows}단'
                          : 'Target ${unit.targetRows}',
                      color: C.lvD,
                      bg: C.lvL,
                    ),
                  if (_isAuto)
                    _Tag(
                      text: _autoLabel(ko),
                      color: C.tx2,
                      bg: C.bd.withValues(alpha: 0.5),
                    ),
                  if (_isManual)
                    _Tag(
                      text: ko ? '수동' : 'manual',
                      color: const Color(0xFFC2410C),
                      bg: C.og.withValues(alpha: 0.14),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.color,
    required this.bg,
  });

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: T.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── _UnitEditDialog ──────────────────────────────────────────────────────────

class _UnitDraft {
  final String title;
  final String instruction;
  final int targetRows;
  final String? groupId;

  const _UnitDraft({
    this.title = '',
    this.instruction = '',
    this.targetRows = 0,
    this.groupId,
  });
}

class _UnitEditDialog extends StatefulWidget {
  const _UnitEditDialog({
    required this.isKorean,
    required this.groups,
    required this.initial,
  });

  final bool isKorean;
  final List<StepGroupMeta> groups;
  final _UnitDraft initial;

  @override
  State<_UnitEditDialog> createState() => _UnitEditDialogState();
}

class _UnitEditDialogState extends State<_UnitEditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _instructionCtrl;
  late TextEditingController _targetCtrl;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial.title);
    _instructionCtrl =
        TextEditingController(text: widget.initial.instruction);
    _targetCtrl = TextEditingController(
      text: widget.initial.targetRows > 0
          ? widget.initial.targetRows.toString()
          : '',
    );
    _groupId = widget.initial.groupId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ko = widget.isKorean;
    return AlertDialog(
      backgroundColor: C.bg,
      title: Text(ko ? '단계 편집' : 'Edit step', style: T.h3),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(title: ko ? '제목' : 'Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: ko ? '예: 본판 시작' : 'e.g. Start body',
                labelText: ko ? '제목' : 'Title',
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(title: ko ? '지시문' : 'Instruction'),
            const SizedBox(height: 6),
            TextField(
              controller: _instructionCtrl,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: ko
                    ? '단계에 필요한 안내를 입력해 주세요.'
                    : 'Describe this step.',
                labelText: ko ? '지시문' : 'Instruction',
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(title: ko ? '목표 단수' : 'Target rows'),
            const SizedBox(height: 6),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: C.gx,
                hintText: '0',
                labelText: ko ? '목표 단수' : 'Target rows',
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(title: ko ? '그룹' : 'Group'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _GroupChoiceChip(
                  selected: _groupId == null,
                  label: ko ? '미할당' : 'Unassigned',
                  onTap: () => setState(() => _groupId = null),
                ),
                for (final g in widget.groups)
                  _GroupChoiceChip(
                    selected: _groupId == g.id,
                    label: g.localizedTitle(ko),
                    onTap: () => setState(() => _groupId = g.id),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ko ? '취소' : 'Cancel'),
        ),
        TextButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ko ? '제목을 입력해 주세요.' : 'Please enter a title.',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _UnitDraft(
                title: title,
                instruction: _instructionCtrl.text.trim(),
                targetRows: int.tryParse(_targetCtrl.text.trim()) ?? 0,
                groupId: _groupId,
              ),
            );
          },
          child: Text(ko ? '저장' : 'Save'),
        ),
      ],
    );
  }
}

class _GroupChoiceChip extends StatelessWidget {
  const _GroupChoiceChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Colors.white : C.lvD;
    final bg = selected ? C.lv : C.lvL;
    final border = selected ? C.lv : C.lv.withValues(alpha: 0.20);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: T.sm.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── 공용 작은 위젯 ────────────────────────────────────────────────────────

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: T.body.copyWith(color: C.mu),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isKorean, required this.msg});

  final bool isKorean;
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: C.mu),
            const SizedBox(height: 12),
            Text(
              msg,
              style: T.body.copyWith(color: C.tx2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBucket {
  final StepGroupMeta group;
  final List<StepBlueprintUnit> units;
  const _GroupBucket({required this.group, required this.units});
}
