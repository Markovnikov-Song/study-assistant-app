import 'package:flutter/material.dart';

/// 解题结果操作栏组件。
///
/// 提供"收藏到笔记本"和"加入错题本"两个操作按钮。
/// [isSaved] 为 true 时按钮变为已选中（filled）样式，防止重复入库。
class SolveResultActionBar extends StatelessWidget {
  /// 是否已入库（true 时按钮变为已选中样式）
  final bool isSaved;

  /// 收藏到笔记本回调
  final VoidCallback onSaveToNotebook;

  /// 加入错题本回调
  final VoidCallback onSaveToMistakes;

  const SolveResultActionBar({
    super.key,
    required this.isSaved,
    required this.onSaveToNotebook,
    required this.onSaveToMistakes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: '收藏到笔记本',
          icon: Icons.bookmark_outline_rounded,
          selectedIcon: Icons.bookmark_rounded,
          isSaved: isSaved,
          onPressed: isSaved ? null : onSaveToNotebook,
          cs: cs,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: '加入错题本',
          icon: Icons.error_outline_rounded,
          selectedIcon: Icons.error_rounded,
          isSaved: isSaved,
          onPressed: isSaved ? null : onSaveToMistakes,
          cs: cs,
        ),
      ],
    );
  }
}

/// 单个操作按钮，根据 [isSaved] 切换普通 / 已选中样式。
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSaved;
  final VoidCallback? onPressed;
  final ColorScheme cs;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSaved,
    required this.onPressed,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    if (isSaved) {
      // 已选中：FilledButton.tonal 样式
      return FilledButton.tonalIcon(
        onPressed: null, // 禁用，防止重复入库
        icon: Icon(selectedIcon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // 未选中：普通 TextButton 样式
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
