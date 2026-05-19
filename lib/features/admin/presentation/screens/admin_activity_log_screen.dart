// 이슈 #815 Phase 3 — 모바일어드민 활동 로그 (audit log).
//
// admin_action_logs 컬렉션 실시간 조회.
// 어드민이 회원 관리 화면에서 수행한 모든 액션(차단/해제/등급변경/권한부여 등)을
// 자동 기록한 audit trail.
//
// 보관 정책: 영구 보관 (어드민 수동 삭제 가능).
// 필터: 액션 종류별 (전체/차단/해제/등급변경/권한부여/권한해제).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_data_view.dart';
import '../../../../core/widgets/common_widgets.dart';

const Color _kAdminAccent = Color(0xFFFF8A00);

/// 최근 어드민 액션 로그 (최신 200건).
final _adminActionLogsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('admin_action_logs')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs);
});

class AdminActivityLogScreen extends ConsumerStatefulWidget {
  const AdminActivityLogScreen({super.key});

  @override
  ConsumerState<AdminActivityLogScreen> createState() =>
      _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState
    extends ConsumerState<AdminActivityLogScreen> {
  String _actionFilter = 'all';

  static const _filterSpecs = [
    ('all', '전체'),
    ('user_block', '차단'),
    ('user_unblock', '해제'),
    ('plan_change', '등급변경'),
    ('admin_grant', '권한부여'),
    ('admin_revoke', '권한해제'),
  ];

  bool _matches(Map<String, dynamic> data) {
    if (_actionFilter == 'all') return true;
    return data['action'] == _actionFilter;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(_adminActionLogsProvider);

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
        title: Text('활동 로그', style: T.h3.copyWith(color: C.tx)),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // 필터 칩
                  MoriBlockShell(
                    label: '액션 필터',
                    icon: Icons.filter_list_rounded,
                    accent: _kAdminAccent,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final spec in _filterSpecs)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _FilterBtn(
                                label: spec.$2,
                                selected: _actionFilter == spec.$1,
                                onTap: () =>
                                    setState(() => _actionFilter = spec.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AsyncDataView<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      async: logsAsync,
                      isEmpty: (docs) =>
                          docs.where((d) => _matches(d.data())).isEmpty,
                      emptyBuilder: () => MoriBlockShell(
                        label: '활동 로그',
                        icon: Icons.history_rounded,
                        accent: _kAdminAccent,
                        child: const EmptyBlockPlaceholder(
                          message: '기록된 활동이 없어요.\n회원 관리 화면에서 액션을 수행하면 여기에 표시돼요.',
                          rows: 3,
                        ),
                      ),
                      placeholderRows: 6,
                      rowHeight: 64,
                      builder: (docs) {
                        final filtered =
                            docs.where((d) => _matches(d.data())).toList();
                        return MoriBlockShell(
                          label: '활동 로그 (${filtered.length}건)',
                          icon: Icons.history_rounded,
                          accent: _kAdminAccent,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: C.bd.withValues(alpha: 0.3)),
                            itemBuilder: (_, i) =>
                                _LogRow(data: filtered[i].data()),
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

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterBtn({
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

class _LogRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LogRow({required this.data});

  String get _actionLabel {
    switch (data['action']) {
      case 'user_block':
        return '회원 차단';
      case 'user_unblock':
        return '차단 해제';
      case 'plan_change':
        return '등급 변경';
      case 'admin_grant':
        return '관리자 권한 부여';
      case 'admin_revoke':
        return '관리자 권한 해제';
      default:
        return (data['action'] as String?) ?? '액션';
    }
  }

  Color get _actionColor {
    switch (data['action']) {
      case 'user_block':
      case 'admin_revoke':
        return C.og;
      case 'admin_grant':
        return _kAdminAccent;
      case 'plan_change':
        return C.lvD;
      default:
        return C.mu;
    }
  }

  IconData get _actionIcon {
    switch (data['action']) {
      case 'user_block':
        return Icons.block_rounded;
      case 'user_unblock':
        return Icons.lock_open_rounded;
      case 'plan_change':
        return Icons.upgrade_rounded;
      case 'admin_grant':
        return Icons.admin_panel_settings_rounded;
      case 'admin_revoke':
        return Icons.no_accounts_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = data['createdAt'] as Timestamp?;
    final when = createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt.toDate());
    final actorEmail = (data['actorEmail'] as String?) ?? '';
    final targetEmail = (data['targetEmail'] as String?) ?? '';
    final targetUid = (data['targetUid'] as String?) ?? '';
    final metadata = (data['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    String detail = targetEmail.isEmpty ? targetUid : targetEmail;
    if (data['action'] == 'plan_change') {
      final from = metadata['from'] ?? '?';
      final to = metadata['to'] ?? '?';
      detail += ' · $from → $to';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _actionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_actionIcon, size: 16, color: _actionColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_actionLabel,
                          style: T.bodyBold.copyWith(color: C.tx)),
                    ),
                    Text(when,
                        style: T.caption.copyWith(color: C.mu, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: T.caption.copyWith(color: C.tx2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '실행: $actorEmail',
                  style: T.caption.copyWith(color: C.mu, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
