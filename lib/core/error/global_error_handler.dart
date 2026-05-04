import 'dart:async';
import '../network/dio_client.dart';
import '../../services/error_service.dart';

/// 全局错误处理器
/// 自动捕获未处理的异常并记录到日志
class GlobalErrorHandler {
  static void setup() {
    // 捕获 Flutter 框架层面的未处理异常
    FlutterError.onError = (FlutterErrorDetails details) {
      ErrorService.instance.record(
        message: details.exceptionAsString(),
        level: ErrorLevel.error,
        stackTrace: details.stack?.toString(),
        context: 'Flutter Framework Error',
      );

      // 保留原始处理（调试模式下打印到控制台）
      FlutterError.dumpErrorToConsole(details);
    };

    // 捕获 Dart 层面的未处理异常
    runZonedGuarded(
      () {},
      (error, stackTrace) {
        ErrorService.instance.record(
          message: error.toString(),
          level: ErrorLevel.error,
          stackTrace: stackTrace.toString(),
          context: 'Dart Unhandled Error',
        );
      },
    );

    // 捕获异步错误
    // 在 main() 中调用 runZonedGuarded 来包裹整个 app
  }

  /// 处理 Dio 请求错误
  static void handleDioError(dynamic error, String endpoint) {
    String message = '网络请求失败';
    int? statusCode;

    if (error is DioError) {
      switch (error.type) {
        case DioErrorType.connectTimeout:
        case DioErrorType.sendTimeout:
        case DioErrorType.receiveTimeout:
          message = '请求超时';
          break;
        case DioErrorType.response:
          statusCode = error.response?.statusCode;
          message = error.response?.data?['message']?.toString() ??
              error.response?.statusMessage ??
              'HTTP 错误 $statusCode';
          break;
        case DioErrorType.cancel:
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
