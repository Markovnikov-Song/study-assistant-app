import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan_models.dart';
import '../providers/study_planner_providers.dart';
import '../../../routes/app_router.dart';

/// 今日任务卡片，插入到 ChatPage 空状态区域上方。
/// 条件：有 active 计划 && 今日有 pending items && 用户未关闭
class TodayTaskCard extends ConsumerStatefulWidget {
  const TodayTaskCard({super.key});

  @override
  ConsumerState<TodayTaskCard> createState() => _TodayTaskCardState();
}

class _TodayTaskCardState extends ConsumerState<TodayTaskCard> {
  bool _dismissed = false;
  bool _checkedDismiss = false;

  static const _prefKey = 'today_task_card_dismissed_date';

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final today = _todayStr();
    if (mounted) {
      setState(() {
        _dismissed = saved == today;
        _checkedDismiss = true;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _todayStr());
    if (mounted) setState(() => _dismissed = true);
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedDismiss || _dismissed) return const SizedBox.shrink();

    final planAsync = ref.watch(activePlanProvider);
    final todayAsync = ref.watch(todayPlanItemsProvider);

    return planAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null || !plan.isActive) return const SizedBox.shrink();
        return todayAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final pending = items.where((i) => i.isPending).toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return _buildCard(context, plan, pending);
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, StudyPlan plan, List<PlanItem> pending) {
    final cs = Theme.of(context).colorScheme;
    final show = pending.take(3).toList();
    final allDone = pending.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Icon(Icons.today_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allDone ? '今日任务全部完成 🎉' : '今日学习任务 · ${pending.length} 项待完成',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.outline),
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 任务列表
          if (!allDone)
            ...show.map((item) => _TaskRow(item: item, cs: cs)),

          // 底部操作
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push(R.spec),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text('查看完整计划 →', style: TextStyle(fontSize: 13)),
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

class _TaskRow extends ConsumerWidget {
  final PlanItem item;
  final ColorScheme cs;

  const _TaskRow({required this.item, required this.cs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (item.subjectId == null) return;
        // 跳转到学科专属对话，预填节点文本
        final chatId = DateTime.now().millisecondsSinceEpoch.toString();
        context.push(
          '/chat/$chatId/subject/${item.subjectId}',
          extra: {'prefillText': item.nodeText},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.nodeText,
                style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.estimatedMinutes}min',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}
