import 'package:flutter/material.dart';

/// 解题结果操作栏。
///
/// 提供“收藏到笔记本”和“加入错题本”两个独立操作。
class SolveResultActionBar extends StatelessWidget {
  final bool isSavedToNotebook;
  final bool isSavedToMistakes;
  final VoidCallback onSaveToNotebook;
  final VoidCallback onSaveToMistakes;

  const SolveResultActionBar({
    super.key,
    required this.isSavedToNotebook,
    required this.isSavedToMistakes,
    required this.onSaveToNotebook,
    required this.onSaveToMistakes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: '收藏到笔记本',
          semanticsLabel: 'solve-save-to-notebook',
          icon: Icons.bookmark_outline_rounded,
          selectedIcon: Icons.bookmark_rounded,
          isSaved: isSavedToNotebook,
          onPressed: isSavedToNotebook ? null : onSaveToNotebook,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: '加入错题本',
          semanticsLabel: 'solve-save-to-mistakes',
          icon: Icons.error_outline_rounded,
          selectedIcon: Icons.error_rounded,
          isSaved: isSavedToMistakes,
          onPressed: isSavedToMistakes ? null : onSaveToMistakes,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSaved;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.semanticsLabel,
    required this.icon,
    required this.selectedIcon,
    required this.isSaved,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = isSaved
        ? FilledButton.tonalIcon(
            onPressed: null,
            icon: Icon(selectedIcon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 13)),
            style: _buttonStyle(),
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 13)),
            style: _buttonStyle(),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        label: isSaved ? '$semanticsLabel-saved' : semanticsLabel,
        button: true,
        enabled: onPressed != null,
        child: child,
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
