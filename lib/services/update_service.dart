// ─────────────────────────────────────────────────────────────
// update_service.dart — 应用内更新服务
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/api_constants.dart';
import '../core/network/dio_client.dart';

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

class UpdateCheckResult {
  final bool hasUpdate;
  final bool isForced;
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
  static const _apkChannel = MethodChannel('apk_install');

  static Future<void> initialize() async {}

  Future<UpdateCheckResult> checkForUpdate() async {
    if (!Platform.isAndroid) return const UpdateCheckResult.noUpdate();

    try {
      final response = await _dio.get(ApiConstants.appVersion);
      final raw = response.data as Map<String, dynamic>;
      final info = AppVersionInfo.fromJson({
        ...raw,
        'download_url': _normalizeDownloadUrl(raw['download_url'] as String? ?? ''),
      });

      final packageInfo = await PackageInfo.fromPlatform();
      if (_isNewer(info.latestVersion, packageInfo.version)) {
        return UpdateCheckResult(
          hasUpdate: true,
          isForced: _isNewer(info.minVersion, packageInfo.version),
          info: info,
        );
      }
      return const UpdateCheckResult.noUpdate();
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate failed: $e');
      return const UpdateCheckResult.noUpdate();
    }
  }

  Future<void> downloadAndInstall(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await Permission.requestInstallPackages.request().isGranted) {
      throw Exception('请先在系统设置中允许「伴学」安装未知应用');
    }

    final url = _normalizeDownloadUrl(downloadUrl);
    final version = _versionFromUrl(url) ?? 'latest';
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/study-assistant-$version.apk';
    final file = File(savePath);
    if (await file.exists()) await file.delete();

    final downloader = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 30),
        followRedirects: true,
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    await downloader.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    await _assertValidApk(file);

    try {
      await _apkChannel.invokeMethod<bool>('install', {'path': savePath});
    } on PlatformException catch (e) {
      throw Exception(e.message ?? '调起安装失败，请点「浏览器下载」');
    }
  }

  Future<void> _assertValidApk(File file) async {
    final size = await file.length();
    if (size < 50 * 1024 * 1024) {
      await file.delete();
      throw Exception('安装包不完整（${(size / 1024 / 1024).toStringAsFixed(1)} MB）');
    }
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      // ZIP / APK magic: PK\x03\x04
      if (header.length < 4 ||
          header[0] != 0x50 ||
          header[1] != 0x4b ||
          header[2] != 0x03 ||
          header[3] != 0x04) {
        await file.delete();
        throw Exception('下载到的不是有效安装包，请用浏览器重试');
      }
    } finally {
      await raf.close();
    }
  }

  String _normalizeDownloadUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.host == '47.104.165.105' && uri.port == 8000) {
      return url.replaceFirst(
        'http://47.104.165.105:8000',
        'https://www.study-assistant.cn',
      );
    }
    if (uri.scheme == 'http' &&
        (uri.host == 'www.study-assistant.cn' || uri.host == 'study-assistant.cn')) {
      return uri.replace(scheme: 'https').toString();
    }
    return url;
  }

  String? _versionFromUrl(String url) {
    return RegExp(r'app-v([\d.]+)\.apk').firstMatch(url)?.group(1);
  }

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
