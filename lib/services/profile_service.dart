import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/user.dart';

class ProfileService {
  final Dio _dio = DioClient.instance.dio;

  Future<User> changeUsername(String newUsername) async {
    try {
      final res = await _dio.patch(
        ApiConstants.userMeUsername,
        data: {'new_username': newUsername},
      );
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _dio.patch(
        ApiConstants.userMePassword,
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<User> uploadAvatar(Uint8List bytes) async {
    try {
      final base64String = base64Encode(bytes);
      final res = await _dio.post(
        ApiConstants.userMeAvatar,
        data: {'avatar_base64': base64String},
      );
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
