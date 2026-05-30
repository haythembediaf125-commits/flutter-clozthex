import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableCategories} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT,
        icon TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSuppliers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        balance REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableCustomers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        total_purchases REAL DEFAULT 0,
        loyalty_points INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableProducts} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        barcode TEXT UNIQUE,
        sku TEXT,
        category_id TEXT,
        supplier_id TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_quantity INTEGER DEFAULT 5,
        size TEXT,
        color TEXT,
        brand TEXT,
        image_path TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES ${AppConstants.tableCategories}(id),
        FOREIGN KEY (supplier_id) REFERENCES ${AppConstants.tableSuppliers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSales} (
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        discount_type TEXT DEFAULT 'fixed',
        tax REAL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        paid REAL DEFAULT 0,
        change_amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        notes TEXT,
        status TEXT DEFAULT 'completed',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${AppConstants.tableCustomers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSaleItems} (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        barcode TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL,
        purchase_price REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${AppConstants.tableSales}(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES ${AppConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableExpenses} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        notes TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSettings} (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Insert default settings
    await _insertDefaultSettings(db);
    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final defaults = {
      AppConstants.keyStoreName: AppConstants.defaultStoreName,
      AppConstants.keyStorePhone: '',
      AppConstants.keyStoreAddress: '',
      AppConstants.keyCurrency: AppConstants.defaultCurrency,
      AppConstants.keyTaxRate: '0',
      AppConstants.keyLowStockAlert: AppConstants.defaultLowStockAlert.toString(),
    };
    for (final entry in defaults.entries) {
      await db.insert(AppConstants.tableSettings, {'key': entry.key, 'value': entry.value});
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final categories = [
      {'id': 'cat-1', 'name': 'قمصان', 'color': '#3B82F6', 'icon': 'shirt', 'created_at': now, 'updated_at': now},
      {'id': 'cat-2', 'name': 'بناطيل', 'color': '#8B5CF6', 'icon': 'pants', 'created_at': now, 'updated_at': now},
      {'id': 'cat-3', 'name': 'جاكيتات', 'color': '#F59E0B', 'icon': 'jacket', 'created_at': now, 'updated_at': now},
      {'id': 'cat-4', 'name': 'أحذية', 'color': '#10B981', 'icon': 'shoe', 'created_at': now, 'updated_at': now},
      {'id': 'cat-5', 'name': 'إكسسوارات', 'color': '#EF4444', 'icon': 'accessory', 'created_at': now, 'updated_at': now},
    ];
    for (final cat in categories) {
      await db.insert(AppConstants.tableCategories, cat);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add purchase_price column to sale_items
    if (oldVersion < 2) {
      final cols = await db.rawQuery("PRAGMA table_info(${AppConstants.tableSaleItems})");
      final hasCol = cols.any((c) => c['name'] == 'purchase_price');
      if (!hasCol) {
        await db.execute(
          'ALTER TABLE ${AppConstants.tableSaleItems} ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0',
        );
      }
    }
  }

  // Generic CRUD operations
  Future<String> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    return data['id'] as String;
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAll(String table, {String? orderBy}) async {
    final db = await database;
    return await db.query(table, orderBy: orderBy ?? 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final db = await database;
    final result = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return await db.rawUpdate(sql, args);
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await database;
    final result = await db.query(AppConstants.tableSettings, where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) return result.first['value'] as String? ?? defaultValue;
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      AppConstants.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
    _database = null;
  }
}
