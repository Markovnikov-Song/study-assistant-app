import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景风格数据模型
class BackgroundStyle {
  final String id;
  final String name;
  final String description;
  final List<String> svgAssets; // 4个页面的背景
  /// 浅色模式底色（透过 SVG 的底层颜色）
  final Color lightBg;
  /// 深色模式底色
  final Color darkBg;
  /// 导航栏/卡片主色调（用于强调色）
  final Color accentColor;
  /// SVG 装饰层透明度 (0.0-1.0)
  final double svgOpacity;

  const BackgroundStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.svgAssets,
    required this.lightBg,
    required this.darkBg,
    required this.accentColor,
    this.svgOpacity = 0.7,
  });

  /// 生成基于 accentColor 的浅色 ColorScheme
  ColorScheme toLightColorScheme() {
    final primary = accentColor;
    final primaryLight = _lighten(primary, 0.15);
    final primaryDark = _darken(primary, 0.1);
    
    return ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryLight.withValues(alpha: 0.15),
      onPrimaryContainer: primaryDark,
      secondary: _complementary(primary),
      onSecondary: Colors.white,
      secondaryContainer: _complementary(primary).withValues(alpha: 0.15),
      onSecondaryContainer: _darken(_complementary(primary), 0.2),
      tertiary: _triadic1(primary),
      onTertiary: Colors.white,
      tertiaryContainer: _triadic1(primary).withValues(alpha: 0.15),
      onTertiaryContainer: _darken(_triadic1(primary), 0.2),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFFDC2626),
      surface: lightBg,
      onSurface: _getTextColor(lightBg),
      surfaceContainerHighest: _darken(lightBg, 0.05),
      onSurfaceVariant: _darken(lightBg, 0.4),
      outline: _darken(lightBg, 0.15),
      outlineVariant: _darken(lightBg, 0.1),
      shadow: Colors.black.withValues(alpha: 0.15),
    );
  }

  /// 生成基于 accentColor 的深色 ColorScheme
  ColorScheme toDarkColorScheme() {
    final primaryLight = _lighten(accentColor, 0.1);
    final primary = primaryLight;
    final primaryDark = accentColor;
    
    return ColorScheme.dark(
      primary: primary,
      onPrimary: darkBg,
      primaryContainer: primaryDark.withValues(alpha: 0.3),
      onPrimaryContainer: primaryLight,
      secondary: _complementary(accentColor),
      onSecondary: darkBg,
      secondaryContainer: _complementary(accentColor).withValues(alpha: 0.3),
      onSecondaryContainer: _lighten(_complementary(accentColor), 0.2),
      tertiary: _triadic1(accentColor),
      onTertiary: darkBg,
      tertiaryContainer: _triadic1(accentColor).withValues(alpha: 0.3),
      onTertiaryContainer: _lighten(_triadic1(accentColor), 0.2),
      error: const Color(0xFFFCA5A5),
      onError: darkBg,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFCA5A5),
      surface: darkBg,
      onSurface: _getTextColor(darkBg),
      surfaceContainerHighest: _lighten(darkBg, 0.1),
      onSurfaceVariant: _lighten(darkBg, 0.4),
      outline: _lighten(darkBg, 0.2),
      outlineVariant: _lighten(darkBg, 0.1),
      shadow: Colors.black,
    );
  }

  /// 获取浅色版本的 primary（深色模式下使用更亮的色调）
  Color get primaryLight => _lighten(accentColor, 0.1);

  // ─── 颜色工具方法 ────────────────────────────────────────

  /// 判断颜色是否为深色（用于决定文字颜色）
  static bool _isDark(Color color) {
    return color.computeLuminance() < 0.5;
  }

  /// 获取适合文字颜色（深色背景用浅色文字，浅色背景用深色文字）
  static Color _getTextColor(Color bgColor) {
    return _isDark(bgColor)
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E293B);
  }

  /// 变亮
  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// 变暗
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// 生成互补色（色相偏移 180°）
  static Color _complementary(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + 180) % 360).toColor();
  }

  /// 生成三角色第一色（色相偏移 120°）
  static Color _triadic1(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + 120) % 360).toColor();
  }
}

/// 预设背景风格
class KBackgroundStyles {
  KBackgroundStyles._();

  /// 默认风格 - 深靛蓝/紫渐变配浮光球
  static const defaultStyle = BackgroundStyle(
    id: 'default',
    name: '静谧学习',
    description: '深靛蓝/紫渐变，专注学习氛围',
    svgAssets: [
      'assets/images/backgrounds/bg_chat.svg',
      'assets/images/backgrounds/bg_library.svg',
      'assets/images/backgrounds/bg_toolkit.svg',
      'assets/images/backgrounds/bg_profile.svg',
    ],
    lightBg: Color(0xFFF8FAFF),   // 淡蓝白
    darkBg: Color(0xFF0F172A),    // 深靛蓝黑
    accentColor: Color(0xFF6366F1),
    svgOpacity: 0.7,
  );

