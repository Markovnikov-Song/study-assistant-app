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
      case DioExceptionType.connectionError:
        return const ApiException(message: '无法连接服务器，请检查网络后重试');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final data = e.response?.data;
        String msg;

        if (code == 401) {
          return const ApiException(message: '登录已过期，请重新登录', statusCode: 401);
        }

        // 安全解析错误信息，处理 data 可能是 List 或 Map 的情况
        if (data is Map<String, dynamic>) {
          // 标准 FastAPI 错误格式：{"detail": "..."} 或 {"detail": [...]}
          final detail = data['detail'];
          if (detail is String) {
            msg = detail;
          } else if (detail is List && detail.isNotEmpty) {
            // FastAPI 422 错误：detail 是验证错误列表
            final first = detail[0];
            if (first is Map && first['msg'] is String) {
              msg = first['msg']!;
            } else {
              msg = first.toString();
            }
          } else {
            msg = '请求失败（状态码 $code）';
          }
        } else if (data is String) {
          msg = data;
        } else {
          msg = '请求失败（状态码 $code）';
        }

        return ApiException(message: msg, statusCode: code);
      case DioExceptionType.cancel:
        return const ApiException(message: '请求已取消');
      case DioExceptionType.unknown:
        return const ApiException(message: '网络异常，请检查网络连接后重试');
      default:
        return const ApiException(message: '网络异常，请稍后重试');
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
