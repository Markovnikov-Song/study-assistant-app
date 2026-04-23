import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景风格数据模型
class BackgroundStyle {
  final String id;
  final String name;
  final String description;
  final List<String> svgAssets; // 4个页面的背景

  const BackgroundStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.svgAssets,
  });
}

/// 预设背景风格
class KBackgroundStyles {
  KBackgroundStyles._();

  /// 默认风格 - 深靛蓝/紫渐变配浮光球
  static const defaultStyle = BackgroundStyle(
    id: 'default',
    name: '静谧学习',
    description: '深靛蓝/紫渐变配浮光球，专注学习氛围',
    svgAssets: [
      'assets/images/backgrounds/bg_chat.svg',
      'assets/images/backgrounds/bg_library.svg',
      'assets/images/backgrounds/bg_toolkit.svg',
      'assets/images/backgrounds/bg_profile.svg',
    ],
  );

  /// 极简纯色
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
  );

  /// 午夜深蓝
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
