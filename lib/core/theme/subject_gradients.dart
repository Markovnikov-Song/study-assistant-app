import 'package:flutter/material.dart';

/// 科目卡片渐变色板（全局统一，索引存于 subjects.color_index）
class SubjectGradients {
  SubjectGradients._();

  static const paletteSize = 12;

  static const List<List<Color>> palette = [
    [Color(0xFF6366F1), Color(0xFF818CF8)], // 靛蓝
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)], // 紫
    [Color(0xFF7C3AED), Color(0xFF9D6FF7)], // 深紫
    [Color(0xFF10B981), Color(0xFF34D399)], // 绿
    [Color(0xFF06B6D4), Color(0xFF22D3EE)], // 青
    [Color(0xFF3B82F6), Color(0xFF60A5FA)], // 蓝
    [Color(0xFFF59E0B), Color(0xFFFBBF24)], // 橙
    [Color(0xFFEC4899), Color(0xFFF472B6)], // 粉
    [Color(0xFFEF4444), Color(0xFFF87171)], // 红
    [Color(0xFF84CC16), Color(0xFFA3E635)], // 黄绿
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)], //  Teal
    [Color(0xFFF97316), Color(0xFFFB923C)], // 珊瑚橙
  ];

  /// 与前端 Subject.name.hashCode 一致，用于新建科目时默认配色
  static int indexFromName(String name) {
    if (name.isEmpty) return 0;
    return name.hashCode.abs() % paletteSize;
  }

  static int resolveIndex({int? colorIndex, required String name}) {
    if (colorIndex != null &&
        colorIndex >= 0 &&
        colorIndex < paletteSize) {
      return colorIndex;
    }
    return indexFromName(name);
  }

  static List<Color> colorsFor({int? colorIndex, required String name}) {
    return palette[resolveIndex(colorIndex: colorIndex, name: name)];
  }

  static Color primaryFor({int? colorIndex, required String name}) {
    return colorsFor(colorIndex: colorIndex, name: name).first;
  }
}
