import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../core/storage/storage_service.dart';
import '../models/user.dart';

class AuthService {
  final Dio _dio = DioClient.instance.dio;

  Future<User> login(String username, String password) async {
    try {
      final res = await _dio.post(ApiConstants.login, data: {
        'username': username,
        'password': password,
      });
      await StorageService.instance.saveToken(res.data['access_token']);
      return User(
        id: res.data['user_id'].toString(),
        username: res.data['username'],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<User> register(String username, String password) async {
    try {
      final res = await _dio.post(ApiConstants.register, data: {
        'username': username,
        'password': password,
      });
      await StorageService.instance.saveToken(res.data['access_token']);
      return User(
        id: res.data['user_id'].toString(),
        username: res.data['username'],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } on DioException catch (e) {
      debugPrint('[AuthService] logout 请求失败: $e');
    }
    await StorageService.instance.clearTokens();
  }
}
