// ─────────────────────────────────────────────────────────────
// update_service.dart — 应用内更新服务
// 负责检查版本、下载 APK、触发安装
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/update.apk';

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    await OpenFile.open(savePath);
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
