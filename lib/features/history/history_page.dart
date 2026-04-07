import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/history_provider.dart';
import '../../routes/app_router.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('对话历史')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('暂无对话历史'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = sessions[i];
              return Card(
                child: ListTile(
                  leading: Text(s.typeLabel, style: const TextStyle(fontSize: 20)),
                  title: Text(s.title ?? '未命名对话'),
                  subtitle: Text(
                    '${s.createdAt.year}-${s.createdAt.month.toString().padLeft(2, '0')}-${s.createdAt.day.toString().padLeft(2, '0')} '
                    '${s.createdAt.hour}:${s.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 跳转到对应学科详情并加载该会话
                    if (s.subjectId != null) {
                      context.push(AppRoutes.subjectDetailPath(s.subjectId!));
                    }                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
