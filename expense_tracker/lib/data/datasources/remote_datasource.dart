import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class RemoteDatasource {
  final Dio _dio;

  RemoteDatasource(this._dio);

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> signup(
      String email, String password, String name) async {
    final response = await _dio.post(
      '${AppConstants.baseUrl}/auth/signup',
      data: {'email': email, 'password': password, 'name': name},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '${AppConstants.baseUrl}/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> createExpense({
    required String id,
    required double amount,
    required String category,
    String? note,
    required DateTime date,
    File? imageFile,
  }) async {
    final token = await _getToken();
    final formData = FormData.fromMap({
      'id': id,
      'amount': amount.toString(),
      'category': category,
      'note': note ?? '',
      'date': date.toIso8601String().split('T')[0],
      if (imageFile != null)
        'image': await MultipartFile.fromFile(imageFile.path),
    });

    final response = await _dio.post(
      '${AppConstants.baseUrl}/expenses',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getExpenses({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final token = await _getToken();
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (category != null) queryParams['category'] = category;
    if (search != null) queryParams['search'] = search;

    final response = await _dio.get(
      '${AppConstants.baseUrl}/expenses',
      queryParameters: queryParams,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  // delta sync — only get changes since last sync
  Future<Map<String, dynamic>> getChangesSince(String? since) async {
    final token = await _getToken();
    final queryParams = <String, dynamic>{};
    if (since != null) queryParams['since'] = since;

    final response = await _dio.get(
      '${AppConstants.baseUrl}/expenses/changes',
      queryParameters: queryParams,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final token = await _getToken();
    final response = await _dio.get(
      '${AppConstants.baseUrl}/expenses/summary',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  Future<void> deleteExpense(String id) async {
    final token = await _getToken();
    await _dio.delete(
      '${AppConstants.baseUrl}/expenses/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
