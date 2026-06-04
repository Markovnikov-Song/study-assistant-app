import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/quiz/node_practice_sheet.dart';
import '../../core/capability/capability_execution_contract.dart';
import '../../features/spec/services/plan_task_completion_service.dart';
import '../../models/subject.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/subject_provider.dart';
import '../../routes/app_routes.dart';

class PracticePage extends ConsumerWidget {
  final CapabilityExecutionContext execution;

  const PracticePage({
    super.key,
    this.execution = const CapabilityExecutionContext(
      capabilityId: 'practice.start',
    ),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      appBar: AppBar(title: const Text('去练习'), centerTitle: false),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 18,
          18,
          isWide ? 32 : 18,
          32,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PracticeHeader(isWide: isWide),
                if (execution.isPlanBound ||
                    execution.topic.trim().isNotEmpty ||
                    execution.count != null) ...[
                  const SizedBox(height: 12),
                  _PlanPracticeCard(execution: execution),
                ],
                const SizedBox(height: 18),
                _PracticeActionGrid(isWide: isWide),
                const SizedBox(height: 24),
                Text(
                  '按科目练',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                subjectsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => _EmptyPracticeState(
                    icon: Icons.error_outline_rounded,
                    title: '科目加载失败',
                    subtitle: '$error',
                  ),
                  data: (subjects) {
                    final active = subjects
                        .where((subject) => !subject.isArchived)
                        .toList();
                    if (active.isEmpty) {
                      return _EmptyPracticeState(
                        icon: Icons.menu_book_outlined,
                        title: '还没有科目',
                        subtitle: '先创建一个科目，再开始按科目练习。',
                        actionLabel: '创建科目',
                        onAction: () => context.push(R.profileSubjects),
                      );
                    }
                    return _SubjectPracticeList(subjects: active);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPracticeCard extends ConsumerStatefulWidget {
  final CapabilityExecutionContext execution;

  const _PlanPracticeCard({required this.execution});

  @override
  ConsumerState<_PlanPracticeCard> createState() => _PlanPracticeCardState();
}

class _PlanPracticeCardState extends ConsumerState<_PlanPracticeCard> {
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final execution = widget.execution;
    final topic = execution.topic.trim();
    final count = execution.count;
    final subjectId = _queryInt(execution, 'subject_id');
    final nodeId = '${execution.params['node_id'] ?? ''}'.trim();
    final subtitle = [
      if (topic.isNotEmpty) '主题：$topic',
      if (count != null) '题量：$count',
    ].join(' · ');

    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _completing
            ? null
            : () => _openPractice(
                nodeId: nodeId.isNotEmpty
                    ? nodeId
                    : 'plan-${execution.itemId ?? topic.hashCode}',
                nodeText: topic.isNotEmpty ? topic : '计划练习',
                subjectId: subjectId,
              ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: cs.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '继续计划练习',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _completing
                    ? null
                    : () => _openPractice(
                        nodeId: nodeId.isNotEmpty
                            ? nodeId
                            : 'plan-${execution.itemId ?? topic.hashCode}',
                        nodeText: topic.isNotEmpty ? topic : '计划练习',
                        subjectId: subjectId,
                      ),
                icon: _completing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_completing ? '回写中' : '开始'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPractice({
    required String nodeId,
    required String nodeText,
    required int? subjectId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NodePracticeSheet(
        nodeId: nodeId,
        nodeText: nodeText,
        subjectId: subjectId,
        onCompleted: (result) async {
          if (!widget.execution.isPlanBound) return;
          setState(() => _completing = true);
          try {
            await PlanTaskCompletionService.complete(
              ref: ref,
              context: context,
              execution: widget.execution,
              result: result,
            );
          } finally {
            if (mounted) setState(() => _completing = false);
          }
        },
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  final bool isWide;

  const _PracticeHeader({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(isWide ? 22 : 18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.play_circle_fill_rounded, color: cs.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始一次练习',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '按科目、知识点或计划进入练习。错题复习由后端队列调度，不在这里单独抢入口。',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                    fontSize: 13,
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

class _PracticeActionGrid extends StatelessWidget {
  final bool isWide;

  const _PracticeActionGrid({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _PracticeAction(
        icon: Icons.account_tree_rounded,
        title: '按知识点练',
        subtitle: '从思维导图或讲义节点进入针对性练习',
        onTap: () => context.push(R.mindmapEntry),
      ),
      _PracticeAction(
        icon: Icons.event_available_rounded,
        title: '按计划练',
        subtitle: '查看今天的学习安排和计划任务',
        onTap: () => context.push(R.toolkitCalendar),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: _PracticeActionCard(action: actions[i])),
            if (i != actions.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (final action in actions) ...[
          _PracticeActionCard(action: action),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SubjectPracticeList extends ConsumerWidget {
  final List<Subject> subjects;

  const _SubjectPracticeList({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final subject in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubjectPracticeTile(
              subject: subject,
              onTap: () {
                ref.read(currentSubjectProvider.notifier).state = subject;
                _openSubjectPractice(context, subject);
              },
            ),
          ),
      ],
    );
  }
}

class _SubjectPracticeTile extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;

  const _SubjectPracticeTile({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subject.category?.isNotEmpty == true
                          ? subject.category!
                          : '按这个科目生成一组可作答练习',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('开始'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PracticeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _PracticeActionCard extends StatelessWidget {
  final _PracticeAction action;

  const _PracticeActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(action.icon, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPracticeState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyPracticeState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.primary, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

void _openSubjectPractice(BuildContext context, Subject subject) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NodePracticeSheet(
      nodeId: 'subject-${subject.id}',
      nodeText: subject.name,
      subjectId: subject.id,
    ),
  );
}

int? _queryInt(CapabilityExecutionContext execution, String key) {
  final value = execution.params[key];
  if (value == null) return null;
  return int.tryParse('$value');
}
