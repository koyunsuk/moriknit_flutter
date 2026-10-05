// lib/features/expense/data/knitting_expense_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/knitting_expense.dart';

class KnittingExpenseRepository {
  KnittingExpenseRepository(this._uid);

  final String _uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('knitting_expenses');

  /// 특정 연/월의 지출 목록을 실시간 구독합니다.
  Stream<List<KnittingExpense>> watchByMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => KnittingExpense.fromDoc(d)).toList());
  }

  /// 전체 지출 목록을 실시간 구독합니다 (최대 200건).
  Stream<List<KnittingExpense>> watchAll() {
    return _col
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => KnittingExpense.fromDoc(d)).toList());
  }

  /// 지출 항목을 저장(신규/수정)합니다.
  Future<void> save(KnittingExpense expense) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final id = expense.id.isEmpty ? _uuid.v4() : expense.id;
    final data = expense.copyWith(id: id, userId: _uid).toJson();
    await _col.doc(id).set(data, SetOptions(merge: true));
  }

  /// 지출 항목을 삭제합니다.
  Future<void> delete(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _col.doc(id).delete();
  }
}

// ── Providers ────────────────────────────────────────────────

final knittingExpenseRepositoryProvider =
    Provider<KnittingExpenseRepository>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return KnittingExpenseRepository(uid);
});

/// 연/월별 지출 목록 StreamProvider.family (year, month)
final expensesByMonthProvider = StreamProvider.family<
    List<KnittingExpense>, (int, int)>((ref, yearMonth) {
  final repo = ref.watch(knittingExpenseRepositoryProvider);
  return repo.watchByMonth(yearMonth.$1, yearMonth.$2);
});
