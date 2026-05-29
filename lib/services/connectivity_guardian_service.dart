import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../core/storage/storage_service.dart';
import 'error_service.dart';

/// 连接守护：实时监测 404/断路由，联动后端智能体扫描与修复。
class ConnectivityGuardianService {
  ConnectivityGuardianService._();
  static final ConnectivityGuardianService instance =
      ConnectivityGuardianService._();

  static const _scanPath = '/api/ops/guardian/scan';
  static const _statusPath = '/api/ops/guardian/status';

  Timer? _timer;
  bool _scanning = false;
  DateTime? _lastClientScan;
  Map<String, dynamic>? _lastStatus;

  Dio get _dio => DioClient.instance.dio;

  /// 登录后启动：定时扫描 + 依赖后端启动扫描结果。
  void start() {
    stop();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      _runRemoteScan(trigger: 'periodic');
    });
    Future.delayed(const Duration(seconds: 8), () {
      _runRemoteScan(trigger: 'startup');
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dio 拦截器在 404 时调用。
  Future<void> onApiFailure({
    required String method,
    required String path,
    required int? statusCode,
  }) async {
    if (statusCode != 404) return;

    final feature = _featureForPath(path);
    ErrorService.instance.record(
      message: '接口不可达：$method $path${feature.isEmpty ? '' : '（$feature）'}',
      level: ErrorLevel.warning,
      context: 'ConnectivityGuardian',
      endpoint: '$method $path',
      statusCode: statusCode,
    );

    await _runRemoteScan(trigger: 'api_404', path: path);
  }

  String _featureForPath(String path) {
    if (path.contains('/mini-apps')) return '学习小软件工坊';
    if (path.contains('/api-config')) return 'API 配置';
    if (path.contains('/capabilities')) return '工具箱能力';
    if (path.contains('/library')) return '课程空间';
    if (path.contains('/cas/')) return 'CAS';
    if (path.contains('/study-planner')) return '学习规划';
    if (path.contains('/planning')) return '自动化规划';
    return '';
  }

  Future<void> _runRemoteScan({required String trigger, String? path}) async {
    final token = await StorageService.instance.getToken();
    if (token == null || token.isEmpty) return;
    if (_scanning) return;
    _scanning = true;
    try {
      final res = await _dio.post(_scanPath);
      final data = res.data as Map<String, dynamic>?;
      _lastClientScan = DateTime.now();
      _lastStatus = data;
      _recordScanResult(data, trigger: trigger, path: path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[ConnectivityGuardian] ops API 未部署，跳过远程扫描');
      }
    } catch (e) {
      debugPrint('[ConnectivityGuardian] scan failed: $e');
    } finally {
      _scanning = false;
    }
  }

  void _recordScanResult(
    Map<String, dynamic>? data, {
    required String trigger,
    String? path,
  }) {
    if (data == null) return;
    final issues = data['issues'] as List<dynamic>? ?? [];
    final fixes = data['fixes_applied'] as int? ?? 0;
    final needsRestart = data['needs_restart'] == true;

    if (issues.isEmpty) {
      if (trigger == 'api_404' && path != null) {
        ErrorService.instance.record(
          message: '连接守护已扫描：$path 在服务端路由正常，可能是参数或权限问题',
          level: ErrorLevel.info,
          context: 'ConnectivityGuardian',
          endpoint: path,
        );
      }
      return;
    }

    for (final raw in issues) {
      if (raw is! Map) continue;
      final p = raw['path'] as String? ?? '';
      final feature = raw['feature'] as String? ?? '';
      final msg = raw['message'] as String? ?? '接口异常';
      final fixDetail = raw['fix_detail'] as String? ?? '';
      ErrorService.instance.record(
        message: fixDetail.isEmpty ? '$feature: $msg' : '$feature: $msg — $fixDetail',
        level: ErrorLevel.warning,
        context: 'ConnectivityGuardian/$trigger',
        endpoint: p,
        statusCode: raw['status_code'] as int?,
      );
    }

    if (needsRestart) {
      ErrorService.instance.record(
        message: '连接守护已自动修补 $fixes 处路由注册，需重启服务器后端后生效',
        level: ErrorLevel.info,
        context: 'ConnectivityGuardian',
      );
    }
  }

  /// 手动触发一次远程扫描（设置页 / 系统日志页）。
  Future<void> runScanNow() async {
    await _runRemoteScan(trigger: 'manual');
  }

  Future<Map<String, dynamic>?> fetchStatus() async {
    try {
      final res = await _dio.get(_statusPath);
      _lastStatus = res.data as Map<String, dynamic>?;
      return _lastStatus;
    } catch (_) {
      return _lastStatus;
    }
  }

  DateTime? get lastClientScan => _lastClientScan;
}
