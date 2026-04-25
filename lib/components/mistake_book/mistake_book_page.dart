import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/review.dart';
import '../../providers/review_provider.dart';
import '../review/review_session_page.dart';

class MistakeBookPage extends ConsumerWidget {
  const MistakeBookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('错题本'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待复盘'),
              Tab(text: '已复盘'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingTab(),
            _ReviewedTab(),
          ],
        ),
      ),
    );
  }
}

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingMistakesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (mistakes) {
        if (mistakes.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            title: '暂无待复盘错题',
            subtitle: '做题时遇到的错题会自动出现在这里',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: mistakes.length,
          itemBuilder: (_, i) => _MistakeCard(
            mistake: mistakes[i],
            onTap: () => _startReview(context, mistakes[i]),
          ),
        );
      },
    );
  }

  void _startReview(BuildContext context, Mistake mistake) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewSessionPage(mistake: mistake)),
    );
  }
}

class _ReviewedTab extends ConsumerWidget {
  const _ReviewedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewedMistakesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (mistakes) {
        if (mistakes.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: '暂无已复盘记录',
            subtitle: '完成复盘后，错题会出现在这里',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: mistakes.length,
          itemBuilder: (_, i) => _MistakeCard(
            mistake: mistakes[i],
            showMastery: true,
            onTap: () => _startReview(context, mistakes[i]),
          ),
        );
      },
    );
  }

  void _startReview(BuildContext context, Mistake mistake) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewSessionPage(mistake: mistake)),
    );
  }
}

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
    final dateStr = DateFormat('yyyy-MM-dd').format(mistake.createdAt);
    final isPending = mistake.isPending;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mistake.title ?? mistake.content,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        if (mistake.reviewCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '复习 ${mistake.reviewCount} 次',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (showMastery) _MasteryChip(score: mistake.masteryScore),
              Chip(
                label: Text(isPending ? '待复盘' : '已复盘'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                ),
                backgroundColor: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasteryChip extends StatelessWidget {
  final int score;
  const _MasteryChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 4 ? Colors.green : score >= 2 ? Colors.orange : Colors.red;
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
          Icon(Icons.star, size: 12, color: color),
          const SizedBox(width: 3),
          Text('$score/5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

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
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}
