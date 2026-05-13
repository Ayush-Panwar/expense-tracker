import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'expense_table.dart';
import 'pending_delete_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Expenses, PendingDeletes])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pendingDeletes);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return SqfliteQueryExecutor.inDatabaseFolder(path: 'expenses.db');
  }

  // paginated query — never load all at once
  Future<List<Expense>> getExpensesPaginated(int limit, int offset) {
    return (select(expenses)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> getExpenseCount() async {
    final count = countAll();
    final query = selectOnly(expenses)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<List<Expense>> getUnsyncedExpenses() {
    return (select(expenses)..where((t) => t.isSynced.equals(false))).get();
  }

  Future<Expense?> getExpenseById(String id) {
    return (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertExpense(ExpensesCompanion entry) {
    return into(expenses).insert(entry);
  }

  // upsert — handles updates from other devices
  Future<void> upsertExpense(ExpensesCompanion entry) {
    return into(expenses).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> markAsSynced(String id, String imageUrl) {
    return (update(expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(
        isSynced: const Value(true),
        remoteImageUrl: Value(imageUrl),
      ),
    );
  }

  Future<void> removeExpense(String id) {
    return (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await delete(expenses).go();
    await delete(pendingDeletes).go();
  }

  // pending deletes
  Future<void> addPendingDelete(String expenseId) {
    return into(pendingDeletes).insert(
      PendingDeletesCompanion(expenseId: Value(expenseId)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<PendingDelete>> getPendingDeletes() {
    return select(pendingDeletes).get();
  }

  Future<void> removePendingDelete(String expenseId) {
    return (delete(pendingDeletes)
          ..where((t) => t.expenseId.equals(expenseId)))
        .go();
  }
}
