// lib/features/blueprint/presentation/tester_group_screen.dart
//
// 이슈 #792 — 테스터 그룹 권한 UI.
// 작성자 → 테스터 초대/관리 + 진행률 확인 + 일괄 공지(DM) 발송.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/step_run_provider.dart';
import '../../dm/data/dm_repository.dart';
import '../domain/step_blueprint.dart';

class TesterGroupScreen extends ConsumerStatefulWidget {
  final String blueprintId;

  const TesterGroupScreen({super.key, required this.blueprintId});

  @override
  ConsumerState<TesterGroupScreen> createState() => _TesterGroupScreenState();
}

class _TesterGroupScreenState extends ConsumerState<TesterGroupScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = const [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
      final repo = ref.read(stepBlueprintRepositoryProvider);
      final results = await repo.searchUsersByDisplayName(
        query,
        excludeUid: currentUid,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchResults = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<BlueprintMemberRole?> _pickRole(BuildContext context, bool isKorean) {
    return showModalBottomSheet<BlueprintMemberRole>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '역할 선택' : 'Pick role', style: T.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in BlueprintMemberRole.values)
                    _RolePickChip(
                      label: _roleLabel(role, isKorean),
                      onTap: () => Navigator.pop(ctx, role),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isKorean ? '취소' : 'Cancel',
                    style: TextStyle(color: C.mu),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(BlueprintMemberRole r, bool isKorean) {
    switch (r) {
      case BlueprintMemberRole.admin:
        return isKorean ? '관리자' : 'Admin';
      case BlueprintMemberRole.editor:
        return isKorean ? '편집자' : 'Editor';
      case BlueprintMemberRole.tester:
        return isKorean ? '테스터' : 'Tester';
      case BlueprintMemberRole.commenter:
        return isKorean ? '코멘터' : 'Commenter';
      case BlueprintMemberRole.viewer:
        return isKorean ? '뷰어' : 'Viewer';
    }
  }

  Future<void> _addMember(
    Map<String, String> user,
    bool isKorean,
  ) async {
    final role = await _pickRole(context, isKorean);
    if (role == null || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref
            .read(stepBlueprintRepositoryProvider)
            .upsertMember(
              blueprintId: widget.blueprintId,
              memberUid: user['uid']!,
              role: role,
            ),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '테스터를 추가했어요.' : 'Tester added.');
      setState(() {
        _searchCtrl.clear();
        _searchResults = const [];
      });
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _removeMember(String memberUid, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref
            .read(stepBlueprintRepositoryProvider)
            .removeMember(
              blueprintId: widget.blueprintId,
              memberUid: memberUid,
            ),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '테스터를 제거했어요.' : 'Tester removed.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _broadcastAnnouncement(
    StepBlueprint blueprint,
    bool isKorean,
  ) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '일괄 공지 보내기' : 'Broadcast Announcement',
            style: T.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean
                  ? '모든 테스터 멤버에게 DM으로 공지를 보냅니다.'
                  : 'Send a DM to all tester members.',
              style: T.caption.copyWith(color: C.mu),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: isKorean ? '공지 내용' : 'Announcement',
                hintText: isKorean
                    ? '예: 베타 v0.2 업데이트 — 7장 단계 수정됨'
                    : 'e.g. Beta v0.2 — Section 7 updated',
                filled: true,
                fillColor: C.gx,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel',
                style: TextStyle(color: C.mu)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
            ),
            child: Text(isKorean ? '보내기' : 'Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty || !mounted) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;
    final currentUserModel = ref.read(currentUserProvider).valueOrNull;
    final myName = (currentUserModel?.displayName.isNotEmpty == true)
        ? currentUserModel!.displayName
        : (currentUser.displayName ?? '');
    final myHandle = currentUserModel?.handle ?? '';
    final myPhoto = currentUser.photoURL ?? '';

    final body = isKorean
        ? '[함께 뜨기 공지: ${blueprint.localizedTitle(true)}]\n$text'
        : '[Knit-Along Notice: ${blueprint.localizedTitle(false)}]\n$text';

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '공지를 보내는 중입니다.' : 'Sending announcement...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(stepBlueprintRepositoryProvider);
          final dmRepo = DmRepository();
          final memberUids = blueprint.members.keys.toList();
          for (final memberUid in memberUids) {
            if (memberUid == currentUser.uid) continue;
            final profile = await repo.getUserProfile(memberUid);
            final theirName = (profile?['displayName'] ?? '').toString();
            final theirPhoto = (profile?['photoURL'] ?? '').toString();
            final roomId = await dmRepo.getOrCreateRoom(
              uid1: currentUser.uid,
              name1: myName,
              photo1: myPhoto,
              handle1: myHandle,
              uid2: memberUid,
              name2: theirName,
              photo2: theirPhoto,
            );
            await dmRepo.sendMessage(
              roomId: roomId,
              senderId: currentUser.uid,
              senderName: myName,
              text: body,
              recipientId: memberUid,
            );
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '공지를 보냈어요.' : 'Announcement sent.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    // 이슈 #797 — blueprintByIdProvider 는 step_blueprints 컬렉션만 watch 하므로
    // legacy pattern_charts 어댑터 청사진은 무한 loading 발생.
    // blueprintByIdWithLegacyProvider 로 변경해 legacy fallback 포함.
    final blueprintAsync =
        ref.watch(blueprintByIdWithLegacyProvider(widget.blueprintId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          isKorean ? '테스터 그룹 관리' : 'Tester Group',
          style: T.h3,
        ),
        actions: [
          // 이슈 #794 — 피드백 채널 진입
          IconButton(
            icon: Icon(Icons.feedback_outlined, color: C.lvD),
            tooltip: isKorean ? '테스터 피드백' : 'Tester Feedback',
            onPressed: () => context.push(
              Routes.testerFeedback.replaceAll(':id', widget.blueprintId),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: AsyncDataView<StepBlueprint?>(
              async: blueprintAsync,
              // 이슈 #797 — 에러 시 재시도 가능하도록 onRetry 노출.
              onRetry: () => ref.invalidate(
                  blueprintByIdWithLegacyProvider(widget.blueprintId)),
              builder: (blueprint) {
                if (blueprint == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        isKorean
                            ? '도안을 불러올 수 없어요.'
                            : 'Could not load pattern.',
                        style: T.body.copyWith(color: C.mu),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. 도안 정보
                      MoriBlockShell(
                        label: isKorean ? '도안' : 'Pattern',
                        icon: Icons.menu_book_rounded,
                        accent: C.lv,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(blueprint.localizedTitle(isKorean),
                                style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(
                              isKorean
                                  ? '${blueprint.members.length}명 참여 중'
                                  : '${blueprint.members.length} member(s)',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. 멤버 추가
                      MoriBlockShell(
                        label: isKorean ? '테스터 초대' : 'Invite Tester',
                        icon: Icons.person_add_alt_1_rounded,
                        accent: C.lvD,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                labelText: isKorean
                                    ? '사용자 닉네임으로 검색'
                                    : 'Search by display name',
                                hintText: isKorean
                                    ? '닉네임을 입력하세요'
                                    : 'Enter a display name',
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: C.mu, size: 20),
                                filled: true,
                                fillColor: C.gx,
                                suffixIcon: _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              onSubmitted: _searchUsers,
                              onChanged: (v) {
                                if (v.trim().isEmpty) {
                                  setState(
                                      () => _searchResults = const []);
                                }
                              },
                            ),
                            if (_searchResults.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              for (final user in _searchResults)
                                _UserSearchRow(
                                  user: user,
                                  isAlreadyMember:
                                      blueprint.members.containsKey(
                                          user['uid'] ?? ''),
                                  isOwner:
                                      blueprint.ownerUid == (user['uid'] ?? ''),
                                  isKorean: isKorean,
                                  onAdd: () => _addMember(user, isKorean),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. 현재 멤버 목록
                      MoriBlockShell(
                        label: isKorean ? '현재 멤버' : 'Members',
                        icon: Icons.people_rounded,
                        accent: C.lm,
                        child: blueprint.members.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  isKorean
                                      ? '아직 추가된 멤버가 없어요.'
                                      : 'No members yet.',
                                  style: T.body.copyWith(color: C.mu),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final entry
                                      in blueprint.members.entries)
                                    _MemberRow(
                                      uid: entry.key,
                                      role: entry.value,
                                      blueprintId: widget.blueprintId,
                                      isKorean: isKorean,
                                      onRemove: () =>
                                          _removeMember(entry.key, isKorean),
                                      roleLabel:
                                          _roleLabel(entry.value, isKorean),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),

                      // 4. 일괄 공지
                      MoriBlockShell(
                        label: isKorean ? '일괄 공지' : 'Broadcast',
                        icon: Icons.campaign_rounded,
                        accent: C.og,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isKorean
                                  ? '모든 테스터 멤버에게 DM으로 공지를 보낼 수 있어요.'
                                  : 'Send an announcement to all testers via DM.',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: blueprint.members.isEmpty
                                    ? null
                                    : () => _broadcastAnnouncement(
                                          blueprint,
                                          isKorean,
                                        ),
                                icon: const Icon(Icons.send_rounded,
                                    size: 18),
                                label: Text(isKorean
                                    ? '공지 작성'
                                    : 'Write announcement'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: C.og,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSearchRow extends StatelessWidget {
  final Map<String, String> user;
  final bool isAlreadyMember;
  final bool isOwner;
  final bool isKorean;
  final VoidCallback onAdd;

  const _UserSearchRow({
    required this.user,
    required this.isAlreadyMember,
    required this.isOwner,
    required this.isKorean,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isAlreadyMember || isOwner;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: C.lvL,
            child: Icon(Icons.person_rounded, size: 16, color: C.lvD),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['displayName'] ?? '',
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((user['email'] ?? '').isNotEmpty)
                  Text(user['email']!,
                      style: T.caption.copyWith(color: C.mu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (disabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                isOwner
                    ? (isKorean ? '소유자' : 'Owner')
                    : (isKorean ? '이미 추가됨' : 'Added'),
                style: T.caption.copyWith(color: C.mu),
              ),
            )
          else
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add_rounded, size: 16, color: C.lvD),
              label: Text(
                isKorean ? '추가' : 'Add',
                style: T.caption.copyWith(
                  color: C.lvD,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final String uid;
  final BlueprintMemberRole role;
  final String roleLabel;
  final String blueprintId;
  final bool isKorean;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.uid,
    required this.role,
    required this.roleLabel,
    required this.blueprintId,
    required this.isKorean,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stepBlueprintRepositoryProvider);
    final runsAsync = ref.watch(stepRunsByBlueprintProvider(blueprintId));
    final runs = runsAsync.valueOrNull ?? const [];
    final myRun = runs.where((r) => r.userUid == uid).toList();
    final pct = myRun.isEmpty ? 0.0 : myRun.first.summary.percentComplete;

    return FutureBuilder<Map<String, String>?>(
      future: repo.getUserProfile(uid),
      builder: (context, snap) {
        final displayName = (snap.data?['displayName'] ?? '').toString();
        final fallback = displayName.isNotEmpty
            ? displayName
            : uid.substring(0, uid.length.clamp(0, 6));
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: C.lmG.withValues(alpha: 0.25),
                child: Icon(Icons.person_rounded, size: 18, color: C.lmD),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(fallback,
                              style: T.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.lvL,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleLabel,
                            style: T.caption.copyWith(
                              color: C.lvD,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: C.bd,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(C.lvD),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: T.caption.copyWith(
                            color: C.lvD,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon:
                    Icon(Icons.person_remove_alt_1_rounded, color: C.og, size: 20),
                tooltip: isKorean ? '제거' : 'Remove',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RolePickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RolePickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.lvL,
          border: Border.all(color: C.lv.withValues(alpha: 0.20)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: C.lvD,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
