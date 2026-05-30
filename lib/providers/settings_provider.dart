import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';

class SettingsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  String _storeName = AppConstants.defaultStoreName;
  String _storePhone = '';
  String _storeAddress = '';
  String _currency = AppConstants.defaultCurrency;
  double _taxRate = 0;
  int _lowStockAlert = AppConstants.defaultLowStockAlert;
  bool _loaded = false;

  String get storeName => _storeName;
  String get storePhone => _storePhone;
  String get storeAddress => _storeAddress;
  String get currency => _currency;
  double get taxRate => _taxRate;
  int get lowStockAlert => _lowStockAlert;
  bool get loaded => _loaded;

  Future<void> load() async {
    _storeName = await _db.getSetting(AppConstants.keyStoreName, defaultValue: AppConstants.defaultStoreName);
    _storePhone = await _db.getSetting(AppConstants.keyStorePhone);
    _storeAddress = await _db.getSetting(AppConstants.keyStoreAddress);
    _currency = await _db.getSetting(AppConstants.keyCurrency, defaultValue: AppConstants.defaultCurrency);
    _taxRate = double.tryParse(await _db.getSetting(AppConstants.keyTaxRate, defaultValue: '0')) ?? 0;
    _lowStockAlert = int.tryParse(await _db.getSetting(AppConstants.keyLowStockAlert, defaultValue: '5')) ?? 5;
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateStoreName(String value) async {
    _storeName = value;
    await _db.setSetting(AppConstants.keyStoreName, value);
    notifyListeners();
  }

  Future<void> updateStorePhone(String value) async {
    _storePhone = value;
    await _db.setSetting(AppConstants.keyStorePhone, value);
    notifyListeners();
  }

  Future<void> updateStoreAddress(String value) async {
    _storeAddress = value;
    await _db.setSetting(AppConstants.keyStoreAddress, value);
    notifyListeners();
  }

  Future<void> updateCurrency(String value) async {
    _currency = value;
    await _db.setSetting(AppConstants.keyCurrency, value);
    notifyListeners();
  }

  Future<void> updateTaxRate(double value) async {
    _taxRate = value;
    await _db.setSetting(AppConstants.keyTaxRate, value.toString());
    notifyListeners();
  }

  Future<void> updateLowStockAlert(int value) async {
    _lowStockAlert = value;
    await _db.setSetting(AppConstants.keyLowStockAlert, value.toString());
    notifyListeners();
  }
}
