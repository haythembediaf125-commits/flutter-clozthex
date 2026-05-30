import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Expense>> getAllExpenses({DateTime? from, DateTime? to}) async {
    String where = '';
    List<dynamic> args = [];

    if (from != null && to != null) {
      where = 'WHERE date BETWEEN ? AND ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }

    final result = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableExpenses} $where ORDER BY date DESC',
      args.isEmpty ? null : args,
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByType(ExpenseType type) async {
    final result = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableExpenses} WHERE expense_type = ? ORDER BY date DESC',
      [type.name],
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = await _db.rawQuery(
      'SELECT * FROM ${AppConstants.tableExpenses} WHERE date BETWEEN ? AND ? ORDER BY date DESC',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<String> addExpense(Expense expense) async {
    return await _db.insert(AppConstants.tableExpenses, expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    return await _db.update(AppConstants.tableExpenses, expense.toMap(), expense.id);
  }

  Future<int> deleteExpense(String id) async {
    return await _db.delete(AppConstants.tableExpenses, id);
  }

  Future<double> getTotalExpenses({DateTime? from, DateTime? to}) async {
    String where = '';
    List<dynamic> args = [];

    if (from != null && to != null) {
      where = 'WHERE date BETWEEN ? AND ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }

    final result = await _db.rawQuery(
      'SELECT SUM(amount) as total FROM ${AppConstants.tableExpenses} $where',
      args.isEmpty ? null : args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, double>> getExpensesByTypeSummary({DateTime? from, DateTime? to}) async {
    String where = from != null && to != null ? 'WHERE date BETWEEN ? AND ?' : '';
    List<dynamic> args = from != null && to != null ? [from.toIso8601String(), to.toIso8601String()] : [];

    final result = await _db.rawQuery(
      'SELECT expense_type, SUM(amount) as total FROM ${AppConstants.tableExpenses} $where GROUP BY expense_type',
      args.isEmpty ? null : args,
    );

    final Map<String, double> summary = {};
    for (final row in result) {
      final type = row['expense_type'] as String? ?? 'general';
      summary[type] = (row['total'] as num?)?.toDouble() ?? 0;
    }
    return summary;
  }

  Future<List<Map<String, dynamic>>> getExpensesByMonth({int months = 6}) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, 1);
    final safeStartDate = startDate.isBefore(DateTime(2020)) ? DateTime(2020, 1, 1) : startDate;

    final result = await _db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) as month,
        SUM(amount) as total,
        COUNT(*) as count
      FROM ${AppConstants.tableExpenses}
      WHERE date >= ?
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month ASC
    ''', [safeStartDate.toIso8601String()]);

    return result;
  }

  Future<Map<String, dynamic>> getExpenseStats() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final [
      todayTotal,
      monthTotal,
      allTimeTotal,
      byType
    ] = await Future.wait([
      getTotalExpenses(from: monthStart, to: today),
      getTotalExpenses(from: monthStart),
      getTotalExpenses(),
      getExpensesByTypeSummary(from: monthStart),
    ]);

    return {
      'today_total': todayTotal,
      'month_total': monthTotal,
      'all_time_total': allTimeTotal,
      'by_type': byType,
      'month_start': monthStart,
    };
  }
}