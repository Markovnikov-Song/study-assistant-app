import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';

/// 悬浮计时条：番茄钟运行时显示在页面底部
class PomodoroFloatingBar extends ConsumerWidget {
  const PomodoroFloatingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroTimerProvider);
    if (!state.isRunning && state.phase != PomodoroPhase.paused) {
      return const SizedBox.shrink();
    }

    final remaining = state.remainingSeconds;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isResting = state.phase == PomodoroPhase.resting;
    final isPaused = state.phase == PomodoroPhase.paused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isResting
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: isResting ? AppColors.success : AppColors.primary,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isResting ? Icons.coffee_outlined : Icons.timer_outlined,
            size: 18,
            color: isResting ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isResting ? '休息中' : (isPaused ? '已暂停' : '专注中'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isResting ? AppColors.success : AppColors.primary,
                  ),
                ),
                if (state.currentEvent != null)
                  Text(
                    state.currentEvent!.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isResting ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          // 番茄数
          Text(
            '🍅×${state.completedPomodoros}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          // 暂停/继续
          IconButton(
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            iconSize: 20,
            onPressed: () {
              if (isPaused) {
                ref.read(pomodoroTimerProvider.notifier).resume();
              } else {
                ref.read(pomodoroTimerProvider.notifier).pause();
              }
            },
          ),
          // 停止
          IconButton(
            icon: const Icon(Icons.stop),
            iconSize: 20,
            onPressed: () => _confirmStop(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停止计时'),
        content: const Text('是否标记当前事件为已完成？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pomodoroTimerProvider.notifier).stop(markCompleted: false);
            },
            child: const Text('不标记，直接停止'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pomodoroTimerProvider.notifier).stop(markCompleted: true);
            },
            child: const Text('标记为已完成'),
          ),
        ],
      ),
    );
  }
}
