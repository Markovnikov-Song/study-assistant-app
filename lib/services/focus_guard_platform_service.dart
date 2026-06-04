import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FocusGuardAppInfo {
  final String packageName;
  final String label;

  const FocusGuardAppInfo({required this.packageName, required this.label});

  factory FocusGuardAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return FocusGuardAppInfo(
      packageName: map['packageName'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }
}

class FocusGuardPermissionStatus {
  final String platform;
  final bool usageAccessGranted;
  final bool overlayGranted;
  final bool screenTimeAvailable;
  final bool entitlementRequired;
  final bool serviceAvailable;

  const FocusGuardPermissionStatus({
    required this.platform,
    required this.usageAccessGranted,
    required this.overlayGranted,
    required this.screenTimeAvailable,
    required this.entitlementRequired,
    required this.serviceAvailable,
  });

  factory FocusGuardPermissionStatus.unsupported() {
    if (kIsWeb) {
      return const FocusGuardPermissionStatus(
        platform: 'web',
        usageAccessGranted: false,
        overlayGranted: false,
        screenTimeAvailable: false,
        entitlementRequired: false,
        serviceAvailable: false,
      );
    }
    return FocusGuardPermissionStatus(
      platform: Platform.operatingSystem,
      usageAccessGranted: false,
      overlayGranted: false,
      screenTimeAvailable: false,
      entitlementRequired: Platform.isIOS,
      serviceAvailable: false,
    );
  }

  factory FocusGuardPermissionStatus.fromMap(Map<dynamic, dynamic> map) {
    return FocusGuardPermissionStatus(
      platform: map['platform'] as String? ?? 'unknown',
      usageAccessGranted: map['usageAccessGranted'] as bool? ?? false,
      overlayGranted: map['overlayGranted'] as bool? ?? false,
      screenTimeAvailable: map['screenTimeAvailable'] as bool? ?? false,
      entitlementRequired: map['entitlementRequired'] as bool? ?? false,
      serviceAvailable: map['serviceAvailable'] as bool? ?? false,
    );
  }

  bool get canRunAndroidGuard =>
      platform == 'android' && usageAccessGranted && overlayGranted;
}

class FocusGuardPlatformService {
  FocusGuardPlatformService._();
  static final instance = FocusGuardPlatformService._();

  static const _channel = MethodChannel('focus_guard');

  Future<FocusGuardPermissionStatus> getStatus() async {
    if (kIsWeb) return FocusGuardPermissionStatus.unsupported();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      return FocusGuardPermissionStatus.fromMap(raw ?? const {});
    } on MissingPluginException {
      return FocusGuardPermissionStatus.unsupported();
    }
  }

  Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<void> openOverlaySettings() async {
    if (kIsWeb) return;
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  Future<List<FocusGuardAppInfo>> getInstalledApps() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getInstalledApps');
      return (raw ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(FocusGuardAppInfo.fromMap)
          .where((app) => app.packageName.isNotEmpty && app.label.isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> start({required List<String> allowedPackages}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('start', {
      'allowedPackages': allowedPackages,
    });
    return ok ?? false;
  }

  Future<bool> stop() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('stop');
    return ok ?? false;
  }
}
