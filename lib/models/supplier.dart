import 'package:uuid/uuid.dart';

class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.balance = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.create({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double balance = 0,
  }) {
    final now = DateTime.now();
    return Supplier(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      balance: balance,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num? ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Supplier copyWith({String? name, String? phone, String? email, String? address, String? notes, double? balance}) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
