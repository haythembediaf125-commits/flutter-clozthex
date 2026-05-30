import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/debt.dart';

class DebtService {
  final DatabaseHelper _db = DatabaseHelper();

  // ── أموال المدينة (مطلوبات - owes to the store) ─────────────────────

  Future<List<Debt>> getDebtsOwed() async {
    final result = await _db.getAll(AppConstants.tableDebtsOwed, orderBy: 'created_at DESC');
    return result.map((map) => Debt.fromMap(map, DebtType.owed)).toList();
  }

  Future<List<Debt>> getDebtsOwedUnpaid() async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tableDebtsOwed} WHERE is_paid = 0 ORDER BY created_at DESC"
    );
    return result.map((map) => Debt.fromMap(map, DebtType.owed)).toList();
  }

  Future<double> getTotalDebtsOwed() async {
    final result = await _db.rawQuery(
      "SELECT SUM(amount) as total FROM ${AppConstants.tableDebtsOwed} WHERE is_paid = 0"
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<String> addDebtOwed(Debt debt) async {
    return await _db.insert(AppConstants.tableDebtsOwed, debt.toMap());
  }

  Future<int> updateDebtOwed(Debt debt) async {
    return await _db.update(AppConstants.tableDebtsOwed, debt.toMap(), debt.id);
  }

  Future<int> deleteDebtOwed(String id) async {
    return await _db.delete(AppConstants.tableDebtsOwed, id);
  }

  Future<int> markDebtOwedAsPaid(String id) async {
    final now = DateTime.now();
    return await _db.rawUpdate(
      "UPDATE ${AppConstants.tableDebtsOwed} SET is_paid = 1, paid_date = ?, updated_at = ? WHERE id = ?",
      [now.toIso8601String(), now.toIso8601String(), id]
    );
  }

  // ── أموال المحل (على المحل - due from the store) ─────────────────────

  Future<List<Debt>> getDebtsDue() async {
    final result = await _db.getAll(AppConstants.tableDebtsDue, orderBy: 'created_at DESC');
    return result.map((map) => Debt.fromMap(map, DebtType.due)).toList();
  }

  Future<List<Debt>> getDebtsDueUnpaid() async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tableDebtsDue} WHERE is_paid = 0 ORDER BY created_at DESC"
    );
    return result.map((map) => Debt.fromMap(map, DebtType.due)).toList();
  }

  Future<double> getTotalDebtsDue() async {
    final result = await _db.rawQuery(
      "SELECT SUM(amount) as total FROM ${AppConstants.tableDebtsDue} WHERE is_paid = 0"
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<String> addDebtDue(Debt debt) async {
    return await _db.insert(AppConstants.tableDebtsDue, debt.toMap());
  }

  Future<int> updateDebtDue(Debt debt) async {
    return await _db.update(AppConstants.tableDebtsDue, debt.toMap(), debt.id);
  }

  Future<int> deleteDebtDue(String id) async {
    return await _db.delete(AppConstants.tableDebtsDue, id);
  }

  Future<int> markDebtDueAsPaid(String id) async {
    final now = DateTime.now();
    return await _db.rawUpdate(
      "UPDATE ${AppConstants.tableDebtsDue} SET is_paid = 1, paid_date = ?, updated_at = ? WHERE id = ?",
      [now.toIso8601String(), now.toIso8601String(), id]
    );
  }

  // ── إحصائيات عامة ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDebtsSummary() async {
    final owedUnpaid = await getTotalDebtsOwed();
    final dueUnpaid = await getTotalDebtsDue();
    final owedList = await getDebtsOwed();
    final dueList = await getDebtsDue();

    return {
      'total_owed': owedUnpaid,
      'total_due': dueUnpaid,
      'net_position': owedUnpaid - dueUnpaid,  // إيجابي = المال لك، سلبي = عليك
      'owed_count': owedList.where((d) => !d.isPaid).length,
      'due_count': dueList.where((d) => !d.isPaid).length,
      'paid_owed_count': owedList.where((d) => d.isPaid).length,
      'paid_due_count': dueList.where((d) => d.isPaid).length,
    };
  }

  Future<List<Map<String, dynamic>>> getDebtsByMonth({int months = 6}) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, 1);

    final owedResult = await _db.rawQuery(
      """SELECT strftime('%Y-%m', created_at) as month, SUM(amount) as total, COUNT(*) as count
         FROM ${AppConstants.tableDebtsOwed}
         WHERE created_at >= ?
         GROUP BY month
         ORDER BY month""",
      [startDate.toIso8601String()]
    );

    final dueResult = await _db.rawQuery(
      """SELECT strftime('%Y-%m', created_at) as month, SUM(amount) as total, COUNT(*) as count
         FROM ${AppConstants.tableDebtsDue}
         WHERE created_at >= ?
         GROUP BY month
         ORDER BY month""",
      [startDate.toIso8601String()]
    );

    return [
      {'owed': owedResult, 'due': dueResult}
    ];
  }
}