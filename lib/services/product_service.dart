import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';

class ProductService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Products ─────────────────────────────────────────────────────────────

  Future<List<Product>> getAllProducts({bool activeOnly = false}) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      ${activeOnly ? 'WHERE p.is_active = 1' : ''}
      ORDER BY p.name ASC
    ''');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      WHERE p.name LIKE ? OR p.barcode LIKE ? OR p.brand LIKE ?
      ORDER BY p.name ASC
    ''', ['%$query%', '%$query%', '%$query%']);
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getByBarcode(String barcode) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      WHERE p.barcode = ?
    ''', [barcode]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> getByCategory(String categoryId) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      WHERE p.category_id = ?
      ORDER BY p.name ASC
    ''', [categoryId]);
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      WHERE p.quantity <= p.min_quantity AND p.is_active = 1
      ORDER BY p.quantity ASC
    ''');
    return rows.map(Product.fromMap).toList();
  }

  Future<String> addProduct(Product product) async {
    return await _db.insert(AppConstants.tableProducts, product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _db.update(AppConstants.tableProducts, product.toMap(), product.id);
  }

  Future<void> deleteProduct(String id) async {
    await _db.delete(AppConstants.tableProducts, id);
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    await _db.rawUpdate(
      'UPDATE ${AppConstants.tableProducts} SET quantity = ?, updated_at = ? WHERE id = ?',
      [newQuantity, DateTime.now().toIso8601String(), productId],
    );
  }

  Future<void> adjustQuantity(String productId, int delta) async {
    await _db.rawUpdate(
      'UPDATE ${AppConstants.tableProducts} SET quantity = MAX(0, quantity + ?), updated_at = ? WHERE id = ?',
      [delta, DateTime.now().toIso8601String(), productId],
    );
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInventoryStats() async {
    final result = await _db.rawQuery('''
      SELECT
        COUNT(*) as total_products,
        SUM(quantity) as total_items,
        SUM(quantity * purchase_price) as total_cost_value,
        SUM(quantity * sale_price) as total_sale_value,
        COUNT(CASE WHEN quantity = 0 THEN 1 END) as out_of_stock,
        COUNT(CASE WHEN quantity > 0 AND quantity <= min_quantity THEN 1 END) as low_stock
      FROM ${AppConstants.tableProducts}
      WHERE is_active = 1
    ''');
    return result.isNotEmpty ? result.first : {};
  }

  // ─── Categories ───────────────────────────────────────────────────────────

  Future<List<Category>> getAllCategories() async {
    final rows = await _db.getAll(AppConstants.tableCategories, orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<String> addCategory(Category category) async {
    return await _db.insert(AppConstants.tableCategories, category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    await _db.update(AppConstants.tableCategories, category.toMap(), category.id);
  }

  Future<void> deleteCategory(String id) async {
    await _db.delete(AppConstants.tableCategories, id);
  }
}
