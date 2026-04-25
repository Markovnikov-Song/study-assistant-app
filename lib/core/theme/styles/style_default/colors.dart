import 'package:flutter/material.dart';
import '../style_base.dart';

/// ============================================================
/// 默认风格色彩系统 - 静谧学习
/// ============================================================

class DefaultColors implements ColorPack {
  const DefaultColors();

  // ─── 主色调 ────────────────────────────────────────────────
  @override
  Color get primary => const Color(0xFF6366F1);
  @override
  Color get primaryLight => const Color(0xFF818CF8);
  @override
  Color get primaryDark => const Color(0xFF4F46E5);

  // ─── 功能色 ────────────────────────────────────────────────
  @override
  Color get secondary => const Color(0xFF10B981);
  @override
  Color get secondaryLight => const Color(0xFF34D399);
  @override
  Color get accent => const Color(0xFFF59E0B);
  @override
  Color get accentLight => const Color(0xFFFBBF24);

  // ─── 错误/警告/成功 ─────────────────────────────────────────
  @override
  Color get error => const Color(0xFFEF4444);
  @override
  Color get errorLight => const Color(0xFFFCA5A5);
  @override
  Color get warning => const Color(0xFFF59E0B);
  @override
  Color get warningLight => const Color(0xFFFCD34D);
  @override
  Color get success => const Color(0xFF10B981);
  @override
  Color get successLight => const Color(0xFF6EE7B7);
  @override
  Color get info => const Color(0xFF3B82F6);
  @override
  Color get infoLight => const Color(0xFF93C5FD);

  // ─── 浅色模式背景 ──────────────────────────────────────────
  @override
  Color get background => const Color(0xFFF8FAFC);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFFFFFF);
  @override
  Color get surfaceContainer => const Color(0xFFF1F5F9);
  @override
  Color get surfaceContainerHigh => const Color(0xFFE2E8F0);

  // ─── 浅色模式文字 ──────────────────────────────────────────
  @override
  Color get textPrimary => const Color(0xFF1E293B);
  @override
  Color get textSecondary => const Color(0xFF64748B);
  @override
  Color get textTertiary => const Color(0xFF94A3B8);
  @override
  Color get textOnPrimary => const Color(0xFFFFFFFF);

  // ─── 深色模式背景 ─────────────────────────────────────────
  @override
  Color get backgroundDark => const Color(0xFF0F172A);
  @override
  Color get surfaceDark => const Color(0xFF1E293B);
  @override
  Color get surfaceElevatedDark => const Color(0xFF334155);
  @override
  Color get surfaceContainerDark => const Color(0xFF1E293B);
  @override
  Color get surfaceContainerHighDark => const Color(0xFF334155);

  // ─── 深色模式文字 ──────────────────────────────────────────
  @override
  Color get textPrimaryDark => const Color(0xFFF1F5F9);
  @override
  Color get textSecondaryDark => const Color(0xFF94A3B8);
  @override
  Color get textTertiaryDark => const Color(0xFF64748B);

  // ─── 边框与分割线 ──────────────────────────────────────────
  @override
  Color get border => const Color(0xFFE2E8F0);
  @override
  Color get borderLight => const Color(0xFFF1F5F9);
  @override
  Color get borderDark => const Color(0xFF334155);
  @override
  Color get divider => const Color(0xFFE2E8F0);
  @override
  Color get dividerDark => const Color(0xFF334155);

  // ─── 阴影颜色 ──────────────────────────────────────────────
  @override
  Color get shadowPrimary => const Color(0xFF6366F1).withValues(alpha: 0.25);
  @override
  Color get shadowDark => Colors.black.withValues(alpha: 0.15);
  @override
  Color get shadowDarkNight => Colors.black.withValues(alpha: 0.5);
  @override
  Color get shadowLightNight => const Color(0xFF6366F1).withValues(alpha: 0.2);

  // ─── 渐变色 ────────────────────────────────────────────────
  LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
      );

  LinearGradient get warmGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      );

  LinearGradient get natureGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
      );

  LinearGradient get skyGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      );

  LinearGradient get auroraGradient => const LinearGradient(
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
}
