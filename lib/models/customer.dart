import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double totalPurchases;
  final int loyaltyPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.totalPurchases = 0,
    this.loyaltyPoints = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.create({required String name, String? phone, String? email, String? address, String? notes}) {
    final now = DateTime.now();
    return Customer(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      totalPurchases: (map['total_purchases'] as num? ?? 0).toDouble(),
      loyaltyPoints: (map['loyalty_points'] as int?) ?? 0,
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
      'total_purchases': totalPurchases,
      'loyalty_points': loyaltyPoints,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
