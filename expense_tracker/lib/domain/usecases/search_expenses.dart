import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class SearchExpenses {
  final ExpenseRepository repository;

  SearchExpenses(this.repository);

  Future<List<ExpenseEntity>> call({
    String? category,
    String? query,
    int page = 1,
    int limit = 20,
  }) {
    return repository.searchExpenses(
      category: category,
      query: query,
      page: page,
      limit: limit,
    );
  }
}
