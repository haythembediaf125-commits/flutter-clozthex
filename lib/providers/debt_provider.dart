import 'package:flutter/foundation.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';

class DebtProvider with ChangeNotifier {
  final DebtService _service = DebtService();

  // State
  List<Debt> _debtsOwed = [];
  List<Debt> _debtsDue = [];
  Map<String, dynamic> _summary = {};
  bool _loading = false;
  String? _error;

  // Getters
  List<Debt> get debtsOwed => _debtsOwed;
  List<Debt> get debtsDue => _debtsDue;
  List<Debt> get unpaidDebtsOwed => _debtsOwed.where((d) => !d.isPaid).toList();
  List<Debt> get unpaidDebtsDue => _debtsDue.where((d) => !d.isPaid).toList();
  Map<String, dynamic> get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  double get totalOwed => _summary['total_owed'] as double? ?? 0;
  double get totalDue => _summary['total_due'] as double? ?? 0;
  double get netPosition => _summary['net_position'] as double? ?? 0;

  // Load all data
  Future<void> loadAll() async {
    setState(() => _loading = true, error: null);
    try {
      final [owed, due, summaryData] = await Future.wait([
        _service.getDebtsOwed(),
        _service.getDebtsDue(),
        _service.getDebtsSummary(),
      ]);
      _debtsOwed = owed;
      _debtsDue = due;
      _summary = summaryData;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── أموال المدينة (مطلوبات) ────────────────────────────────────────────

  Future<bool> addDebtOwed({
    required String personName,
    String? phone,
    required double amount,
    String? description,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      final debt = Debt.create(
        personName: personName,
        phone: phone,
        amount: amount,
        description: description,
        dueDate: dueDate,
        notes: notes,
        type: DebtType.owed,
      );
      await _service.addDebtOwed(debt);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDebtOwed(Debt debt) async {
    try {
      await _service.updateDebtOwed(debt);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markDebtOwedAsPaid(String id) async {
    try {
      await _service.markDebtOwedAsPaid(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDebtOwed(String id) async {
    try {
      await _service.deleteDebtOwed(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── أموال المحل (على المحل) ────────────────────────────────────────────

  Future<bool> addDebtDue({
    required String personName,
    String? phone,
    required double amount,
    String? description,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      final debt = Debt.create(
        personName: personName,
        phone: phone,
        amount: amount,
        description: description,
        dueDate: dueDate,
        notes: notes,
        type: DebtType.due,
      );
      await _service.addDebtDue(debt);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDebtDue(Debt debt) async {
    try {
      await _service.updateDebtDue(debt);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markDebtDueAsPaid(String id) async {
    try {
      await _service.markDebtDueAsPaid(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDebtDue(String id) async {
    try {
      await _service.deleteDebtDue(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setState({bool? loading, String? error}) {
    if (loading != null) _loading = loading;
    if (error != null) _error = error;
    notifyListeners();
  }
}