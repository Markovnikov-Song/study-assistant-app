import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../providers/current_subject_provider.dart';
import '../../widgets/markdown_latex_view.dart';

// ── Provider：获取 Skill 完整定义 ─────────────────────────────────────────────

final _skillDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, skillId) async {
  final res = await DioClient.instance.dio.get('/api/agent/skills/$skillId');
  return res.data as Map<String, dynamic>;
});

// ── SkillRunnerPage ───────────────────────────────────────────────────────────

/// 按步骤引导用户执行一个 Skill 的页面。
///
/// 流程：
/// 1. 显示 Skill 简介 + 第一步的 prompt（需要用户输入主题/内容）
/// 2. 用户输入后，调用 /api/agent/execute-node 执行第一步
/// 3. 展示 AI 输出，用户确认后执行下一步
/// 4. 所有步骤完成后显示总结
class SkillRunnerPage extends ConsumerStatefulWidget {
  final String skillId;
  final String skillName;

  const SkillRunnerPage({
    super.key,
    required this.skillId,
    required this.skillName,
  });

  @override
  ConsumerState<SkillRunnerPage> createState() => _SkillRunnerPageState();
}

class _SkillRunnerPageState extends ConsumerState<SkillRunnerPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // 当前执行到第几步（0-based）
  int _currentStep = 0;
  // 每步的输出结果 nodeId → content
  final Map<String, String> _outputs = {};
  // 是否正在执行
  bool _running = false;
  // 是否全部完成
  bool _done = false;
  // 错误信息
  String? _error;
  // 用户输入的主题（第一步使用）
  String? _topic;
  // 是否已输入主题，进入执行阶段
  bool _topicEntered = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _executeStep(
      List<Map<String, dynamic>> nodes, int stepIndex) async {
    if (stepIndex >= nodes.length) {
      if (!mounted) return;
      setState(() => _done = true);
      return;
    }

    final node = nodes[stepIndex];
    final nodeId = node['id'] as String;
    final prompt = node['prompt'] as String;
    final inputMapping =
        (node['inputMapping'] as Map?)?.cast<String, String>() ?? {};

    // 构建 input：把 inputMapping 映射到之前步骤的输出
    final input = <String, dynamic>{};
    if (_topic != null) input['topic'] = _topic;
    if (_topic != null) input['content'] = _topic;
    if (_topic != null) input['problem'] = _topic;
    if (_topic != null) input['subject'] = _topic;

    for (final entry in inputMapping.entries) {
      final parts = entry.value.split('.');
      if (parts.length == 2) {
        final prevNodeId = parts[0];
        if (_outputs.containsKey(prevNodeId)) {
          input[entry.key] = _outputs[prevNodeId];
        }
      } else if (_outputs.containsKey(entry.value)) {
        input[entry.key] = _outputs[entry.value];
      }
    }

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final subjectId = ref.read(currentSubjectProvider)?.id;
      final res = await DioClient.instance.dio.post(
        '/api/agent/execute-node',
        data: {
          'skill_id': widget.skillId,
          'node_id': nodeId,
          'prompt': prompt,
          'input': input,
          if (subjectId != null) 'subject_id': subjectId,
        },
      );
      final content = (res.data as Map<String, dynamic>)['content'] as String? ?? '';
      if (!mounted) return;
      setState(() {
        _outputs[nodeId] = content.trim().isEmpty ? '（该步骤暂无内容，可能正在开发中）' : content;
        _currentStep = stepIndex + 1;
        _running = false;
        if (_currentStep >= nodes.length) _done = true;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = '执行失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillAsync = ref.watch(_skillDetailProvider(widget.skillId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.skillName),
        centerTitle: false,
      ),
      body: skillAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (skill) {
          final nodes = ((skill['promptChain'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
          final description = skill['description'] as String? ?? '';

          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Skill 简介卡片
                    _SkillIntroCard(
                      name: widget.skillName,
                      description: description,
                      totalSteps: nodes.length,
                    ),
                    const SizedBox(height: 16),

                    // 主题输入（未输入时显示）
                    if (!_topicEntered) ...[
                      _TopicInputCard(
                        controller: _inputCtrl,
                        onConfirm: () {
                          final t = _inputCtrl.text.trim();
                          if (t.isEmpty) return;
                          setState(() {
                            _topic = t;
                            _topicEntered = true;
                          });
                          _inputCtrl.clear();
                          _executeStep(nodes, 0);
                        },
                      ),
                    ],

                    // 已完成的步骤
                    for (int i = 0; i < _currentStep && i < nodes.length; i++)
                      _StepResultCard(
                        stepIndex: i,
                        totalSteps: nodes.length,
                        nodeId: nodes[i]['id'] as String,
                        prompt: nodes[i]['prompt'] as String,
                        output: _outputs[nodes[i]['id'] as String] ?? '',
                        topic: _topic,
                      ),

                    // 当前步骤执行中
                    if (_running)
                      _RunningCard(
                        stepIndex: _currentStep,
                        totalSteps: nodes.length,
                      ),

                    // 错误提示
                    if (_error != null)
                      _ErrorCard(
                        error: _error!,
                        onRetry: () => _executeStep(nodes, _currentStep),
                      ),

                    // 完成总结
                    if (_done) _DoneCard(skillName: widget.skillName),

                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // 底部操作栏
              if (_topicEntered && !_done && !_running && _error == null &&
                  _currentStep < nodes.length)
                _BottomBar(
                  stepIndex: _currentStep,
                  totalSteps: nodes.length,
                  onNext: () => _executeStep(nodes, _currentStep),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 子组件 ────────────────────────────────────────────────────────────────────

class _SkillIntroCard extends StatelessWidget {
  final String name;
  final String description;
  final int totalSteps;

  const _SkillIntroCard({
    required this.name,
    required this.description,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalSteps 个步骤',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;

  const _TopicInputCard({
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '你想学习什么？',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '输入知识点、题目或学习内容，AI 将按步骤引导你学习',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: '例如：牛顿第二定律、积分的概念…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onConfirm(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onConfirm,
                child: const Text('开始'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepResultCard extends StatefulWidget {
  final int stepIndex;
  final int totalSteps;
  final String nodeId;
  final String prompt;
  final String output;
  final String? topic;

  const _StepResultCard({
    required this.stepIndex,
    required this.totalSteps,
    required this.nodeId,
    required this.prompt,
    required this.output,
    required this.topic,
  });

  @override
  State<_StepResultCard> createState() => _StepResultCardState();
}

class _StepResultCardState extends State<_StepResultCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 渲染 prompt 里的 {topic} 占位符
    final displayPrompt = widget.prompt
        .replaceAll('{topic}', widget.topic ?? '')
        .replaceAll('{content}', widget.topic ?? '')
        .replaceAll('{problem}', widget.topic ?? '')
        .replaceAll('{subject}', widget.topic ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标题行
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.stepIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '第 ${widget.stepIndex + 1} 步 / 共 ${widget.totalSteps} 步',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            // Prompt 提示（折叠显示，避免长文本撑爆布局）
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                displayPrompt,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // AI 输出
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: widget.output.trim().isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.construction_outlined,
                            size: 16, color: cs.outline),
                        const SizedBox(width: 6),
                        Text('该步骤暂无输出',
                            style: TextStyle(
                                fontSize: 13, color: cs.outline)),
                      ],
                    )
                  : MarkdownLatexView(data: widget.output),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunningCard extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;

  const _RunningCard({required this.stepIndex, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Text(
            '正在执行第 ${stepIndex + 1} 步 / 共 $totalSteps 步…',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  final String skillName;

  const _DoneCard({required this.skillName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 10),
          Text(
            '「$skillName」已完成！',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green),
          ),
          const SizedBox(height: 6),
          Text(
            '所有学习步骤已完成，你可以向上滚动查看完整内容',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;

  const _BottomBar({
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '下一步：第 ${stepIndex + 1} 步 / 共 $totalSteps 步',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: stepIndex / totalSteps,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(stepIndex == 0 ? '开始执行' : '继续下一步'),
          ),
        ],
      ),
    );
  }
}
