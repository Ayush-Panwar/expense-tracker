import '../entities/sync_result.dart';
import '../repositories/expense_repository.dart';

class SyncExpenses {
  final ExpenseRepository repository;

  SyncExpenses(this.repository);

  Future<SyncResult> call() async {
    await repository.pushLocalChanges();
    return await repository.pullRemoteChanges();
  }
}
