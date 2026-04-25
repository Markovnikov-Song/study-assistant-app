import 'package:flutter/material.dart';
import 'style_base.dart';
import 'style_default/export.dart';
import 'style_clay/export.dart';
import 'style_minimal/export.dart';

/// ============================================================
/// 主题风格管理器
/// 统一管理所有 UI 风格，提供风格切换能力
/// ============================================================

class ThemeManager {
  ThemeManager._();

  /// 所有已注册的风格包
  static final Map<String, StylePack> _stylePacks = {
    StyleIds.defaultStyle: DefaultStylePack(),
    StyleIds.clay: ClayStylePack(),
    StyleIds.minimal: MinimalStylePack(),
  };

  /// 获取所有风格列表
  static List<StylePack> get allStyles => _stylePacks.values.toList();

  /// 获取风格元数据列表
  static List<StyleMeta> get allMetas => allStyles.map((s) => s.meta).toList();

  /// 根据 ID 获取风格包
  static StylePack? getStylePack(String id) => _stylePacks[id];

  /// 根据 ID 获取元数据
  static StyleMeta? getMeta(String id) => _stylePacks[id]?.meta;

  /// 注册新风格（扩展用）
  static void registerStyle(StylePack pack) {
    _stylePacks[pack.id] = pack;
  }

  /// 获取浅色主题
  static ThemeData getLightTheme(String id) {
    return _stylePacks[id]?.lightTheme ?? DefaultStylePack().lightTheme;
  }

  /// 获取深色主题
  static ThemeData getDarkTheme(String id) {
    return _stylePacks[id]?.darkTheme ?? DefaultStylePack().darkTheme;
  }

  /// 获取当前主题
  static ThemeData getTheme(String id, Brightness brightness) {
    return brightness == Brightness.dark ? getDarkTheme(id) : getLightTheme(id);
  }

  /// 检查风格是否存在
  static bool hasStyle(String id) => _stylePacks.containsKey(id);
}

/// ============================================================
/// 全局样式 ID 常量（便于使用）
/// ============================================================
class UIStyleIds {
  UIStyleIds._();

  /// 默认风格
  static const String defaultStyle = StyleIds.defaultStyle;

  /// 黏土风
  static const String clay = StyleIds.clay;

  /// 极简风格
  static const String minimal = StyleIds.minimal;

  /// 默认风格列表
  static const List<String> all = [
    StyleIds.defaultStyle,
    StyleIds.clay,
    StyleIds.minimal,
  ];

  /// 获取风格名称
  static String getName(String id) {
    return ThemeManager.getMeta(id)?.name ?? '未知';
  }

  /// 获取风格描述
  static String getDescription(String id) {
    return ThemeManager.getMeta(id)?.description ?? '';
  }
}

/// ============================================================
/// 便捷颜色访问器（可在组件中使用）
/// ============================================================
class StyleColors {
  const StyleColors._();

  static ColorPack getColors(String styleId) {
    switch (styleId) {
      case StyleIds.clay:
        return const ClayColors();
      case StyleIds.minimal:
        return const MinimalColors();
      case StyleIds.defaultStyle:
      default:
        return const DefaultColors();
    }
  }

  /// 当前主题颜色（通过 InheritedWidget 或 Provider 获取）
  static Color primary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// ============================================================
/// 便捷间距访问器
/// ============================================================
class StyleSpacing {
  const StyleSpacing._();

  static SpacingPack getSpacing(String styleId) {
    switch (styleId) {
      case StyleIds.clay:
        return const ClaySpacing();
      case StyleIds.minimal:
        return const MinimalSpacing();
      case StyleIds.defaultStyle:
      default:
        return const DefaultSpacing();
    }
  }

  /// 静态访问（假设使用默认风格，需要动态时请用上面的方法）
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
}

/// ============================================================
/// 便捷阴影访问器
/// ============================================================
class StyleShadows {
  const StyleShadows._();

  /// 获取指定风格的阴影
  static List<BoxShadow> getShadows(String styleId, String shadowType, {bool isDark = false}) {
    switch (styleId) {
      case StyleIds.clay:
        final spacing = const ClaySpacing();
        switch (shadowType) {
          case 'clay':
            return isDark ? spacing.clayShadowDark : spacing.clayShadow;
          case 'pressed':
            return spacing.clayShadowPressed;
          case 'lg':
            return spacing.shadowLg;
          case 'md':
            return spacing.shadowMd;
          default:
            return spacing.shadowSm;
        }
      case StyleIds.minimal:
        final spacing = const MinimalSpacing();
        switch (shadowType) {
          case 'lg':
            return spacing.shadowLg;
          case 'md':
            return spacing.shadowMd;
          default:
            return spacing.shadowSm;
        }
      case StyleIds.defaultStyle:
      default:
        final spacing = const DefaultSpacing();
        switch (shadowType) {
          case 'lg':
            return spacing.shadowLg;
          case 'xl':
            return spacing.shadowXl;
          case 'primary':
            return spacing.shadowPrimary;
          default:
            return spacing.shadowMd;
        }
    }
  }
}
