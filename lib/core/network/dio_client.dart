import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../error/global_error_handler.dart';
import '../../services/connectivity_guardian_service.dart';
import '../storage/storage_service.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio dio;

  void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 180),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      _ApiLogInterceptor(),
    ]);
  }
}

/// API 请求日志：错误写入系统日志；调试模式下额外打印控制台。
class _ApiLogInterceptor extends Interceptor {
  String _endpoint(RequestOptions options) =>
      '${options.method} ${options.uri.path}';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] → ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[API] ← ${response.statusCode} ${response.requestOptions.uri.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.uri.path;
    GlobalErrorHandler.handleDioError(err, _endpoint(err.requestOptions));
    if (err.response?.statusCode == 404) {
      ConnectivityGuardianService.instance.onApiFailure(
        method: err.requestOptions.method,
        path: path,
        statusCode: 404,
      );
    }
    if (kDebugMode) {
      debugPrint('[API] ✗ ${err.type}: ${err.message}');
    }
    handler.next(err);
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.instance.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
