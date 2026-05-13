import 'expense.dart';

class SyncResult {
  final List<ExpenseEntity> upserted;
  final List<String> deleted;

  const SyncResult({
    this.upserted = const [],
    this.deleted = const [],
  });

  bool get hasChanges => upserted.isNotEmpty || deleted.isNotEmpty;
}
