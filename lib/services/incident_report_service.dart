import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/network/dio_client.dart';
import '../core/utils/device_info.dart';
import 'error_service.dart';

/// 提交结构化反馈到云端收件箱。
class IncidentReportService {
  IncidentReportService._();
  static final IncidentReportService instance = IncidentReportService._();

  static const submitPath = '/api/ops/incidents';

  static const hiddenRoutes = {'/splash', '/login', '/register'};

  bool shouldShowFab(String? route) {
    if (route == null || route.isEmpty) return false;
    final path = Uri.tryParse(route)?.path;
    final normalizedRoute = (path == null || path.isEmpty) ? route : path;
    for (final r in hiddenRoutes) {
      if (normalizedRoute == r || normalizedRoute.startsWith('$r/')) {
        return false;
      }
    }
    return true;
  }

  Future<Map<String, dynamic>> collectDeviceInfo() async {
    final info = <String, dynamic>{
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'deviceType': DeviceInfo.deviceType.name,
    };
    try {
      final pkg = await PackageInfo.fromPlatform();
      info['packageName'] = pkg.packageName;
      info['buildNumber'] = pkg.buildNumber;
    } catch (_) {}
    return info;
  }

  Future<String> appVersionLabel() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      return '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> submit({
    required String route,
    String? description,
    String? contact,
    Uint8List? screenshot,
  }) async {
    final version = await appVersionLabel();
    final device = await collectDeviceInfo();
    final logs = ErrorService.instance
        .getLogs()
        .take(80)
        .map((e) => e.toJson())
        .toList();

    final form = FormData.fromMap({
      'route': route,
      'description': description ?? '',
      'contact': contact ?? '',
      'app_version': version,
      'device_info': jsonEncode(device),
      'client_logs': jsonEncode(logs),
      if (screenshot != null && screenshot.isNotEmpty)
        'screenshot': MultipartFile.fromBytes(
          screenshot,
          filename: 'screenshot.png',
        ),
    });

    final res = await DioClient.instance.dio.post(
      submitPath,
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
