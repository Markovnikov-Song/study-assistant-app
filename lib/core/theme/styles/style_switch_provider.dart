import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'style_base.dart';
import 'theme_manager.dart';

/// ============================================================
/// UI 风格切换 Provider
/// ============================================================

/// 当前 UI 风格 ID
final uiStyleIdProvider = StateNotifierProvider<UIStyleNotifier, String>((ref) {
  return UIStyleNotifier();
});

/// 加载状态
final uiStyleLoadedProvider = StateProvider<bool>((ref) => false);

/// 当前风格的元数据
final uiStyleMetaProvider = Provider<StyleMeta>((ref) {
  final styleId = ref.watch(uiStyleIdProvider);
  return ThemeManager.getMeta(styleId) ?? const StyleMeta(
    id: StyleIds.defaultStyle,
    name: '静谧学习',
    description: '默认风格',
  );
});

/// 当前风格的浅色主题
final uiLightThemeProvider = Provider<ThemeData>((ref) {
  final styleId = ref.watch(uiStyleIdProvider);
  return ThemeManager.getLightTheme(styleId);
});

/// 当前风格的深色主题
final uiDarkThemeProvider = Provider<ThemeData>((ref) {
  final styleId = ref.watch(uiStyleIdProvider);
  return ThemeManager.getDarkTheme(styleId);
});

/// 根据系统亮度获取当前主题
final uiCurrentThemeProvider = Provider.family<ThemeData, Brightness>((ref, brightness) {
  return brightness == Brightness.dark
      ? ref.watch(uiDarkThemeProvider)
      : ref.watch(uiLightThemeProvider);
});

/// 风格切换状态管理
class UIStyleNotifier extends StateNotifier<String> {
  UIStyleNotifier() : super(StyleIds.defaultStyle) {
    _loadSaved();
  }

  /// 存储键
  static const _storageKey = 'ui_style_id';

  /// 加载保存的风格
  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_storageKey);
      if (savedId != null && ThemeManager.hasStyle(savedId)) {
        state = savedId;
      }
    } catch (e) {
      debugPrint('加载 UI 风格失败: $e');
    }
  }

  /// 切换风格
  Future<void> setStyle(String styleId) async {
    if (!ThemeManager.hasStyle(styleId)) {
      debugPrint('未知的 UI 风格: $styleId');
      return;
    }

    state = styleId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, styleId);
    } catch (e) {
      debugPrint('保存 UI 风格失败: $e');
    }
  }

  /// 重置为默认风格
  Future<void> reset() async {
    state = StyleIds.defaultStyle;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('重置 UI 风格失败: $e');
    }
  }
}

/// ============================================================
/// 扩展：便捷风格切换 Widget
/// ============================================================

/// 风格预览数据（用于选择器）
class StylePreview {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color backgroundColor;

  const StylePreview({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.backgroundColor,
  });

  factory StylePreview.fromStyle(StylePack pack) {
    // 这里简化处理，实际可以根据 pack 类型获取颜色
    return StylePreview(
      id: pack.id,
      name: pack.meta.name,
      description: pack.meta.description,
      primaryColor: _getPrimaryColor(pack.id),
      backgroundColor: _getBackgroundColor(pack.id),
    );
  }

  static Color _getPrimaryColor(String styleId) {
    switch (styleId) {
      case StyleIds.clay:
        return const Color(0xFF8B93FF);
      case StyleIds.minimal:
        return const Color(0xFF000000);
      default:
        return const Color(0xFF6366F1);
    }
  }

  static Color _getBackgroundColor(String styleId) {
    switch (styleId) {
      case StyleIds.clay:
        return const Color(0xFFF7F5F0);
      case StyleIds.minimal:
        return const Color(0xFFFFFFFF);
      default:
        return const Color(0xFFF8FAFC);
    }
  }
}

/// 所有风格的预览列表
final stylePreviewsProvider = Provider<List<StylePreview>>((ref) {
  return ThemeManager.allStyles.map((s) => StylePreview.fromStyle(s)).toList();
});

/// 当前选中的风格预览
final currentStylePreviewProvider = Provider<StylePreview>((ref) {
  final styleId = ref.watch(uiStyleIdProvider);
  final previews = ref.watch(stylePreviewsProvider);
  return previews.firstWhere(
    (p) => p.id == styleId,
    orElse: () => previews.first,
  );
});
