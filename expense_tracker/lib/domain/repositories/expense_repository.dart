import '../entities/expense.dart';
import '../entities/summary.dart';
import '../entities/sync_result.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseEntity>> getLocalExpensesPaginated(int limit, int offset);

  Future<List<ExpenseEntity>> searchExpenses({
    String? category,
    String? query,
    int page,
    int limit,
  });

  Future<SummaryEntity> getSummary();
  Future<void> addExpense(ExpenseEntity expense);
  Future<void> deleteExpense(String id, bool isSynced);
  Future<void> pushLocalChanges();
  Future<SyncResult> pullRemoteChanges();
}
