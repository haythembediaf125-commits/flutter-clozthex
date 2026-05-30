import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService _service = ExpenseService();

  List<Expense> _expenses = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _stats = {};

  List<Expense> get expenses => _expenses;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic> get stats => _stats;

  double get todayTotal => (_stats['today_total'] as num?)?.toDouble() ?? 0;
  double get monthTotal => (_stats['month_total'] as num?)?.toDouble() ?? 0;
  double get allTimeTotal => (_stats['all_time_total'] as num?)?.toDouble() ?? 0;
  Map<String, double> get byType => (_stats['by_type'] as Map<String, double>?) ?? {};

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _service.getAllExpenses();
      _stats = await _service.getExpenseStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadByMonth(int year, int month) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _service.getExpensesByMonth(year, month);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense({
    required String title,
    required double amount,
    ExpenseType type = ExpenseType.general,
    String? category,
    String? notes,
    DateTime? date,
  }) async {
    try {
      final expense = Expense.create(
        title: title,
        amount: amount,
        type: type,
        category: category,
        notes: notes,
        date: date,
      );
      await _service.addExpense(expense);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExpense(Expense expense) async {
    try {
      await _service.updateExpense(expense);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _service.deleteExpense(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlyReport({int months = 6}) async {
    return await _service.getExpensesByMonth(months: months);
  }
}