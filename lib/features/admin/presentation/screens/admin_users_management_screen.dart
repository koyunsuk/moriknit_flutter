// 이슈 #815 Phase 3 — 모바일어드민 회원 관리 화면.
//
// 와이어프레임이 아닌 실제 동작 화면:
//   - users 컬렉션 실시간 검색 (이메일/UID/닉네임/핸들)
//   - 등급 변경 (free/starter/pro/business) — 즉시 Firestore write
//   - 차단/차단해제 — users/{uid}.isBlocked merge (소프트 차단, 데이터 보존)
//   - 관리자 권한 부여/해제 — admins/{uid} set/delete
//   - 모든 액션은 admin_action_logs 컬렉션에 audit log 자동 기록
//
// 사용 위젯: MoriBlockShell, MoriChip, AsyncDataView, EmptyBlockPlaceholder, BgOrbs.
// 색상/타이포: C / T 토큰만 사용. 인라인 색상·TextStyle 금지.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_data_view.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/domain/user_model.dart';

const Color _kAdminAccent = Color(0xFFFF8A00);

/// 어드민 사용자 검색 결과 — 최신 가입순 250건.
/// 검색어가 있으면 클라이언트 필터로 좁힘 (이메일/UID/displayName/handle).
final _adminUsersListProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(250)
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
});

