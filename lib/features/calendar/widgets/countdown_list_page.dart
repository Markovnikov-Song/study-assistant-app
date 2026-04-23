import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';

class CountdownListPage extends ConsumerWidget {
  const CountdownListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 查询未来 365 天内的倒计时事件
    final now = DateTime.now();
    final range = DateRange(
      start: now,
      end: now.add(const Duration(days: 365)),
    );
    final eventsAsync = ref.watch(calendarEventsProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('考试倒计时'),
        centerTitle: false,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (events) {
          final countdowns = events
              .where((e) => e.isCountdown)
              .toList()
            ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

          if (countdowns.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      '还没有考试倒计时',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '新建事件时开启「标记为考试/重要日期」',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: countdowns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _CountdownCard(event: countdowns[i]),
          );
        },
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final CalendarEvent event;
  const _CountdownCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final daysLeft = event.eventDate.difference(DateTime.now()).inDays;
    final color = _countdownColor(daysLeft);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.flag_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.eventDate.toString().substring(0, 10),
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: daysLeft <= 0 ? 1.0 : (1 - daysLeft / 365).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  daysLeft <= 0 ? '今天' : '$daysLeft',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (daysLeft > 0)
                  Text('天', style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _countdownColor(int daysLeft) {
    if (daysLeft <= 0) return AppColors.error;
    if (daysLeft < 10) return AppColors.error;
    if (daysLeft <= 30) return AppColors.warning;
    return AppColors.success;
  }
}
