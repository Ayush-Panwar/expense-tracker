import 'package:dio/dio.dart';
import '../database/database.dart';
import '../data/datasources/local_datasource.dart';
import '../data/datasources/remote_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/connectivity_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/connectivity_repository.dart';
import '../domain/usecases/get_expenses.dart';
import '../domain/usecases/add_expense.dart';
import '../domain/usecases/delete_expense.dart';
import '../domain/usecases/sync_expenses.dart';
import '../domain/usecases/search_expenses.dart';
import '../domain/usecases/get_summary.dart';
import '../domain/usecases/login.dart';
import '../domain/usecases/signup.dart';

class DI {
  static final DI _instance = DI._();
  factory DI() => _instance;
  DI._();

  late final LocalDatasource _localDatasource;
  late final RemoteDatasource _remoteDatasource;
  late final ExpenseRepository _expenseRepo;
  late final AuthRepository _authRepo;
  late final ConnectivityRepository _connectivityRepo;

  void init() {
    final db = AppDatabase.instance;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _localDatasource = LocalDatasource(db);
    _remoteDatasource = RemoteDatasource(dio);
    _expenseRepo = ExpenseRepositoryImpl(
      localDatasource: _localDatasource,
      remoteDatasource: _remoteDatasource,
    );
    _authRepo = AuthRepositoryImpl(
      remoteDatasource: _remoteDatasource,
      localDatasource: _localDatasource,
    );
    _connectivityRepo = ConnectivityRepositoryImpl();
  }

  AuthRepository get authRepo => _authRepo;
  ExpenseRepository get expenseRepo => _expenseRepo;
  ConnectivityRepository get connectivityRepo => _connectivityRepo;

  GetExpenses get getExpenses => GetExpenses(_expenseRepo);
  AddExpense get addExpense => AddExpense(_expenseRepo);
  DeleteExpense get deleteExpense => DeleteExpense(_expenseRepo);
  SyncExpenses get syncExpenses => SyncExpenses(_expenseRepo);
  SearchExpenses get searchExpenses => SearchExpenses(_expenseRepo);
  GetSummary get getSummary => GetSummary(_expenseRepo);
  Login get login => Login(_authRepo);
  Signup get signup => Signup(_authRepo);
}
