// lib/features/expense/domain/knitting_expense.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  needle,  // 바늘 🪡
  yarn,    // 실 🧶
  pattern, // 도안 📄
  tool,    // 도구 🛒
  book,    // 서적 📚
  other,   // 기타 📦
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.needle:
        return '바늘';
      case ExpenseCategory.yarn:
        return '실';
      case ExpenseCategory.pattern:
        return '도안';
      case ExpenseCategory.tool:
        return '도구';
      case ExpenseCategory.book:
        return '서적';
      case ExpenseCategory.other:
        return '기타';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.needle:
        return '🪡';
      case ExpenseCategory.yarn:
        return '🧶';
      case ExpenseCategory.pattern:
        return '📄';
      case ExpenseCategory.tool:
        return '🛒';
      case ExpenseCategory.book:
        return '📚';
      case ExpenseCategory.other:
        return '📦';
    }
  }
}

class KnittingExpense {
  final String id;
  final String userId;
  final String category; // ExpenseCategory.name
  final String title;
  final int amountWon;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  const KnittingExpense({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.amountWon,
    required this.date,
    required this.note,
    required this.createdAt,
  });

  ExpenseCategory get categoryEnum {
    try {
      return ExpenseCategory.values.firstWhere((e) => e.name == category);
    } catch (_) {
      return ExpenseCategory.other;
    }
  }

  KnittingExpense copyWith({
    String? id,
    String? userId,
    String? category,
    String? title,
    int? amountWon,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return KnittingExpense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      title: title ?? this.title,
      amountWon: amountWon ?? this.amountWon,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'title': title,
      'amountWon': amountWon,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory KnittingExpense.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return KnittingExpense(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      category: json['category'] as String? ?? ExpenseCategory.other.name,
      title: json['title'] as String? ?? '',
      amountWon: (json['amountWon'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date']),
      note: json['note'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
    );
  }

  factory KnittingExpense.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return KnittingExpense.fromJson({...data, 'id': doc.id});
  }
}
