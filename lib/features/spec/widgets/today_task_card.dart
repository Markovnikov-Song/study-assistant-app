import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../routes/app_router.dart';
import '../models/study_plan_models.dart';
import '../providers/study_planner_providers.dart';
import '../services/capability_launch_service.dart';

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
      error: (_, _) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null || !plan.isActive) return const SizedBox.shrink();
        return todayAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            final pending = items.where((item) => item.isPending).toList();
            return _buildCard(context, plan, items, pending);
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    StudyPlan plan,
    List<PlanItem> todayItems,
    List<PlanItem> pending,
  ) {
    final cs = Theme.of(context).colorScheme;
    final show = pending.take(3).toList();
    final done = todayItems
        .where((item) => item.isDone || item.isSkipped)
        .length;
    final progress = todayItems.isEmpty ? 0.0 : done / todayItems.length;
    final next = pending.isEmpty ? null : pending.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Icon(Icons.track_changes, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '今日任务条 · $done/${todayItems.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 7,
                backgroundColor: cs.primary.withValues(alpha: 0.16),
                color: cs.primary,
              ),
            ),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                '下一关约 ${next.estimatedMinutes} 分钟，完成后获得 +${next.estimatedMinutes.clamp(10, 60)} XP。',
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '今日任务已完成，可以去复盘或让助教安排下一轮。',
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
              ),
            ),
          for (final item in show) _TaskRow(item: item, cs: cs),
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
                    child: const Text('查看完整计划'),
                  ),
                ),
                if (next != null)
                  FilledButton.icon(
                    onPressed: () => context.push(
                      CapabilityLaunchService.routeForPlanItem(next),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final PlanItem item;
  final ColorScheme cs;

  const _TaskRow({required this.item, required this.cs});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(CapabilityLaunchService.routeForPlanItem(item)),
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
              '${item.estimatedMinutes} min',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}
