import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/study_plan_models.dart';
import 'capability_launch_service.dart';

class StudyRewardService {
  const StudyRewardService._();

  static Future<void> showTaskCompleted({
    required BuildContext context,
    required WidgetRef ref,
    required StudyPlan plan,
    required int completedItemId,
    String message = '任务已完成',
    bool popAfterClose = false,
  }) async {
    if (!context.mounted) return;

    final completedItem = _findItem(plan.items, completedItemId);
    final todayItems = plan.todayItems;
    final todayDone = todayItems
        .where((item) => item.isDone || item.isSkipped)
        .length;
    final todayTotal = todayItems.length;
    final nextItem = _nextPending(todayItems) ?? _nextPending(plan.items);
    final xp = _xpFor(completedItem);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _RewardSheet(
        message: message,
        xp: xp,
        todayDone: todayDone,
        todayTotal: todayTotal,
        nextItem: nextItem,
        onClose: () {
          Navigator.of(sheetContext).pop();
          if (popAfterClose && context.mounted && context.canPop()) {
            context.pop();
          }
        },
        onNext: nextItem == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                if (context.mounted) {
                  context.push(
                    CapabilityLaunchService.routeForPlanItem(nextItem),
                  );
                }
              },
      ),
    );
  }

  static PlanItem? _findItem(List<PlanItem> items, int id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static PlanItem? _nextPending(List<PlanItem> items) {
    for (final item in items) {
      if (item.isPending) return item;
    }
    return null;
  }

  static int _xpFor(PlanItem? item) {
    final minutes = item?.estimatedMinutes ?? 20;
    return minutes.clamp(10, 60);
  }
}

class _RewardSheet extends StatelessWidget {
  final String message;
  final int xp;
  final int todayDone;
  final int todayTotal;
  final PlanItem? nextItem;
  final VoidCallback onClose;
  final VoidCallback? onNext;

  const _RewardSheet({
    required this.message,
    required this.xp,
    required this.todayDone,
    required this.todayTotal,
    required this.nextItem,
    required this.onClose,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = todayTotal == 0 ? 0.0 : todayDone / todayTotal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+$xp XP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        message,
                        style: TextStyle(fontSize: 13, color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              todayTotal == 0 ? '已记录本次学习' : '今日进度 $todayDone/$todayTotal',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 7,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            if (nextItem != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下一关',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextItem!.nodeText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '预计 ${nextItem!.estimatedMinutes} 分钟，完成后继续推进今日进度。',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              )
            else
              Text(
                '今日任务已清空，可以进入复盘或休息一下。',
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    child: Text(nextItem == null ? '收起' : '稍后再说'),
                  ),
                ),
                if (nextItem != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('继续下一关'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
