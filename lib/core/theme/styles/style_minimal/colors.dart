import 'package:flutter/material.dart';
import '../style_base.dart';

/// ============================================================
/// 极简风格色彩系统
/// 干净、利落、无装饰
/// ============================================================

class MinimalColors implements ColorPack {
  const MinimalColors();

  // ─── 主色调 (纯黑/白为主) ─────────────────────────────────
  @override
  Color get primary => const Color(0xFF000000);
  @override
  Color get primaryLight => const Color(0xFF333333);
  @override
  Color get primaryDark => const Color(0xFF000000);

  // ─── 功能色 (极淡) ─────────────────────────────────────────
  @override
  Color get secondary => const Color(0xFF666666);
  @override
  Color get secondaryLight => const Color(0xFF999999);
  @override
  Color get accent => const Color(0xFF333333);
  @override
  Color get accentLight => const Color(0xFF666666);

  // ─── 错误/警告/成功 ─────────────────────────────────────────
  @override
  Color get error => const Color(0xFFDC2626);
  @override
  Color get errorLight => const Color(0xFFFCA5A5);
  @override
  Color get warning => const Color(0xFFCA8A04);
  @override
  Color get warningLight => const Color(0xFFFDE047);
  @override
  Color get success => const Color(0xFF16A34A);
  @override
  Color get successLight => const Color(0xFF86EFAC);
  @override
  Color get info => const Color(0xFF2563EB);
  @override
  Color get infoLight => const Color(0xFF93C5FD);

  // ─── 浅色模式背景 (纯白) ──────────────────────────────────
  @override
  Color get background => const Color(0xFFFFFFFF);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFAFAFA);
  @override
  Color get surfaceContainer => const Color(0xFFF5F5F5);
  @override
  Color get surfaceContainerHigh => const Color(0xFFF0F0F0);

  // ─── 浅色模式文字 (纯黑) ──────────────────────────────────
  @override
  Color get textPrimary => const Color(0xFF000000);
  @override
  Color get textSecondary => const Color(0xFF666666);
  @override
  Color get textTertiary => const Color(0xFF999999);
  @override
  Color get textOnPrimary => const Color(0xFFFFFFFF);

  // ─── 深色模式背景 (纯黑) ──────────────────────────────────
  @override
  Color get backgroundDark => const Color(0xFF000000);
  @override
  Color get surfaceDark => const Color(0xFF0A0A0A);
  @override
  Color get surfaceElevatedDark => const Color(0xFF171717);
  @override
  Color get surfaceContainerDark => const Color(0xFF0A0A0A);
  @override
  Color get surfaceContainerHighDark => const Color(0xFF262626);

  // ─── 深色模式文字 ──────────────────────────────────────────
  @override
  Color get textPrimaryDark => const Color(0xFFFFFFFF);
  @override
  Color get textSecondaryDark => const Color(0xFFA3A3A3);
  @override
  Color get textTertiaryDark => const Color(0xFF737373);

  // ─── 边框与分割线 (极细) ──────────────────────────────────
  @override
  Color get border => const Color(0xFFE5E5E5);
  @override
  Color get borderLight => const Color(0xFFF5F5F5);
  @override
  Color get borderDark => const Color(0xFF262626);
  @override
  Color get divider => const Color(0xFFE5E5E5);
  @override
  Color get dividerDark => const Color(0xFF262626);

  // ─── 阴影颜色 (无阴影或极淡) ───────────────────────────────
  @override
  Color get shadowPrimary => const Color(0xFF000000).withValues(alpha: 0.05);
  @override
  Color get shadowDark => const Color(0xFF000000).withValues(alpha: 0.08);
  @override
  Color get shadowDarkNight => const Color(0xFF000000).withValues(alpha: 0.5);
  @override
  Color get shadowLightNight => const Color(0xFF333333).withValues(alpha: 0.3);

  // ─── 渐变色 (无渐变或极淡) ─────────────────────────────────
  LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF333333)],
      );

  LinearGradient get warmGradient => const LinearGradient(
        colors: [Color(0xFF333333), Color(0xFF666666)],
      );

  LinearGradient get natureGradient => const LinearGradient(
        colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
      );

  LinearGradient get skyGradient => const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
      );

  LinearGradient get auroraGradient => const LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF666666)],
      );
}
