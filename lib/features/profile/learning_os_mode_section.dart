// Learning OS — AI 学习功能入口区块
// 叠加在"我的"页面，不替换底部导航（需求 4.1）。
//
// 设计原则：用户不需要"选择模式"，只需要选择"想做什么"。
// 四种调用路径对用户透明，UI 只暴露意图入口。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI 学习功能入口区块，展示在"我的"页面。
///
/// 提供两个入口：
/// 1. "让 AI 帮我选学习方法" → Skill 驱动路径（输入意图，AI 匹配 Skill）
/// 2. "制定长期学习计划"     → Multi-Agent 路径（设定目标，AI 全程规划）
class LearningOsModeSection extends ConsumerWidget {
  const LearningOsModeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'AI 学习助手',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 入口 1：Skill 驱动（输入意图）
        _IntentInputCard(),

        const SizedBox(height: 8),

        // 入口 2：Multi-Agent（长期计划）
        _LongTermPlanCard(),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── 意图输入卡片（Skill 驱动路径）────────────────────────────────────────────

class _IntentInputCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_IntentInputCard> createState() => _IntentInputCardState();
}

class _IntentInputCardState extends ConsumerState<_IntentInputCard> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() => _loading = true);
    _controller.clear();

    try {
      // TODO: 调用 AgentCouncilImpl.resolveIntent()，展示推荐 Skill 列表
      // 当前先用 SnackBar 占位，Phase 3 UI 完成后替换
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在为「$text」匹配学习方法…'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: '查看', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '让 AI 帮我选学习方法',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '例如：帮我复习今天的物理错题、备考高数…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          onPressed: _submit,
                          icon: const Icon(Icons.send, size: 18),
                          tooltip: '匹配学习方法',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 长期计划卡片（Multi-Agent 路径）──────────────────────────────────────────

class _LongTermPlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          // TODO: 跳转到议事会/长期计划页面（Phase 3 UI）
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('长期学习计划功能开发中，敬请期待'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: cs.onSecondaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '制定长期学习计划',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '设定目标，AI 自动规划各科时间表',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
