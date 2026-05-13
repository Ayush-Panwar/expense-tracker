import 'package:drift/drift.dart';

class PendingDeletes extends Table {
  TextColumn get expenseId => text()();

  @override
  Set<Column> get primaryKey => {expenseId};
}
