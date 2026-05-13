import '../entities/summary.dart';
import '../repositories/expense_repository.dart';

class GetSummary {
  final ExpenseRepository repository;

  GetSummary(this.repository);

  Future<SummaryEntity> call() {
    return repository.getSummary();
  }
}
