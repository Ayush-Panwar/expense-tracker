import '../repositories/expense_repository.dart';

class SyncExpenses {
  final ExpenseRepository repository;

  SyncExpenses(this.repository);

  /// pushes local changes, pulls remote changes
  /// returns true if local DB was modified by pull
  Future<bool> call() async {
    await repository.pushLocalChanges();
    return await repository.pullRemoteChanges();
  }
}
