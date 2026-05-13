import 'dart:io';
import 'package:flutter/foundation.dart';
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

void _log(String tag, String msg) {
  debugPrint('[EP][$tag] $msg');
}

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
  int _loadedCount = 0; // tracks how many items user has scrolled to

  static const _pageSize = 20;

  @override
  ExpenseState build() {
    _log('BUILD', 'initializing');
    final di = DI();
    _getExpenses = di.getExpenses;
    _addExpense = di.addExpense;
    _deleteExpense = di.deleteExpense;
    _syncExpenses = di.syncExpenses;
    _searchExpenses = di.searchExpenses;
    _getSummary = di.getSummary;
    return const ExpenseState();
  }

  // ─── DB READ: load page from local DB ───

  /// initial load or reload — always reads from DB
  Future<void> loadExpenses() async {
    _log('LOAD', 'loading first page');
    state = state.copyWith(isLoading: true);
    try {
      final expenses = await _getExpenses(limit: _pageSize, offset: 0);
      _loadedCount = expenses.length;
      _log('LOAD', 'got ${expenses.length}, hasMore=${expenses.length >= _pageSize}');
      state = state.copyWith(
        expenses: expenses,
        isLoading: false,
        hasMore: expenses.length >= _pageSize,
      );
    } catch (e) {
      _log('LOAD', 'ERROR: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to load');
    }
  }

  /// infinite scroll
  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore || state.hasActiveFilter) return;
    _isLoadingMore = true;

    _log('LOAD_MORE', 'offset=$_loadedCount');
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = await _getExpenses(limit: _pageSize, offset: _loadedCount);
      _loadedCount += nextPage.length;
      _log('LOAD_MORE', 'got ${nextPage.length}, total=$_loadedCount');
      state = state.copyWith(
        expenses: [...state.expenses, ...nextPage],
        isLoadingMore: false,
        hasMore: nextPage.length >= _pageSize,
      );
    } catch (e) {
      _log('LOAD_MORE', 'ERROR: $e');
      state = state.copyWith(isLoadingMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// reload all currently loaded pages from DB (preserves scroll position)
  Future<void> _reloadFromDB() async {
    final count = _loadedCount > 0 ? _loadedCount : _pageSize;
    _log('RELOAD', 'reloading $count items from DB');
    try {
      final expenses = await _getExpenses(limit: count, offset: 0);
      _loadedCount = expenses.length;
      final hasMore = expenses.length >= _pageSize && expenses.length >= count;
      _log('RELOAD', 'got ${expenses.length}, hasMore=$hasMore');

      // only update UI if data actually changed
      if (!_listsEqual(expenses, state.expenses)) {
        _log('RELOAD', 'data changed — updating UI');
        state = state.copyWith(
          expenses: expenses,
          hasMore: hasMore,
        );
      } else {
        _log('RELOAD', 'data unchanged — skipping UI update');
      }
    } catch (e) {
      _log('RELOAD', 'ERROR: $e');
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
        _log('SUMMARY', 'changed: today=${summary.today}');
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
      _log('FILTER', 'cleared');
      await loadExpenses();
      return;
    }

    _filterVersion++;
    final myVersion = _filterVersion;
    _log('FILTER', 'v$myVersion category=$category query=$query');

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
        _log('FILTER', 'v$myVersion got ${results.length} results');
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
    _log('FILTER', 'clearing');
    state = state.copyWith(clearCategory: true, clearQuery: true);
    loadExpenses();
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
    _log('ADD', '${id.substring(0, 8)} $category ₹$amount');

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

    // write to DB
    await _addExpense(expense);

    // reload from DB (new item will be at correct sorted position)
    await _reloadFromDB();

    // background sync
    try {
      final changed = await _syncExpenses();
      if (changed) await _reloadFromDB();
      await loadSummary();
    } catch (_) {}
  }

  Future<void> deleteExpense(String id, bool isSynced) async {
    _log('DELETE', id.substring(0, 8));

    // optimistic UI removal
    final prev = state.expenses;
    state = state.copyWith(
      expenses: prev.where((e) => e.id != id).toList(),
    );
    _loadedCount = state.expenses.length;

    try {
      await _deleteExpense(id, isSynced);
      await loadSummary();
    } catch (_) {
      // rollback
      state = state.copyWith(expenses: prev);
      _loadedCount = prev.length;
    }
  }

  // ─── SYNC ───

  Future<void> syncAll() async {
    if (_isSyncing) {
      _log('SYNC', 'skipped — busy');
      return;
    }
    _isSyncing = true;
    _log('SYNC', 'start. loaded=$_loadedCount filter=${state.hasActiveFilter}');

    try {
      final dbChanged = await _syncExpenses();
      _log('SYNC', 'dbChanged=$dbChanged');

      if (dbChanged) {
        if (state.hasActiveFilter) {
          _log('SYNC', 'filter active — re-running search');
          await applyFilter(
            category: state.activeCategory,
            query: state.activeQuery,
          );
        } else {
          // reload whatever the user has scrolled to
          await _reloadFromDB();
        }
      } else {
        // no remote changes — but local sync status might have changed
        if (!state.hasActiveFilter && state.expenses.any((e) => !e.isSynced)) {
          _log('SYNC', 'refreshing sync status');
          await _reloadFromDB();
        }
      }

      await loadSummary();
      _log('SYNC', 'complete');
    } catch (e) {
      _log('SYNC', 'ERROR: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

final expenseProvider = NotifierProvider<ExpenseNotifier, ExpenseState>(
  ExpenseNotifier.new,
);
