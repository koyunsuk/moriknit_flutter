// 이슈 #816 Phase 3 — 셀러 매출 대시보드.
//
// 본인이 셀러인 도안의 판매 내역을 집계해서 표시:
//   - users/{uid}/market_sales 컬렉션 read (셀러 본인 매출 사본)
//   - 기간 필터: 일/주/월 (기본값 = 월)
//   - 도안별 매출 TOP 5
//   - 최근 주문 리스트 (최신 20건)
//
// 데이터 소스:
//   - 본 화면은 본인 market_sales 만 조회 (어드민 권한 불필요)
//   - market_sales 컬렉션이 비어있어도 EmptyBlockPlaceholder로 안전 표시

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_data_view.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../providers/auth_provider.dart';
import '../../../market/domain/market_item.dart';

const Color _kSellerAccent = Color(0xFF7CB342);

enum _SalesPeriod {
  day('일', 1),
  week('주', 7),
  month('월', 30);

  final String label;
  final int days;
  const _SalesPeriod(this.label, this.days);
}

/// 본인 매출 (셀러 사본) — 최신 200건.
final _myMarketSalesProvider =
    StreamProvider<List<MarketPurchase>>((ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('market_sales')
      .orderBy('purchasedAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs.map(MarketPurchase.fromFirestore).toList());
});

class SellerSalesDashboardScreen extends ConsumerStatefulWidget {
  const SellerSalesDashboardScreen({super.key});

  @override
  ConsumerState<SellerSalesDashboardScreen> createState() =>
      _SellerSalesDashboardScreenState();
}

class _SellerSalesDashboardScreenState
    extends ConsumerState<SellerSalesDashboardScreen> {
  _SalesPeriod _period = _SalesPeriod.month;

  List<MarketPurchase> _filterByPeriod(List<MarketPurchase> all) {
    final since = DateTime.now().subtract(Duration(days: _period.days));
    return all.where((p) {
      final at = p.purchasedAt;
      if (at == null) return false;
      return at.isAfter(since);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(_myMarketSalesProvider);

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
        title: Text('매출 대시보드', style: T.h3.copyWith(color: C.tx)),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: AsyncDataView<List<MarketPurchase>>(
              async: salesAsync,
              isEmpty: (l) => l.isEmpty,
              emptyBuilder: () => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _PeriodSelector(
                      period: _period,
                      onChanged: (p) => setState(() => _period = p)),
                  const SizedBox(height: 12),
                  MoriBlockShell(
                    label: '매출',
                    icon: Icons.payments_rounded,
                    accent: _kSellerAccent,
                    child: const EmptyBlockPlaceholder(
                      message: '아직 판매된 도안이 없어요.\n도안이 판매되면 여기에 매출 정보가 표시돼요.',
                      rows: 3,
                    ),
                  ),
                ],
              ),
              placeholderRows: 6,
              rowHeight: 64,
              builder: (all) {
                final filtered = _filterByPeriod(all);
                final total = filtered.fold<int>(0, (a, b) => a + b.price);
                final count = filtered.length;
                final avg = count == 0 ? 0 : (total / count).round();

                // 도안별 매출 집계
                final Map<String, int> byItemId = {};
                final Map<String, String> titleByItem = {};
                for (final p in filtered) {
                  byItemId[p.itemId] = (byItemId[p.itemId] ?? 0) + p.price;
                  titleByItem[p.itemId] = p.title;
                }
                final sortedTopItems = byItemId.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final top = sortedTopItems.take(5).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _PeriodSelector(
                        period: _period,
                        onChanged: (p) => setState(() => _period = p)),
                    const SizedBox(height: 12),

                    // 매출 요약 (총액/건수/평균)
                    MoriBlockShell(
                      label: '${_period.label} 매출 요약',
                      icon: Icons.payments_rounded,
                      accent: _kSellerAccent,
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCell(
                              value: NumberFormat.decimalPattern().format(total),
                              suffix: '원',
                              label: '총 매출',
                            ),
                          ),
                          Expanded(
                            child: _SummaryCell(
                              value: '$count',
                              suffix: '건',
                              label: '판매 건수',
                            ),
                          ),
                          Expanded(
                            child: _SummaryCell(
                              value: NumberFormat.decimalPattern().format(avg),
                              suffix: '원',
                              label: '평균 단가',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TOP 도안
                    MoriBlockShell(
                      label: 'TOP 도안',
                      icon: Icons.emoji_events_rounded,
                      accent: C.lv,
                      child: top.isEmpty
                          ? const EmptyBlockPlaceholder(
                              message: '아직 집계된 판매가 없어요.',
                              rows: 2,
                              rowHeight: 40,
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < top.length; i++)
                                  _TopItemRow(
                                    rank: i + 1,
                                    title: titleByItem[top[i].key] ?? '(제목 없음)',
                                    amount: top[i].value,
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // 최근 주문
                    MoriBlockShell(
                      label: '최근 주문',
                      icon: Icons.shopping_bag_rounded,
                      accent: C.pk,
                      child: filtered.isEmpty
                          ? const EmptyBlockPlaceholder(
                              message: '해당 기간에 주문이 없어요.',
                              rows: 2,
                              rowHeight: 40,
                            )
                          : Column(
                              children: [
                                for (final p in filtered.take(20))
                                  _OrderRow(purchase: p),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final _SalesPeriod period;
  final ValueChanged<_SalesPeriod> onChanged;
  const _PeriodSelector({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in _SalesPeriod.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: period == p
                      ? _kSellerAccent
                      : _kSellerAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _kSellerAccent
                        .withValues(alpha: period == p ? 1.0 : 0.30),
                  ),
                ),
                child: Text(
                  p.label,
                  style: T.caption.copyWith(
                    color: period == p ? Colors.white : _kSellerAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String value;
  final String suffix;
  final String label;
  const _SummaryCell({
    required this.value,
    required this.suffix,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                style: T.h3.copyWith(
                    color: _kSellerAccent, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child:
                  Text(suffix, style: T.caption.copyWith(color: C.tx2)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: T.caption.copyWith(color: C.mu)),
      ],
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final int rank;
  final String title;
  final int amount;
  const _TopItemRow({
    required this.rank,
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => C.mu,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$rank',
                style: T.caption.copyWith(
                    color: medalColor, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: T.body.copyWith(color: C.tx),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${NumberFormat.decimalPattern().format(amount)}원',
            style: T.bodyBold.copyWith(color: _kSellerAccent),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final MarketPurchase purchase;
  const _OrderRow({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final when = purchase.purchasedAt == null
        ? '-'
        : DateFormat('MM-dd HH:mm').format(purchase.purchasedAt!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchase.title.isEmpty ? '(제목 없음)' : purchase.title,
                  style: T.body.copyWith(color: C.tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  when,
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${NumberFormat.decimalPattern().format(purchase.price)}원',
            style: T.bodyBold.copyWith(color: C.tx),
          ),
        ],
      ),
    );
  }
}
