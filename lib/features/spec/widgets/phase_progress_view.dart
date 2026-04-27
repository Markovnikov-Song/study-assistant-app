import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_planner_providers.dart';

/// 阶段 2：规划进度视图（轮询后台生成状态）
class PhaseProgressView extends ConsumerWidget {
  final int planId;
  final List<String> subjectNames;
  final VoidCallback onComplete;

  const PhaseProgressView({
    super.key,
    required this.planId,
    required this.subjectNames,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(planProgressProvider(planId));

    return progressAsync.when(
      loading: () => _buildBody(context, cs, 'pending', 0.0),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('规划生成失败：$e', style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(planProgressProvider(planId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (progress) {
        final status = progress['status'] as String? ?? 'pending';
        final pct = (progress['progress'] as num?)?.toDouble() ?? 0.0;
        final errorMsg = progress['error'] as String?;

        if (status == 'done') {
          // 规划完成，通知父组件切换到计划表视图
          WidgetsBinding.instance.addPostFrameCallback((_) => onComplete());
        }

        return _buildBody(context, cs, status, pct, errorMsg: errorMsg);
      },
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, String status, double pct, {String? errorMsg}) {
    final isDone = status == 'done';
    final isFailed = status == 'failed';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isFailed
                  ? cs.errorContainer
                  : isDone
                      ? cs.primaryContainer
                      : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: isFailed
                ? Icon(Icons.error_outline, size: 40, color: cs.error)
                : isDone
                    ? Icon(Icons.check_circle_outline, size: 40, color: cs.primary)
                    : const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
          ),
          const SizedBox(height: 24),

          // 标题
          Text(
            isFailed
                ? '规划生成失败'
                : isDone
                    ? '计划已生成！'
                    : '正在为你生成学习计划…',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isFailed
                ? (errorMsg != null ? '失败原因：$errorMsg' : '请检查网络后重试')
                : isDone
                    ? '即将跳转到计划表'
                    : '助教正在分析各学科知识点，请稍候',
            style: TextStyle(color: cs.outline, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // 进度条
          if (!isFailed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: isDone ? 1.0 : pct,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(pct * 100).floor()}%',
              style: TextStyle(fontSize: 13, color: cs.outline),
            ),
            const SizedBox(height: 24),
          ],

          // 学科状态卡片
          ...subjectNames.map((name) => _SubjectStatusCard(
                name: name,
                status: isDone ? 'done' : isFailed ? 'failed' : 'analyzing',
                cs: cs,
              )),
        ],
      ),
    );
  }
}

class _SubjectStatusCard extends StatelessWidget {
  final String name;
  final String status; // analyzing / done / failed
  final ColorScheme cs;

  const _SubjectStatusCard({
    required this.name,
    required this.status,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == 'done';
    final isFailed = status == 'failed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            isFailed
                ? Icons.error_outline
                : isDone
                    ? Icons.check_circle_outline
                    : Icons.hourglass_empty,
            size: 20,
            color: isFailed
                ? cs.error
                : isDone
                    ? cs.primary
                    : cs.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(
            isFailed ? '失败' : isDone ? '已完成' : '分析中…',
            style: TextStyle(
              fontSize: 12,
              color: isFailed ? cs.error : isDone ? cs.primary : cs.outline,
            ),
          ),
        ],
      ),
    );
  }
}
