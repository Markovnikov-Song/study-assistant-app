import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/exam_provider.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key});
  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(currentSubjectProvider);
    return Scaffold(
      appBar: AppBar(title: const SubjectBarTitle(), centerTitle: false),
      body: subject == null
          ? const NoSubjectHint()
          : Column(
              children: [
                TabBar(controller: _tabCtrl, tabs: const [Tab(text: '预测试卷'), Tab(text: '自定义出题')]),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _PredictedTab(subjectId: subject.id),
                      _CustomTab(subjectId: subject.id),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── 预测试卷 ──────────────────────────────────────────────────────────────
class _PredictedTab extends ConsumerWidget {
  final int subjectId;
  const _PredictedTab({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(predictedPaperProvider(subjectId));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AI 分析历年题考点分布和学科资料，自动生成模拟试卷。', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.isLoading ? null : () => ref.read(predictedPaperProvider(subjectId).notifier).generate(),
            icon: state.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
            label: Text(state.isLoading ? '生成中…' : '生成预测试卷'),
          ),
          if (state.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(state.error!, style: const TextStyle(color: Colors.red))),
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Expanded(child: Card(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(state.result!)))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('导出 Markdown')),
          ],
        ],
      ),
    );
  }
}

// ── 自定义出题 ────────────────────────────────────────────────────────────
class _CustomTab extends ConsumerStatefulWidget {
  final int subjectId;
  const _CustomTab({required this.subjectId});
  @override
  ConsumerState<_CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends ConsumerState<_CustomTab> {
  static const _allTypes = ['选择题', '填空题', '简答题', '计算题'];
  static const _defaultScores = {'选择题': 2, '填空题': 3, '简答题': 10, '计算题': 15};
  final Set<String> _selected = {'选择题', '简答题'};
  final Map<String, int> _counts = {'选择题': 3, '填空题': 3, '简答题': 3, '计算题': 3};
  final Map<String, int> _scores = {'选择题': 2, '填空题': 3, '简答题': 10, '计算题': 15};
  String _difficulty = '中等';
  final _topicCtrl = TextEditingController();

  @override
  void dispose() { _topicCtrl.dispose(); super.dispose(); }

  int get _totalScore => _selected.fold(0, (s, t) => s + (_counts[t]! * _scores[t]!));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customQuizProvider(widget.subjectId));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('题型', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: _allTypes.map((t) => FilterChip(
            label: Text(t), selected: _selected.contains(t),
            onSelected: (v) => setState(() => v ? _selected.add(t) : _selected.remove(t)),
          )).toList()),

          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('数量 / 每题分值', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._selected.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 52, child: Text(t, style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(child: _NumField(label: '数量', value: _counts[t]!, onChanged: (v) => setState(() => _counts[t] = v))),
                const SizedBox(width: 8),
                Expanded(child: _NumField(label: '分值', value: _scores[t]!, onChanged: (v) => setState(() => _scores[t] = v))),
              ]),
            )),
            Text('总分：$_totalScore 分', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],

          const SizedBox(height: 16),
          const Text('难度', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: '简单', label: Text('简单')), ButtonSegment(value: '中等', label: Text('中等')), ButtonSegment(value: '困难', label: Text('困难'))],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),

          const SizedBox(height: 16),
          TextField(controller: _topicCtrl, decoration: const InputDecoration(labelText: '考点/主题（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: (state.isLoading || _selected.isEmpty) ? null : () => ref.read(customQuizProvider(widget.subjectId).notifier).generate(
              questionTypes: _selected.toList(), typeCounts: Map.from(_counts),
              typeScores: Map.from(_scores), difficulty: _difficulty,
              topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
            ),
            icon: state.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
            label: Text(state.isLoading ? '生成中…' : '生成题目'),
          ),

          if (state.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(state.error!, style: const TextStyle(color: Colors.red))),
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(state.result!))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('导出 Markdown')),
          ],
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value.toString(),
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    keyboardType: TextInputType.number,
    onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) onChanged(n); },
  );
}
