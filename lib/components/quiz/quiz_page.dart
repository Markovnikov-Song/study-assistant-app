import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_saver/file_saver.dart';
import '../../core/capability/capability_execution_contract.dart';
import '../../core/widgets/responsive_widgets.dart';
import '../../models/document.dart';
import '../../models/subject.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/subject_provider.dart';
import '../../features/spec/services/plan_task_completion_service.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/mcp_status_indicator.dart';

class QuizPage extends ConsumerStatefulWidget {
  final CapabilityExecutionContext execution;

  const QuizPage({
    super.key,
    this.execution = const CapabilityExecutionContext(
      capabilityId: 'quiz.generate',
    ),
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  /// 从学习计划/能力参数决定初始 Tab，避免「自定义出题」被默认停在预测试卷。
  static int _initialTabIndex(CapabilityExecutionContext execution) {
    final tabRaw = execution.params['tab'] ?? execution.params['tab_index'];
    if (tabRaw != null) {
      final i = int.tryParse('$tabRaw');
      if (i != null && i >= 0 && i < 3) return i;
    }
    final mode = (execution.params['source_mode'] as String?)?.trim();
    if (mode == 'topic_only') return 2;
    if (mode == 'material') return 1;
    // 学习计划、带主题/题量的精准组卷 → 不进预测试卷
    if (execution.isPlanBound ||
        execution.topic.trim().isNotEmpty ||
        execution.count != null) {
      return 1;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: _initialTabIndex(widget.execution),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(currentSubjectProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const SubjectBarTitle(),
        centerTitle: false,
        actions: const [McpStatusIndicator(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '预测试卷'),
              Tab(text: '根据资料出题'),
              Tab(text: '自定义出题'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _QuizSubjectGate(
                  subjectId: subject?.id,
                  child: (id) => _PredictedTab(subjectId: id, isWide: isWide),
                ),
                _QuizSubjectGate(
                  subjectId: subject?.id,
                  child: (id) => _CustomTab(
                    subjectId: id,
                    execution: widget.execution,
                    isWide: isWide,
                    sourceMode: 'material',
                  ),
                ),
                _QuizSubjectGate(
                  subjectId: subject?.id,
                  child: (id) => _CustomTab(
                    subjectId: id,
                    execution: widget.execution,
                    isWide: isWide,
                    sourceMode: 'topic_only',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 科目门禁：无科目时居中选科，有科目后展示功能 ─────────────────────────────

class _QuizSubjectGate extends ConsumerWidget {
  final int? subjectId;
  final Widget Function(int subjectId) child;

  const _QuizSubjectGate({
    required this.subjectId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjectId == null) {
      return _QuizSubjectPicker(isWide: MediaQuery.sizeOf(context).width >= 900);
    }
    return child(subjectId!);
  }
}

class _QuizSubjectPicker extends ConsumerWidget {
  final bool isWide;

  const _QuizSubjectPicker({required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final subjectsAsync = ref.watch(subjectsProvider);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 48 : 24,
          vertical: isWide ? 40 : 32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 560 : 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  size: 36,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '选择科目',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '选定科目后可生成预测试卷，或按题型、数量、分值精准组卷',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              subjectsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Text('加载科目失败：$e'),
                data: (subjects) {
                  final active = subjects.where((s) => !s.isArchived).toList();
                  if (active.isEmpty) {
                    return _SubjectPickerActions(showList: false);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...active.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InlineSubjectTile(subject: s),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SubjectPickerActions(showList: true),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineSubjectTile extends ConsumerWidget {
  final Subject subject;

  const _InlineSubjectTile({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(currentSubjectProvider.notifier).state = subject;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subject.category != null)
                      Text(
                        subject.category!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectPickerActions extends StatelessWidget {
  final bool showList;

  const _SubjectPickerActions({required this.showList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showList) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '或',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SubjectPickerSheet(),
          ),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('浏览全部科目'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CreateSubjectSheet(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('新建科目'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

// ── 预测试卷 ──────────────────────────────────────────────────────────────────

class _PredictedTab extends ConsumerStatefulWidget {
  final int subjectId;
  final bool isWide;

  const _PredictedTab({required this.subjectId, required this.isWide});

  @override
  ConsumerState<_PredictedTab> createState() => _PredictedTabState();
}

class _PredictedTabState extends ConsumerState<_PredictedTab> {
  bool _useBroad = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(predictedPaperProvider(widget.subjectId));
    final form = _buildForm(state);

    if (state.result != null) {
      return _QuizPageLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            form,
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(state.result!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _exportMarkdown(state.result!),
              icon: const Icon(Icons.download),
              label: const Text('导出 Markdown'),
            ),
          ],
        ),
      );
    }

    if (widget.isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _QuizPageLayout(child: form),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _QuizSidePanel(subjectId: widget.subjectId),
            ),
          ],
        ),
      );
    }

    return _QuizPageLayout(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            form,
            const SizedBox(height: 24),
            _QuizSidePanel(subjectId: widget.subjectId, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(GenerationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'AI 分析历年题考点分布和科目资料，自动生成模拟试卷',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _useBroad,
              onChanged: (v) => setState(() => _useBroad = v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const Text('结合通用知识', style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: state.isLoading
              ? null
              : () {
                  ref
                      .read(predictedPaperProvider(widget.subjectId).notifier)
                      .generate(useBroad: _useBroad);
                },
          icon: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(state.isLoading ? '生成中…' : '生成预测试卷'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _exportMarkdown(String content) async {
    final date = DateTime.now();
    final d =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    await FileSaver.instance.saveFile(
      name: '预测试卷_$d',
      bytes: Uint8List.fromList(utf8.encode(content)),
      ext: 'md',
      mimeType: MimeType.text,
    );
  }
}

// ── 侧栏 / 底部补充信息（填充 Web 空白、提示上传历年题）────────────────────

/// 自定义 / 根据资料出题侧栏（不含预测试卷与历年题，避免「盖住」组卷表单）
class _CustomQuizSidePanel extends StatelessWidget {
  final bool fromMaterial;

  const _CustomQuizSidePanel({required this.fromMaterial});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TipCard(
          icon: Icons.tune,
          title: fromMaterial ? '根据资料出题' : '自定义出题',
          body: fromMaterial
              ? '会从本学科已解析资料中检索相关内容，再按左侧题型、数量与分值组卷。'
              : '不读取资料库，仅按你填写的考点/主题与题型设置组卷，适合考前自测或专题练习。',
        ),
        const SizedBox(height: 12),
        _TipCard(
          icon: Icons.checklist,
          title: '组卷建议',
          body: '先勾选题型并设置数量、分值，再选择难度；「结合通用知识」可在资料不足时补充常识性考查。',
        ),
      ],
    );
  }
}

class _QuizSidePanel extends ConsumerWidget {
  final int subjectId;
  final bool compact;

  const _QuizSidePanel({required this.subjectId, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final examsAsync = ref.watch(pastExamsProvider(subjectId));
    final uploadState = ref.watch(examActionsProvider(subjectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TipCard(
          icon: Icons.lightbulb_outline,
          title: '提升预测试卷质量',
          body: '上传历年真题后，AI 能更准确分析考点分布，生成更贴近考试的模拟卷。',
        ),
        const SizedBox(height: 12),
        _TipCard(
          icon: Icons.tune,
          title: '精准组卷',
          body: '「根据资料出题」会检索资料库；「自定义出题」仅按你填写的考点/主题，两种都可选题型、数量与分值。',
        ),
        const SizedBox(height: 16),
        Text(
          '历年题资料',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: uploadState.isUploading
              ? null
              : () => ref
                  .read(examActionsProvider(subjectId).notifier)
                  .pickAndUpload(),
          icon: uploadState.isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: Text(uploadState.isUploading ? '上传中…' : '上传历年题'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        examsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('加载失败', style: TextStyle(color: cs.error)),
          data: (exams) {
            if (exams.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '暂无历年题，上传 PDF / 图片 / Word 后可增强预测效果',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              );
            }
            final show = compact ? exams.take(3) : exams.take(5);
            return Column(
              children: [
                ...show.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PastExamChip(exam: e),
                  ),
                ),
                if (exams.length > show.length)
                  Text(
                    '还有 ${exams.length - show.length} 份…',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PastExamChip extends StatelessWidget {
  final PastExamFile exam;

  const _PastExamChip({required this.exam});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (exam.status) {
      DocumentStatus.completed => Colors.green,
      DocumentStatus.failed => Colors.red,
      DocumentStatus.processing || DocumentStatus.pending => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exam.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${exam.questionCount} 题',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _QuizPageLayout extends StatelessWidget {
  final Widget child;

  const _QuizPageLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      desktopMaxWidth: 720,
      tabletMaxWidth: 640,
      mobileMaxWidth: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: child,
      ),
    );
  }
}

// ── 自定义出题 ────────────────────────────────────────────────────────────────

class _CustomTab extends ConsumerStatefulWidget {
  final int subjectId;
  final CapabilityExecutionContext execution;
  final bool isWide;
  final String sourceMode;

  const _CustomTab({
    required this.subjectId,
    required this.execution,
    required this.isWide,
    required this.sourceMode,
  });

  @override
  ConsumerState<_CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends ConsumerState<_CustomTab> {
  static const _allTypes = ['选择题', '填空题', '简答题', '计算题'];
  final Set<String> _selected = {'选择题', '简答题'};
  final Map<String, int> _counts = {
    '选择题': 3,
    '填空题': 3,
    '简答题': 3,
    '计算题': 3,
  };
  final Map<String, int> _scores = {
    '选择题': 2,
    '填空题': 3,
    '简答题': 10,
    '计算题': 15,
  };
  String _difficulty = '中等';
  bool _useBroad = false;

  bool get _fromMaterial => widget.sourceMode == 'material';
  final _topicCtrl = TextEditingController();
  bool _finishingPlanItem = false;

  @override
  void initState() {
    super.initState();
    final topic = widget.execution.topic.trim();
    if (topic.isNotEmpty) {
      _topicCtrl.text = topic;
    }
    final count = widget.execution.count;
    if (count != null && count > 0) {
      _counts.updateAll((key, value) => count);
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  int get _totalScore =>
      _selected.fold(0, (s, t) => s + (_counts[t]! * _scores[t]!));

  CustomQuizKey get _quizKey =>
      (subjectId: widget.subjectId, sourceMode: widget.sourceMode);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customQuizProvider(_quizKey));

    final form = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _fromMaterial ? '根据资料出题' : '自定义出题',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _fromMaterial
                ? '从本学科已解析资料检索相关内容，再按下方题型、数量、分值与难度组卷。'
                : '不读取资料库，仅按下方考点/主题与题型、数量、分值组卷。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          const Text('题型', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _allTypes
                .map(
                  (t) => FilterChip(
                    label: Text(t),
                    selected: _selected.contains(t),
                    onSelected: (v) => setState(
                      () => v ? _selected.add(t) : _selected.remove(t),
                    ),
                  ),
                )
                .toList(),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '数量 / 每题分值',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._selected.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(t, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NumField(
                        label: '数量',
                        value: _counts[t]!,
                        onChanged: (v) => setState(() => _counts[t] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NumField(
                        label: '分值',
                        value: _scores[t]!,
                        onChanged: (v) => setState(() => _scores[t] = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              '总分：$_totalScore 分',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
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
            decoration: InputDecoration(
              labelText: _fromMaterial
                  ? '考点/主题（可选，用于检索资料）'
                  : '考点/主题（必填）',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _useBroad,
                onChanged: (v) => setState(() => _useBroad = v ?? false),
                visualDensity: VisualDensity.compact,
              ),
              const Text('结合通用知识', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (state.isLoading ||
                    _selected.isEmpty ||
                    (!_fromMaterial && _topicCtrl.text.trim().isEmpty))
                ? null
                : () => ref.read(customQuizProvider(_quizKey).notifier).generate(
                      questionTypes: _selected.toList(),
                      typeCounts: Map.from(_counts),
                      typeScores: Map.from(_scores),
                      difficulty: _difficulty,
                      topic: _topicCtrl.text.trim().isEmpty
                          ? null
                          : _topicCtrl.text.trim(),
                      sourceMode: widget.sourceMode,
                      useBroad: _useBroad,
                    ),
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(state.isLoading ? '生成中…' : '生成题目'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(state.result!),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _exportMarkdown(state.result!),
              icon: const Icon(Icons.download),
              label: const Text('导出 Markdown'),
            ),
            if (widget.execution.isPlanBound) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _finishingPlanItem ? null : _finishPlanItem,
                icon: _finishingPlanItem
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('完成并回写计划'),
              ),
            ],
          ],
        ],
      ),
    );

    if (widget.isWide && state.result == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _QuizPageLayout(child: form)),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _CustomQuizSidePanel(fromMaterial: _fromMaterial),
            ),
          ],
        ),
      );
    }

    return _QuizPageLayout(child: form);
  }

  Future<void> _exportMarkdown(String content) async {
    final date = DateTime.now();
    final d =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    await FileSaver.instance.saveFile(
      name: '自定义题目_$d',
      bytes: Uint8List.fromList(utf8.encode(content)),
      ext: 'md',
      mimeType: MimeType.text,
    );
  }

  Future<void> _finishPlanItem() async {
    if (!widget.execution.isPlanBound) return;
    setState(() => _finishingPlanItem = true);
    try {
      await PlanTaskCompletionService.complete(
        ref: ref,
        context: context,
        execution: widget.execution,
        result: {
          'attempted_count': _selected.fold<int>(
            0,
            (sum, type) => sum + (_counts[type] ?? 0),
          ),
          'generated': true,
          'topic': _topicCtrl.text.trim(),
          'difficulty': _difficulty,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回写失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _finishingPlanItem = false);
    }
  }
}

// ── 数字输入框 ────────────────────────────────────────────────────────────────

class _NumField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n > 0) onChanged(n);
        },
      );
}
