import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设备类型枚举
enum DeviceType {
  /// 手机（竖屏）
  mobile,
  /// 平板（竖屏或横屏）
  tablet,
  /// 桌面/网页（横屏）
  desktop,
}

/// 响应式断点常量
class Breakpoints {
  Breakpoints._();

  /// 移动端最大宽度
  static const double mobile = 600;

  /// 平板最小宽度
  static const double tablet = 600;

  /// 平板最大宽度
  static const double tabletMax = 1024;

  /// 桌面最小宽度
  static const double desktop = 1024;
}

/// 设备信息工具类
class DeviceInfo {
  DeviceInfo._();

  static bool _initialized = false;
  static DeviceType _deviceType = DeviceType.mobile;
  static Size _screenSize = Size.zero;

  /// 初始化设备信息（必须在 WidgetsFlutterBinding.ensureInitialized() 后调用）
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // 检测平台
    if (kIsWeb) {
      _deviceType = DeviceType.desktop;
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _deviceType = DeviceType.mobile;
    } else {
      _deviceType = DeviceType.desktop;
    }
  }

  /// 更新屏幕尺寸（应在 MediaQuery 改变时调用）
  static void updateScreenSize(Size size) {
    _screenSize = size;
    _updateDeviceType();
  }

  static void _updateDeviceType() {
    final width = _screenSize.width;

    if (width < Breakpoints.mobile) {
      _deviceType = DeviceType.mobile;
    } else if (width < Breakpoints.desktop) {
      _deviceType = DeviceType.tablet;
    } else {
      _deviceType = DeviceType.desktop;
    }
  }

  /// 获取当前设备类型
  static DeviceType get deviceType => _deviceType;

  /// 是否是移动端
  static bool get isMobile => _deviceType == DeviceType.mobile;

  /// 是否是平板
  static bool get isTablet => _deviceType == DeviceType.tablet;

  /// 是否是桌面端
  static bool get isDesktop => _deviceType == DeviceType.desktop;

  /// 是否是大屏幕（平板横屏或桌面）
  static bool get isLargeScreen => _deviceType != DeviceType.mobile;

  /// 当前屏幕尺寸
  static Size get screenSize => _screenSize;

  /// 是否是横屏
  static bool get isLandscape => _screenSize.width > _screenSize.height;
}

/// 设备类型 Provider
final deviceTypeProvider = StateProvider<DeviceType>((ref) => DeviceInfo.deviceType);

/// 屏幕尺寸 Provider
final screenSizeProvider = StateProvider<Size>((ref) => Size.zero);
