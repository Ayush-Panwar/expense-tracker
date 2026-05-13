import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class AddExpense {
  final ExpenseRepository repository;

  AddExpense(this.repository);

  Future<void> call(ExpenseEntity expense) {
    return repository.addExpense(expense);
  }
}
