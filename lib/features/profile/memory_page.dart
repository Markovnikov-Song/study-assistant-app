import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

// Provider：获取指定学科（或全局）的记忆
final memoryProvider = FutureProvider.family<Map<String, dynamic>, int?>((ref, subjectId) async {
  final dio = DioClient.instance.dio;
  final res = await dio.get(
    '/api/chat/memory',
    queryParameters: subjectId != null ? {'subject_id': subjectId} : null,
  );
  return (res.data['memory'] as Map<String, dynamic>?) ?? {};
});

class MemoryPage extends ConsumerWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 全局记忆（subject_id=null）
    final memoryAsync = ref.watch(memoryProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习记忆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除记忆',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: memoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (memory) => memory.isEmpty
            ? _EmptyMemory()
            : _MemoryContent(memory: memory),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除学习记忆'),
        content: const Text('AI 将忘记你的学习偏好和薄弱点，下次对话会重新积累。确定清除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DioClient.instance.dio.delete('/api/chat/memory');
        ref.invalidate(memoryProvider(null));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记忆已清除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败：$e')),
          );
        }
      }
    }
  }
}

class _EmptyMemory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('暂无学习记忆', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '多和 AI 对话后，它会逐渐了解你的学习特点',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MemoryContent extends StatelessWidget {
  final Map<String, dynamic> memory;
  const _MemoryContent({required this.memory});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (memory['summary'] != null) ...[
          _SectionCard(
            icon: Icons.person_outline,
            title: '画像摘要',
            child: Text(memory['summary'] as String, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 12),
        ],
        if (_list(memory['weak_points']).isNotEmpty) ...[
          _SectionCard(
            icon: Icons.warning_amber_outlined,
            title: '薄弱知识点',
            iconColor: Colors.orange,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _list(memory['weak_points'])
                  .map((e) => Chip(
                        label: Text(e),
                        backgroundColor: Colors.orange.shade50,
                        side: BorderSide(color: Colors.orange.shade200),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_list(memory['frequent_topics']).isNotEmpty) ...[
          _SectionCard(
            icon: Icons.tag,
            title: '常问话题',
            iconColor: Colors.blue,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _list(memory['frequent_topics'])
                  .map((e) => Chip(
                        label: Text(e),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide(color: Colors.blue.shade200),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (memory['learning_style'] != null) ...[
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: '学习偏好',
            iconColor: Colors.green,
            child: Text(memory['learning_style'] as String),
          ),
          const SizedBox(height: 12),
        ],
        if (_list(memory['misconceptions']).isNotEmpty) ...[
          _SectionCard(
            icon: Icons.error_outline,
            title: '常见误解',
            iconColor: Colors.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _list(memory['misconceptions'])
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.red)),
                            Expanded(child: Text(e)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          '记忆由 AI 从你的对话中自动提取，每次对话后更新',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<String> _list(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  const _SectionCard({required this.icon, required this.title, required this.child, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
