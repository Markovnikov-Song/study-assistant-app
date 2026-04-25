import 'package:flutter/material.dart';
import '../style_base.dart';

/// ============================================================
/// 黏土风色彩系统 (Claymorphism)
/// 柔和、糖果感、微凸的体积感
/// ============================================================

class ClayColors implements ColorPack {
  const ClayColors();

  // ─── 主色调 (马卡龙紫/蓝) ──────────────────────────────────
  @override
  Color get primary => const Color(0xFF8B93FF); // 柔和的黏土紫蓝
  @override
  Color get primaryLight => const Color(0xFFA5AAFF);
  @override
  Color get primaryDark => const Color(0xFF6B74E5);

  // ─── 功能色 (更柔和、糖果感) ───────────────────────────────
  @override
  Color get secondary => const Color(0xFFFF9EAA); // 黏土粉
  @override
  Color get secondaryLight => const Color(0xFFFFB5C0);
  @override
  Color get accent => const Color(0xFFFFD05B); // 黏土黄
  @override
  Color get accentLight => const Color(0xFFFFDF88);

  // ─── 错误/警告/成功 (低饱和度、不刺眼) ─────────────────────
  @override
  Color get error => const Color(0xFFFF7A7A);
  @override
  Color get errorLight => const Color(0xFFFFA3A3);
  @override
  Color get warning => const Color(0xFFFFB84C);
  @override
  Color get warningLight => const Color(0xFFFFD48A);
  @override
  Color get success => const Color(0xFF65C18C);
  @override
  Color get successLight => const Color(0xFF9ED5BA);
  @override
  Color get info => const Color(0xFF74B9FF);
  @override
  Color get infoLight => const Color(0xFFA1CFFF);

  // ─── 浅色模式背景 (偏暖的奶油白) ───────────────────────────
  @override
  Color get background => const Color(0xFFF7F5F0); // 奶油底色
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFFFFFF);
  @override
  Color get surfaceContainer => const Color(0xFFEBE6DF);
  @override
  Color get surfaceContainerHigh => const Color(0xFFDFD8CD);

  // ─── 浅色模式文字 ──────────────────────────────────────────
  @override
  Color get textPrimary => const Color(0xFF4A4A4A); // 不用纯黑，用暖深灰
  @override
  Color get textSecondary => const Color(0xFF858585);
  @override
  Color get textTertiary => const Color(0xFFB0B0B0);
  @override
  Color get textOnPrimary => const Color(0xFFFFFFFF);

  // ─── 深色模式背景 (带点紫调的深灰黏土) ─────────────────────
  @override
  Color get backgroundDark => const Color(0xFF232530);
  @override
  Color get surfaceDark => const Color(0xFF2D2F3D);
  @override
  Color get surfaceElevatedDark => const Color(0xFF383B4D);
  @override
  Color get surfaceContainerDark => const Color(0xFF2D2F3D);
  @override
  Color get surfaceContainerHighDark => const Color(0xFF45485E);

  // ─── 深色模式文字 ──────────────────────────────────────────
  @override
  Color get textPrimaryDark => const Color(0xFFF0F0F0);
  @override
  Color get textSecondaryDark => const Color(0xFFA5A8BA);
  @override
  Color get textTertiaryDark => const Color(0xFF74778C);

  // ─── 边框与分割线 ─────────────────────────────────────────
  @override
  Color get border => const Color(0xFFE8E5E1);
  @override
  Color get borderLight => const Color(0xFFF2F0EC);
  @override
  Color get borderDark => const Color(0xFF45485E);
  @override
  Color get divider => const Color(0xFFE8E5E1);
  @override
  Color get dividerDark => const Color(0xFF45485E);

  // ─── 阴影颜色 (核心：外阴影暗，高光阴影亮) ─────────────────
  @override
  Color get shadowPrimary => const Color(0xFF8B93FF).withValues(alpha: 0.25);
  @override
  Color get shadowDark => const Color(0xFFD1CDC7).withValues(alpha: 0.8); // 右下角柔和暗面
  @override
  Color get shadowDarkNight => Colors.black.withValues(alpha: 0.4);
  @override
  Color get shadowLightNight => const Color(0xFF45485E).withValues(alpha: 0.5); // 左上角高光反光

  // ─── 渐变色 ────────────────────────────────────────────────
  LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA5AAFF), Color(0xFF8B93FF)],
      );

  LinearGradient get warmGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFDF88), Color(0xFFFFD05B)],
      );

  LinearGradient get natureGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9ED5BA), Color(0xFF65C18C)],
      );

  LinearGradient get skyGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8B93FF), Color(0xFFA5AAFF), Color(0xFFC5CAFF)],
      );

  LinearGradient get auroraGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8B93FF),
          Color(0xFFFF9EAA),
          Color(0xFFFFD05B),
        ],
        stops: [0.0, 0.5, 1.0],
      );
}

