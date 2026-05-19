// 이슈 #816 Phase 3 — 셀러 리뷰 응답 화면.
//
// 본인이 셀러인 도안의 리뷰를 한 곳에 모아 표시 + 응답:
//   1. market_items where sellerUid == 본인 → 본인 도안 리스트
//   2. 각 도안의 reviews 서브컬렉션을 합쳐 최신순 정렬
//   3. 셀러는 리뷰에 응답 (response 필드 merge) — 한 리뷰당 응답 1개
//
// 응답 저장: runWithMoriLoadingDialog 표준 패턴.
// 셀러 본인 도안만 접근 가능 (firestore.rules 의 market_items.write 정책 활용).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_data_view.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../providers/auth_provider.dart';

const Color _kSellerAccent = Color(0xFF7CB342);

/// 본인 도안의 리뷰 모음.
/// (itemId, itemTitle, reviewDoc) 튜플 리스트.
class SellerReviewEntry {
  final String itemId;
  final String itemTitle;
  final String reviewId;
  final String reviewerName;
  final String reviewerUid;
  final double rating;
  final String comment;
  final String? response; // 셀러 응답
  final DateTime? createdAt;

  const SellerReviewEntry({
    required this.itemId,
    required this.itemTitle,
    required this.reviewId,
    required this.reviewerName,
    required this.reviewerUid,
    required this.rating,
    required this.comment,
    this.response,
    this.createdAt,
  });
}

final _sellerReviewsProvider =
    FutureProvider<List<SellerReviewEntry>>((ref) async {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return const [];

  final db = FirebaseFirestore.instance;
  // 1) 본인 도안 list
  final itemsSnap = await db
      .collection('market_items')
      .where('sellerUid', isEqualTo: uid)
      .limit(100)
      .get();
  if (itemsSnap.docs.isEmpty) return const [];

  // 2) 각 도안의 reviews 서브컬렉션
  final List<SellerReviewEntry> all = [];
  for (final itemDoc in itemsSnap.docs) {
    final title = (itemDoc.data()['title'] as String?) ?? '(제목 없음)';
    try {
      final reviewsSnap = await db
          .collection('market_items')
          .doc(itemDoc.id)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      for (final r in reviewsSnap.docs) {
        final data = r.data();
        final ts = data['createdAt'];
        DateTime? createdAt;
        if (ts is Timestamp) {
          createdAt = ts.toDate();
        } else if (ts is String) {
          createdAt = DateTime.tryParse(ts);
        }
        all.add(SellerReviewEntry(
          itemId: itemDoc.id,
          itemTitle: title,
          reviewId: r.id,
          reviewerName: (data['reviewerName'] as String?) ?? '익명',
          reviewerUid: (data['reviewerUid'] as String?) ?? '',
          rating: (data['rating'] as num?)?.toDouble() ?? 0,
          comment: (data['comment'] as String?) ?? '',
          response: data['response'] as String?,
          createdAt: createdAt,
        ));
      }
    } catch (_) {
      // 권한/인덱스 문제 시 해당 도안만 스킵
    }
  }

  all.sort((a, b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return all;
});

class SellerReviewsScreen extends ConsumerStatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  ConsumerState<SellerReviewsScreen> createState() =>
      _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends ConsumerState<SellerReviewsScreen> {
  String _filter = 'all'; // all / unanswered

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(_sellerReviewsProvider);

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
        title: Text('리뷰 응답', style: T.h3.copyWith(color: C.tx)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: C.tx),
            onPressed: () => ref.invalidate(_sellerReviewsProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // 필터
                  MoriBlockShell(
                    label: '필터',
                    icon: Icons.filter_list_rounded,
                    accent: _kSellerAccent,
                    child: Row(
                      children: [
                        _FilterBtn(
                          label: '전체',
                          selected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _FilterBtn(
                          label: '미응답',
                          selected: _filter == 'unanswered',
                          onTap: () => setState(() => _filter = 'unanswered'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AsyncDataView<List<SellerReviewEntry>>(
                      async: reviewsAsync,
                      isEmpty: (l) => _applyFilter(l).isEmpty,
                      emptyBuilder: () => MoriBlockShell(
                        label: '리뷰',
                        icon: Icons.star_rounded,
                        accent: _kSellerAccent,
                        child: EmptyBlockPlaceholder(
                          message: _filter == 'unanswered'
                              ? '응답 대기 중인 리뷰가 없어요.'
                              : '받은 리뷰가 없어요.\n도안이 판매되고 구매자가 리뷰를 남기면 여기에 표시돼요.',
                          rows: 3,
                        ),
                      ),
                      placeholderRows: 5,
                      rowHeight: 84,
                      builder: (all) {
                        final list = _applyFilter(all);
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _ReviewCard(entry: list[i], onResponded: () {
                                ref.invalidate(_sellerReviewsProvider);
                              }),
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

  List<SellerReviewEntry> _applyFilter(List<SellerReviewEntry> all) {
    if (_filter == 'unanswered') {
      return all
          .where((e) => e.response == null || e.response!.trim().isEmpty)
          .toList();
    }
    return all;
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
          color: selected ? _kSellerAccent : _kSellerAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _kSellerAccent.withValues(alpha: selected ? 1.0 : 0.30),
          ),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? Colors.white : _kSellerAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final SellerReviewEntry entry;
  final VoidCallback onResponded;
  const _ReviewCard({required this.entry, required this.onResponded});

  @override
  Widget build(BuildContext context) {
    final when = entry.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt!);
    final hasResponse = entry.response != null && entry.response!.trim().isNotEmpty;

    return MoriBlockShell(
      label: entry.itemTitle,
      icon: Icons.menu_book_rounded,
      accent: _kSellerAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 별점 + 이름 + 시간
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < entry.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: const Color(0xFFFFC107),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.reviewerName,
                  style: T.caption.copyWith(color: C.tx, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(when, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry.comment, style: T.body.copyWith(color: C.tx)),

          // 셀러 응답
          if (hasResponse) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSellerAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kSellerAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded, size: 14, color: _kSellerAccent),
                      const SizedBox(width: 4),
                      Text('셀러 응답',
                          style: T.caption.copyWith(
                              color: _kSellerAccent,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(entry.response!, style: T.body.copyWith(color: C.tx)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(hasResponse ? Icons.edit_rounded : Icons.reply_rounded,
                  size: 16, color: _kSellerAccent),
              label: Text(
                hasResponse ? '응답 수정' : '응답 작성',
                style: T.caption.copyWith(
                  color: _kSellerAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _openResponseDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResponseDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: entry.response ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('리뷰 응답', style: T.h3.copyWith(color: C.tx)),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '구매자에게 전할 메시지를 입력해 주세요.',
            filled: true,
            fillColor: C.gx,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('취소', style: TextStyle(color: C.tx2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kSellerAccent),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) {
                Navigator.pop(dialogCtx, false);
                return;
              }
              Navigator.pop(dialogCtx, true);
              try {
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: '저장하는 중입니다.',
                  subtitle: '잠시만 기다려 주세요.',
                  task: () async {
                    await FirebaseFirestore.instance
                        .collection('market_items')
                        .doc(entry.itemId)
                        .collection('reviews')
                        .doc(entry.reviewId)
                        .set({
                      'response': text,
                      'respondedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  },
                );
                if (!context.mounted) return;
                showSavedSnackBar(
                    ScaffoldMessenger.of(context), message: '응답을 저장했어요.');
                onResponded();
              } catch (e) {
                if (!context.mounted) return;
                showSaveErrorSnackBar(
                    ScaffoldMessenger.of(context), message: '$e');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved != true) return;
  }
}
