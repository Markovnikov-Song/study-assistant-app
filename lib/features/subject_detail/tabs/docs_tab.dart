import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/document.dart';
import '../../../providers/document_provider.dart';

class DocsTab extends ConsumerWidget {
  final int subjectId;
  const DocsTab({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider(subjectId));
    final uploadState = ref.watch(documentActionsProvider(subjectId));

    // 显示错误
    ref.listen(documentActionsProvider(subjectId), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：${next.error}'), backgroundColor: Colors.red),
        );
        ref.read(documentActionsProvider(subjectId).notifier).clearError();
      }
    });

    return Column(
      children: [
        // 上传区
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: OutlinedButton.icon(
            onPressed: uploadState.isUploading
                ? null
                : () => ref.read(documentActionsProvider(subjectId).notifier).pickAndUpload(),
            icon: uploadState.isUploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: Text(uploadState.isUploading ? '上传中…' : '上传资料（PDF / Word / PPT / TXT / MD）'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: OutlinedButton.icon(
            onPressed: uploadState.isUploading
                ? null
                : () async {
                    try {
                      await ref.read(documentActionsProvider(subjectId).notifier).reindexAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已触发重新索引，请稍候…')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('重新索引失败：$e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新索引全部（修复检索不到的问题）'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
          ),
        ),
        const Divider(height: 1),
        // 处理中进度条
        if (docsAsync.maybeWhen(
          data: (docs) => docs.any((d) =>
              d.status == DocumentStatus.pending ||
              d.status == DocumentStatus.processing),
          orElse: () => false,
        ))
          const LinearProgressIndicator(),
        // 文件列表
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (docs) {
              if (docs.isEmpty) {
                return const Center(child: Text('暂无资料，请上传文件'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _DocCard(doc: docs[i], subjectId: subjectId),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocCard extends ConsumerWidget {
  final StudyDocument doc;
  final int subjectId;
  const _DocCard({required this.doc, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: _statusIcon(doc.status),
        title: Text(doc.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.statusLabel),
            if (doc.error != null)
              Text(doc.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.status == DocumentStatus.completed)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: '重新索引',
                onPressed: () async {
                  try {
                    await ref.read(documentActionsProvider(subjectId).notifier).reindex(doc.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('重新索引中…')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('失败：$e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case DocumentStatus.processing:
        return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
      case DocumentStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case DocumentStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除「${doc.filename}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(documentActionsProvider(subjectId).notifier).delete(doc.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败：$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