class AdminUsersManagementScreen extends ConsumerStatefulWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  ConsumerState<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState
    extends ConsumerState<AdminUsersManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _planFilter = 'all'; // all/free/starter/pro/business

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _match(UserModel u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.email.toLowerCase().contains(q) ||
        u.uid.toLowerCase().contains(q) ||
        u.displayName.toLowerCase().contains(q) ||
        u.handle.toLowerCase().contains(q);
  }

  bool _planMatch(UserModel u) {
    if (_planFilter == 'all') return true;
    return u.subscription.planId == _planFilter;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersListProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: C.tx),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('회원 관리', style: T.h3.copyWith(color: C.tx)),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // 검색 + 필터 블록
                  MoriBlockShell(
                    label: '검색·필터',
                    icon: Icons.search_rounded,
                    accent: _kAdminAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: '이메일 · UID · 닉네임 · @핸들',
                            filled: true,
                            fillColor: C.gx,
                            prefixIcon: Icon(Icons.search_rounded, color: C.mu, size: 20),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.close_rounded, color: C.mu, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final spec in const [
                                ('all', '전체'),
                                ('free', 'Free'),
                                ('starter', 'Starter'),
                                ('pro', 'Pro'),
                                ('business', 'Business'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _FilterChipBtn(
                                    label: spec.$2,
                                    selected: _planFilter == spec.$1,
                                    onTap: () =>
                                        setState(() => _planFilter = spec.$1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 회원 리스트
                  Expanded(
                    child: AsyncDataView<List<UserModel>>(
                      async: usersAsync,
                      isEmpty: (l) =>
                          l.where(_match).where(_planMatch).isEmpty,
                      emptyBuilder: () => MoriBlockShell(
                        label: '회원',
                        icon: Icons.people_rounded,
                        accent: _kAdminAccent,
                        child: const EmptyBlockPlaceholder(
                          message: '조건에 맞는 회원이 없어요.\n검색어/필터를 다시 확인해 주세요.',
                          rows: 3,
                        ),
                      ),
                      placeholderRows: 6,
                      rowHeight: 56,
                      builder: (users) {
                        final filtered =
                            users.where(_match).where(_planMatch).toList();
                        return MoriBlockShell(
                          label: '회원 (${filtered.length}명)',
                          icon: Icons.people_rounded,
                          accent: _kAdminAccent,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: C.bd.withValues(alpha: 0.3)),
                            itemBuilder: (_, i) => _UserRow(user: filtered[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kAdminAccent : _kAdminAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _kAdminAccent.withValues(alpha: selected ? 1.0 : 0.30),
          ),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? Colors.white : _kAdminAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final UserModel user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = user.subscription.planId;
    final created = user.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(user.createdAt!);
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _UserActionDialog(user: user),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: C.lvL,
              backgroundImage:
                  user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
              child: user.photoURL.isEmpty
                  ? Text(
                      (user.displayName.isNotEmpty
                              ? user.displayName
                              : user.email.isNotEmpty
                                  ? user.email
                                  : 'U')[0]
                          .toUpperCase(),
                      style: T.bodyBold.copyWith(color: C.lvD),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName.isEmpty ? user.email : user.displayName,
                          style: T.bodyBold.copyWith(color: C.tx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PlanBadge(plan: plan),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email.isEmpty
                        ? user.uid
                        : '${user.email} · 가입 $created',
                    style: T.caption.copyWith(color: C.mu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (plan) {
      'pro' => (C.lv.withValues(alpha: 0.15), C.lvD),
      'business' => (C.og.withValues(alpha: 0.15), C.og),
      'starter' => (C.lm.withValues(alpha: 0.18), C.lmD),
      _ => (C.bd.withValues(alpha: 0.30), C.tx2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        plan,
        style: T.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 회원 상세 + 액션 다이얼로그.
///
/// 액션:
///   - 등급 변경 (Dropdown) → users/{uid}.subscription.planId merge
///   - 차단 토글 → users/{uid}.isBlocked merge (소프트 차단, 데이터 보존)
///   - 관리자 권한 토글 → admins/{uid} set/delete
///   - 모든 액션은 admin_action_logs 자동 기록
class _UserActionDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _UserActionDialog({required this.user});

  @override
  ConsumerState<_UserActionDialog> createState() => _UserActionDialogState();
}

class _UserActionDialogState extends ConsumerState<_UserActionDialog> {
  late String _selectedPlan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.user.subscription.planId;
  }

  Future<void> _logAction({
    required String action,
    required String targetUid,
    String? targetEmail,
    Map<String, dynamic>? metadata,
  }) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) return;
    try {
      await FirebaseFirestore.instance.collection('admin_action_logs').add({
        'actorUid': actor.uid,
        'actorEmail': actor.email ?? '',
        'action': action,
        'targetUid': targetUid,
        'targetEmail': targetEmail ?? '',
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // 로그 실패는 핵심 액션을 막지 않음
    }
  }

  Future<void> _savePlan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '저장하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .set({
            'subscription': {
              'planId': _selectedPlan,
              'status': 'active',
            },
          }, SetOptions(merge: true));
          await _logAction(
            action: 'plan_change',
            targetUid: widget.user.uid,
            targetEmail: widget.user.email,
            metadata: {
              'from': widget.user.subscription.planId,
              'to': _selectedPlan,
            },
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '등급이 변경됐어요.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlocked(bool current) async {
    final next = !current;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: next ? '차단하는 중입니다.' : '해제하는 중입니다.',
        task: () async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .set({'isBlocked': next}, SetOptions(merge: true));
          await _logAction(
            action: next ? 'user_block' : 'user_unblock',
            targetUid: widget.user.uid,
            targetEmail: widget.user.email,
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: next ? '회원을 차단했어요.' : '차단을 해제했어요.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _toggleAdmin(bool current) async {
    final next = !current;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: next ? '권한을 부여하는 중입니다.' : '권한을 해제하는 중입니다.',
        task: () async {
          final adminDoc = FirebaseFirestore.instance
              .collection('admins')
              .doc(widget.user.uid);
          if (next) {
            await adminDoc.set({
              'role': 'admin',
              'addedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await adminDoc.delete();
          }
          await _logAction(
            action: next ? 'admin_grant' : 'admin_revoke',
            targetUid: widget.user.uid,
            targetEmail: widget.user.email,
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: next ? '관리자 권한을 부여했어요.' : '관리자 권한을 해제했어요.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isBlockedAsync = ref.watch(_userBlockedFlagProvider(user.uid));
    final isAdminAsync = ref.watch(_userAdminFlagProvider(user.uid));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: C.lvL,
                    backgroundImage: user.photoURL.isNotEmpty
                        ? NetworkImage(user.photoURL)
                        : null,
                    child: user.photoURL.isEmpty
                        ? Text(
                            (user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.email.isNotEmpty
                                        ? user.email
                                        : 'U')[0]
                                .toUpperCase(),
                            style: T.bodyBold.copyWith(color: C.lvD),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isEmpty ? user.email : user.displayName,
                          style: T.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.email.isNotEmpty)
                          Text(
                            user.email,
                            style: T.caption.copyWith(color: C.mu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'UID: ${user.uid}',
                          style: T.caption.copyWith(color: C.mu, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 등급 변경
              Text('등급', style: T.sm.copyWith(color: C.tx2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPlan,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: C.gx,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'free', child: Text('free')),
                        DropdownMenuItem(value: 'starter', child: Text('starter')),
                        DropdownMenuItem(value: 'pro', child: Text('pro')),
                        DropdownMenuItem(value: 'business', child: Text('business')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedPlan = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_busy ||
                            _selectedPlan == user.subscription.planId)
                        ? null
                        : _savePlan,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAdminAccent,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 차단 토글
              _ActionTile(
                icon: Icons.block_rounded,
                title: '계정 차단',
                subtitle: '차단된 회원은 데이터는 보존되며 앱 접근이 제한돼요.',
                accent: C.og,
                trailing: isBlockedAsync.when(
                  loading: () => const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => Icon(Icons.error_outline, color: C.og, size: 18),
                  data: (blocked) => Switch(
                    value: blocked,
                    onChanged: (_) => _toggleBlocked(blocked),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 관리자 권한
              _ActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: '관리자 권한',
                subtitle: 'admins/{uid} 컬렉션에 등록됩니다.',
                accent: _kAdminAccent,
                trailing: isAdminAsync.when(
                  loading: () => const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => Icon(Icons.error_outline, color: C.og, size: 18),
                  data: (admin) => Switch(
                    value: admin,
                    onChanged: (_) => _toggleAdmin(admin),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('닫기', style: TextStyle(color: C.tx2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget trailing;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.bodyBold.copyWith(color: C.tx)),
                const SizedBox(height: 2),
                Text(subtitle, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// 회원 차단 플래그 실시간 구독.
final _userBlockedFlagProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['isBlocked'] == true);
});

/// 회원 관리자 플래그 실시간 구독.
final _userAdminFlagProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists);
});
