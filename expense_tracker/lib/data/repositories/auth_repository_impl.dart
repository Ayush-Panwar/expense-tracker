import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote_datasource.dart';
import '../datasources/local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final RemoteDatasource remoteDatasource;
  final LocalDatasource localDatasource;

  AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  @override
  Future<String> login(String email, String password) async {
    try {
      final result = await remoteDatasource.login(email, password);
      final token = result['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await localDatasource.clearAll();
      return token;
    } on DioException catch (e) {
      throw _mapDioError(e, 'Login failed');
    }
  }

  @override
  Future<String> signup(String email, String password, String name) async {
    try {
      final result = await remoteDatasource.signup(email, password, name);
      final token = result['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await localDatasource.clearAll();
      return token;
    } on DioException catch (e) {
      throw _mapDioError(e, 'Signup failed');
    }
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await localDatasource.clearAll();
  }

  @override
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  Failure _mapDioError(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure();
    }
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return AuthFailure(data['error']);
    }
    return AuthFailure(fallback);
  }
}
