// 이슈 #704 Phase 4 — 충돌 인박스 화면.
//
// SyncQueue / ConflictResolver 가 manual 정책으로 보류한 충돌들을 누적해 보여주는 화면.
// 사용자가 항목을 탭하면 ConflictResolutionDialog 호출.
//
// 현재(Phase 4): 실제 충돌 데이터 소스는 Phase 5에서 연동 예정 → 빈 상태 표시만.
// 다이얼로그 위젯과 화면 골격만 완성하고, 누적 큐는 추후 Provider로 주입.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/conflict_resolution_dialog.dart';

/// 단일 충돌 항목 모델 (UI 표시용).
///
/// Phase 5에서 SyncQueue 와 결합해 실제 데이터로 채움.
class ConflictItem {
  final String id;
  final String entity; // 'swatch', 'project', 'pattern', ...
  final String docId;
  final String title;
  final Map<String, String> localFields;
  final Map<String, String> serverFields;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;

  const ConflictItem({
    required this.id,
    required this.entity,
    required this.docId,
    required this.title,
    required this.localFields,
    required this.serverFields,
    this.localUpdatedAt,
    this.serverUpdatedAt,
  });
}

/// 누적된 충돌 목록 Provider (Phase 5에서 실제 큐 연동).
/// 현재는 빈 리스트 반환.
final conflictInboxProvider =
    StateNotifierProvider<ConflictInboxNotifier, List<ConflictItem>>(
  (ref) => ConflictInboxNotifier(),
);

class ConflictInboxNotifier extends StateNotifier<List<ConflictItem>> {
  ConflictInboxNotifier() : super(const []);

  void add(ConflictItem item) {
    state = [...state, item];
  }

  void remove(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

class ConflictInboxScreen extends ConsumerWidget {
  const ConflictInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(conflictInboxProvider);

    return AppShellScaffold(
      subtitle: '동기화 충돌',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryBlock(count: conflicts.length),
            const SizedBox(height: 12),
            MoriBlockShell(
              label: '충돌 목록',
              icon: Icons.sync_problem,
              accent: C.og,
              child: conflicts.isEmpty
                  ? const _EmptyState()
                  : Column(
                      children: [
                        for (final c in conflicts) ...[
                          _ConflictTile(
                            item: c,
                            onTap: () => _openDialog(context, ref, c),
                          ),
                          if (c != conflicts.last)
                            Divider(height: 1, color: C.bd),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog(
    BuildContext context,
    WidgetRef ref,
    ConflictItem item,
  ) async {
    final result = await showConflictResolutionDialog<Map<String, String>>(
      context: context,
      title: '${_entityLabel(item.entity)} 충돌',
      local: item.localFields,
      server: item.serverFields,
      labelOf: (_) => item.title,
      fieldsOf: (m) => m,
      updatedAtOf: (m) =>
          identical(m, item.localFields) ? item.localUpdatedAt : item.serverUpdatedAt,
      mergeBuilder: (baseLocal, server, sideMap) {
        final merged = <String, String>{};
        for (final entry in sideMap.entries) {
          merged[entry.key] = entry.value == FieldSide.local
              ? (baseLocal[entry.key] ?? '')
              : (server[entry.key] ?? '');
        }
        // sideMap에 없는 키는 local 기본
        for (final k in baseLocal.keys) {
          merged.putIfAbsent(k, () => baseLocal[k] ?? '');
        }
        return merged;
      },
    );

    if (result != null) {
      ref.read(conflictInboxProvider.notifier).remove(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('충돌이 해결됐어요.', style: T.body),
            backgroundColor: C.lvD,
          ),
        );
      }
    }
  }

  String _entityLabel(String entity) {
    switch (entity) {
      case 'swatch':
        return '스와치';
      case 'project':
        return '프로젝트';
      case 'pattern':
        return '도안';
      case 'counter':
        return '카운터';
      default:
        return entity;
    }
  }
}

class _SummaryBlock extends StatelessWidget {
  final int count;

  const _SummaryBlock({required this.count});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: C.og.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sync_problem, color: C.og, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0 ? '충돌 없음' : '대기 중 $count건',
                  style: T.h3,
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? '로컬과 서버 데이터가 모두 동기화됐어요.'
                      : '항목을 탭하면 로컬/서버/머지 중 선택할 수 있어요.',
                  style: T.sm.copyWith(color: C.mu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: C.lvD),
          const SizedBox(height: 8),
          Text('충돌이 없어요', style: T.bodyBold),
          const SizedBox(height: 4),
          Text(
            '동기화 충돌이 발생하면 여기로 모여요.',
            style: T.caption.copyWith(color: C.mu),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  final ConflictItem item;
  final VoidCallback onTap;

  const _ConflictTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded, color: C.og, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _EntityBadge(entity: item.entity),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.title,
                          style: T.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'doc: ${item.docId}',
                    style: T.caption.copyWith(color: C.mu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EntityBadge extends StatelessWidget {
  final String entity;

  const _EntityBadge({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: C.lv.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entity,
        style: T.caption.copyWith(
          color: C.lvD,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
