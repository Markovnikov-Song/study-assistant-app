import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notebook.dart';
import '../../providers/notebook_provider.dart';
import 'widgets/notebook_card.dart';
import 'note_create_page.dart';

class NotebookListPage extends ConsumerWidget {
  const NotebookListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotebooks = ref.watch(notebookListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记本'),
        actions: [
                    TextButton.icon(
                      onPressed: () => _openNotePage(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('新建'),
          ),
        ],
      ),
      body: asyncNotebooks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (notebooks) => _NotebookListBody(notebooks: notebooks),
      ),
    );
  }

    void _openNotePage(BuildContext context, WidgetRef ref) {
    // 逻辑：如果已经有笔记本列表，优先打开第一个非系统的笔记本；如果没有，则使用 ID 1
    final notebooks = ref.read(notebookListProvider).maybeWhen(
      data: (list) => list,
      orElse: () => <Notebook>[],
    );
    
        final targetId = notebooks.where((n) => !n.isSystem).firstOrNull?.id 
        ?? notebooks.firstOrNull?.id 
        ?? 1;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteCreatePage(
          notebookId: targetId,
        ),
      ),
    );
  }
}

class _NotebookListBody extends ConsumerWidget {
  const _NotebookListBody({required this.notebooks});
  final List<Notebook> notebooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = notebooks.where((n) => !n.isArchived).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
        return b.createdAt.compareTo(a.createdAt);
      });
    final archived = notebooks.where((n) => n.isArchived).toList();

    return ListView(
      children: [
        // ── 所有未归档笔记本（可拖拽排序）──────────────────────
        if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无笔记本，点击右上角"新建"创建', style: TextStyle(color: Colors.grey))),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;
              final notifier = ref.read(notebookListProvider.notifier);
              final reordered = List<Notebook>.from(active);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              for (var i = 0; i < reordered.length; i++) {
                if (reordered[i].sortOrder != i) {
                  await notifier.updateNotebook(reordered[i].id, sortOrder: i);
                }
              }
            },
            children: active.map((nb) => NotebookCard(
              key: ValueKey(nb.id),
              notebook: nb,
              onPin: () => ref.read(notebookListProvider.notifier).updateNotebook(nb.id, isPinned: !nb.isPinned),
              onArchive: () => ref.read(notebookListProvider.notifier).updateNotebook(nb.id, isArchived: true),
              onDelete: () => _confirmDelete(context, ref, nb),
            )).toList(),
          ),

        // ── 已归档分组（折叠）────────────────────────────────────
        if (archived.isNotEmpty)
          ExpansionTile(
            title: Text('已归档（${archived.length}）'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            children: archived.map((nb) => NotebookCard(
              key: ValueKey('archived_${nb.id}'),
              notebook: nb,
              onPin: () => ref.read(notebookListProvider.notifier).updateNotebook(nb.id, isPinned: !nb.isPinned),
              onArchive: () => ref.read(notebookListProvider.notifier).updateNotebook(nb.id, isArchived: false),
              onDelete: () => _confirmDelete(context, ref, nb),
            )).toList(),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Notebook nb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记本'),
        content: Text('确定要删除"${nb.name}"吗？该笔记本下的所有笔记也将被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notebookListProvider.notifier).deleteNotebook(nb.id);
    }
  }
}
