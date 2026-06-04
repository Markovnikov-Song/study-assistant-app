import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/focus_guard_platform_service.dart';

class FocusGuardSettings {
  final bool enabled;
  final bool appLockEnabled;
  final bool keepScreenAwake;
  final List<String> allowedPackages;
  final List<String> legacyAllowList;

  const FocusGuardSettings({
    this.enabled = false,
    this.appLockEnabled = false,
    this.keepScreenAwake = true,
    this.allowedPackages = const [],
    this.legacyAllowList = const ['学习助手', '词典', '计算器'],
  });

  static const _kEnabled = 'focus_guard_enabled';
  static const _kAppLockEnabled = 'focus_guard_app_lock_enabled';
  static const _kKeepScreenAwake = 'focus_guard_keep_screen_awake';
  static const _kAllowedPackages = 'focus_guard_allowed_packages';
  static const _kLegacyAllowList = 'focus_guard_allow_list';

  static Future<FocusGuardSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return FocusGuardSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      appLockEnabled: prefs.getBool(_kAppLockEnabled) ?? false,
      keepScreenAwake: prefs.getBool(_kKeepScreenAwake) ?? true,
      allowedPackages: prefs.getStringList(_kAllowedPackages) ?? const [],
      legacyAllowList:
          prefs.getStringList(_kLegacyAllowList) ?? const ['学习助手', '词典', '计算器'],
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setBool(_kAppLockEnabled, appLockEnabled);
    await prefs.setBool(_kKeepScreenAwake, keepScreenAwake);
    await prefs.setStringList(_kAllowedPackages, allowedPackages);
    await prefs.setStringList(_kLegacyAllowList, legacyAllowList);
  }

  FocusGuardSettings copyWith({
    bool? enabled,
    bool? appLockEnabled,
    bool? keepScreenAwake,
    List<String>? allowedPackages,
    List<String>? legacyAllowList,
  }) => FocusGuardSettings(
    enabled: enabled ?? this.enabled,
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    allowedPackages: allowedPackages ?? this.allowedPackages,
    legacyAllowList: legacyAllowList ?? this.legacyAllowList,
  );
}

class FocusGuardNotifier extends StateNotifier<FocusGuardSettings> {
  bool _sessionActive = false;

  FocusGuardNotifier() : super(const FocusGuardSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await FocusGuardSettings.load();
  }

  Future<void> update(FocusGuardSettings settings) async {
    state = settings;
    await settings.save();
    await syncNativeGuard();
  }

  Future<void> togglePackage(String packageName) async {
    final next = [...state.allowedPackages];
    if (next.contains(packageName)) {
      next.remove(packageName);
    } else {
      next.add(packageName);
    }
    await update(state.copyWith(allowedPackages: next));
  }

  Future<void> activateForSession() async {
    _sessionActive = true;
    await syncNativeGuard();
  }

  Future<void> deactivateForSession() async {
    _sessionActive = false;
    await FocusGuardPlatformService.instance.stop();
  }

  Future<void> syncNativeGuard() async {
    final platform = FocusGuardPlatformService.instance;
    final status = await platform.getStatus();
    if (_sessionActive &&
        state.enabled &&
        state.appLockEnabled &&
        status.canRunAndroidGuard) {
      await platform.start(allowedPackages: state.allowedPackages);
    } else {
      await platform.stop();
    }
  }
}

final focusGuardProvider =
    StateNotifierProvider<FocusGuardNotifier, FocusGuardSettings>(
      (_) => FocusGuardNotifier(),
    );

final focusGuardPermissionStatusProvider =
    FutureProvider<FocusGuardPermissionStatus>((ref) {
      return FocusGuardPlatformService.instance.getStatus();
    });

final focusGuardInstalledAppsProvider = FutureProvider<List<FocusGuardAppInfo>>(
  (ref) {
    return FocusGuardPlatformService.instance.getInstalledApps();
  },
);
