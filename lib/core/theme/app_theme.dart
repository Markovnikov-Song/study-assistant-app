import 'package:flutter/material.dart';

/// ============================================================
/// 伴学 App 设计常量
/// 间距、圆角、阴影等全局 UI 尺寸定义
/// ============================================================

class AppTheme {
  AppTheme._();

  // ─── 间距常量 ──────────────────────────────────────────────
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double space2xl = 32.0;
  static const double space3xl = 48.0;

  // ─── 圆角常量 ──────────────────────────────────────────────
  static const double radiusSm = 6.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // ─── 阴影常量 ──────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        const BoxShadow(
          color: Color(0x12000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 15,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowXl => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 25,
          offset: Offset(0, 10),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ];

  // ─── 动画时长 ─────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ─── BorderRadius 快捷引用 ─────────────────────────────────
  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
}
