import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'toolkit_page.dart';

/// 工具箱排序设置页面
class ToolkitSettingsPage extends ConsumerWidget {
  const ToolkitSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // 监听状态变化，并获取排序后的工具列表
    final order = ref.watch(toolOrderProvider);
    final toolMap = {for (var tool in kDefaultTools) tool.id: tool};
    final orderedTools = order
        .map((id) => toolMap[id])
        .whereType<ToolItem>()
        .toList();
    // 添加默认列表中新增的工具（向后兼容）
    for (final tool in kDefaultTools) {
      if (!order.contains(tool.id)) {
        orderedTools.add(tool);
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '工具排序',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        actions: [
          // 恢复默认按钮
          TextButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(toolOrderProvider.notifier).resetToDefault();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已恢复默认顺序'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: cs.inverseSurface,
                  ),
                );
              }
            },
            child: Text(
              '恢复默认',
              style: TextStyle(
                color: cs.primary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 提示信息
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '长按并拖动工具卡片来调整顺序',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 可拖拽的工具列表
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: orderedTools.length,
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.mediumImpact();
                // Flutter 2.0+: newIndex 已经是移除后的正确位置，直接传递
                ref.read(toolOrderProvider.notifier).reorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final tool = orderedTools[index];
                return _ReorderableToolCard(
                  key: ValueKey(tool.id),
                  tool: tool,
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 可拖拽的工具卡片
class _ReorderableToolCard extends ConsumerWidget {
  final ToolItem tool;
  final int index;

  const _ReorderableToolCard({
    required super.key,
    required this.tool,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 获取用户自定义图标
    final currentIcon = ref.watch(toolIconsProvider.notifier).getIcon(
      tool.id,
      tool.icon,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // 工具图标
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tool.gradientColors,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tool.gradientColors.first.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            currentIcon,
            size: 24,
            color: Colors.white,
          ),
        ),
        // 工具信息
        title: Text(
          tool.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text(
          tool.description,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        // 拖拽手柄
        trailing: ReorderableDragStartListener(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 1.0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.drag_handle,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
