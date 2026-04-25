import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/review.dart';
import '../../providers/review_provider.dart';
import 'review_session_page.dart';
import 'review_queue_page.dart';

/// 复盘中心页面
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('复盘中心'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '待复盘'),
            Tab(text: '已复盘'),
            Tab(text: '复习队列'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingMistakesTab(),
          _ReviewedMistakesTab(),
          ReviewQueuePage(),
        ],
      ),
    );
  }
}

/// 待复盘 Tab
class _PendingMistakesTab extends ConsumerWidget {
  const _PendingMistakesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakesAsync = ref.watch(pendingMistakesProvider);

    return mistakesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (mistakes) {
        if (mistakes.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            title: '太棒了！',
            subtitle: '暂无待复盘的错题',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mistakes.length,
          itemBuilder: (context, index) {
            return _MistakeCard(
              mistake: mistakes[index],
              onTap: () => _startReview(context, mistakes[index]),
            );
          },
        );
      },
    );
  }

  void _startReview(BuildContext context, Mistake mistake) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionPage(mistake: mistake),
      ),
    );
  }
}

/// 已复盘 Tab
class _ReviewedMistakesTab extends ConsumerWidget {
  const _ReviewedMistakesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakesAsync = ref.watch(reviewedMistakesProvider);

    return mistakesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (mistakes) {
        if (mistakes.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: '暂无复盘记录',
            subtitle: '完成复盘后，错题会出现在这里',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mistakes.length,
          itemBuilder: (context, index) {
            return _MistakeCard(
              mistake: mistakes[index],
              onTap: () => _startReview(context, mistakes[index]),
              showMastery: true,
            );
          },
        );
      },
    );
  }

  void _startReview(BuildContext context, Mistake mistake) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionPage(mistake: mistake),
      ),
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

/// 错题卡片
class _MistakeCard extends StatelessWidget {
  final Mistake mistake;
  final VoidCallback onTap;
  final bool showMastery;

  const _MistakeCard({
    required this.mistake,
    required this.onTap,
    this.showMastery = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = mistake.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPending ? '待复盘' : '已复盘',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isPending
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ),
                  if (mistake.mistakeCategory != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _categoryLabel(mistake.mistakeCategory!),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (showMastery) _buildMasteryIndicator(mistake.masteryScore),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mistake.title ?? '错题',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (mistake.questionText != null) ...[
                const SizedBox(height: 8),
                Text(
                  mistake.questionText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(mistake.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (mistake.reviewCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.replay,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '复习 ${mistake.reviewCount} 次',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasteryIndicator(int score) {
    final color = _masteryColor(score);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$score/5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _masteryColor(int score) {
    if (score >= 4) return Colors.green;
    if (score >= 2) return Colors.orange;
    return Colors.red;
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'concept':
        return '概念模糊';
      case 'calculation':
        return '计算错误';
      case 'careless':
        return '粗心';
      case 'complete':
        return '完全不会';
      default:
        return category;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
