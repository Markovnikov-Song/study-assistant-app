import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/exam_provider.dart';

class QuizGenTab extends ConsumerStatefulWidget {
  final int subjectId;
  const QuizGenTab({super.key, required this.subjectId});

  @override
  ConsumerState<QuizGenTab> createState() => _QuizGenTabState();
}

class _QuizGenTabState extends ConsumerState<QuizGenTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: '预测试卷'), Tab(text: '自定义出题')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _PredictedPaperTab(subjectId: widget.subjectId),
              _CustomQuizTab(subjectId: widget.subjectId),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 预测试卷 ──────────────────────────────────────────────────────────────
class _PredictedPaperTab extends ConsumerWidget {
  final int subjectId;
  const _PredictedPaperTab({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(predictedPaperProvider(subjectId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AI 分析历年题考点分布和学科资料，自动生成模拟试卷。'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.isLoading
                ? null
                : () => ref.read(predictedPaperProvider(subjectId).notifier).generate(),
            icon: const Icon(Icons.auto_awesome),
            label: state.isLoading
                ? const Text('生成中…')
                : const Text('生成预测试卷'),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.result!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {/* TODO: 导出 */},
              icon: const Icon(Icons.download),
              label: const Text('导出 Markdown'),
            ),
          ],
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}

// ── 自定义出题 ────────────────────────────────────────────────────────────
class _CustomQuizTab extends ConsumerStatefulWidget {
  final int subjectId;
  const _CustomQuizTab({required this.subjectId});

  @override
  ConsumerState<_CustomQuizTab> createState() => _CustomQuizTabState();
}

class _CustomQuizTabState extends ConsumerState<_CustomQuizTab> {
  static const _allTypes = ['选择题', '填空题', '简答题', '计算题'];

  final Set<String> _selectedTypes = {'选择题', '简答题'};
  final Map<String, int> _counts = {'选择题': 3, '填空题': 3, '简答题': 3, '计算题': 3};
  final Map<String, int> _scores = {'选择题': 2, '填空题': 3, '简答题': 10, '计算题': 15};
  String _difficulty = '中等';
  final _topicCtrl = TextEditingController();

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  int get _totalScore => _selectedTypes.fold(0, (sum, t) => sum + (_counts[t]! * _scores[t]!));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customQuizProvider(widget.subjectId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 题型选择
          const Text('题型', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _allTypes.map((t) => FilterChip(
              label: Text(t),
              selected: _selectedTypes.contains(t),
              onSelected: (v) => setState(() => v ? _selectedTypes.add(t) : _selectedTypes.remove(t)),
            )).toList(),
          ),

          // 各题型数量/分值
          if (_selectedTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('各题型数量 / 每题分值', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._selectedTypes.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 56, child: Text(t, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      label: '数量',
                      value: _counts[t]!,
                      onChanged: (v) => setState(() => _counts[t] = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      label: '分值',
                      value: _scores[t]!,
                      onChanged: (v) => setState(() => _scores[t] = v),
                    ),
                  ),
                ],
              ),
            )),
            Text('总分：$_totalScore 分', style: const TextStyle(color: Colors.grey)),
          ],

          const SizedBox(height: 16),
          // 难度
          const Text('难度', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '简单', label: Text('简单')),
              ButtonSegment(value: '中等', label: Text('中等')),
              ButtonSegment(value: '困难', label: Text('困难')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: '考点/主题（可选）',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (state.isLoading || _selectedTypes.isEmpty)
                ? null
                : () => ref.read(customQuizProvider(widget.subjectId).notifier).generate(
                      questionTypes: _selectedTypes.toList(),
                      typeCounts: Map.from(_counts),
                      typeScores: Map.from(_scores),
                      difficulty: _difficulty,
                      topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
                    ),
            icon: const Icon(Icons.auto_awesome),
            label: state.isLoading ? const Text('生成中…') : const Text('生成题目'),
          ),

          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.result!),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {/* TODO: 导出 */},
              icon: const Icon(Icons.download),
              label: const Text('导出 Markdown'),
            ),
          ],
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n > 0) onChanged(n);
      },
    );
  }
}
