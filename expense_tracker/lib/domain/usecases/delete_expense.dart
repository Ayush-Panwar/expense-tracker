import '../repositories/expense_repository.dart';

class DeleteExpense {
  final ExpenseRepository repository;

  DeleteExpense(this.repository);

  Future<void> call(String id, bool isSynced) {
    return repository.deleteExpense(id, isSynced);
  }
}
