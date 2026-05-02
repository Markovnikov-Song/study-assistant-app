// ─────────────────────────────────────────────────────────────
// update_service.dart — 应用内更新服务
// 负责检查版本、下载 APK、触发安装
// 支持后台下载，切换应用不会中断
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/api_constants.dart';
import '../core/network/dio_client.dart';

/// 版本信息，从后端接口返回
class AppVersionInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  final String changelog;

  const AppVersionInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.downloadUrl,
    required this.changelog,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        latestVersion: json['version'] as String,
        minVersion: json['min_version'] as String,
        downloadUrl: json['download_url'] as String,
        changelog: (json['changelog'] as String?) ?? '',
      );
}

/// 更新检查结果
class UpdateCheckResult {
  /// 是否有新版本
  final bool hasUpdate;

  /// 是否强制更新（当前版本低于 min_version）
  final bool isForced;

  /// 版本信息（hasUpdate 为 true 时有值）
  final AppVersionInfo? info;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.isForced,
    this.info,
  });

  const UpdateCheckResult.noUpdate()
      : hasUpdate = false,
        isForced = false,
        info = null;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  Dio get _dio => DioClient.instance.dio;
  
  final ReceivePort _port = ReceivePort();
  String? _currentTaskId;
  void Function(double)? _progressCallback;

  /// 初始化后台下载服务（在 main.dart 中调用）
  static Future<void> initialize() async {
    await FlutterDownloader.initialize(
      debug: kDebugMode,
      ignoreSsl: false,
    );
  }

  /// 注册下载进度监听
  void _registerDownloadCallback() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    
    _port.listen((dynamic data) {
      final taskId = data[0] as String;
      final status = DownloadTaskStatus.fromInt(data[1] as int);
      final progress = data[2] as int;

      if (taskId == _currentTaskId) {
        if (status == DownloadTaskStatus.running) {
          _progressCallback?.call(progress / 100.0);
        } else if (status == DownloadTaskStatus.complete) {
          _progressCallback?.call(1.0);
          WakelockPlus.disable(); // 下载完成，释放 WakeLock
        } else if (status == DownloadTaskStatus.failed) {
          WakelockPlus.disable();
        }
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  /// 检查是否有新版本，返回检查结果
  /// 网络失败时静默返回 noUpdate，不影响正常使用
  Future<UpdateCheckResult> checkForUpdate() async {
    // 仅 Android 支持自分发 APK 安装
    if (!Platform.isAndroid) return const UpdateCheckResult.noUpdate();

    try {
      final response = await _dio.get(ApiConstants.appVersion);
      final info = AppVersionInfo.fromJson(response.data as Map<String, dynamic>);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewer(info.latestVersion, currentVersion)) {
        final isForced = _isNewer(info.minVersion, currentVersion);
        return UpdateCheckResult(hasUpdate: true, isForced: isForced, info: info);
      }

      return const UpdateCheckResult.noUpdate();
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate failed: $e');
      return const UpdateCheckResult.noUpdate();
    }
  }

  /// 下载 APK 并安装，通过 [onProgress] 回调报告进度 0.0~1.0
  /// 使用后台下载服务，切换应用不会中断下载
  Future<void> downloadAndInstall(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    // 请求安装未知来源权限
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      debugPrint('[UpdateService] REQUEST_INSTALL_PACKAGES denied');
      return;
    }

    // 请求存储权限（Android 13 以下需要）
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        debugPrint('[UpdateService] Storage permission denied');
      }
    }

    // 启用 WakeLock，防止下载时设备休眠或应用被杀
    await WakelockPlus.enable();

    _progressCallback = onProgress;
    _registerDownloadCallback();

    final dir = await getExternalStorageDirectory();
    final savePath = dir?.path ?? (await getTemporaryDirectory()).path;

    // 使用后台下载服务
    _currentTaskId = await FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: savePath,
      fileName: 'update.apk',
      showNotification: true, // 显示系统通知
      openFileFromNotification: true, // 下载完成后点击通知打开文件
      saveInPublicStorage: false,
    );

    // 等待下载完成
    await _waitForDownloadComplete();

    // 打开 APK 安装
    final apkPath = '$savePath/update.apk';
    await OpenFile.open(apkPath);
  }

  /// 等待下载完成
  Future<void> _waitForDownloadComplete() async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_currentTaskId == null) break;
      
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: 'SELECT * FROM task WHERE task_id = "$_currentTaskId"',
      );
      
      if (tasks == null || tasks.isEmpty) break;
      
      final task = tasks.first;
      if (task.status == DownloadTaskStatus.complete ||
          task.status == DownloadTaskStatus.failed ||
          task.status == DownloadTaskStatus.canceled) {
        break;
      }
    }
  }

  /// 比较版本号，返回 a 是否比 b 更新
  /// 格式：major.minor.patch（如 1.2.3）
  bool _isNewer(String a, String b) {
    try {
      final av = a.split('.').map(int.parse).toList();
      final bv = b.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final ai = i < av.length ? av[i] : 0;
        final bi = i < bv.length ? bv[i] : 0;
        if (ai > bi) return true;
        if (ai < bi) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
