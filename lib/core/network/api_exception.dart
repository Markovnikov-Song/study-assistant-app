import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(message: '网络连接超时，请检查网络');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final msg = e.response?.data?['detail'] ?? '请求失败';
        return ApiException(message: msg.toString(), statusCode: code);
      case DioExceptionType.cancel:
        return const ApiException(message: '请求已取消');
      default:
        final detail = e.message != null ? '（${e.message}）' : '';
        return ApiException(message: '网络异常，请检查服务器是否启动$detail');
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
