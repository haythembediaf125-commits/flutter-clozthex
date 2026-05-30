import 'package:uuid/uuid.dart';

enum DebtStatus { pending, paid }

enum DebtType { owed, due } // owed = أموال المدينة (مطلوبات), due = أموال المحل (على المحل)

class Debt {
  final String id;
  final String personName;
  final String? phone;
  final double amount;
  final String? description;
  final DateTime? dueDate;
  final bool isPaid;
  final DateTime? paidDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DebtType type;

  const Debt({
    required this.id,
    required this.personName,
    this.phone,
    required this.amount,
    this.description,
    this.dueDate,
    this.isPaid = false,
    this.paidDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
  });

  factory Debt.create({
    required String personName,
    String? phone,
    required double amount,
    String? description,
    DateTime? dueDate,
    String? notes,
    required DebtType type,
  }) {
    final now = DateTime.now();
    return Debt(
      id: const Uuid().v4(),
      personName: personName,
      phone: phone,
      amount: amount,
      description: description,
      dueDate: dueDate,
      isPaid: false,
      paidDate: null,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      type: type,
    );
  }

  factory Debt.fromMap(Map<String, dynamic> map, DebtType type) {
    return Debt(
      id: map['id'] as String,
      personName: map['person_name'] as String,
      phone: map['phone'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      isPaid: (map['is_paid'] as int?) == 1,
      paidDate: map['paid_date'] != null ? DateTime.parse(map['paid_date'] as String) : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      type: type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'phone': phone,
      'amount': amount,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
      'paid_date': paidDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Debt copyWith({
    String? id,
    String? personName,
    String? phone,
    double? amount,
    String? description,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? paidDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DebtType? type,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phone: phone ?? this.phone,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }

  // Getters for Arabic display
  String get statusText => isPaid ? 'مدفوع' : 'غير مدفوع';
  String get typeText => type == DebtType.owed ? 'مطلوب' : 'مستحق';
  String get typeLabel => type == DebtType.owed ? 'أموال المدينة' : 'أموال المحل';
}