class AppConstants {
  static const String appName = 'ClowtheX';
  static const String appVersion = '1.0.0';
  static const String dbName = 'clowthex.db';
  static const int dbVersion = 2;

  // Tables
  static const String tableProducts = 'products';
  static const String tableCategories = 'categories';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableSuppliers = 'suppliers';
  static const String tableCustomers = 'customers';
  static const String tableSettings = 'settings';
  static const String tableExpenses = 'expenses';

  // Settings Keys
  static const String keyStoreName = 'store_name';
  static const String keyStorePhone = 'store_phone';
  static const String keyStoreAddress = 'store_address';
  static const String keyCurrency = 'currency';
  static const String keyTaxRate = 'tax_rate';
  static const String keyLowStockAlert = 'low_stock_alert';

  // Default Values
  static const String defaultCurrency = 'دج';
  static const String defaultStoreName = 'ClowtheX';
  static const int defaultLowStockAlert = 5;
}
