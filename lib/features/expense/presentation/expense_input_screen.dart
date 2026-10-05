// lib/features/expense/presentation/expense_input_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/knitting_expense_repository.dart';
import '../domain/knitting_expense.dart';

class ExpenseInputScreen extends ConsumerStatefulWidget {
  final KnittingExpense? existing;
  const ExpenseInputScreen({super.key, this.existing});

  @override
  ConsumerState<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends ConsumerState<ExpenseInputScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _fmt = DateFormat('yyyy년 M월 d일');

  ExpenseCategory _category = ExpenseCategory.yarn;
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _category = e.categoryEnum;
      _date = e.date;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amountWon.toString();
      _noteCtrl.text = e.note;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amountText = _amountCtrl.text.trim();

    if (title.isEmpty) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '항목명을 입력해 주세요.');
      return;
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '금액을 올바르게 입력해 주세요.');
      return;
    }

    final expense = KnittingExpense(
      id: widget.existing?.id ?? const Uuid().v4(),
      userId: '',
      category: _category.name,
      title: title,
      amountWon: amount,
      date: _date,
      note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '저장하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () => ref.read(knittingExpenseRepositoryProvider).save(expense),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '저장됐어요.');
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(_isEdit ? '지출 수정' : '지출 추가', style: T.h3),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카테고리
                SectionTitle(title: '카테고리'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExpenseCategory.values.map((cat) {
                    final isSelected = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? C.lv : C.lv.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          '${cat.emoji} ${cat.label}',
                          style: T.body.copyWith(
                            color: isSelected ? Colors.white : C.lvD,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 날짜
                SectionTitle(title: '날짜'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.bd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18, color: C.mu),
                        const SizedBox(width: 10),
                        Text(_fmt.format(_date), style: T.body.copyWith(color: C.tx)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 항목명
                SectionTitle(title: '항목명'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  style: T.body.copyWith(color: C.tx),
                  decoration: InputDecoration(
                    labelText: '항목명',
                    hintText: '예) 4mm 대바늘',
                    filled: true,
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 금액
                SectionTitle(title: '금액 (원)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: T.body.copyWith(color: C.tx),
                  decoration: InputDecoration(
                    labelText: '금액',
                    hintText: '예) 15000',
                    suffixText: '원',
                    filled: true,
                    fillColor: C.gx,
                  ),
                ),
                const SizedBox(height: 20),

                // 메모
                SectionTitle(title: '메모 (선택)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  style: T.body.copyWith(color: C.tx),
                  decoration: InputDecoration(
                    labelText: '메모',
                    hintText: '구매처, 링크 등 자유롭게 입력',
                    filled: true,
                    fillColor: C.gx,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ),
        ),
      ),
    );
  }
}
