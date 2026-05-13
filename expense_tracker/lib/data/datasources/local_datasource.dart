import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database.dart';
import '../models/expense_model.dart';

class LocalDatasource {
  final AppDatabase _db;

  LocalDatasource(this._db);

  Future<List<ExpenseModel>> getExpensesPaginated(int limit, int offset) async {
    final rows = await _db.getExpensesPaginated(limit, offset);
    return rows.map((e) => ExpenseModel.fromDrift(e)).toList();
  }

  Future<int> getExpenseCount() async {
    return await _db.getExpenseCount();
  }

  Future<List<ExpenseModel>> getUnsyncedExpenses() async {
    final rows = await _db.getUnsyncedExpenses();
    return rows.map((e) => ExpenseModel.fromDrift(e)).toList();
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final result = await _db.getExpenseById(id);
    return result != null ? ExpenseModel.fromDrift(result) : null;
  }

  Future<void> insertExpense(ExpenseModel expense) {
    return _db.insertExpense(expense.toCompanion());
  }

  Future<void> upsertExpense(ExpenseModel expense) {
    return _db.upsertExpense(expense.toCompanion());
  }

  Future<void> markAsSynced(String id, String imageUrl) {
    return _db.markAsSynced(id, imageUrl);
  }

  Future<void> deleteExpense(String id) {
    return _db.removeExpense(id);
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastSyncedAt');
  }

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastSyncedAt');
  }

  Future<void> setLastSyncedAt(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSyncedAt', timestamp);
  }

  // pending deletes
  Future<void> addPendingDelete(String expenseId) {
    return _db.addPendingDelete(expenseId);
  }

  Future<List<String>> getPendingDeletes() async {
    final deletes = await _db.getPendingDeletes();
    return deletes.map((d) => d.expenseId).toList();
  }

  Future<void> removePendingDelete(String expenseId) {
    return _db.removePendingDelete(expenseId);
  }
}
