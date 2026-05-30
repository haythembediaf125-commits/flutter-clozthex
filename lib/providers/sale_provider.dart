import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/sale_service.dart';

class SaleException implements Exception {
  final String message;
  SaleException(this.message);

  @override
  String toString() => message;
}

class SaleProvider with ChangeNotifier {
  final SaleService _service = SaleService();

  // Cart state
  final List<CartItem> _cart = [];
  String? _customerId;
  String? _customerName;
  double _discount = 0;
  DiscountType _discountType = DiscountType.fixed;
  double _taxRate = 0;
  double _paid = 0;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _notes;

  // Error state
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sales history
  List<Sale> _sales = [];
  bool _loading = false;
  String? _lastError;

  // Getters
  List<CartItem> get cart => List.unmodifiable(_cart);
  List<Sale> get sales => _sales;
  bool get loading => _loading;
  String? get customerId => _customerId;
  String? get customerName => _customerName;
  double get discount => _discount;
  DiscountType get discountType => _discountType;
  double get taxRate => _taxRate;
  double get paid => _paid;
  PaymentMethod get paymentMethod => _paymentMethod;
  String? get notes => _notes;

  double get subtotal => _cart.fold(0, (s, i) => s + (i.unitPrice * i.quantity));
  double get discountAmount => _discountType == DiscountType.percentage
      ? subtotal * (_discount / 100)
      : _discount;
  double get afterDiscount => subtotal - discountAmount;
  double get taxAmount => afterDiscount * (_taxRate / 100);
  double get total => afterDiscount + taxAmount;
  double get change => _paid - total;
  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);

  // ─── Cart Management ───────────────────────────────────────────────────────

  void addToCart(Product product, {int quantity = 1}) {
    final existing = _cart.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      final item = _cart[existing];
      if (item.quantity + quantity <= product.quantity) {
        _cart[existing] = CartItem(
          productId: item.productId,
          productName: item.productName,
          barcode: item.barcode,
          unitPrice: item.unitPrice,
          purchasePrice: item.purchasePrice,
          quantity: item.quantity + quantity,
          discount: item.discount,
        );
      }
    } else {
      if (product.quantity > 0) {
        _cart.add(CartItem(
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          unitPrice: product.salePrice,
          purchasePrice: product.purchasePrice,
          quantity: quantity,
        ));
      }
    }
    notifyListeners();
  }

  void updateCartItemQuantity(String productId, int quantity) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    if (quantity <= 0) {
      _cart.removeAt(idx);
    } else {
      _cart[idx].quantity = quantity;
    }
    notifyListeners();
  }

  void updateCartItemPrice(String productId, double price) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = _cart[idx];
    _cart[idx] = CartItem(
      productId: item.productId,
      productName: item.productName,
      barcode: item.barcode,
      unitPrice: price,
      purchasePrice: item.purchasePrice,
      quantity: item.quantity,
      discount: item.discount,
    );
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0;
    _discountType = DiscountType.fixed;
    _paid = 0;
    _notes = null;
    _customerId = null;
    _customerName = null;
    notifyListeners();
  }

  void setCustomer(String? id, String? name) {
    _customerId = id;
    _customerName = name;
    notifyListeners();
  }

  void setDiscount(double value, DiscountType type) {
    _discount = value;
    _discountType = type;
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate;
    notifyListeners();
  }

  void setPaid(double amount) {
    _paid = amount;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setNotes(String? notes) {
    _notes = notes;
    notifyListeners();
  }

  // ─── Sale Operations ───────────────────────────────────────────────────────

  Future<Sale> completeSale() async {
    // Validate cart
    if (_cart.isEmpty) {
      throw SaleException('السلة فارغة');
    }

    // Validate paid amount
    if (_paymentMethod == PaymentMethod.cash && _paid < total) {
      throw SaleException('المبلغ المدفوع أقل من الإجمالي');
    }

    _lastError = null;
    notifyListeners();

    try {
      // Create a copy of cart items for the service
      final cartItemsCopy = _cart.map((item) => CartItem(
        productId: item.productId,
        productName: item.productName,
        barcode: item.barcode,
        unitPrice: item.unitPrice,
        purchasePrice: item.purchasePrice,
        quantity: item.quantity,
        discount: item.discount,
      )).toList();

      final sale = await _service.completeSale(
        cartItems: cartItemsCopy,
        customerId: _customerId,
        customerName: _customerName,
        discount: _discount,
        discountType: _discountType,
        taxRate: _taxRate,
        paid: _paid,
        paymentMethod: _paymentMethod,
        notes: _notes,
      );

      clearCart();
      await loadSales();
      return sale;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadSales({int limit = 50}) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      _sales = await _service.getAllSales(limit: limit);
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Sale?> getSaleById(String id) => _service.getSaleById(id);

  Future<Map<String, dynamic>> getTodayStats() => _service.getTodayStats();

  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10}) =>
      _service.getTopProducts(limit: limit);

  Future<List<Map<String, dynamic>>> getDailySalesChart({int days = 30}) =>
      _service.getDailySalesChart(days: days);

  // ── الأرباح ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfitSummary({DateTime? from, DateTime? to}) =>
      _service.getProfitSummary(from: from, to: to);

  Future<List<Map<String, dynamic>>> getProfitByDay({int days = 30}) =>
      _service.getProfitByDay(days: days);

  Future<List<Map<String, dynamic>>> getProfitByMonth({int months = 6}) =>
      _service.getProfitByMonth(months: months);

  Future<List<Map<String, dynamic>>> getShopHealthChart({int days = 30}) =>
      _service.getShopHealthChart(days: days);

  Future<void> returnSale(String id) async {
    await _service.returnSale(id);
    await loadSales();
  }
}
