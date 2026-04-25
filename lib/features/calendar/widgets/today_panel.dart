import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_router.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';
import '../services/calendar_api_service.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/calendar_events.dart';

class TodayPanel extends ConsumerStatefulWidget {
  const TodayPanel({super.key});

  @override
  ConsumerState<TodayPanel> createState() => _TodayPanelState();
}

class _TodayPanelState extends ConsumerState<TodayPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayEventsProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outline,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '今日',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  todayAsync.maybeWhen(
                    data: (result) => _ProgressChip(stats: result.stats),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push(R.spec),
                    child: const Text('查看完整计划'),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // 事件列表
          if (_expanded)
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载失败：$e'),
              ),
              data: (result) {
                if (result.events.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      '今天还没有学习安排，点击 + 新建事件',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final sorted = [...result.events]
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) => _EventTile(event: sorted[i]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  final TodayStats stats;
  const _ProgressChip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (stats.completionRate * 100).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${stats.completed}/${stats.total}（$pct%）',
        style: TextStyle(fontSize: 12, color: cs.primary),
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final CalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = _parseColor(event.color, cs);

    return Opacity(
      opacity: event.isCompleted ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 学科颜色标记
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${event.startTime}  ·  ${event.durationMinutes} 分钟',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 完成状态指示器
            GestureDetector(
              onTap: () => _toggleComplete(ref, context),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  color: event.isCompleted ? color : Colors.transparent,
                ),
                child: event.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComplete(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(calendarApiServiceProvider).updateEvent(
        event.id,
        {'is_completed': !event.isCompleted},
      );
      if (!event.isCompleted) {
        AppEventBus.instance.fire(CalendarEventCompleted(
          eventId: event.id,
          subjectId: event.subjectId,
        ));
      } else {
        AppEventBus.instance.fire(CalendarEventUncompleted(eventId: event.id));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('状态更新失败：$e')),
        );
      }
    }
  }

  Color _parseColor(String hex, ColorScheme cs) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return cs.primary;
    }
  }
}
