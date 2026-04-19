import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/ravelry_repository.dart';
import '../domain/ravelry_models.dart';
import 'ravelry_project_edit_sheet.dart';

final _projectDetailProvider = FutureProvider.autoDispose.family<RavelryProjectDetail, int>(
  (ref, id) {
    final repo = ref.watch(ravelryRepositoryProvider);
    if (repo == null) throw Exception('Ravelry 연결이 필요합니다.');
    return repo.fetchProjectDetail(id);
  },
);

class RavelryProjectDetailScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;

  const RavelryProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<RavelryProjectDetailScreen> createState() => _RavelryProjectDetailScreenState();
}

class _RavelryProjectDetailScreenState extends ConsumerState<RavelryProjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final detailAsync = ref.watch(_projectDetailProvider(widget.projectId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.projectName, style: T.h3),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          detailAsync.whenData((detail) => PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: C.tx),
            onSelected: (v) {
              if (v == 'edit') {
                showRavelryProjectUpdateSheet(
                  context,
                  ref,
                  projectId: detail.id,
                  projectName: detail.name,
                  statusTypeId: detail.statusTypeId,
                  notes: detail.notes,
                  isKorean: isKorean,
                  onUpdated: () => ref.invalidate(_projectDetailProvider(widget.projectId)),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(isKorean ? '수정' : 'Edit'),
              ),
            ],
          )).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: C.og, size: 48),
                    const SizedBox(height: 12),
                    Text('$e',
                        style: T.caption.copyWith(color: C.og),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(_projectDetailProvider(widget.projectId)),
                      child: Text(isKorean ? '다시 시도' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (detail) => _ProjectDetailBody(detail: detail, isKorean: isKorean),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailBody extends StatelessWidget {
  const _ProjectDetailBody({required this.detail, required this.isKorean});
  final RavelryProjectDetail detail;
  final bool isKorean;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 커버 이미지
          if (detail.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: detail.photoUrls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Container(color: C.lvL, child: Icon(Icons.folder_special_rounded, color: C.lv, size: 48)),
                ),
              ),
            ),
          const SizedBox(height: 16),

          Text(detail.name, style: T.h3),
          if (detail.patternName != null) ...[
            const SizedBox(height: 4),
            Text(detail.patternName!, style: T.body.copyWith(color: C.mu)),
          ],
          const SizedBox(height: 12),

          // 상태 칩
          if (detail.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isKorean ? detail.statusKo : (detail.status ?? ''),
                style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 20),

          // 날짜 정보
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DateCell(
                    label: isKorean ? '시작일' : 'Started',
                    value: _formatDate(detail.startedAt),
                  ),
                ),
                Container(width: 1, height: 36, color: C.bd),
                Expanded(
                  child: _DateCell(
                    label: isKorean ? '완료일' : 'Completed',
                    value: _formatDate(detail.completedAt),
                  ),
                ),
              ],
            ),
          ),

          // 메모
          if (detail.notes != null && detail.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionTitle(title: isKorean ? '메모' : 'Notes'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Text(
                detail.notes!,
                style: T.sm.copyWith(color: C.tx2, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: T.caption.copyWith(color: C.mu)),
        const SizedBox(height: 2),
        Text(value, style: T.bodyBold),
      ],
    );
  }
}
