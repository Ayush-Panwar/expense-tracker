import 'dart:io';
import '../../domain/entities/expense.dart';
import '../../domain/entities/summary.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/local_datasource.dart';
import '../datasources/remote_datasource.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final LocalDatasource localDatasource;
  final RemoteDatasource remoteDatasource;

  ExpenseRepositoryImpl({
    required this.localDatasource,
    required this.remoteDatasource,
  });

  @override
  Future<List<ExpenseEntity>> getLocalExpensesPaginated(int limit, int offset) {
    return localDatasource.getExpensesPaginated(limit, offset);
  }

  @override
  Future<int> getLocalExpenseCount() {
    return localDatasource.getExpenseCount();
  }

  @override
  Future<List<ExpenseEntity>> searchExpenses({
    String? category,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDatasource.getExpenses(
        page: page,
        limit: limit,
        category: category,
        search: query,
      );
      final expenses = result['expenses'] as List<dynamic>;
      return expenses.map((json) => ExpenseModel.fromJson(json)).toList();
    } catch (_) {
      // offline fallback
      final all = await localDatasource.getExpensesPaginated(limit, 0);
      return all.where((e) {
        if (category != null && e.category != category) return false;
        if (query != null && query.isNotEmpty) {
          final q = query.toLowerCase();
          final noteMatch = e.note?.toLowerCase().contains(q) ?? false;
          final catMatch = e.category.toLowerCase().contains(q);
          if (!noteMatch && !catMatch) return false;
        }
        return true;
      }).toList();
    }
  }

  @override
  Future<SummaryEntity> getSummary() async {
    try {
      final data = await remoteDatasource.getSummary();
      return SummaryEntity(
        today: (data['today'] as num).toDouble(),
        week: (data['week'] as num).toDouble(),
        month: (data['month'] as num).toDouble(),
      );
    } catch (_) {
      return const SummaryEntity();
    }
  }

  @override
  Future<void> addExpense(ExpenseEntity expense) {
    final model = ExpenseModel(
      id: expense.id,
      amount: expense.amount,
      category: expense.category,
      note: expense.note,
      date: expense.date,
      localImagePath: expense.localImagePath,
      remoteImageUrl: expense.remoteImageUrl,
      isSynced: expense.isSynced,
      createdAt: expense.createdAt,
    );
    return localDatasource.insertExpense(model);
  }

  @override
  Future<void> deleteExpense(String id, bool isSynced) async {
    final expense = await localDatasource.getExpenseById(id);

    if (isSynced) {
      try {
        await remoteDatasource.deleteExpense(id);
      } catch (_) {
        await localDatasource.addPendingDelete(id);
      }
    }
    await localDatasource.deleteExpense(id);

    if (expense?.localImagePath != null) {
      try {
        final file = File(expense!.localImagePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> pushLocalChanges() async {
    // pending deletes
    final pendingIds = await localDatasource.getPendingDeletes();
    for (final id in pendingIds) {
      try {
        await remoteDatasource.deleteExpense(id);
        await localDatasource.removePendingDelete(id);
      } catch (_) {}
    }

    // unsynced expenses
    final unsynced = await localDatasource.getUnsyncedExpenses();
    for (final expense in unsynced) {
      try {
        File? imageFile;
        if (expense.localImagePath != null) {
          imageFile = File(expense.localImagePath!);
        }

        final response = await remoteDatasource.createExpense(
          id: expense.id,
          amount: expense.amount,
          category: expense.category,
          note: expense.note,
          date: expense.date,
          imageFile: imageFile,
        );

        if (response['deletedAt'] != null) {
          await localDatasource.deleteExpense(expense.id);
        } else {
          final imageUrl = response['imageUrl'] as String? ?? '';
          await localDatasource.markAsSynced(expense.id, imageUrl);
        }
      } catch (_) {}
    }
  }

  @override
  Future<bool> pullRemoteChanges() async {
    try {
      bool hadChanges = false;
      bool hasMore = true;
      String? cursor = await localDatasource.getLastSyncedAt();

      while (hasMore) {
        final result = await remoteDatasource.getChangesSince(cursor);

        final upserted = result['upserted'] as List<dynamic>;
        final deleted = result['deleted'] as List<dynamic>;
        final serverTime = result['serverTime'] as String;
        hasMore = result['hasMore'] as bool? ?? false;

        if (upserted.isEmpty && deleted.isEmpty) {
          await localDatasource.setLastSyncedAt(serverTime);
          break;
        }

        hadChanges = true;

        for (final json in upserted) {
          final model = ExpenseModel.fromJson(json);
          await localDatasource.upsertExpense(model);
        }

        for (final id in deleted) {
          await localDatasource.deleteExpense(id as String);
        }

        cursor = serverTime;
        await localDatasource.setLastSyncedAt(serverTime);
      }

      return hadChanges;
    } catch (_) {
      return false;
    }
  }
}