  /// 极简纯色 - 装饰淡化，突出底色
  static const minimal = BackgroundStyle(
    id: 'minimal',
    name: '极简纯色',
    description: '无装饰，纯粹干净',
    svgAssets: [
      'assets/images/backgrounds/bg_minimal.svg',
      'assets/images/backgrounds/bg_minimal.svg',
      'assets/images/backgrounds/bg_minimal.svg',
      'assets/images/backgrounds/bg_minimal.svg',
    ],
    lightBg: Color(0xFFFFFFFF),   // 纯白
    darkBg: Color(0xFF111111),    // 纯黑
    accentColor: Color(0xFF374151),
    svgOpacity: 0.25,  // 极淡装饰
  );

  /// 活力橙黄
  static const vibrant = BackgroundStyle(
    id: 'vibrant',
    name: '活力橙黄',
    description: '温暖阳光色调，充满能量',
    svgAssets: [
      'assets/images/backgrounds/bg_vibrant_chat.svg',
      'assets/images/backgrounds/bg_vibrant_library.svg',
      'assets/images/backgrounds/bg_vibrant_toolkit.svg',
      'assets/images/backgrounds/bg_vibrant_profile.svg',
    ],
    lightBg: Color(0xFFFFFBF0),   // 暖奶白
    darkBg: Color(0xFF1C1208),    // 深棕黑
    accentColor: Color(0xFFF59E0B),
    svgOpacity: 0.6,
  );

  /// 清新绿意
  static const nature = BackgroundStyle(
    id: 'nature',
    name: '清新绿意',
    description: '自然绿色调，舒适放松',
    svgAssets: [
      'assets/images/backgrounds/bg_nature_chat.svg',
      'assets/images/backgrounds/bg_nature_library.svg',
      'assets/images/backgrounds/bg_nature_toolkit.svg',
      'assets/images/backgrounds/bg_nature_profile.svg',
    ],
    lightBg: Color(0xFFF0FDF4),   // 嫩绿白
    darkBg: Color(0xFF052E16),    // 深森林绿
    accentColor: Color(0xFF10B981),
    svgOpacity: 0.5,
  );

  /// 午夜深蓝 - 深色需要更多细节
  static const midnight = BackgroundStyle(
    id: 'midnight',
    name: '午夜深蓝',
    description: '深邃神秘，夜间模式最佳',
    svgAssets: [
      'assets/images/backgrounds/bg_midnight_chat.svg',
      'assets/images/backgrounds/bg_midnight_library.svg',
      'assets/images/backgrounds/bg_midnight_toolkit.svg',
      'assets/images/backgrounds/bg_midnight_profile.svg',
    ],
    lightBg: Color(0xFFF0F4FF),   // 淡星空蓝
    darkBg: Color(0xFF0A0E1A),    // 极深夜蓝
    accentColor: Color(0xFF3B82F6),
    svgOpacity: 0.75,
  );

  static const List<BackgroundStyle> all = [
    defaultStyle,
    minimal,
    vibrant,
    nature,
    midnight,
  ];

  static BackgroundStyle getById(String id) {
    return all.firstWhere(
      (s) => s.id == id,
      orElse: () => defaultStyle,
    );
  }
}

/// 背景风格 Provider
final backgroundStyleProvider =
    StateNotifierProvider<BackgroundStyleNotifier, BackgroundStyle>((ref) {
  return BackgroundStyleNotifier();
});

/// 加载状态 Provider（用于等待异步初始化完成）
final backgroundStyleLoadedProvider = StateProvider<bool>((ref) => false);

class BackgroundStyleNotifier extends StateNotifier<BackgroundStyle> {
  BackgroundStyleNotifier() : super(KBackgroundStyles.defaultStyle) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('background_style_id');
      if (savedId != null) {
        state = KBackgroundStyles.getById(savedId);
      }
    } catch (e) {
      debugPrint('加载背景风格失败: $e');
    }
  }

  Future<void> setStyle(BackgroundStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_style_id', style.id);
    } catch (e) {
      debugPrint('保存背景风格失败: $e');
    }
  }

  Future<void> reset() async {
    state = KBackgroundStyles.defaultStyle;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_style_id');
    } catch (e) {
      debugPrint('重置背景风格失败: $e');
    }
  }
}

/// 当前页面的背景 SVG 路径
final currentPageBackgroundProvider =
    Provider.family<String, int>((ref, pageIndex) {
  final style = ref.watch(backgroundStyleProvider);
  if (pageIndex >= 0 && pageIndex < style.svgAssets.length) {
    return style.svgAssets[pageIndex];
  }
  return KBackgroundStyles.defaultStyle.svgAssets[pageIndex];
});

/// ─── 动态主题系统 ─────────────────────────────────────────────
///
/// 基于 BackgroundStyle.accentColor 动态生成 ColorScheme
/// 组件可通过 ref.watch(accentColorSchemeProvider(context)) 获取
/// 风格切换时自动更新

/// 获取当前 accentColor 对应的 ColorScheme（自动适配明暗模式）
final accentColorSchemeProvider = Provider.family<ColorScheme, BuildContext>((ref, context) {
  final style = ref.watch(backgroundStyleProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? style.toDarkColorScheme() : style.toLightColorScheme();
});

/// 便捷获取当前 accentColor
final accentColorProvider = Provider<Color>((ref) {
  final style = ref.watch(backgroundStyleProvider);
  return style.accentColor;
});

/// 便捷获取浅色版本的 primary
final primaryColorProvider = Provider<Color>((ref) {
  final style = ref.watch(backgroundStyleProvider);
  return style.primaryLight;
});
