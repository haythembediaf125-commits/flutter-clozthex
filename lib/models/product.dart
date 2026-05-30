import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final String? barcode;
  final String? sku;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String? supplierName;
  final double purchasePrice;
  final double salePrice;
  final int quantity;
  final int minQuantity;
  final String? size;
  final String? color;
  final String? brand;
  final String? imagePath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.description,
    this.barcode,
    this.sku,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    this.supplierName,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    this.minQuantity = 5,
    this.size,
    this.color,
    this.brand,
    this.imagePath,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= minQuantity;
  bool get isOutOfStock => quantity == 0;
  double get profitMargin => salePrice > 0 ? ((salePrice - purchasePrice) / salePrice) * 100 : 0;
  double get profit => salePrice - purchasePrice;

  factory Product.create({
    required String name,
    String? description,
    String? barcode,
    String? sku,
    String? categoryId,
    String? supplierId,
    required double purchasePrice,
    required double salePrice,
    int quantity = 0,
    int minQuantity = 5,
    String? size,
    String? color,
    String? brand,
    String? imagePath,
  }) {
    final now = DateTime.now();
    return Product(
      id: const Uuid().v4(),
      name: name,
      description: description,
      barcode: barcode,
      sku: sku,
      categoryId: categoryId,
      supplierId: supplierId,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      quantity: quantity,
      minQuantity: minQuantity,
      size: size,
      color: color,
      brand: brand,
      imagePath: imagePath,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      supplierId: map['supplier_id'] as String?,
      supplierName: map['supplier_name'] as String?,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      minQuantity: (map['min_quantity'] as int?) ?? 5,
      size: map['size'] as String?,
      color: map['color'] as String?,
      brand: map['brand'] as String?,
      imagePath: map['image_path'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'barcode': barcode,
      'sku': sku,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'size': size,
      'color': color,
      'brand': brand,
      'image_path': imagePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? name,
    String? description,
    String? barcode,
    String? sku,
    String? categoryId,
    String? supplierId,
    double? purchasePrice,
    double? salePrice,
    int? quantity,
    int? minQuantity,
    String? size,
    String? color,
    String? brand,
    String? imagePath,
    bool? isActive,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      size: size ?? this.size,
      color: color ?? this.color,
      brand: brand ?? this.brand,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
