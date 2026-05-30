import 'package:uuid/uuid.dart';

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final double unitPrice;
  final double purchasePrice;
  final double discount;
  final double total;
  final DateTime createdAt;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    this.purchasePrice = 0,
    this.discount = 0,
    required this.total,
    required this.createdAt,
  });

  double get profit => (unitPrice - purchasePrice - discount) * quantity;

  factory SaleItem.create({
    required String saleId,
    required String productId,
    required String productName,
    String? barcode,
    required int quantity,
    required double unitPrice,
    double purchasePrice = 0,
    double discount = 0,
  }) {
    return SaleItem(
      id: const Uuid().v4(),
      saleId: saleId,
      productId: productId,
      productName: productName,
      barcode: barcode,
      quantity: quantity,
      unitPrice: unitPrice,
      purchasePrice: purchasePrice,
      discount: discount,
      total: (unitPrice - discount) * quantity,
      createdAt: DateTime.now(),
    );
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String?,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      purchasePrice: (map['purchase_price'] as num? ?? 0).toDouble(),
      discount: (map['discount'] as num? ?? 0).toDouble(),
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'purchase_price': purchasePrice,
      'discount': discount,
      'total': total,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
