import 'package:flutter/material.dart';
import '../models/chat_message.dart';

/// 场景识别卡片组件
/// 在对话流中插入，引导用户跳转到对应功能
class SceneCard extends StatelessWidget {
  final SceneCardData data;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const SceneCard({
    super.key,
    required this.data,
    required this.onConfirm,
    required this.onDismiss,
  });

  // 根据场景类型返回左侧竖条颜色
  Color _accentColor(BuildContext context) {
    switch (data.sceneType) {
      case SceneType.subject:  return const Color(0xFF1E88E5); // 蓝色
      case SceneType.planning: return const Color(0xFF43A047); // 绿色
      case SceneType.tool:     return const Color(0xFFFB8C00); // 橙色
      case SceneType.spec:     return const Color(0xFF8E24AA); // 紫色
    }
  }

  // 根据场景类型返回图标
  IconData _icon() {
    switch (data.sceneType) {
      case SceneType.subject:  return Icons.school_outlined;
      case SceneType.planning: return Icons.assignment_outlined;
      case SceneType.tool:     return Icons.build_outlined;
      case SceneType.spec:     return Icons.account_tree_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.dismissed) return const SizedBox.shrink();

    final accent = _accentColor(context);
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧彩色竖条
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // 内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_icon(), size: 16, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle!,
                          style: TextStyle(fontSize: 12, color: cs.outline),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(data.confirmLabel, style: const TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(data.dismissLabel, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
