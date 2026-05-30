import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/product.dart';

class BackupResult {
  final bool success;
  final String? message;
  final String? filePath;
  final bool isImport;

  const BackupResult({required this.success, this.message, this.filePath, this.isImport = false});
}

class BackupService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Request Storage Permission ───────────────────────────────────────────

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  // ─── Save to Downloads Folder ─────────────────────────────────────────────

  Future<File> _saveToDownloads(String fileName, List<int> bytes) async {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // Try Downloads public folder first
      await _requestStoragePermission();
      final publicDownloads = Directory('/storage/emulated/0/Download/ClowtheX');
      try {
        if (!await publicDownloads.exists()) {
          await publicDownloads.create(recursive: true);
        }
        targetDir = publicDownloads;
      } catch (_) {
        // Fallback to external storage
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            targetDir = Directory('${ext.path}/ClowtheX');
            if (!await targetDir.exists()) await targetDir.create(recursive: true);
          }
        } catch (_) {
          // Last fallback: internal documents
          final docs = await getApplicationDocumentsDirectory();
          targetDir = Directory('${docs.path}/backups');
          if (!await targetDir.exists()) await targetDir.create(recursive: true);
        }
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      targetDir = Directory('${docs.path}/backups');
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
    }

    final file = File('${targetDir!.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ─── JSON Export (Full Backup) ────────────────────────────────────────────

  Future<BackupResult> exportFullBackup() async {
    try {
      final data = await _gatherAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final fileName = 'clowthex_backup_${_timestamp()}.json';
      final file = await _saveToDownloads(fileName, utf8.encode(jsonStr));

      // Also share so user can save wherever they want
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'نسخة احتياطية ClowtheX',
        text: 'نسخة احتياطية كاملة - ClowtheX',
      );

      return BackupResult(
        success: true,
        message: 'تم حفظ الملف:\n📁 ClowtheX/$fileName',
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'فشل التصدير: $e');
    }
  }

  // ─── Pick backup file (no import yet) ───────────────────────────────────────

  Future<PlatformFile?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      withData: true, // ensure bytes available even without path
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  // ─── JSON Import (Restore Backup) — call AFTER user confirms ─────────────

  Future<BackupResult> importFromFile(PlatformFile file) async {
    try {
      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        return const BackupResult(success: false, message: 'تعذّر قراءة الملف', isImport: true);
      }
      final data = jsonDecode(content) as Map<String, dynamic>;
      await _restoreFromData(data);
      return const BackupResult(
        success: true,
        message: '✅ تم استيراد جميع البيانات بنجاح',
        isImport: true,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'فشل الاستيراد: $e', isImport: true);
    }
  }

  // ─── Excel Export (Products) ──────────────────────────────────────────────

  Future<BackupResult> exportProductsToExcel() async {
    try {
      final rows = await _db.rawQuery('''
        SELECT p.*, c.name as category_name, s.name as supplier_name
        FROM ${AppConstants.tableProducts} p
        LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
        ORDER BY p.name
      ''');

      final excel = Excel.createExcel();
      final sheet = excel['المنتجات'];
      excel.delete('Sheet1');

      final headers = [
        'الاسم', 'الباركود', 'الفئة', 'المورد', 'سعر الشراء',
        'سعر البيع', 'الكمية', 'الحد الأدنى', 'الحجم', 'اللون', 'الماركة', 'الحالة'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('FFD4A017'));
      }

      for (int r = 0; r < rows.length; r++) {
        final p = rows[r];
        final values = [
          p['name'], p['barcode'] ?? '', p['category_name'] ?? '',
          p['supplier_name'] ?? '', p['purchase_price'], p['sale_price'],
          p['quantity'], p['min_quantity'], p['size'] ?? '',
          p['color'] ?? '', p['brand'] ?? '',
          (p['is_active'] as int?) == 1 ? 'نشط' : 'غير نشط',
        ];
        for (int c = 0; c < values.length; c++) {
          final v = values[c];
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
              v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v?.toString() ?? '');
        }
      }

      final bytes = excel.save()!;
      final fileName = 'clowthex_products_${_timestamp()}.xlsx';
      final file = await _saveToDownloads(fileName, bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'تصدير المنتجات - ClowtheX');
      return BackupResult(
        success: true,
        message: 'تم تصدير ${rows.length} منتج\n📁 ClowtheX/$fileName',
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'فشل تصدير المنتجات: $e');
    }
  }

  // ─── Excel Export (Sales) ─────────────────────────────────────────────────

  Future<BackupResult> exportSalesToExcel({DateTime? from, DateTime? to}) async {
    try {
      String whereClause = '';
      List<dynamic> args = [];
      if (from != null && to != null) {
        whereClause = 'WHERE s.created_at BETWEEN ? AND ?';
        args = [from.toIso8601String(), to.toIso8601String()];
      }

      final rows = await _db.rawQuery('''
        SELECT s.*, GROUP_CONCAT(si.product_name || ' x' || si.quantity, ' | ') as items_summary
        FROM ${AppConstants.tableSales} s
        LEFT JOIN ${AppConstants.tableSaleItems} si ON si.sale_id = s.id
        $whereClause
        GROUP BY s.id
        ORDER BY s.created_at DESC
      ''', args.isNotEmpty ? args : null);

      final excel = Excel.createExcel();
      final sheet = excel['المبيعات'];
      excel.delete('Sheet1');

      final headers = [
        'رقم الفاتورة', 'التاريخ', 'العميل', 'المجموع الفرعي',
        'الخصم', 'الضريبة', 'الإجمالي', 'المدفوع', 'الباقي',
        'طريقة الدفع', 'الحالة', 'المنتجات'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('FFD4A017'));
      }

      for (int r = 0; r < rows.length; r++) {
        final s = rows[r];
        final values = [
          s['invoice_number'],
          DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(s['created_at'] as String)),
          s['customer_name'] ?? 'عميل عام',
          s['subtotal'], s['discount'], s['tax'], s['total'],
          s['paid'], s['change_amount'],
          s['payment_method'], s['status'], s['items_summary'] ?? '',
        ];
        for (int c = 0; c < values.length; c++) {
          final v = values[c];
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
              v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v?.toString() ?? '');
        }
      }

      final bytes = excel.save()!;
      final fileName = 'clowthex_sales_${_timestamp()}.xlsx';
      final file = await _saveToDownloads(fileName, bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'تصدير المبيعات - ClowtheX');
      return BackupResult(
        success: true,
        message: 'تم تصدير ${rows.length} فاتورة\n📁 ClowtheX/$fileName',
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'فشل تصدير المبيعات: $e');
    }
  }

  // ─── Pick Excel file (no import yet) ─────────────────────────────────────

  Future<PlatformFile?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      dialogTitle: 'اختر ملف Excel للمنتجات',
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  // ─── Excel Import (Products) — call AFTER user confirms ──────────────────

  Future<BackupResult> importProductsFromExcelFile(PlatformFile file) async {
    try {
      List<int>? bytes;
      if (file.path != null) {
        bytes = File(file.path!).readAsBytesSync();
      } else {
        bytes = file.bytes?.toList();
      }
      if (bytes == null) return const BackupResult(success: false, message: 'تعذّر قراءة الملف', isImport: true);
      return await _importExcelBytes(bytes);
    } catch (e) {
      return BackupResult(success: false, message: 'فشل استيراد المنتجات: $e', isImport: true);
    }
  }

  Future<BackupResult> _importExcelBytes(List<int> bytes) async {
    final excelDoc = Excel.decodeBytes(bytes);
    final sheet = excelDoc.tables.values.first;
    int imported = 0;
    int failed = 0;

    for (int r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      if (row.isEmpty || row[0]?.value == null) continue;
      try {
        final name = row[0]?.value?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final barcode = row[1]?.value?.toString().trim();
        final purchasePrice = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
        final salePrice = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
        final quantity = int.tryParse(row[6]?.value?.toString() ?? '0') ?? 0;
        final minQty = int.tryParse(row[7]?.value?.toString() ?? '5') ?? 5;
        final size = row[8]?.value?.toString().trim();
        final color = row[9]?.value?.toString().trim();
        final brand = row[10]?.value?.toString().trim();
        final product = Product.create(
          name: name,
          barcode: (barcode?.isEmpty ?? true) ? null : barcode,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          quantity: quantity,
          minQuantity: minQty,
          size: (size?.isEmpty ?? true) ? null : size,
          color: (color?.isEmpty ?? true) ? null : color,
          brand: (brand?.isEmpty ?? true) ? null : brand,
        );
        await _db.insert(AppConstants.tableProducts, product.toMap());
        imported++;
      } catch (_) {
        failed++;
      }
    }

    return BackupResult(
      success: true,
      message: '✅ تم استيراد $imported منتج${failed > 0 ? ' (فشل: $failed)' : ''}',
      isImport: true,
    );
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _gatherAllData() async {
    final categories = await _db.getAll(AppConstants.tableCategories);
    final suppliers = await _db.getAll(AppConstants.tableSuppliers);
    final customers = await _db.getAll(AppConstants.tableCustomers);
    final products = await _db.getAll(AppConstants.tableProducts);
    final sales = await _db.getAll(AppConstants.tableSales);
    final saleItems = await _db.getAll(AppConstants.tableSaleItems);
    final expenses = await _db.getAll(AppConstants.tableExpenses);
    final settings = await _db.rawQuery('SELECT * FROM ${AppConstants.tableSettings}');

    return {
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'ClowtheX',
      'data': {
        'categories': categories,
        'suppliers': suppliers,
        'customers': customers,
        'products': products,
        'sales': sales,
        'sale_items': saleItems,
        'expenses': expenses,
        'settings': settings,
      }
    };
  }

  Future<void> _restoreFromData(Map<String, dynamic> backup) async {
    final data = backup['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('تنسيق الملف غير صحيح');

    final db = await _db.database;
    await db.transaction((txn) async {
      // Delete in correct order (FK constraints)
      await txn.delete(AppConstants.tableSaleItems);
      await txn.delete(AppConstants.tableSales);
      await txn.delete(AppConstants.tableProducts);
      await txn.delete(AppConstants.tableSuppliers);
      await txn.delete(AppConstants.tableCustomers);
      await txn.delete(AppConstants.tableCategories);
      await txn.delete(AppConstants.tableExpenses);
      await txn.delete(AppConstants.tableSettings);

      final tableOrder = [
        'categories',
        'suppliers',
        'customers',
        'products',
        'sales',
        'sale_items',
        'expenses',
      ];

      final tableMap = {
        'categories': AppConstants.tableCategories,
        'suppliers': AppConstants.tableSuppliers,
        'customers': AppConstants.tableCustomers,
        'products': AppConstants.tableProducts,
        'sales': AppConstants.tableSales,
        'sale_items': AppConstants.tableSaleItems,
        'expenses': AppConstants.tableExpenses,
      };

      for (final key in tableOrder) {
        final rows = data[key] as List<dynamic>?;
        if (rows != null) {
          for (final row in rows) {
            await txn.insert(
              tableMap[key]!,
              Map<String, dynamic>.from(row as Map),
              conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Settings (key/value only)
      final settings = data['settings'] as List<dynamic>?;
      if (settings != null) {
        for (final s in settings) {
          final m = Map<String, dynamic>.from(s as Map);
          // Keep only key and value columns
          await txn.insert(
            AppConstants.tableSettings,
            {'key': m['key'], 'value': m['value']},
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
}
