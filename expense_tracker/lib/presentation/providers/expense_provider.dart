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

  const ExpenseState({
    this.expenses = const [],
    this.summary = const SummaryEntity(),
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
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
  int _filterVersion = 0;
  int _loadedCount = 0;

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
    return const ExpenseState();
  }

  // ─── INITIAL LOAD ───
  // smart: try local DB first, if empty fetch page 1 from server directly
  // then background sync fills the rest

  Future<void> initialLoad() async {
    state = state.copyWith(isLoading: true);

    try {
      // try local DB first
      final localCount = await _getExpenses.count();

      if (localCount > 0) {
        // have cached data — show immediately
        final expenses = await _getExpenses(limit: _pageSize, offset: 0);
        _loadedCount = expenses.length;
        state = state.copyWith(
          expenses: expenses,
          isLoading: false,
          hasMore: expenses.length >= _pageSize,
        );
      } else {
        // empty local DB (first login or cleared)
        // fetch page 1 directly from server for instant display
        try {
          final serverPage = await _getExpenses.fromServer(page: 1, limit: _pageSize);
          _loadedCount = serverPage.length;
          state = state.copyWith(
            expenses: serverPage,
            isLoading: false,
            hasMore: serverPage.length >= _pageSize,
          );
        } catch (_) {
          // offline + empty DB — show empty state
          state = state.copyWith(isLoading: false, expenses: const []);
        }
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load');
    }
  }

  // ─── DB READ ───

  Future<void> _reloadFromDB() async {
    final count = _loadedCount > 0 ? _loadedCount : _pageSize;
    // fetch one extra to detect if more exist (same trick as server's 501)
    final fetchCount = count + 1;
    try {
      final fetched = await _getExpenses(limit: fetchCount, offset: 0);
      final hasMore = fetched.length > count;
      // only keep `count` items in state, not the extra
      final expenses = hasMore ? fetched.sublist(0, count) : fetched;
      _loadedCount = expenses.length;

      if (!_listsEqual(expenses, state.expenses)) {
        state = state.copyWith(expenses: expenses, hasMore: hasMore);
      }
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore || state.hasActiveFilter) {
      return;
    }
    _isLoadingMore = true;

    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = await _getExpenses(limit: _pageSize, offset: _loadedCount);
      _loadedCount += nextPage.length;
      state = state.copyWith(
        expenses: [...state.expenses, ...nextPage],
        isLoadingMore: false,
        hasMore: nextPage.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  bool _listsEqual(List<ExpenseEntity> a, List<ExpenseEntity> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ─── SUMMARY ───

  Future<void> loadSummary() async {
    try {
      final summary = await _getSummary();
      if (summary != state.summary) {
        state = state.copyWith(summary: summary);
      }
    } catch (_) {}
  }

  // ─── FILTER / SEARCH ───

  Future<void> applyFilter({String? category, String? query}) async {
    final hasCategory = category != null;
    final hasQuery = query != null && query.isNotEmpty;

    if (!hasCategory && !hasQuery) {
      _filterVersion++;
      _loadedCount = 0;
      await _reloadFirstPage(clearFilter: true);
      return;
    }

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
    _loadedCount = 0;
    _reloadFirstPage(clearFilter: true);
  }

  Future<void> _reloadFirstPage({bool clearFilter = false}) async {
    try {
      final expenses = await _getExpenses(limit: _pageSize, offset: 0);
      _loadedCount = expenses.length;
      state = state.copyWith(
        expenses: expenses,
        isLoading: false,
        hasMore: expenses.length >= _pageSize,
        clearCategory: clearFilter,
        clearQuery: clearFilter,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── CRUD ───

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
    _loadedCount++;

    // respect active filter
    if (state.hasActiveFilter) {
      await applyFilter(
        category: state.activeCategory,
        query: state.activeQuery,
      );
    } else {
      await _reloadFromDB();
    }

    try {
      final changed = await _syncExpenses();
      if (changed) {
        if (state.hasActiveFilter) {
          await applyFilter(
            category: state.activeCategory,
            query: state.activeQuery,
          );
        } else {
          await _reloadFromDB();
        }
      }
      await loadSummary();
    } catch (_) {}
  }

  Future<void> deleteExpense(String id, bool isSynced) async {
    final prev = state.expenses;
    state = state.copyWith(
      expenses: prev.where((e) => e.id != id).toList(),
    );
    _loadedCount = state.expenses.length;

    try {
      await _deleteExpense(id, isSynced);
      await loadSummary();
    } catch (_) {
      state = state.copyWith(expenses: prev);
      _loadedCount = prev.length;
    }
  }

  // ─── SYNC ───

  Future<void> syncAll() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      final dbChanged = await _syncExpenses();

      if (dbChanged) {
        if (state.hasActiveFilter) {
          await applyFilter(
            category: state.activeCategory,
            query: state.activeQuery,
          );
        } else {
          await _reloadFromDB();
        }
      } else {
        // check if sync status flags changed (isSynced false → true)
        if (!state.hasActiveFilter && state.expenses.any((e) => !e.isSynced)) {
          await _reloadFromDB();
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
