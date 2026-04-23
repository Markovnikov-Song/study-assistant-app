import 'package:flutter/material.dart';

/// ============================================================
/// 伴学 App 色彩系统
/// 基于「静谧学习」设计理念
/// ============================================================

class AppColors {
  AppColors._();

  // ─── 主色调 ────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // ─── 功能色 ────────────────────────────────────────────────
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);

  // ─── 错误/警告/成功 ─────────────────────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF6EE7B7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF93C5FD);

  // ─── 浅色模式背景 ──────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);

  // ─── 浅色模式文字 ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── 边框与分割线 ──────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // ─── 深色模式背景 ──────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceElevatedDark = Color(0xFF334155);
  static const Color surfaceContainerDark = Color(0xFF1E293B);
  static const Color surfaceContainerHighDark = Color(0xFF334155);

  // ─── 深色模式文字 ──────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ─── 深色模式边框 ──────────────────────────────────────────
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);

  // ─── 渐变色 ────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient natureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  // ─── 阴影颜色 ──────────────────────────────────────────────
  static Color shadowPrimary = primary.withValues(alpha: 0.25);
  static Color shadowDark = Colors.black.withValues(alpha: 0.15);
}

/// ============================================================
/// 语义化颜色扩展
/// ============================================================
extension AppColorsSemantic on ColorScheme {
  // 主色调
  Color get primaryAccent => AppColors.primary;
  Color get primaryLight => AppColors.primaryLight;
  Color get primaryDark => AppColors.primaryDark;

  // 成功/警告/错误
  Color get success => AppColors.success;
  Color get successLight => AppColors.successLight;
  Color get warning => AppColors.warning;
  Color get warningLight => AppColors.warningLight;
  Color get errorAccent => AppColors.error;
  Color get errorLight => AppColors.errorLight;
  Color get info => AppColors.info;
  Color get infoLight => AppColors.infoLight;

  // 渐变
  Gradient get primaryGradient => AppColors.primaryGradient;
  Gradient get warmGradient => AppColors.warmGradient;
  Gradient get natureGradient => AppColors.natureGradient;
  Gradient get skyGradient => AppColors.skyGradient;
}
