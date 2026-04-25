import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/review.dart';
import '../../providers/review_provider.dart';

/// 复习队列页面
class ReviewQueuePage extends ConsumerWidget {
  const ReviewQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(reviewQueueProvider);

    return queueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (queue) => _buildQueueContent(context, ref, queue),
    );
  }

  Widget _buildQueueContent(
    BuildContext context,
    WidgetRef ref,
    ReviewQueue queue,
  ) {
    if (queue.items.isEmpty) {
      return const _EmptyQueueState();
    }

    return CustomScrollView(
      slivers: [
        // 统计卡片
        SliverToBoxAdapter(
          child: _buildStatsCards(context, queue),
        ),
        // 复习列表
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ReviewCardItem(
                item: queue.items[index],
                onRate: (quality) => _rateCard(ref, queue.items[index].id, quality),
              ),
              childCount: queue.items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context, ReviewQueue queue) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '今日待复习',
                  value: '${queue.todayCount}',
                  subtitle: queue.overdueCount > 0
                      ? '其中 ${queue.overdueCount} 项已过期'
                      : '暂无积压',
                  color: queue.overdueCount > 0 ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '今日已完成',
                  value: '${queue.todayDone}',
                  subtitle: '正确率 ${queue.recallRate.toStringAsFixed(0)}%',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '已掌握',
                  value: '${queue.masteredCount}',
                  subtitle: '连续答对3次以上',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '总卡片数',
                  value: '${queue.totalCount}',
                  subtitle: '分布在各学科',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rateCard(WidgetRef ref, int cardId, int quality) async {
    final notifier = ref.read(reviewNotifierProvider.notifier);
    await notifier.rateCard(cardId: cardId, quality: quality);
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            '太棒了！',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无待复习的题目',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '去「练习」或「复盘」学习新知识吧',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 复习卡片项
class _ReviewCardItem extends StatefulWidget {
  final ReviewItem item;
  final Function(int quality) onRate;

  const _ReviewCardItem({
    required this.item,
    required this.onRate,
  });

  @override
  State<_ReviewCardItem> createState() => _ReviewCardItemState();
}

class _ReviewCardItemState extends State<_ReviewCardItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 难度/掌握度指示
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _masteryColor(item.masteryScore).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.masteryScore}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _masteryColor(item.masteryScore),
                          ),
                        ),
                        Text(
                          '/5',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nodeTitle ?? item.nodeId,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildChip(item.difficultyLabel, Colors.blue),
                            const SizedBox(width: 8),
                            if (item.isOverdue)
                              _buildChip('已过期', Colors.red)
                            else
                              Text(
                                _formatNextReview(item.nextReview),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // 展开的评分区域
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这次答得怎么样？',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QualityButton(
                        label: '忘了',
                        quality: 0,
                        color: Colors.red,
                        onTap: () => widget.onRate(0),
                      ),
                      const SizedBox(width: 8),
                      _QualityButton(
                        label: '模糊',
                        quality: 1,
                        color: Colors.orange,
                        onTap: () => widget.onRate(1),
                      ),
                      const SizedBox(width: 8),
                      _QualityButton(
                        label: '想起',
                        quality: 2,
                        color: Colors.blue,
                        onTap: () => widget.onRate(2),
                      ),
                      const SizedBox(width: 8),
                      _QualityButton(
                        label: '巩固',
                        quality: 3,
                        color: Colors.green,
                        onTap: () => widget.onRate(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _masteryColor(int score) {
    if (score >= 4) return Colors.green;
    if (score >= 2) return Colors.orange;
    return Colors.red;
  }

  String _formatNextReview(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) {
      return '已过期';
    } else if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '明天';
    } else {
      return '${diff.inDays}天后';
    }
  }
}

/// 评分按钮
class _QualityButton extends StatelessWidget {
  final String label;
  final int quality;
  final Color color;
  final VoidCallback onTap;

  const _QualityButton({
    required this.label,
    required this.quality,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }
}
