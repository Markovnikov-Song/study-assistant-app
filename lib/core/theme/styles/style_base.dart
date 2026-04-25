import 'package:flutter/material.dart';

/// ============================================================
/// 主题风格基础接口
/// 所有风格必须实现此接口
/// ============================================================

/// 风格标识符 - 使用字符串常量，便于配置和切换
class StyleIds {
  StyleIds._();

  static const String defaultStyle = 'default';
  static const String clay = 'clay';
  static const String minimal = 'minimal';
}

/// 风格元数据
class StyleMeta {
  final String id;
  final String name;
  final String description;
  final String previewImage; // 预览图路径

  const StyleMeta({
    required this.id,
    required this.name,
    required this.description,
    this.previewImage = '',
  });
}

/// 风格包接口
abstract class StylePack {
  /// 风格标识符
  String get id;

  /// 风格元数据
  StyleMeta get meta;

  /// 浅色主题
  ThemeData get lightTheme;

  /// 深色主题
  ThemeData get darkTheme;

  /// 获取当前主题（根据 brightness）
  ThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }
}

/// 颜色包接口
abstract class ColorPack {
  // ─── 主色调 ────────────────────────────────────────────────
  Color get primary;
  Color get primaryLight;
  Color get primaryDark;

  // ─── 功能色 ────────────────────────────────────────────────
  Color get secondary;
  Color get secondaryLight;
  Color get accent;
  Color get accentLight;

  // ─── 错误/警告/成功 ─────────────────────────────────────────
  Color get error;
  Color get errorLight;
  Color get warning;
  Color get warningLight;
  Color get success;
  Color get successLight;
  Color get info;
  Color get infoLight;

  // ─── 浅色模式背景 ──────────────────────────────────────────
  Color get background;
  Color get surface;
  Color get surfaceElevated;
  Color get surfaceContainer;
  Color get surfaceContainerHigh;

  // ─── 浅色模式文字 ──────────────────────────────────────────
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textOnPrimary;

  // ─── 深色模式背景 ─────────────────────────────────────────
  Color get backgroundDark;
  Color get surfaceDark;
  Color get surfaceElevatedDark;
  Color get surfaceContainerDark;
  Color get surfaceContainerHighDark;

  // ─── 深色模式文字 ──────────────────────────────────────────
  Color get textPrimaryDark;
  Color get textSecondaryDark;
  Color get textTertiaryDark;

  // ─── 边框与分割线 ──────────────────────────────────────────
  Color get border;
  Color get borderLight;
  Color get borderDark;
  Color get divider;
  Color get dividerDark;

  // ─── 阴影颜色 ──────────────────────────────────────────────
  Color get shadowPrimary;
  Color get shadowDark;
  Color get shadowDarkNight;
  Color get shadowLightNight;
}

/// 主题包接口（包含颜色 + 主题数据）
abstract class ThemePack implements ColorPack {
  ThemeData get lightTheme;
  ThemeData get darkTheme;
}

/// 间距与圆角常量包
abstract class SpacingPack {
  // ─── 间距常量 ──────────────────────────────────────────────
  double get spaceXs;
  double get spaceSm;
  double get spaceMd;
  double get spaceLg;
  double get spaceXl;
  double get space2xl;
  double get space3xl;

  // ─── 圆角常量 ──────────────────────────────────────────────
  double get radiusSm;
  double get radiusMd;
  double get radiusLg;
  double get radiusXl;
  double get radiusFull;

  // ─── BorderRadius 便捷访问 ─────────────────────────────────
  BorderRadius get borderRadiusSm;
  BorderRadius get borderRadiusMd;
  BorderRadius get borderRadiusLg;
  BorderRadius get borderRadiusXl;

  // ─── 动画时长 ─────────────────────────────────────────────
  Duration get durationFast;
  Duration get durationNormal;
  Duration get durationSlow;
}
