import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'package:uuid/uuid.dart';

class SaleService {
  final DatabaseHelper _db = DatabaseHelper();
  int _invoiceCounter = 0;
  bool _counterInitialized = false;

  Future<void> _initCounter() async {
    if (!_counterInitialized) {
      try {
        final result = await _db.rawQuery(
          "SELECT MAX(CAST(SUBSTR(invoice_number, 9) AS INTEGER)) as max_num FROM ${AppConstants.tableSales}",
        );
        final maxNum = result.first['max_num'] as int?;
        _invoiceCounter = (maxNum ?? 0) + 1;
        _counterInitialized = true;
      } catch (e) {
        // If query fails, start from 1
        _invoiceCounter = 1;
        _counterInitialized = true;
      }
    }
  }

  Future<String> _nextInvoiceNumber() async {
    await _initCounter();
    final num = _invoiceCounter++;
    return 'INV-${DateTime.now().year}-${num.toString().padLeft(5, '0')}';
  }

  Future<Sale> completeSale({
    required List<CartItem> cartItems,
    String? customerId,
    String? customerName,
    double discount = 0,
    DiscountType discountType = DiscountType.fixed,
    double taxRate = 0,
    double paid = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String? notes,
  }) async {
    final db = await _db.database;
    final saleId = const Uuid().v4();
    final invoiceNumber = await _nextInvoiceNumber();
    final now = DateTime.now();

    final subtotal = cartItems.fold<double>(0, (s, i) => s + (i.unitPrice * i.quantity));
    final discountAmount = discountType == DiscountType.percentage
        ? subtotal * (discount / 100)
        : discount;
    final afterDiscount = subtotal - discountAmount;
    final taxAmount = afterDiscount * (taxRate / 100);
    final total = afterDiscount + taxAmount;
    final change = paid - total;

    final sale = Sale(
      id: saleId,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      items: [],
      subtotal: subtotal,
      discount: discount,
      discountType: discountType,
      tax: taxAmount,
      total: total,
      paid: paid,
      changeAmount: change < 0 ? 0 : change,
      paymentMethod: paymentMethod,
      notes: notes,
      status: SaleStatus.completed,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // Insert sale
      await txn.insert(AppConstants.tableSales, sale.toMap());

      // Insert items and deduct stock
      for (final item in cartItems) {
        final saleItem = item.toSaleItem(saleId);
        await txn.insert(AppConstants.tableSaleItems, saleItem.toMap());
        await txn.rawUpdate(
          'UPDATE ${AppConstants.tableProducts} SET quantity = MAX(0, quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // Update customer total purchases
      if (customerId != null) {
        await txn.rawUpdate(
          'UPDATE ${AppConstants.tableCustomers} SET total_purchases = total_purchases + ?, updated_at = ? WHERE id = ?',
          [total, now.toIso8601String(), customerId],
        );
      }
    });

    return sale;
  }

  Future<List<Sale>> getAllSales({int limit = 50, int offset = 0}) async {
    final rows = await _db.rawQuery('''
      SELECT * FROM ${AppConstants.tableSales}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<Sale?> getSaleById(String id) async {
    final saleRows = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableSales} WHERE id = ?', [id]);
    if (saleRows.isEmpty) return null;

    final itemRows = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableSaleItems} WHERE sale_id = ?', [id]);
    final items = itemRows.map(SaleItem.fromMap).toList();
    return Sale.fromMap(saleRows.first, items: items);
  }

  Future<Sale?> getSaleByInvoice(String invoiceNumber) async {
    final saleRows = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableSales} WHERE invoice_number = ?', [invoiceNumber]);
    if (saleRows.isEmpty) return null;

    final itemRows = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableSaleItems} WHERE sale_id = ?', [saleRows.first['id']]);
    final items = itemRows.map(SaleItem.fromMap).toList();
    return Sale.fromMap(saleRows.first, items: items);
  }

  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT * FROM ${AppConstants.tableSales}
      WHERE created_at BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<void> returnSale(String saleId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final itemRows = await txn.query(
        AppConstants.tableSaleItems, where: 'sale_id = ?', whereArgs: [saleId]);
      for (final item in itemRows) {
        await txn.rawUpdate(
          'UPDATE ${AppConstants.tableProducts} SET quantity = quantity + ? WHERE id = ?',
          [item['quantity'], item['product_id']],
        );
      }
      await txn.update(
        AppConstants.tableSales,
        {'status': 'returned', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final result = await _db.rawQuery('''
      SELECT
        COUNT(*) as total_sales,
        COALESCE(SUM(total), 0) as total_revenue,
        COALESCE(SUM(discount), 0) as total_discount
      FROM ${AppConstants.tableSales}
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result.isNotEmpty ? result.first : {'total_sales': 0, 'total_revenue': 0.0};
  }

  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10, DateTime? from, DateTime? to}) async {
    String dateFilter = '';
    List<dynamic> args = [];
    if (from != null && to != null) {
      dateFilter = 'AND s.created_at BETWEEN ? AND ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }
    return await _db.rawQuery('''
      SELECT
        si.product_id,
        si.product_name,
        SUM(si.quantity) as total_sold,
        SUM(si.total) as total_revenue
      FROM ${AppConstants.tableSaleItems} si
      JOIN ${AppConstants.tableSales} s ON s.id = si.sale_id
      WHERE s.status = 'completed' $dateFilter
      GROUP BY si.product_id
      ORDER BY total_sold DESC
      LIMIT ?
    ''', [...args, limit]);
  }

  Future<List<Map<String, dynamic>>> getDailySalesChart({int days = 30}) async {
    return await _db.rawQuery('''
      SELECT
        DATE(created_at) as sale_date,
        COUNT(*) as count,
        COALESCE(SUM(total), 0) as revenue
      FROM ${AppConstants.tableSales}
      WHERE created_at >= DATE('now', '-$days days') AND status = 'completed'
      GROUP BY DATE(created_at)
      ORDER BY sale_date ASC
    ''');
  }

  // ── حساب الأرباح ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfitSummary({DateTime? from, DateTime? to}) async {
    String dateFilter = '';
    List<dynamic> args = [];
    if (from != null && to != null) {
      dateFilter = 'AND s.created_at BETWEEN ? AND ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }

    // حساب إجمالي الإيرادات والتكاليف
    final result = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(si.total), 0) as total_revenue,
        COALESCE(SUM(si.purchase_price * si.quantity), 0) as total_cost,
        COALESCE(SUM(si.discount), 0) as total_discount,
        COUNT(DISTINCT s.id) as total_sales
      FROM ${AppConstants.tableSaleItems} si
      JOIN ${AppConstants.tableSales} s ON s.id = si.sale_id
      WHERE s.status = 'completed' $dateFilter
    ''', args);

    if (result.isEmpty || result.first['total_revenue'] == null) {
      return {
        'total_revenue': 0.0,
        'total_cost': 0.0,
        'total_profit': 0.0,
        'profit_margin': 0.0,
        'total_discount': 0.0,
        'total_sales': 0,
      };
    }

    final revenue = (result.first['total_revenue'] as num?)?.toDouble() ?? 0;
    final cost = (result.first['total_cost'] as num?)?.toDouble() ?? 0;
    final profit = revenue - cost;
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;

    return {
      'total_revenue': revenue,
      'total_cost': cost,
      'total_profit': profit,
      'profit_margin': margin,
      'total_discount': (result.first['total_discount'] as num?)?.toDouble() ?? 0,
      'total_sales': result.first['total_sales'] as int? ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getProfitByDay({int days = 30}) async {
    return await _db.rawQuery('''
      SELECT
        DATE(s.created_at) as sale_date,
        COALESCE(SUM(si.total), 0) as revenue,
        COALESCE(SUM(si.purchase_price * si.quantity), 0) as cost,
        COALESCE(SUM(si.total), 0) - COALESCE(SUM(si.purchase_price * si.quantity), 0) as profit
      FROM ${AppConstants.tableSaleItems} si
      JOIN ${AppConstants.tableSales} s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.created_at >= DATE('now', '-$days days')
      GROUP BY DATE(s.created_at)
      ORDER BY sale_date ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getProfitByMonth({int months = 6}) async {
    final startDate = DateTime.now().subtract(Duration(days: months * 30));
    return await _db.rawQuery('''
      SELECT
        strftime('%Y-%m', s.created_at) as month,
        COALESCE(SUM(si.total), 0) as revenue,
        COALESCE(SUM(si.purchase_price * si.quantity), 0) as cost,
        COALESCE(SUM(si.total), 0) - COALESCE(SUM(si.purchase_price * si.quantity), 0) as profit
      FROM ${AppConstants.tableSaleItems} si
      JOIN ${AppConstants.tableSales} s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.created_at >= ?
      GROUP BY strftime('%Y-%m', s.created_at)
      ORDER BY month ASC
    ''', [startDate.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getShopHealthChart({int days = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    // جلب المبيعات اليومية
    final sales = await _db.rawQuery('''
      SELECT DATE(created_at) as date, SUM(total) as revenue
      FROM ${AppConstants.tableSales}
      WHERE status = 'completed' AND created_at >= ?
      GROUP BY DATE(created_at)
    ''', [startDate.toIso8601String()]);

    // جلب المصروفات اليومية
    final expenses = await _db.rawQuery('''
      SELECT DATE(date) as date, SUM(amount) as amount
      FROM expenses
      WHERE date >= ?
      GROUP BY DATE(date)
    ''', [startDate.toIso8601String()]);

    // جلب الديون الصادرة (لنا) يومياً
    final debtsOwed = await _db.rawQuery('''
      SELECT DATE(created_at) as date, SUM(amount) as amount
      FROM debts_owed
      WHERE created_at >= ?
      GROUP BY DATE(created_at)
    ''', [startDate.toIso8601String()]);

    // دمج البيانات في قائمة واحدة مرتبة حسب التاريخ
    Map<String, Map<String, dynamic>> healthData = {};
    
    for (var row in sales) {
      String date = row['date'].toString();
      healthData[date] = {'date': date, 'revenue': row['revenue'], 'expenses': 0.0, 'debts': 0.0};
    }
    
    for (var row in expenses) {
      String date = row['date'].toString();
      if (!healthData.containsKey(date)) healthData[date] = {'date': date, 'revenue': 0.0, 'expenses': 0.0, 'debts': 0.0};
      healthData[date]!['expenses'] = row['amount'];
    }

    for (var row in debtsOwed) {
      String date = row['date'].toString();
      if (!healthData.containsKey(date)) healthData[date] = {'date': date, 'revenue': 0.0, 'expenses': 0.0, 'debts': 0.0};
      healthData[date]!['debts'] = row['amount'];
    }

    var result = healthData.values.toList();
    result.sort((a, b) => a['date'].compareTo(b['date']));
    return result;
  }
}
