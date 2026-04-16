import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../storage/storage_service.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio dio;

  void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 180),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    ]);
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
