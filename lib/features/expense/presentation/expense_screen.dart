// lib/features/expense/presentation/expense_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/knitting_expense_repository.dart';
import '../domain/knitting_expense.dart';
import 'expense_input_screen.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  late DateTime _selectedMonth;
  final _fmt = NumberFormat('#,###', 'ko_KR');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _selectedMonth = next;
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: '월 선택',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Future<void> _deleteExpense(KnittingExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('지출 삭제'),
        content: Text('"${expense.title}" 항목을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제', style: TextStyle(color: C.og)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '삭제하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () => ref.read(knittingExpenseRepositoryProvider).delete(expense.id),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '삭제됐어요.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearMonth = (_selectedMonth.year, _selectedMonth.month);
    final expensesAsync = ref.watch(expensesByMonthProvider(yearMonth));
    final monthLabel = DateFormat('yyyy년 M월').format(_selectedMonth);
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('뜨개 가계부', style: T.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            color: C.tx,
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                // 월 이동 컨트롤
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: C.tx),
                        onPressed: _prevMonth,
                      ),
                      Text(monthLabel, style: T.bodyBold.copyWith(color: C.tx)),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: isCurrentMonth ? C.bd : C.tx,
                        ),
                        onPressed: isCurrentMonth ? null : _nextMonth,
                      ),
                    ],
                  ),
                ),
                // 본문
                Expanded(
                  child: expensesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('오류: $e', style: T.body.copyWith(color: C.og))),
                    data: (expenses) => _buildContent(expenses),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ExpenseInputScreen(),
          ),
        ),
        backgroundColor: C.lv,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(List<KnittingExpense> expenses) {
    if (expenses.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          const SizedBox(height: 8),
          MoriBlockShell(
            label: '이번 달 지출',
            icon: Icons.account_balance_wallet_outlined,
            accent: C.lv,
            child: EmptyBlockPlaceholder(
              message: '이번 달 지출 내역이 없어요.\n+ 버튼으로 지출을 추가해 보세요.',
              rows: 2,
            ),
          ),
        ],
      );
    }

    // 카테고리별 합계
    final Map<ExpenseCategory, int> categoryTotals = {};
    int totalAmount = 0;
    for (final e in expenses) {
      final cat = e.categoryEnum;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amountWon;
      totalAmount += e.amountWon;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        const SizedBox(height: 8),
        // 요약 블록
        MoriBlockShell(
          label: '이번 달 지출',
          icon: Icons.account_balance_wallet_outlined,
          accent: C.lv,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 카테고리별 합계
              ...categoryTotals.entries.map((entry) {
                final cat = entry.key;
                final amount = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(cat.label, style: T.body.copyWith(color: C.tx2)),
                      const Spacer(),
                      Text(
                        '${_fmt.format(amount)}원',
                        style: T.bodyBold.copyWith(color: C.tx),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('합계', style: T.bodyBold.copyWith(color: C.tx)),
                  Text(
                    '${_fmt.format(totalAmount)}원',
                    style: T.h3.copyWith(color: C.lv),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 목록 블록
        MoriBlockShell(
          label: '지출 목록',
          icon: Icons.receipt_long_outlined,
          accent: C.pk,
          child: Column(
            children: expenses.map((e) => _ExpenseTile(
              expense: e,
              fmt: _fmt,
              onLongPress: () => _deleteExpense(e),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseInputScreen(existing: e),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final KnittingExpense expense;
  final NumberFormat fmt;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _ExpenseTile({
    required this.expense,
    required this.fmt,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = expense.categoryEnum;
    final dateStr = DateFormat('M/d').format(expense.date);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: T.bodyBold.copyWith(color: C.tx), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(dateStr, style: T.caption.copyWith(color: C.mu)),
                ],
              ),
            ),
            Text(
              '${fmt.format(expense.amountWon)}원',
              style: T.bodyBold.copyWith(color: C.tx),
            ),
          ],
        ),
      ),
    );
  }
}
