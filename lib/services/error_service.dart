import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 错误级别
enum ErrorLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// 错误日志条目
@immutable
class ErrorLog {
  final String id;
  final DateTime timestamp;
  final ErrorLevel level;
  final String message;
  final String? stackTrace;
  final String? context;
  final String? endpoint;
  final int? statusCode;

  const ErrorLog({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
    this.context,
    this.endpoint,
    this.statusCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        'stackTrace': stackTrace,
        'context': context,
        'endpoint': endpoint,
        'statusCode': statusCode,
      };

  factory ErrorLog.fromJson(Map<String, dynamic> json) => ErrorLog(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: ErrorLevel.values.byName(json['level'] as String),
        message: json['message'] as String,
        stackTrace: json['stackTrace'] as String?,
        context: json['context'] as String?,
        endpoint: json['endpoint'] as String?,
        statusCode: json['statusCode'] as int?,
      );
}

/// 全局错误处理服务
class ErrorService {
  static const _storageKey = 'app_error_logs';
  static const _maxLogs = 100;

  final List<ErrorLog> _logs = [];
  final StreamController<ErrorLog> _errorStreamController =
      StreamController.broadcast();

  /// 错误流，监听新错误
  Stream<ErrorLog> get errorStream => _errorStreamController.stream;

  /// 单例
  static final ErrorService instance = ErrorService._();
  ErrorService._();

  /// 初始化：从存储加载日志
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _logs.addAll(list.map((e) => ErrorLog.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('[ErrorService] Failed to load logs: $e');
    }
  }

  /// 记录错误
  void record({
    required String message,
    ErrorLevel level = ErrorLevel.error,
    String? stackTrace,
    String? context,
    String? endpoint,
    int? statusCode,
  }) {
    final log = ErrorLog(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      message: message,
      stackTrace: stackTrace,
      context: context,
      endpoint: endpoint,
      statusCode: statusCode,
    );

    _logs.insert(0, log);

    // 限制日志数量
    while (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    // 通知监听者
    _errorStreamController.add(log);

    // 保存到存储
    _saveLogs();

    // 打印到控制台（仅 debug 模式）
    if (kDebugMode) {
      _printLog(log);
    }
  }

  void recordException(
    Object exception, [
    StackTrace? stackTrace,
  ]) {
    record(
      message: exception.toString(),
      level: ErrorLevel.error,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// 获取所有日志
  List<ErrorLog> getLogs() => List.unmodifiable(_logs);

  /// 获取指定级别的日志
  List<ErrorLog> getLogsByLevel(ErrorLevel level) =>
      _logs.where((log) => log.level == level).toList();

  /// 清空所有日志
  Future<void> clearLogs() async {
    _logs.clear();
    await _saveLogs();
  }

  /// 删除单条日志
  Future<void> deleteLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
    await _saveLogs();
  }

  /// 导出日志（用于上报或分享）
  String exportLogs() {
    return jsonEncode(_logs.map((e) => e.toJson()).toList());
  }

  /// 保存日志到存储
  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_logs.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[ErrorService] Failed to save logs: $e');
    }
  }

  /// 生成唯一ID
  String _generateId() => '${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[_randomInt(chars.length)]).join();
  }

  int _randomInt(int max) => DateTime.now().microsecond % max;

  /// 打印日志到控制台
  void _printLog(ErrorLog log) {
    final levelColor = switch (log.level) {
      ErrorLevel.debug => '\x1B[34m', // blue
      ErrorLevel.info => '\x1B[32m', // green
      ErrorLevel.warning => '\x1B[33m', // yellow
      ErrorLevel.error => '\x1B[31m', // red
      ErrorLevel.critical => '\x1B[41m', // red background
    };
    final reset = '\x1B[0m';

    print('$levelColor[${log.level.name.toUpperCase()}]${reset} ${log.message}');
    if (log.stackTrace != null) {
      print('$levelColor[STACK]${reset}\n${log.stackTrace}');
    }
  }
}
