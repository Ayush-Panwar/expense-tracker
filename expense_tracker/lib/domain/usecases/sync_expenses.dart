import '../repositories/expense_repository.dart';

class SyncExpenses {
  final ExpenseRepository repository;

  SyncExpenses(this.repository);

  Future<bool> call() async {
    await repository.pushLocalChanges();
    return await repository.pullRemoteChanges();
  }
}
