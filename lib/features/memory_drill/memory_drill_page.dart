import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capability/capability_execution_contract.dart';
import '../spec/services/plan_task_completion_service.dart';

class MemoryDrillPage extends ConsumerStatefulWidget {
  final CapabilityExecutionContext execution;

  const MemoryDrillPage({
    super.key,
    required this.execution,
  });

  @override
  ConsumerState<MemoryDrillPage> createState() => _MemoryDrillPageState();
}

class _MemoryDrillPageState extends ConsumerState<MemoryDrillPage> {
  late final List<_DrillItem> _items;
  int _index = 0;
  int _correct = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _items = List.generate(
      (widget.execution.count ?? 20).clamp(1, 120),
      (i) => _DrillItem(
        prompt: _promptFor(i + 1),
        answer: _answerFor(i + 1),
      ),
    );
  }

  String _promptFor(int n) {
    final label = _contentTypeLabel(widget.execution.contentType ?? 'memory-item');
    final topic = widget.execution.topic.trim().isEmpty
        ? '当前主题'
        : widget.execution.topic.trim();
    return '$topic · $label $n';
  }

  String _answerFor(int n) {
    final label = _contentTypeLabel(widget.execution.contentType ?? 'memory-item');
    return '回忆并说出这个$label的含义、用法或关键区别。';
  }

  String _contentTypeLabel(String value) => switch (value) {
        'vocabulary' => '词汇',
        'political-concept' => '政治概念',
        'formula' => '公式',
        'knowledge-node' => '知识点',
        _ => '记忆条目',
      };

  double get _accuracy => _index == 0 ? 0 : _correct / _index;

  void _answer(bool known) {
    if (_index >= _items.length) return;
    setState(() {
      if (known) _correct += 1;
      _index += 1;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      if (widget.execution.isPlanBound) {
        await PlanTaskCompletionService.complete(
          ref: ref,
          context: context,
          execution: widget.execution,
          popAfterComplete: true,
          successMessage: '已完成，正确率 ${(_accuracy * 100).round()}%',
          result: {
            'attempted_count': _items.length,
            'correct_count': _correct,
            'accuracy': _accuracy,
            'content_type': widget.execution.contentType,
          },
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已完成，正确率 ${(_accuracy * 100).round()}%')),
        );
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回写失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = _index >= _items.length;
    final current = done ? null : _items[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆训练'),
        actions: [
          if (widget.execution.isPlanBound)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '计划任务',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _items.isEmpty ? 0 : _index / _items.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_index/${_items.length}'),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: done
                        ? _ResultPanel(
                            total: _items.length,
                            correct: _correct,
                            accuracy: _accuracy,
                          )
                        : _DrillCard(
                            key: ValueKey(_index),
                            item: current!,
          contentType: _contentTypeLabel(widget.execution.contentType ?? 'memory-item'),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (done)
                FilledButton.icon(
                  onPressed: _finishing ? null : _finish,
                  icon: _finishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    widget.execution.isPlanBound ? '完成并回写计划' : '完成训练',
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _answer(false),
                        icon: const Icon(Icons.close),
                        label: const Text('还不熟'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _answer(true),
                        icon: const Icon(Icons.check),
                        label: const Text('记住了'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrillItem {
  final String prompt;
  final String answer;

  const _DrillItem({required this.prompt, required this.answer});
}

class _DrillCard extends StatelessWidget {
  final _DrillItem item;
  final String contentType;

  const _DrillCard({super.key, required this.item, required this.contentType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contentType, style: TextStyle(color: cs.primary, fontSize: 12)),
          const SizedBox(height: 12),
          Text(
            item.prompt,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(item.answer, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final int total;
  final int correct;
  final double accuracy;

  const _ResultPanel({
    required this.total,
    required this.correct,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_alt_outlined, size: 40, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            '训练完成',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成 $total 个，记住 $correct 个，正确率 ${(accuracy * 100).round()}%',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
