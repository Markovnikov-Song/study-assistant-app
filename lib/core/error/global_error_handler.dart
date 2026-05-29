import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../services/error_service.dart';

/// 全局错误处理器
/// 自动捕获未处理的异常并记录到日志
class GlobalErrorHandler {
  /// 在 main() 里、runApp 之前调用。
  static void setupFlutterErrorHandler() {
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      ErrorService.instance.record(
        message: details.exceptionAsString(),
        level: ErrorLevel.error,
        stackTrace: details.stack?.toString(),
        context: 'Flutter Framework Error',
      );
      defaultOnError?.call(details);
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };
  }

  /// runZonedGuarded 的 error 回调。
  static void handleZoneError(Object error, StackTrace stackTrace) {
    ErrorService.instance.record(
      message: error.toString(),
      level: ErrorLevel.error,
      stackTrace: stackTrace.toString(),
      context: 'Dart Unhandled Error',
    );
  }

  /// 处理 Dio 请求错误
  static void handleDioError(dynamic error, String endpoint) {
    String message = '网络请求失败';
    int? statusCode;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = '请求超时';
          break;
        case DioExceptionType.badResponse:
          statusCode = error.response?.statusCode;
          message =
              error.response?.data?['message']?.toString() ??
              error.response?.statusMessage ??
              'HTTP 错误 $statusCode';
          break;
        case DioExceptionType.cancel:
          message = '请求已取消';
          break;
        default:
          message = error.message ?? '网络错误';
      }
    } else {
      message = error.toString();
    }

    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.error,
      stackTrace: error.toString(),
      context: 'Dio Request',
      endpoint: endpoint,
      statusCode: statusCode,
    );
  }

  /// 处理通用业务错误
  static void handleBusinessError(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.warning,
      context: context ?? 'Business Error',
    );
  }

  /// 记录信息日志
  static void logInfo(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.info,
      context: context,
    );
  }

  /// 记录调试日志
  static void logDebug(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.debug,
      context: context,
    );
  }

  /// 记录警告日志
  static void logWarning(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.warning,
      context: context,
    );
  }
}
