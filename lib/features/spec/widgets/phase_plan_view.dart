import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_plan_models.dart';
import '../providers/study_planner_providers.dart';

/// 阶段 3：计划表视图
class PhasePlanView extends ConsumerStatefulWidget {
  final StudyPlan plan;

  const PhasePlanView({super.key, required this.plan});

  @override
  ConsumerState<PhasePlanView> createState() => _PhasePlanViewState();
}

class _PhasePlanViewState extends ConsumerState<PhasePlanView> {
  late StudyPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  // 按日期分组
  Map<String, List<PlanItem>> _groupByDate(List<PlanItem> items) {
    final map = <String, List<PlanItem>>{};
    for (final item in items) {
      final key = item.plannedDate != null
          ? '${item.plannedDate!.year}-${item.plannedDate!.month.toString().padLeft(2, '0')}-${item.plannedDate!.day.toString().padLeft(2, '0')}'
          : '未排期';
      map.putIfAbsent(key, () => []).add(item);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<void> _updateItemStatus(PlanItem item, String status) async {
    try {
      await ref.read(studyPlannerApiServiceProvider).updateItemStatus(
            _plan.id,
            item.id,
            status,
          );
      // 刷新计划
      final updated = await ref.read(studyPlannerApiServiceProvider).getActivePlan();
      if (updated != null && mounted) {
        setState(() => _plan = updated);
        ref.invalidate(activePlanProvider);
        ref.invalidate(todayPlanItemsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abandonPlan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃计划'),
        content: const Text('确认放弃当前学习计划？历史数据将保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(studyPlannerApiServiceProvider).abandonPlan(_plan.id);
      ref.invalidate(activePlanProvider);
      ref.invalidate(todayPlanItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划已放弃')),
        );
        // 重置到对话阶段
        ref.read(specPhaseProvider.notifier).state = SpecPhase.chat;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _groupByDate(_plan.items);
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final totalItems = _plan.items.length;
    final completedItems = _plan.items.where((i) => i.isDone || i.isSkipped).length;
    final todayItems = grouped[todayKey] ?? [];
    final todayDone = todayItems.where((i) => i.isDone || i.isSkipped).length;
    final todayRate = todayItems.isEmpty ? 0.0 : todayDone / todayItems.length;
    final daysRemaining = _plan.deadline.difference(today).inDays;

    return CustomScrollView(
      slivers: [
        // 摘要卡片
        SliverToBoxAdapter(
          child: _SummaryCard(
            totalItems: totalItems,
            completedItems: completedItems,
            daysRemaining: daysRemaining,
            todayRate: todayRate,
            cs: cs,
          ),
        ),

        // 按日期分组的计划条目
        for (final entry in grouped.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    entry.key == todayKey ? '今天 · ${entry.key}' : entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: entry.key == todayKey ? cs.primary : cs.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value.where((i) => i.isDone || i.isSkipped).length}/${entry.value.length}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _PlanItemTile(
                item: entry.value[i],
                onDone: () => _updateItemStatus(entry.value[i], 'done'),
                onSkip: () => _updateItemStatus(entry.value[i], 'skipped'),
              ),
              childCount: entry.value.length,
            ),
          ),
        ],

        // 放弃计划按钮
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: OutlinedButton(
              onPressed: _abandonPlan,
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              child: const Text('放弃计划'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 摘要卡片 ──────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalItems;
  final int completedItems;
  final int daysRemaining;
  final double todayRate;
  final ColorScheme cs;

  const _SummaryCard({
    required this.totalItems,
    required this.completedItems,
    required this.daysRemaining,
    required this.todayRate,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: '总任务',
                  value: '$totalItems',
                  cs: cs,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: '已完成',
                  value: '$completedItems',
                  cs: cs,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: '剩余天数',
                  value: '$daysRemaining',
                  cs: cs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '今日完成率 ${(todayRate * 100).floor()}%',
            style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: todayRate,
              minHeight: 6,
              backgroundColor: cs.primary.withValues(alpha: 0.2),
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatItem({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onPrimaryContainer,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
      ],
    );
  }
}

// ── 计划条目 Tile ─────────────────────────────────────────────────────────────

class _PlanItemTile extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _PlanItemTile({
    required this.item,
    required this.onDone,
    required this.onSkip,
  });

  Color _priorityColor(BuildContext context) {
    return switch (item.priority) {
      'high' => Colors.red.shade400,
      'medium' => Colors.orange.shade400,
      _ => Colors.green.shade400,
    };
  }

  String _priorityLabel() => switch (item.priority) {
        'high' => '重点',
        'medium' => '一般',
        _ => '补充',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = item.isDone || item.isSkipped;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDone
            ? cs.surfaceContainerLow.withValues(alpha: 0.5)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: isDone ? null : onDone,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? cs.primary : Colors.transparent,
              border: Border.all(
                color: isDone ? cs.primary : cs.outline,
                width: 2,
              ),
            ),
            child: isDone
                ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                : null,
          ),
        ),
        title: Text(
          item.nodeText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? cs.outline : cs.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (item.subjectName != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.subjectName!,
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${item.estimatedMinutes} 分钟',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _priorityColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _priorityLabel(),
                style: TextStyle(
                  fontSize: 10,
                  color: _priorityColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: isDone
            ? null
            : PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: cs.outline),
                onSelected: (v) {
                  if (v == 'done') onDone();
                  if (v == 'skip') onSkip();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'done', child: Text('标记完成')),
                  const PopupMenuItem(value: 'skip', child: Text('跳过')),
                ],
              ),
      ),
    );
  }
}
