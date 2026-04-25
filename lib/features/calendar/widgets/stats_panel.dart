import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_providers.dart';

class StatsPanel extends ConsumerWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats7dAsync = ref.watch(calendarStatsProvider('7d'));
    final stats30dAsync = ref.watch(calendarStatsProvider('30d'));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习统计'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 连续打卡
          stats7dAsync.maybeWhen(
            data: (stats) => stats.streakDays >= 7
                ? _StreakBadge(streakDays: stats.streakDays)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),

          // 本月概览
          stats30dAsync.maybeWhen(
            data: (stats) => _SummaryRow(
              totalMinutes: stats.totalDurationMinutes,
              checkinDays: stats.checkinDays,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // 近 7 天每日时长柱状图
          Text(
            '近 7 天学习时长',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          stats7dAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('加载失败：$e'),
            data: (stats) => _BarChart(
              items: stats.dailyStats
                  .map((d) => _BarItem(
                        label: '${d.date.month}/${d.date.day}',
                        value: d.durationMinutes,
                      ))
                  .toList(),
              maxValue: stats.dailyStats.isEmpty
                  ? 60
                  : stats.dailyStats
                      .map((d) => d.durationMinutes)
                      .reduce((a, b) => a > b ? a : b),
            ),
          ),
          const SizedBox(height: 24),

          // 近 30 天学科占比
          Text(
            '近 30 天学科占比',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          stats30dAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('加载失败：$e'),
            data: (stats) {
              if (stats.subjectStats.isEmpty) {
                return Text(
                  '暂无学习记录',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: stats.subjectStats.map((s) {
                  final color = _parseColor(s.color, cs);
                  final hours = (s.durationMinutes / 60).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.subjectName, style: const TextStyle(fontSize: 13)),
                        ),
                        Text(
                          '$hours h  ${(s.percentage * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: s.percentage,
                              minHeight: 6,
                              backgroundColor: color.withValues(alpha: 0.15),
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex, ColorScheme cs) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return cs.primary;
    }
  }
}

class _StreakBadge extends StatelessWidget {
  final int streakDays;
  const _StreakBadge({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已连续学习 $streakDays 天',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '保持下去，你很棒！',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int totalMinutes;
  final int checkinDays;
  const _SummaryRow({required this.totalMinutes, required this.checkinDays});

  @override
  Widget build(BuildContext context) {
    final hours = (totalMinutes / 60).toStringAsFixed(1);
    return Row(
      children: [
        Expanded(child: _StatCard(label: '本月学习', value: '$hours h')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: '打卡天数', value: '$checkinDays 天')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: cs.outline)),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final int value;
  const _BarItem({required this.label, required this.value});
}

class _BarChart extends StatelessWidget {
  final List<_BarItem> items;
  final int maxValue;
  const _BarChart({required this.items, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return const Text('暂无数据');
    }
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${(item.value / 60).toStringAsFixed(0)}h',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  FractionallySizedBox(
                    heightFactor: ratio.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.label, style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
