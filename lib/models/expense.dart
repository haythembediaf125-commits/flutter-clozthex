import 'package:uuid/uuid.dart';

enum ExpenseType {
  general,       // مصروف عام
  rent,          // إيجار
  utilities,    // فواتير (كهرباء، ماء، إنترنت)
  salaries,      // رواتب
  supplies,      // مستلزمات
  maintenance,   // صيانة
  marketing,     // تسويق
  transport,     // نقل وشحن
  other,         // أخرى
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseType type;
  final String? category;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.type = ExpenseType.general,
    this.category,
    this.notes,
    required this.date,
    required this.createdAt,
  });

  factory Expense.create({
    required String title,
    required double amount,
    ExpenseType type = ExpenseType.general,
    String? category,
    String? notes,
    DateTime? date,
  }) {
    final now = DateTime.now();
    return Expense(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      type: type,
      category: category,
      notes: notes,
      date: date ?? now,
      createdAt: now,
    );
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: _parseExpenseType(map['expense_type'] as String?),
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static ExpenseType _parseExpenseType(String? val) {
    switch (val) {
      case 'rent': return ExpenseType.rent;
      case 'utilities': return ExpenseType.utilities;
      case 'salaries': return ExpenseType.salaries;
      case 'supplies': return ExpenseType.supplies;
      case 'maintenance': return ExpenseType.maintenance;
      case 'marketing': return ExpenseType.marketing;
      case 'transport': return ExpenseType.transport;
      case 'other': return ExpenseType.other;
      default: return ExpenseType.general;
    }
  }

  String get typeText {
    switch (type) {
      case ExpenseType.general: return 'مصروف عام';
      case ExpenseType.rent: return 'إيجار';
      case ExpenseType.utilities: return 'فواتير';
      case ExpenseType.salaries: return 'رواتب';
      case ExpenseType.supplies: return 'مستلزمات';
      case ExpenseType.maintenance: return 'صيانة';
      case ExpenseType.marketing: return 'تسويق';
      case ExpenseType.transport: return 'نقل وشحن';
      case ExpenseType.other: return 'أخرى';
    }
  }

  String get typeIcon {
    switch (type) {
      case ExpenseType.general: return '💰';
      case ExpenseType.rent: return '🏠';
      case ExpenseType.utilities: return '💡';
      case ExpenseType.salaries: return '👥';
      case ExpenseType.supplies: return '📦';
      case ExpenseType.maintenance: return '🔧';
      case ExpenseType.marketing: return '📢';
      case ExpenseType.transport: return '🚚';
      case ExpenseType.other: return '📋';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'expense_type': type.name,
      'category': category,
      'notes': notes,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Expense copyWith({
    String? title,
    double? amount,
    ExpenseType? type,
    String? category,
    String? notes,
    DateTime? date,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt,
    );
  }
}