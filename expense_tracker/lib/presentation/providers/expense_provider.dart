import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/expense.dart';
import '../../domain/entities/summary.dart';
import '../../domain/usecases/get_expenses.dart';
import '../../domain/usecases/add_expense.dart';
import '../../domain/usecases/delete_expense.dart';
import '../../domain/usecases/sync_expenses.dart';
import '../../domain/usecases/search_expenses.dart';
import '../../domain/usecases/get_summary.dart';
import '../../core/di.dart';

class ExpenseState {
  final List<ExpenseEntity> expenses;
  final SummaryEntity summary;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? activeCategory;
  final String? activeQuery;
  final String? error;

  bool get hasActiveFilter =>
      activeCategory != null || (activeQuery != null && activeQuery!.isNotEmpty);

  ExpenseState({
    this.expenses = const [],
    this.summary = const SummaryEntity(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.activeCategory,
    this.activeQuery,
    this.error,
  });

  ExpenseState copyWith({
    List<ExpenseEntity>? expenses,
    SummaryEntity? summary,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? activeCategory,
    String? activeQuery,
    String? error,
    bool clearCategory = false,
    bool clearQuery = false,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      activeCategory: clearCategory ? null : (activeCategory ?? this.activeCategory),
      activeQuery: clearQuery ? null : (activeQuery ?? this.activeQuery),
      error: error,
    );
  }
}

class ExpenseNotifier extends Notifier<ExpenseState> {
  late final GetExpenses _getExpenses;
  late final AddExpense _addExpense;
  late final DeleteExpense _deleteExpense;
  late final SyncExpenses _syncExpenses;
  late final SearchExpenses _searchExpenses;
  late final GetSummary _getSummary;
  final _uuid = const Uuid();

  bool _isSyncing = false;
  bool _isLoadingMore = false;
  int _filterVersion = 0; // tracks which filter request is latest

  static const _pageSize = 20;

  @override
  ExpenseState build() {
    final di = DI();
    _getExpenses = di.getExpenses;
    _addExpense = di.addExpense;
    _deleteExpense = di.deleteExpense;
    _syncExpenses = di.syncExpenses;
    _searchExpenses = di.searchExpenses;
    _getSummary = di.getSummary;
    return ExpenseState();
  }

  bool _listsEqual(List<ExpenseEntity> a, List<ExpenseEntity> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _updateExpenses(List<ExpenseEntity> newExpenses, {bool? hasMore}) {
    if (!_listsEqual(newExpenses, state.expenses)) {
      state = state.copyWith(
        expenses: newExpenses,
        isLoading: false,
        hasMore: hasMore ?? state.hasMore,
      );
    } else if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadExpenses({bool silent = false}) async {
    if (!silent && state.expenses.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final expenses = await _getExpenses(limit: _pageSize, offset: 0);
      _updateExpenses(expenses, hasMore: expenses.length >= _pageSize);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load');
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore || state.hasActiveFilter) return;
    _isLoadingMore = true;

    state = state.copyWith(isLoadingMore: true);
    try {
      final currentCount = state.expenses.length;
      final nextPage = await _getExpenses(
        limit: _pageSize,
        offset: currentCount,
      );
      // only append if list hasn't been replaced while we were loading
      if (state.expenses.length == currentCount) {
        state = state.copyWith(
          expenses: [...state.expenses, ...nextPage],
          isLoadingMore: false,
          hasMore: nextPage.length >= _pageSize,
        );
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> loadSummary() async {
    try {
      final summary = await _getSummary();
      if (summary != state.summary) {
        state = state.copyWith(summary: summary);
      }
    } catch (_) {}
  }

  Future<void> applyFilter({String? category, String? query}) async {
    final hasCategory = category != null;
    final hasQuery = query != null && query.isNotEmpty;

    if (!hasCategory && !hasQuery) {
      _filterVersion++;
      await loadExpenses();
      return;
    }

    // track this filter request version
    _filterVersion++;
    final myVersion = _filterVersion;

    state = state.copyWith(
      isLoading: true,
      activeCategory: category,
      activeQuery: query,
      clearCategory: !hasCategory,
      clearQuery: !hasQuery,
    );

    try {
      final results = await _searchExpenses(
        category: category,
        query: hasQuery ? query : null,
      );
      // only apply if this is still the latest filter request
      if (_filterVersion == myVersion) {
        state = state.copyWith(
          expenses: results,
          isLoading: false,
          hasMore: false,
        );
      }
    } catch (_) {
      if (_filterVersion == myVersion) {
        state = state.copyWith(isLoading: false, error: 'Search failed');
      }
    }
  }

  void clearFilters() {
    _filterVersion++;
    loadExpenses();
  }

  Future<void> _refreshAfterSync() async {
    if (state.hasActiveFilter) {
      await applyFilter(
        category: state.activeCategory,
        query: state.activeQuery,
      );
    } else {
      await loadExpenses(silent: true);
    }
  }

  Future<void> addExpense({
    required double amount,
    required String category,
    String? note,
    required DateTime date,
    required File imageFile,
  }) async {
    final id = _uuid.v4();

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${id}_receipt${p.extension(imageFile.path)}';
    final localPath = p.join(appDir.path, fileName);
    await imageFile.copy(localPath);

    final expense = ExpenseEntity(
      id: id,
      amount: amount,
      category: category,
      note: note,
      date: date,
      localImagePath: localPath,
      isSynced: false,
      createdAt: DateTime.now(),
    );

    await _addExpense(expense);
    state = state.copyWith(expenses: [expense, ...state.expenses]);

    try {
      await _syncExpenses();
      await _refreshAfterSync();
      await loadSummary();
    } catch (_) {}
  }

  Future<void> deleteExpense(String id, bool isSynced) async {
    // optimistic removal from UI
    final previousExpenses = state.expenses;
    state = state.copyWith(
      expenses: state.expenses.where((e) => e.id != id).toList(),
    );

    try {
      await _deleteExpense(id, isSynced);
      await loadSummary();
    } catch (_) {
      // rollback on failure
      state = state.copyWith(expenses: previousExpenses);
    }
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final hadChanges = await _syncExpenses();

      if (hadChanges) {
        await _refreshAfterSync();
      } else {
        if (!state.hasActiveFilter) {
          final page = await _getExpenses(limit: _pageSize, offset: 0);
          _updateExpenses(page);
        }
      }

      await loadSummary();
    } catch (_) {
    } finally {
      _isSyncing = false;
    }
  }
}

final expenseProvider = NotifierProvider<ExpenseNotifier, ExpenseState>(
  ExpenseNotifier.new,
);
