import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// CoT（Chain of Thought）思维链折叠组件。
///
/// - [thinkingContent] 为空时返回 [SizedBox.shrink()]，不渲染任何内容
/// - 折叠时显示"查看推理过程 ▶"
/// - 展开时显示"收起推理过程 ▼"，并用 flutter_markdown 渲染思维链内容
///
/// 注意：此处故意使用 [MarkdownBody] 而非 [MarkdownLatexView]，
/// 避免与 markdown_latex_view.dart 产生循环依赖。
class CoTCollapsibleView extends StatelessWidget {
  /// 思维链文本内容（`<think>...</think>` 内的文字）
  final String thinkingContent;

  /// 当前是否展开
  final bool isExpanded;

  /// 展开/折叠切换回调
  final VoidCallback onToggle;

  const CoTCollapsibleView({
    super.key,
    required this.thinkingContent,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // 内容为空时不渲染
    if (thinkingContent.trim().isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 折叠/展开切换按钮
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? '收起推理过程 ▼' : '查看推理过程 ▶',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 展开时渲染思维链内容
        if (isExpanded) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: MarkdownBody(
              data: thinkingContent,
              selectable: false,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
                code: textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.onSurface,
                ),
                codeblockDecoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
