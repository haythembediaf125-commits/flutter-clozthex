import 'package:uuid/uuid.dart';
import 'sale_item.dart';

enum PaymentMethod { cash, card, transfer }
enum SaleStatus { completed, returned, cancelled }
enum DiscountType { fixed, percentage }

class Sale {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String? customerName;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final DiscountType discountType;
  final double tax;
  final double total;
  final double paid;
  final double changeAmount;
  final PaymentMethod paymentMethod;
  final String? notes;
  final SaleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.items = const [],
    required this.subtotal,
    this.discount = 0,
    this.discountType = DiscountType.fixed,
    this.tax = 0,
    required this.total,
    this.paid = 0,
    this.changeAmount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
    this.status = SaleStatus.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  double get discountAmount {
    if (discountType == DiscountType.percentage) {
      return subtotal * (discount / 100);
    }
    return discount;
  }

  double get profit => items.fold(0, (sum, item) => sum + item.profit);

  String get paymentMethodAr {
    switch (paymentMethod) {
      case PaymentMethod.cash: return 'نقداً';
      case PaymentMethod.card: return 'بطاقة';
      case PaymentMethod.transfer: return 'تحويل';
    }
  }

  String get statusAr {
    switch (status) {
      case SaleStatus.completed: return 'مكتملة';
      case SaleStatus.returned: return 'مُرجعة';
      case SaleStatus.cancelled: return 'ملغاة';
    }
  }

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem>? items}) {
    return Sale(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      items: items ?? [],
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num? ?? 0).toDouble(),
      discountType: map['discount_type'] == 'percentage' ? DiscountType.percentage : DiscountType.fixed,
      tax: (map['tax'] as num? ?? 0).toDouble(),
      total: (map['total'] as num).toDouble(),
      paid: (map['paid'] as num? ?? 0).toDouble(),
      changeAmount: (map['change_amount'] as num? ?? 0).toDouble(),
      paymentMethod: _parsePaymentMethod(map['payment_method'] as String?),
      notes: map['notes'] as String?,
      status: _parseSaleStatus(map['status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static PaymentMethod _parsePaymentMethod(String? val) {
    switch (val) {
      case 'card': return PaymentMethod.card;
      case 'transfer': return PaymentMethod.transfer;
      default: return PaymentMethod.cash;
    }
  }

  static SaleStatus _parseSaleStatus(String? val) {
    switch (val) {
      case 'returned': return SaleStatus.returned;
      case 'cancelled': return SaleStatus.cancelled;
      default: return SaleStatus.completed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType == DiscountType.percentage ? 'percentage' : 'fixed',
      'tax': tax,
      'total': total,
      'paid': paid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod.name,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toMap(),
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?)
        ?.map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];
    return Sale.fromMap(json, items: items);
  }
}

class CartItem {
  final String productId;
  final String productName;
  final String? barcode;
  final double unitPrice;
  final double purchasePrice;
  int quantity;
  double discount;

  CartItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.unitPrice,
    required this.purchasePrice,
    this.quantity = 1,
    this.discount = 0,
  });

  double get total => (unitPrice - discount) * quantity;
  double get profit => (unitPrice - purchasePrice - discount) * quantity;

  SaleItem toSaleItem(String saleId) {
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
      total: total,
      createdAt: DateTime.now(),
    );
  }
}
