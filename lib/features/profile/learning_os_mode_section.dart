import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../skill_runner/my_skills_page.dart';
import '../skill_runner/skill_runner_page.dart';
import '../../core/network/dio_client.dart';

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
      // 调用 /api/agent/resolve-intent，获取推荐 Skill 列表
      final res = await DioClient.instance.dio.post(
        '/api/agent/resolve-intent',
        data: {'text': text},
      );
      final data = res.data as Map<String, dynamic>;
      final recommendations = (data['recommended_skills'] as List?) ?? [];

      if (!mounted) return;

      if (recommendations.isEmpty) {
        // 没有匹配的 Skill，跳转到方法库让用户自己选
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('没有找到完全匹配的方法，请从方法库中选择'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MySkillsPage()),
        );
        return;
      }

      if (recommendations.length == 1) {
        // 只有一个推荐，直接进入
        final skill = recommendations.first as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillRunnerPage(
              skillId: skill['skill_id'] as String,
              skillName: skill['name'] as String? ?? skill['skill_id'] as String,
            ),
          ),
        );
        return;
      }

      // 多个推荐，弹出选择对话框
      _showSkillPicker(context, recommendations.cast<Map<String, dynamic>>(), text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('匹配失败：$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSkillPicker(
    BuildContext context,
    List<Map<String, dynamic>> recommendations,
    String goal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('为你推荐的学习方法',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 4),
                  Text('目标：$goal',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...recommendations.map((rec) {
              final skillId = rec['skill_id'] as String;
              final name = rec['name'] as String? ?? skillId;
              final rationale = rec['rationale'] as String? ?? '';
              final score = ((rec['match_score'] as num?)?.toDouble() ?? 0.0);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '${(score * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(rationale,
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SkillRunnerPage(
                        skillId: skillId,
                        skillName: name,
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MySkillsPage()),
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
