import 'package:flutter/foundation.dart' hide Category;
import '../models/product.dart';
import '../models/category.dart';
import '../services/product_service.dart';

class ProductProvider with ChangeNotifier {
  final ProductService _service = ProductService();

  List<Product> _products = [];
  List<Product> _filtered = [];
  List<Category> _categories = [];
  bool _loading = false;
  String _searchQuery = '';
  String? _selectedCategory;

  List<Product> get products => _filtered;
  List<Product> get allProducts => _products;
  List<Category> get categories => _categories;
  bool get loading => _loading;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  List<Product> get lowStockProducts => _products.where((p) => p.isLowStock).toList();
  List<Product> get outOfStockProducts => _products.where((p) => p.isOutOfStock).toList();

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _products = await _service.getAllProducts(activeOnly: false);
      _categories = await _service.getAllCategories();
      _applyFilters();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void filterByCategory(String? categoryId) {
    _selectedCategory = categoryId;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var list = _products;
    if (_selectedCategory != null) {
      list = list.where((p) => p.categoryId == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.barcode?.contains(q) ?? false) ||
        (p.brand?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    _filtered = list;
  }

  Future<void> addProduct(Product product) async {
    await _service.addProduct(product);
    await loadAll();
  }

  Future<void> updateProduct(Product product) async {
    await _service.updateProduct(product);
    await loadAll();
  }

  Future<void> deleteProduct(String id) async {
    await _service.deleteProduct(id);
    await loadAll();
  }

  Future<Product?> getByBarcode(String barcode) async {
    return _service.getByBarcode(barcode);
  }

  Future<Map<String, dynamic>> getInventoryStats() async {
    return _service.getInventoryStats();
  }

  // Categories
  Future<void> addCategory(Category cat) async {
    await _service.addCategory(cat);
    _categories = await _service.getAllCategories();
    notifyListeners();
  }

  Future<void> updateCategory(Category cat) async {
    await _service.updateCategory(cat);
    _categories = await _service.getAllCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _service.deleteCategory(id);
    _categories = await _service.getAllCategories();
    notifyListeners();
  }
}
