import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/rag_sync_settings_provider.dart';

/// 学科设置 Tab — RAG 自动同步开关
class SettingsTab extends ConsumerWidget {
  final int subjectId;
  const SettingsTab({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ragSyncSettingsProvider(subjectId));
    final notifier = ref.read(ragSyncSettingsProvider(subjectId).notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'RAG 知识库同步',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        SwitchListTile(
          title: const Text('讲义自动同步'),
          subtitle: const Text('保存讲义后自动导入资料库，供问答/解题使用'),
          value: settings.autoSyncLecture,
          onChanged: (v) => notifier.setAutoSyncLecture(v),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '开关默认关闭。建议内容整理完毕后再开启，避免草稿污染知识库。',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}
