import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/error_service.dart';

/// Centralized client-side error capture.
class GlobalErrorHandler {
  /// Call before runApp() in main().
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

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ErrorService.instance.record(
        message: error.toString(),
        level: ErrorLevel.error,
        stackTrace: stack.toString(),
        context: 'Platform Dispatcher Error',
      );
      return false;
    };
  }

  /// Error callback for runZonedGuarded.
  static void handleZoneError(Object error, StackTrace stackTrace) {
    ErrorService.instance.record(
      message: error.toString(),
      level: ErrorLevel.error,
      stackTrace: stackTrace.toString(),
      context: 'Dart Unhandled Error',
    );
  }

  /// Records Dio request failures.
  static void handleDioError(dynamic error, String endpoint) {
    String message = 'Network request failed';
    int? statusCode;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Request timed out';
          break;
        case DioExceptionType.badResponse:
          statusCode = error.response?.statusCode;
          message =
              error.response?.data?['message']?.toString() ??
              error.response?.statusMessage ??
              'HTTP error $statusCode';
          break;
        case DioExceptionType.cancel:
          message = 'Request cancelled';
          break;
        default:
          message = error.message ?? 'Network error';
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

  /// Records business-level warnings.
  static void handleBusinessError(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.warning,
      context: context ?? 'Business Error',
    );
  }

  /// Records an info log.
  static void logInfo(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.info,
      context: context,
    );
  }

  /// Records a debug log.
  static void logDebug(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.debug,
      context: context,
    );
  }

  /// Records a warning log.
  static void logWarning(String message, {String? context}) {
    ErrorService.instance.record(
      message: message,
      level: ErrorLevel.warning,
      context: context,
    );
  }
}
