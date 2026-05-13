import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpenses {
  final ExpenseRepository repository;

  GetExpenses(this.repository);

  Future<List<ExpenseEntity>> call({int limit = 20, int offset = 0}) {
    return repository.getLocalExpensesPaginated(limit, offset);
  }

  Future<List<ExpenseEntity>> fromServer({int page = 1, int limit = 20}) {
    return repository.getRemoteExpensesPaginated(page, limit);
  }

  Future<int> count() {
    return repository.getLocalExpenseCount();
  }
}
